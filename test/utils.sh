# Utility functions/variables for testing czhttpd
###

setopt local_options

typeset -g SRC_DIR TESTTMP TESTROOT CONF PORT

: ${SRC_DIR:=$(git rev-parse --show-toplevel)}
: ${TESTTMP:=/tmp/cztest-$$}
: ${TESTROOT:=/tmp/czhttpd-test}
: ${CONF:=$TESTROOT/cz.conf}
: ${PORT:=8080}

typeset -g PID
integer -g debugfd

function error() {
    print "$*" >&2
    exit 115
}

function start_server() {
    setopt noerr_return

    zsh -f $SRC_DIR/czhttpd -v -p $PORT -c $CONF $TESTROOT >&$debugfd &
    typeset +r -g PID=$!
    readonly -g PID

    # Cache current czhttpd pid for Makefile
    print $PID > $SRC_DIR/.czhttpd-pid
}

function stop_server() {
    [[ -z $PID ]] && return 0

    kill -15 $PID
    sleep 0.1
    kill -0 $PID 2>/dev/null && return 1 || return 0
}

function heartbeat() {
    repeat 3; do
        sleep 0.1
        if ! kill -0 $PID 2>/dev/null; then
            (( PORT++ ))
            start_server
        else
            return 0
        fi
    done

    return 1
}

function reload_conf() {
    kill -HUP $PID
    heartbeat
}

function cleanup() {
    setopt noerr_return
    stop_server

    [[ $TESTROOT == "/tmp/czhttpd-test" ]] && rm -rf $TESTROOT
    [[ $TESTTMP == "/tmp/cztest-$$" ]] && rm -rf $TESTTMP

    rm -rf $SRC_DIR/.czhttpd-pid
}

trap "sleep 0.1; cleanup 2>/dev/null; exit" INT TERM KILL EXIT ZERR
