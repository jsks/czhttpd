#!/bin/zsh

autoload colors
(( $terminfo[colors] >= 8 )) && colors

zmodload zsh/stat
zmodload zsh/system

setopt err_return

integer debugfd
typeset -g PID

function assert() {
    if [[ $1 == $2 ]]; then
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
    -l | --log      Redirect czhttpd output to given file
    -p | --port     Port to pass to czhttpd (Default: 8080)
    -v | --verbose  Enable verbose output
EOF

exit
}

function get_http() {
    chttp::parse_args $*

    chttp::connect
    chttp::send_request
    chttp::read_response
    ztcp -c
}

function check() {
    local output

    output="$TESTROOT/${@[-1]:t}.output"
    get_http --output $output $@[4,-1]

    print -n "$fg[blue]($3)$fg[white] $1 $ret[url_effective]..."
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
    (( STEPWISE )) && { read -k '?Press any key to continue...' }

    rm $output
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
    zsh ../czhttpd -p $PORT -c $CONF $TESTROOT >&$debugfd &
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
    rm -rf $TESTROOT
}

zparseopts -D -A opts -verbose v -stepwise s -log: l: -port: p: -help h || error "Failed to parse args"

for i in ${(k)opts}; do
    case $i in
        ("--stepwise"|"-s")
            typeset -g STEPWISE=1;;
        ("--verbose"|"-v")
            typeset -g VERBOSE=1;;
        ("--log"|"-l")
            [[ -f $opts[$i] ]] && exec {debugfd}>>$opts[$i] || error "Invalid logfile";;
        ("--port"|"-p")
            [[ $opts[$i] == <-> ]] && typeset -g PORT=$opts[$i] || error "Invalid port $opts[$i]";;
        ("--help"|"-h")
            help;;
    esac
done

: ${PORT:=8080}
: ${VERBOSE:=0}
[[ $debugfd  == 0 ]] && exec {debugfd}>/dev/null

. ../http_client

trap "cleanup 2>/dev/null; exit" INT TERM KILL EXIT ZERR

TESTROOT=/tmp/czhttpd-test
mkdir $TESTROOT

CONF="$TESTROOT/cz.conf"
: > $CONF

mkdir $TESTROOT/dir
print hello > $TESTROOT/file.txt
print goodbye > $TESTROOT/.dot.txt

start_server
heartbeat

for i in ${1:-test_*.sh}; do
    print "$fg[magenta]$i$fg[white]"
    . ./$i
done
