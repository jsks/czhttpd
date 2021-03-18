####################################################################
# Stress test concurrent connections. Will be sourced by `test.sh` #
####################################################################

<<EOF > $CONF
MAX_CONN=12
HTTP_KEEP_ALIVE=0
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0
EOF

TESTROOT=$root/test.html
restart_server

# Default number connections
describe "Multiple connections with MAX_CONN = 12"
attack -rate="500/1s" default_max_conn

<<EOF > $CONF
MAX_CONN=30
HTTP_KEEP_ALIVE=0
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0
EOF

restart_server

# Increased number connections
describe "Multiple connections with MAX_CONN = 30"
attack -rate="500/1s" 30_max_conn

# Finally
vegeta plot $REPORT_DIR/*_conn.bin > $HTML_DIR/max_conn.html
