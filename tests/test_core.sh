<<EOF > $CONF
MAX_CONN=12
PORT=8080
IP_REDIRECT="[0-9*].[0-9*].[0-9*].[0-9*]"
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
INDEX_FILE=index.html
HIDDEN_FILES=0
FOLLOW_SYMLINKS=0
CACHE=0
CACHE_DIR="/tmp/.czhttpd-$$"
LOG_FILE=/dev/null
EOF

print "Hello" > $TESTROOT/index.html

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
check "Redirection" \
       http_code 301 \
       127.0.0.1:$PORT/dir
check "Incomplete request line" \
       http_code 400 \
       --method " " 127.0.0.1:$PORT
check "Dot file request" \
       http_code 403 \
       127.0.0.1:$PORT/.dot.txt
check "Nonexistent file/dir" \
       http_code 404 \
       127.0.0.1:$PORT/foo
check "Test unknown method" \
       http_code 501 \
       --method "PUT" 127.0.0.1:$PORT
check "HTTP/1.0 request" \
       http_code 505 \
       --http 1.0 127.0.0.1:$PORT
check "Keep alive enabled" \
       header_compare 'Connection: keep-alive' \
       127.0.0.1:$PORT

rm $TESTROOT/index.html

<<EOF > $CONF
MAX_CONN=0
HTTP_KEEP_ALIVE=0
EOF
reload_conf

check "Keep alive disabled" \
       header_compare 'Connection: close' \
       127.0.0.1:$PORT
check "Check maxed out connections" \
       http_code 503 \
       127.0.0.1:$PORT

<<EOF > $CONF
MAX_CONN=4
HTTP_KEEP_ALIVE=1
HTTP_BODY_SIZE=5
HIDDEN_FILES=1
FOLLOW_SYMLINKS=1
CACHE=1
EOF
reload_conf

ln -s $TESTROOT/file.txt $TESTROOT/link

check "Request with cache" \
       http_code 200 \
       127.0.0.1:$PORT
check "Hidden_files request" \
       http_code 200 \
       127.0.0.1:$PORT/.dot.txt
check "Request with symbolic link" \
       http_code 200 \
       127.0.0.1:$PORT/link
check "Symbolic link integrity" \
       file_compare $TESTROOT/file.txt \
       127.0.0.1:$PORT/link
check "Request body too large" \
       http_code 413 \
       --data 'Hello World!' 127.0.0.1:$PORT
check "Request body smaller than content-length" \
       http_code 400 \
       --data 'HH' --header 'Content-Length: 3' 127.0.0.1:$PORT
check "Request body just right" \
       http_code 200 \
       --data 'HH' 127.0.0.1:$PORT
unlink $TESTROOT/link
