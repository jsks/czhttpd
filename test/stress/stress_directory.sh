###############################################################
# Stress test directory serving. Will be sourced by `test.sh` #
###############################################################

<<EOF > $CONF
MAX_CONN=12
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0
EOF

TESTROOT=$root
restart_server

# Default directory listing
describe "Default directory serving"
attack default_directory

# Cache
<<EOF > $CONF
MAX_CONN=12
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=1
EOF
reload_conf

describe "Directory serving with caching"
attack cache_directory

# Compress directory
<<EOF > $CONF

MAX_CONN=12
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0

COMPRESS=1

typeset -g COMPRESS_TYPES="text/html,text/plain"
typeset -g COMPRESS_LEVEL=6
typeset -g COMPRESS_MIN_SIZE=100
typeset -g COMPRESS_CACHE=0
source $SRC_DIR/modules/compress.sh
EOF
reload_conf

describe "Directory serving with compression"
attack compress_directory

# Compress directory with cache
<<EOF > $CONF

MAX_CONN=12
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=1

COMPRESS=1

typeset -g COMPRESS_TYPES="text/html,text/plain"
typeset -g COMPRESS_LEVEL=6
typeset -g COMPRESS_MIN_SIZE=100
typeset -g COMPRESS_CACHE=1
source $SRC_DIR/modules/compress.sh
EOF
reload_conf

describe "Directory serving compression+cache"
attack compress+cache_directory

vegeta plot $REPORT_DIR/*_directory.bin > $HTML_DIR/directory_listing.html
