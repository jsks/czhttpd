#!/usr/bin/env zsh
#
# Testing script for czhttpd. Individual tests split into test_*.sh.
###

if [[ -t 1 ]] && (( $terminfo[colors] >= 8 )); then
    autoload colors
    colors
fi

for i in datetime pcre stat system; zmodload zsh/$i || exit 127

setopt rematch_pcre

typeset -gA STATS
STATS[count]=0
STATS[pass]=0
STATS[fail]=0

# Since we can't have arrays within arrays...
typeset -ga CONNECT_TIMES SEND_TIMES FBYTE_TIMES DOWNLOAD_TIMES

typeset -ga TRACE_FUNCS STEPWISE
typeset -g DESC_STR VERBOSE

readonly -g TEST_DIR=${0:A:h}

# Import common testing functions/variables
source $TEST_DIR/../utils.sh

mkdir -p $TESTTMP $TESTROOT
: >> $CONF

function assert() {
    if [[ $3 =~ $2 ]]; then
        (( STATS[pass]++ )) || :
        if (( pause || VERBOSE )); then
            assert_strs+="$fg[green]✓$fg[white] $i ($fg[blue]$opts[$i]$fg[white])"
        fi
    else
        (( STATS[fail]++ )) || :
        assert_strs+="$fg[red]✗$fg[white] $i ($fg[blue]$opts[$i]$fg[white])"
    fi

    return 0
}

function md5hash () {
    if [[ $OSTYPE == linux* ]]; then
        md5sum $1 | cut -d ' ' -f1
    else
        md5 -q $1
    fi
}

function unixtime() {
    strftime "%a, %d %b %Y %H:%M:%S GMT" ${1:-$EPOCHSECONDS}
}

