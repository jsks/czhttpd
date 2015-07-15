# url_rewrite
<<EOF > $CONF
HIDDEN_FILES=1
COMPRESS=0
CGI_ENABLE=0
DEBUG=0
URL_REWRITE=1
typeset -gA URL_PATTERNS
URL_PATTERNS=( "/file.txt" "/.dot.txt" )
source ../modules/url_rewrite.sh
EOF
reload_conf

check "URL rewrite status code" \
       http_code 200 \
       127.0.0.1:$PORT/file.txt
check "URL rewrite file integrity" \
       file_compare $TESTROOT/.dot.txt \
       127.0.0.1:$PORT/file.txt

# gzip
<<EOF > $CONF
URL_REWRITE=0
CGI_ENABLE=0
DEBUG=0
COMPRESS=1
COMPRESS_TYPES="text/html,text/plain"
COMPRESS_LEVEL=6
COMPRESS_MIN_SIZE=100
source ../modules/compress.sh
EOF
reload_conf

for i in {1..1000}; str+="lorem ipsum "

print $str > $TESTROOT/compress.txt
gzip -k -6 $TESTROOT/compress.txt

check "Compress file request" \
       http_code 200 \
       --header 'Accept-Encoding: gzip' 127.0.0.1:$PORT/compress.txt
check "Compress header check" \
       header_compare 'Content-Encoding: gzip' \
       --header 'Accept-Encoding: gzip' 127.0.0.1:$PORT/compress.txt
check "Compress dir request" \
       http_code 200 \
       --header 'Accept-Encoding: gzip' 127.0.0.1:$PORT
check "Check compressed file integrity" \
       file_compare $TESTROOT/compress.txt.gz \
       --header 'Accept-Encoding: gzip' --header 'Accept-leng: sdf' 127.0.0.1:$PORT/compress.txt
rm $TESTROOT/compress.txt $TESTROOT/compress.txt.gz

# CGI Module
<<EOF > $CONF
URL_REWRITE=0
COMPRESS=0
DEBUG=0
CGI_ENABLE=1
CGI_EXTS="sh"
CGI_TIMEOUT=2
source ../modules/cgi.sh
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

check "Test cgi script" \
       http_code 200 \
       127.0.0.1:$PORT/test_app.sh
check "Test cgi output size" \
       size_download 13 \
       127.0.0.1:$PORT/test_app.sh
check "Test cgi script fail by timeout" \
       http_code 500 \
       127.0.0.1:$PORT/test_app_fail1.sh
check "Test cgi content-type" \
       http_code 500 \
       127.0.0.1:$PORT/test_app_fail2.sh
rm $TESTROOT/{test_app.sh,test_app_fail1.sh,test_app_fail2.sh}
