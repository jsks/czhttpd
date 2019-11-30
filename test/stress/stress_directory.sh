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

stop_server
TESTROOT=$root
start_server
heartbeat

# Default directory listing
describe "Default directory serving"
attack defaults_dir

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

describe "Directory listing with cache"
attack cache_dir

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

describe "Directory listing compression"
attack compress_dir

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

describe "Directory listing compression+cache"
attack compress_cache_dir

vegeta plot $REPORT_DIR/*_dir.bin > $HTML_DIR/directory_listing.html
