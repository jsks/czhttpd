#!/usr/bin/env zsh

source ${0:A:h}/utils.sh

typeset -g TESTROOT=""
typeset -g CONF="./_cz_test.conf"

<<EOF > $CONF
DEBUG=1
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=(parse_request srv)
source $SRC_DIR/modules/debug.sh

IP_REDIRECT=127.0.0.1
MAX_CONN=12
HTTP_KEEP_ALIVE=1
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
CACHE=0
EOF

exec {debugfd}>&1

start_server
heartbeat

wait $PID
