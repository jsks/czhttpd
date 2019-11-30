####################################################################
# Stress test concurrent connections. Will be sourced by `test.sh` #
####################################################################

VEGETA_OPTS+=" -rate=500/1s -keepalive=false"

<<EOF > $CONF
MAX_CONN=1
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0
EOF

stop_server
TESTROOT=$root/test.html
start_server
heartbeat


# Single connection
describe "Multiple connections with MAX_CONN = 1"
attack single_multiple

vegeta plot $REPORT_DIR/single_multiple.bin > $HTML_DIR/single_multiple.html

<<EOF > $CONF
MAX_CONN=12
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0
EOF

# Clean testing env
stop_server
start_server
heartbeat

# Default number connections
describe "Multiple connections with MAX_CONN = 12"
attack default_multiple

vegeta plot $REPORT_DIR/default_multiple.bin > $HTML_DIR/default_multiple.html

<<EOF > $CONF
MAX_CONN=48
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=0
HTML_CACHE=0
EOF

stop_server
start_server
heartbeat

# Increased number connections
describe "Multiple connections with MAX_CONN = 30"
attack max_multiple

vegeta plot $REPORT_DIR/max_multiple.bin > $HTML_DIR/max_multiple.html

# Finally
vegeta plot $REPORT_DIR/*_multiple.bin > $HTML_DIR/multiple.html
