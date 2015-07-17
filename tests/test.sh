#!/bin/zsh
# Testing script for czhttpd. Individual tests split into test_*.sh.

autoload colors
(( $terminfo[colors] >= 8 )) && colors

zmodload zsh/stat
zmodload zsh/system

setopt err_return

integer debugfd COUNTER=1
typeset -g PID

function assert() {
    if [[ $2 =~ $1 ]]; then
        print "$fg[green]Passed$fg[white]"
    else
        print "$fg[red]Failed$fg[white]"
    fi
}

function error() {
    print "$*" >&2
    exit 115
}

function help() {
<<EOF
czhttpd test script

Options:
    -l | --log          Redirect czhttpd output to given file
    -p | --port         Port to pass to czhttpd (Default: 8080)
    -s | --stepwise     Pause after specified test. Argument can also be a comma
                        deliminated list of tests or ranges of tests
                        (ex: -s 2,4,6-9)
    -v | --verbose      Enable verbose output
EOF

exit
}

###
# You know what would make a lot of sense? To use curl. But why do that when we
# can write our own nonconformant http client!
function get_http() {
    chttp::parse_args $*

    chttp::connect
    chttp::send_request
    chttp::read_response
    ztcp -c
}

###
# Makes a request to our server and tests the output. Comparisons are a simple
# pass or fail.
#   Available to test:
#       - file_compare
#       - header_compare
#       - http_code
#       - size_download
#
#   @Args -> $1 Description string for the test
#            $2 Type of comparison
#            $3 Expected value (can be a pattern)
#            $4 Arguments to pass to our http_client (ex url)
#
# Welcome to shell scripting!
function check() {
    local output

    output="$TESTTMP/${@[-1]:t}.output"
    get_http --output $output $@[4,-1]

    print -n "$fg[cyan]$COUNTER. $fg[blue]($3)$fg[white] $1 $ret[url_effective]..."
    case $2 in
        ("file_compare")
            assert $(md5 -q ${3:A}) $(md5 -q $output);;
        ("header_compare")
            assert ${(Lz)3[(ws.:.)2]} ${CHTTP_RESP_HEADERS[${(L)3[(ws.:.)1]}]};;
        ("size_download")
            assert $3 $CHTTP_DOWNLOAD_SIZE;;
        ("http_code")
            assert $3 ${CHTTP_RESP_HEADERS[status_line][(w)2]};;
        (*)
            print "Unknown comparison type: $2"
            return 1;;
    esac

    (( VERBOSE )) && info
    [[ -n ${STEPWISE[(r)$COUNTER]} ]] && { read -k '?Press any key to continue...' }

    (( COUNTER++ ))
}

function info() {
    chttp::print_headers
    print "$fg[yellow]Download size:$fg[white] $CHTTP_DOWNLOAD_SIZE"
    printf "$fg[yellow]Times:$fg[white]  %.3fs connect\n\t%.3fs send\n\
        %.3fs first_byte\n\t%.3fs download\n" \
        $(chttp::calc_time connect) $(chttp::calc_time send) \
        $(chttp::calc_time first_byte) \
        $(chttp::calc_time download)
    printf "\t$fg[magenta]%.3fs Total Time$fg[white]\n" \
        $(( $(chttp::calc_time connect) + $(chttp::calc_time send) \
        + $(chttp::calc_time download) ))
}

function start_server() {
    zsh $SRC_DIR/czhttpd -v -p $PORT -c $CONF $TESTROOT >&$debugfd &
    PID=$!
}

function heartbeat() {
    repeat 3; do
        sleep 0.1
        if ! kill -0 $PID 2>/dev/null; then
            ((PORT++))
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
    kill -15 $PID
    rm -rf $TESTTMP $TESTROOT
}

zparseopts -D -A opts -verbose v -stepwise: s: -log: l: -port: p: -help h || error "Failed to parse args"

for i in ${(k)opts}; do
    case $i in
        ("--stepwise"|"-s")
            typeset -a STEPWISE

            for i in ${(s.,.)opts[$i]}; do
                if [[ -n ${(SM)i#-} ]]; then
                    for j in {${i[(ws.-.)1]}..${i[(ws.-.)2]}}; do
                        [[ $j == <-> ]] && STEPWISE+=$j
                    done
                elif [[ $i == <-> ]]; then
                    STEPWISE+=($i)
                fi
            done;;
        ("--verbose"|"-v")
            VERBOSE=1;;
        ("--log"|"-l")
            if [[ -f $opts[$i] ]]; then
                : >> $opts[$i]
                exec {debugfd}>>$opts[$i]
            else
                error "Invalid logfile"
            fi;;
        ("--port"|"-p")
            if [[ $opts[$i] == <-> ]]; then
                typeset -g PORT=$opts[$i]
            else
                error "Invalid port $opts[$i]"
            fi;;
        ("--help"|"-h")
            help;;
    esac
done

: ${PORT:=8080}
: ${VERBOSE:=0}
[[ $debugfd  == 0 ]] && exec {debugfd}>/dev/null

SRC_DIR=$(git rev-parse --show-toplevel)

source $SRC_DIR/http_client

trap "cleanup 2>/dev/null; exit" INT TERM KILL EXIT ZERR

TESTTMP=/tmp/cztest-$$
mkdir "$TESTTMP"

TESTROOT=/tmp/czhttpd-test
mkdir $TESTROOT

CONF="$TESTROOT/cz.conf"
: > $CONF

mkdir $TESTROOT/dir
print hello > $TESTROOT/file.txt
print goodbye > $TESTROOT/.dot.txt
ln -s $TESTROOT/file.txt $TESTROOT/link

start_server
heartbeat

for i in ${1:-$SRC_DIR/tests/test_*.sh}; do
    print "$fg[magenta]$i$fg[white]"
    source $i
done
