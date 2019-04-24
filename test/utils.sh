# Utility functions/variables for testing czhttpd
###

setopt local_options

typeset -g SRC_DIR TESTTMP TESTROOT CONF PORT

: ${SRC_DIR:=$(git rev-parse --show-toplevel)}
: ${TESTTMP:=/tmp/cztest-$$}
: ${TESTROOT:=/tmp/czhttpd-test}
: ${CONF:=$TESTROOT/cz.conf}
: ${PORT:=8080}

integer -gi PID debugfd

function alive() {
    kill -0 $1 2>/dev/null
}

function error() {
    print "$*" >&2
    exit 115
}

function start_server() {
    setopt noerr_return

    if [[ -f $SRC_DIR/.czhttpd-pid ]] &&
           alive $(<$SRC_DIR/.czhttpd-pid); then
        error "czhttpd already running?"
    fi

    zsh -f $SRC_DIR/czhttpd -v -p $PORT -c $CONF $TESTROOT >&$debugfd &
    typeset +r -g PID=$!
    readonly -g PID

    # Cache current czhttpd pid for Makefile
    print $PID > $SRC_DIR/.czhttpd-pid
}

function stop_server() {
    if [[ -z $PID ]] || ! alive $PID; then
        return 0
    fi

    kill -15 $PID
    sleep 0.1
    ! alive $PID
}

function heartbeat() {
    repeat 3; do
        sleep 0.1
        if ! alive $PID; then
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

    # Only delete default TESTROOT and TESTTMP
    [[ -d "/tmp/czhttpd-test" ]] && rm -rf "/tmp/czhttpd-test"
    [[ -d "/tmp/cztest-$$" ]] && rm -rf "/tmp/cztest-$$"

    rm -rf $SRC_DIR/.czhttpd-pid
}

trap "cleanup; exit" INT TERM KILL EXIT ZERR
