# url_rewrite
<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=($TRACE_FUNCS)
source $SRC_DIR/modules/debug.sh

MAX_CONN=12
PORT=$PORT
IP_REDIRECT="127.0.0.1"
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=2
HTTP_RECV_TIMEOUT=1
HTTP_BODY_SIZE=16384
INDEX_FILE=0
HIDDEN_FILES=1
FOLLOW_SYMLINKS=0
CACHE=1
CACHE_DIR="/tmp/.czhttpd-$$"
LOG_FILE=/dev/null

typeset -g COMPRESS=0
typeset -g CGI_ENABLE=0
typeset -g URL_REWRITE=1

typeset -gA URL_PATTERNS
URL_PATTERNS=( "/file.txt" "/.dot.txt" )
source $SRC_DIR/modules/url_rewrite.sh
EOF
reload_conf

describe "URL rewrite"
check 127.0.0.1:$PORT/file.txt \
      --http_code 200 \
      --file_compare $TESTROOT/.dot.txt \
      --header_compare 'Content-type: text/plain'

# gzip
<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=($TRACE_FUNCS)
source $SRC_DIR/modules/debug.sh

URL_REWRITE=0
CGI_ENABLE=0
COMPRESS=1

typeset -g COMPRESS_TYPES="text/html,text/plain"
typeset -g COMPRESS_LEVEL=6
typeset -g COMPRESS_MIN_SIZE=100
typeset -g COMPRESS_CACHE=1
typeset -g COMPRESS_CACHE_DIR="/tmp/.czhttpd-$$"
source $SRC_DIR/modules/compress.sh
EOF
reload_conf

for i in {1..1000}; str+="lorem ipsum "

print $str > $TESTROOT/compress.txt
gzip -k -6 $TESTROOT/compress.txt

describe "Compress file request"
check --header 'Accept-Encoding: gzip' 127.0.0.1:$PORT/compress.txt \
      --http_code 200 \
      --file_compare $TESTROOT/compress.txt.gz \
      --header_compare 'Content-Encoding: gzip'

describe "Compress dir request"
check --header 'Accept-Encoding: gzip' 127.0.0.1:$PORT \
      --http_code 200 \
      --header_compare 'Content-Encoding: gzip'

describe "Cached dir request"
check --header 'Accept-Encoding: gzip' 127.0.0.1:$PORT \
      --header_compare 'Content-Length: [0-9]'

rm $TESTROOT/compress.txt $TESTROOT/compress.txt.gz

# CGI Module
<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=($TRACE_FUNCS)
source $SRC_DIR/modules/debug.sh

URL_REWRITE=0
COMPRESS=0
CGI_ENABLE=1

typeset -g CGI_EXTS="sh"
typeset -g CGI_TIMEOUT=2
source $SRC_DIR/modules/cgi.sh
EOF
reload_conf

<<EOF > $TESTROOT/test_app.sh
#!/bin/zsh
print "Content-type: text/plain\n\n"
print "Hello World"
EOF
chmod +x $TESTROOT/test_app.sh

<<EOF > $TESTROOT/test_app_fail1.sh
#!/bin/zsh
print "Content-type: text/plain\n\n"
sleep 7
print "foo"
EOF
chmod +x $TESTROOT/test_app_fail1.sh

<<EOF > $TESTROOT/test_app_fail2.sh
#!/bin/zsh
print
print "foo"
EOF
chmod +x $TESTROOT/test_app_fail2.sh

describe "Test cgi script"
check 127.0.0.1:$PORT/test_app.sh \
      --http_code 200 \
      --size_download 13

describe "Test cgi script fail by timeout"
check 127.0.0.1:$PORT/test_app_fail1.sh \
      --http_code 500

describe "Test cgi script fail by content-type"
check 127.0.0.1:$PORT/test_app_fail2.sh \
      --http_code 500

rm $TESTROOT/*.sh
