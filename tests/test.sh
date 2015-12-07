#!/usr/bin/zsh
# Testing script for czhttpd. Individual tests split into test_*.sh.

autoload colors
(( $terminfo[colors] >= 8 )) && colors

zmodload zsh/stat
zmodload zsh/system

setopt err_return

typeset -gA STATS
STATS[count]=0
STATS[pass]=0
STATS[fail]=0

integer debugfd
typeset -g PID

function assert() {
    if [[ $3 =~ $2 ]]; then
        (( STATS[pass]++ )) || :
        if (( VERBOSE )); then
            print "$fg[green]Passed$fg[white]: $i ($fg[blue]$opts[$i]$fg[white])"
        fi
    else
        (( STATS[fail]++ )) || :
        RET=1
        print "$fg[red]Failed$fg[white]: $i ($fg[blue]$opts[$i]$fg[white])"
    fi
}

function md5hash () {
    if [[ $OSTYPE == linux* ]]; then
        md5sum $1 | cut -d ' ' -f1
    else
        md5 -q $1
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
    -t | --trace        Enable function tracing for the following comma
                          deliminated list of czhttpd functions
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
#   @Options -> --file_compare
#               --header_compare
#               --http_code
#               --size_download
#   Everything else gets sent as args to `get_http`
function check() {
    local -A opts
    local output i
    zparseopts -E -D -A opts -file_compare: -header_compare: -size_download: -http_code:

    output="$TESTTMP/${@[-1]:t}.output"
    get_http --output $output $*

    for i in ${(k)opts}; do
        case $i in
            ("--file_compare")
                assert $i $(md5hash ${opts[$i]:A}) $(md5hash $output);;
            ("--header_compare")
                assert $i ${(Lz)opts[$i][(ws.:.)2]} \
                    ${CHTTP_RESP_HEADERS[${(L)opts[$i][(ws.:.)1]}]};;
            ("--size_download")
                assert $i $opts[$i] $CHTTP_DOWNLOAD_SIZE;;
            ("--http_code")
                assert $i $opts[$i] ${CHTTP_RESP_HEADERS[status_line][(w)2]};;
        esac
    done

    (( VERBOSE )) && info
    [[ -n ${STEPWISE[(r)$STATS[count]]} ]] && { read -k '?Press any key to continue...' }
}

function describe() {
    (( STATS[count]++ )) || :
    print "$fg[cyan]$STATS[count]$fg[white]. $*"
}

function info() {
    print
    print "URL: $CHTTP_URL"
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

function print_stats() {
<<EOF
$fg[blue]Total Tests$fg[white]: $STATS[count], \
$fg[blue]Assertions$fg[white]: $(( STATS[pass] + STATS[fail] )) -> \
$fg[green]$STATS[pass] Passed$fg[white], \
$fg[red]$STATS[fail] Failed$fg[white]
EOF
}

function start_server() {
    setopt noerr_return

    zsh $SRC_DIR/czhttpd -v -p $PORT -c $CONF $TESTROOT >&$debugfd &
    PID=$!
}

function stop_server() {
    kill -15 $PID
    sleep 0.1
    kill -0 $pid 2>/dev/null && return 1 || return 0
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
    stop_server
    rm -rf $TESTTMP $TESTROOT
}

zparseopts -D -A opts -verbose v -stepwise: s: -trace: t: -log: l: -port: p: -help h || error "Failed to parse args"

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
        ("--trace"|"-t")
            typeset -a TRACE_FUNCS
            for i in ${(s.,.)opts[$i]}; TRACE_FUNCS+=(${(z)i});;
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

trap "sleep 0.1; cleanup 2>/dev/null; exit" INT TERM KILL EXIT ZERR

TESTTMP=/tmp/cztest-$$
mkdir "$TESTTMP"

TESTROOT=/tmp/czhttpd-test
mkdir $TESTROOT

CONF="$TESTROOT/cz.conf"
: > $CONF

mkdir $TESTROOT/dir
print hejsan > $TESTROOT/index.html
print hello > $TESTROOT/file.txt
print hallå > $TESTROOT/file_pröva.txt
print space > $TESTROOT/file\ space.txt
print goodbye > $TESTROOT/.dot.txt
ln -s $TESTROOT/file.txt $TESTROOT/link

start_server
heartbeat

for i in ${1:-$SRC_DIR/tests/test_*.sh}; do
    print "$fg[magenta]$i$fg[white]"
    source $i
done

print_stats
# Allow all tests to finish, but return w/ err if necessary
return ${STATS[fail]:-0}
