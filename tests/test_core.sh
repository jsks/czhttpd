# Set our default config vars in each testfile rather than `test.sh` so that we
# can guarantee the env no matter what order the tests are run.
<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=($TRACE_FUNCS)
source $SRC_DIR/modules/debug.sh

MAX_CONN=1
PORT=$PORT
IP_REDIRECT="127.0.0.1"
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=2
HTTP_RECV_TIMEOUT=1
HTTP_BODY_SIZE=16384
INDEX_FILE=index.html
HIDDEN_FILES=0
FOLLOW_SYMLINKS=0
CACHE=0
CACHE_DIR="/tmp/.czhttpd-$$"
LOG_FILE="/dev/null"
EOF
reload_conf

# Let's check normal file/dir serving first with a default conf
check "Check index file" \
       http_code 200 \
       127.0.0.1:$PORT
check "Check index file integrity" \
       file_compare $TESTROOT/index.html \
       127.0.0.1:$PORT
check "Directory request" \
       http_code 200 \
       127.0.0.1:$PORT/dir/
check "File request" \
       http_code 200 \
       127.0.0.1:$PORT/file.txt
check "File integrity" \
       file_compare $TESTROOT/file.txt \
       127.0.0.1:$PORT/file.txt
check "UTF8 file request" \
       http_code 200 \
       127.0.0.1:$PORT/file_pröva.txt
check "UTF8 file integrity" \
       file_compare $TESTROOT/file_pröva.txt \
       127.0.0.1:$PORT/file_pröva.txt
check "File with spaces request" \
       http_code 200 \
       127.0.0.1:$PORT/file\ space.txt
check "File with spaces integrity" \
       file_compare $TESTROOT/"file space.txt" \
       127.0.0.1:$PORT/file\ space.txt
check "Directory request" \
       http_code 200 \
       127.0.0.1:$PORT/dir/

# Let's go up the chain of http error codes
check "Redirection" \
       http_code 301 \
       127.0.0.1:$PORT/dir
check "Incomplete request line" \
       http_code 400 \
       --method " " 127.0.0.1:$PORT
check "Dot file disabled request" \
       http_code 403 \
       127.0.0.1:$PORT/.dot.txt
check "Symbolic link disabled request" \
       http_code 403 \
       127.0.0.1:$PORT/link
check "Nonexistent file/dir" \
       http_code 404 \
       127.0.0.1:$PORT/foo
check "Test unknown method" \
       http_code 501 \
       --method "PUT" 127.0.0.1:$PORT
check "HTTP/1.0 request" \
       http_code 505 \
       --http 1.0 127.0.0.1:$PORT

# Finally, let's check that our headers are being set properly
check "Client Connection: close" \
       header_compare 'Connection: close' \
       --header 'Connection: close' 127.0.0.1:$PORT
check "Client Connection: keep-alive" \
       header_compare 'Connection: keep-alive' \
       --header 'Connection: keep-alive' \
       127.0.0.1:$PORT
check "Server header" \
       header_compare 'Server: czhttpd' \
       --header 'Host: SuperAwesomeServer' 127.0.0.1:$PORT
check "File txt mimetype" \
       header_compare 'Content-type: text/plain' \
       127.0.0.1:$PORT/file.txt
check "File html mimetype" \
       header_compare 'Content-type: text/html' \
       127.0.0.1:$PORT/index.html
check "Dir html mimetype" \
       header_compare 'Content-type: text/html' \
       127.0.0.1:$PORT/dir/

rm $TESTROOT/index.html

# Restart our server so that DOCROOT is pointing to a single file
stop_server
TESTROOT=$TESTROOT/file.txt
start_server
heartbeat

check "Check serving single file" \
       http_code 200 \
       127.0.0.1:$PORT
check "Check integrity for serving single file" \
       file_compare $TESTROOT \
       127.0.0.1:$PORT

stop_server
TESTROOT=/tmp/czhttpd-test
start_server
heartbeat

<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=($TRACE_FUNCS)
source $SRC_DIR/modules/debug.sh

MAX_CONN=0
HTTP_KEEP_ALIVE=0
EOF
reload_conf

check "Keep alive disabled" \
       header_compare 'Connection: close' \
       --header 'Connection: keep-alive' 127.0.0.1:$PORT
check "Check maxed out connections" \
       http_code 503 \
       127.0.0.1:$PORT

# Let's enable some non-default config options
<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=($TRACE_FUNCS)
source $SRC_DIR/modules/debug.sh

MAX_CONN=4
HTTP_KEEP_ALIVE=1
HTTP_BODY_SIZE=5
HIDDEN_FILES=1
FOLLOW_SYMLINKS=1
CACHE=1
EOF
reload_conf

# Let's check that czhttpd is caching html files. The only way really is to see
# if the file is being sent with fixed length rather than chunked.
check "Request to build cache" \
       http_code 200 \
       127.0.0.1:$PORT
check "Check http code cache hit" \
       http_code 200 \
       127.0.0.1:$PORT
check "Check cache hit header" \
       header_compare 'Content-length: [0-9]' \
       127.0.0.1:$PORT

check "Enabled hidden files request" \
       http_code 200 \
       127.0.0.1:$PORT/.dot.txt
check "Enabled hidden files integrity" \
       file_compare $TESTROOT/.dot.txt \
       127.0.0.1:$PORT/.dot.txt
check "Request with symbolic link" \
       http_code 200 \
       127.0.0.1:$PORT/link
check "Symbolic link integrity" \
       file_compare $TESTROOT/file.txt \
       127.0.0.1:$PORT/link

# Check parsing request message body
check "Fixed request body too large" \
       http_code 413 \
       --data 'Hello World!' 127.0.0.1:$PORT
check "Fixed request body smaller than content-length" \
       http_code 400 \
       --data 'HH' --header 'Content-Length: 3' 127.0.0.1:$PORT
check "Fixed request body just right" \
       http_code 200 \
       --data 'HH' 127.0.0.1:$PORT
check "Chunked request body too large" \
       http_code 413 \
       --chunked --data 'Hello World!' 127.0.0.1:$PORT
check "Chunked request body just right" \
       http_code 200 \
       --chunked --data 'HH' 127.0.0.1:$PORT
