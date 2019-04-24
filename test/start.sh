#!/usr/bin/env zsh
#
# Quickly start czhttpd with preset config. This script is for the
# Make; it is not meant to be called directly.
###

source ${0:A:h}/utils.sh

typeset -g TESTROOT=""
typeset -g CONF="./_cz_test.conf"

: > $CONF

if [[ $1 == "--full-debug" ]]; then
<<EOF > $CONF
typeset -ga DEBUG_TRACE_FUNCS
DEBUG_TRACE_FUNCS=(parse_request srv)
EOF
fi

<<EOF >> $CONF
DEBUG=1
source $SRC_DIR/modules/debug.sh

IP_REDIRECT=127.0.0.1
MAX_CONN=12
HTTP_KEEP_ALIVE=0
HTTP_TIMEOUT=30
HTTP_RECV_TIMEOUT=5
HTTP_BODY_SIZE=16384
HTTP_CACHE=1
HTTP_MAX_AGE=10
HTML_CACHE=0
EOF

exec {debugfd}>&1

start_server
heartbeat

wait $PID