function help() {
<<EOF
Usage: test.sh [OPTIONS] [file]

czhttpd integration test script

Options:
    -l | --log          Redirect czhttpd output to given file
    -h | --help         This help message
    -p | --port         Port to pass to czhttpd (Default: 8080)
    -s | --stepwise     Pause after specified test matching description or
                          order number. Argument can also be a comma
                          deliminated list of tests by number or ranges of
                          tests. (ex: -s 2,6-9,"Test unknown method")
    -t | --trace        Enable function tracing for the following comma
                          deliminated list of czhttpd functions
    -v | --verbose      Enable verbose output

Actual tests are split into separate test_*.sh files which will be sourced by
this script. To run only a subset of tests, a specific file can be provided as
a CLI argument. Otherwise, by default, all tests will be run.

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
#               --fail
#   Everything else gets sent as args to `get_http`
function check() {
    local -A opts
    local -a assert_strs
    local output i req_rv

    (( STATS[count]++ )) || :
    if [[ -n ${STEPWISE[(r)$STATS[count]]} ||
              ${STEPWISE[(r)$DESC_STR]} ]]; then
        local pause=1
    fi

    zparseopts -E -D -A opts -file_compare: -header_compare: -size_download: \
               -http_code: -fail

    output="$TESTTMP/${@[-1]:t}.output"
    get_http --output $output $* || req_rv=$?

    # If we don't explicitly want http_client to fail, error out
    # here. Really should provide better error messages...
    if [[ ${+opts[--fail]} == 0 && ${req_rv:-0} != 0 ]]; then
        error "$fg[cyan]$STATS[count]$fg[white]. $DESC_STR: $req_rv Error connecting to server"
    fi

    # Add to global arrays to keep track of timings for final stats
    CONNECT_TIMES+=$(chttp::calc_time connect)
    SEND_TIMES+=$(chttp::calc_time send)
    FBYTE_TIMES+=$(chttp::calc_time first_byte)
    DOWNLOAD_TIMES+=$(chttp::calc_time download)

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
            ("--fail")
                assert $i '[^0]' ${req_rv:-0};;
        esac
    done

    if (( pause || VERBOSE || ${#assert_strs} )); then
        print "$fg[cyan]$STATS[count]$fg[white]. $DESC_STR"
        for s in $assert_strs; print $s
        info
    fi

    (( pause )) && read -k '?Press any key to continue...'

    unset DESC_STR
    return 0
}

function describe() {
    typeset -g DESC_STR="$*"
}

function info() {
    print
    print "URL: $CHTTP_URL"
    chttp::print_headers
    print "$fg[yellow]Download size:$fg[white] $CHTTP_DOWNLOAD_SIZE"

    printf "$fg[yellow]Times:$fg[white]  %.2f ms connect\n\t%.2f ms send\n\
        %.2f ms first_byte\n\t%.2f ms download\n" \
        $CONNECT_TIMES[-1] $SEND_TIMES[-1] $FBYTE_TIMES[-1] $DOWNLOAD_TIMES[-1]
    printf "\t$fg[magenta]%.2f ms Total Time$fg[white]\n\n" \
        $(( $CONNECT_TIMES[-1] + $SEND_TIMES[-1] + \
              $FBYTE_TIMES[-1] + $DOWNLOAD_TIMES[-1] ))
}

function avg() {
    printf "%.2f ms" $(( (${(Pj.+.)1}) / ${(P)#1} ))
}

function print_stats() {
<<EOF
$fg[blue]Total Tests$fg[white]: $STATS[count], \
$fg[blue]Assertions$fg[white]: $(( STATS[pass] + STATS[fail] )) -> \
$fg_bold[green]$STATS[pass] ✓$fg_no_bold[white], \
$fg_bold[red]$STATS[fail] ✗$fg_no_bold[white]
EOF

   # Wrapping heredocs in conditionals is ugly, just return early if
   # verbose isn't set
(( !VERBOSE )) && return 0

<<EOF
$fg[magenta]Avg Times: $fg_bold[white]$(avg CONNECT_TIMES) $fg_no_bold[white]connect
           $fg_bold[white]$(avg SEND_TIMES) $fg_no_bold[white]send
           $fg_bold[white]$(avg FBYTE_TIMES) $fg_no_bold[white]first_byte
           $fg_bold[white]$(avg DOWNLOAD_TIMES) $fg_no_bold[white]download

EOF
}

zparseopts -D -A opts -verbose v -stepwise: s: -trace: t: -log: l: -port: p: -help h || error "Failed to parse args"

for i in ${(k)opts}; do
    case $i in
        ("--stepwise"|"-s")
            for i in ${(s.,.)opts[$i]}; do
                if [[ $i =~ "[0-9]{1,2}-[0-9]{1,2}" ]]; then
                    for j in {${i[(ws.-.)1]}..${i[(ws.-.)2]}}; do
                        STEPWISE+=$j
                    done
                else
                    STEPWISE+=($i)
                fi
            done;;
        ("--trace"|"-t")
            for i in ${(s.,.)opts[$i]}; TRACE_FUNCS+=(${(z)i});;
        ("--verbose"|"-v")
            VERBOSE=1;;
        ("--log"|"-l")
            : >> $opts[$i] 2>/dev/null || error "Invalid logfile"
            exec {debugfd}>>$opts[$i];;
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

(( ! debugfd )) && exec {debugfd} >/dev/null
: ${VERBOSE:=0}

source $SRC_DIR/test/http_client

mkdir $TESTROOT/dir
print hejsan > $TESTROOT/index.html
print hello > $TESTROOT/file.txt
print hallå > $TESTROOT/file_pröva.txt
print space > $TESTROOT/file\ space.txt
print goodbye > $TESTROOT/.dot.txt
ln -s $TESTROOT/file.txt $TESTROOT/link

# If we don't specify an individual test file, run everything
for i in ${1:-$TEST_DIR/test_*.sh}; do
    (( VERBOSE )) && print "$fg_bold[magenta]${i:t}$fg_no_bold[white]"
    source $i
done

print_stats

# Allow all tests to finish, but return w/ err if necessary
return ${STATS[fail]:-0}
