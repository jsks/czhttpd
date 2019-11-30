#!/usr/bin/env zsh
#
# Stress test/benchmark czhttpd using vegeta
# (https://github.com/tsenart/vegeta)
###

if [[ -t 1 ]] && (( $terminfo[colors] >= 8 )); then
    autoload colors
    colors
fi

which vegeta >/dev/null || error "Missing vegeta, unable to run stress tests"

typeset -g VEGETA_OPTS VERBOSE DURATION

# Output directories
readonly -g STRESS_DIR=${0:A:h}
readonly -g REPORT_DIR=$STRESS_DIR/report
readonly -g HTML_DIR=$STRESS_DIR/html

# Import common testing functions/variables
source $STRESS_DIR/../utils.sh

mkdir -p $TESTTMP $TESTROOT
: >> $CONF

function help() {
<<EOF
Usage: stress.sh [OPTIONS] [file]

czhttpd stress test and benchmarking script

Options:
    -d | --duration   Vegeta attack duration (default: 5s)
    -h | --help       This help message
    -l | --log        Redirect czhttpd output to given file
    -p | --port       Port to pass to czhttpd (Default: 8080)
    -v | --verbose    Enable verbose output

Actual tests are split into separate stress_*.sh files which will be sourced by
this script. To run only a subset of tests, a specific file can be provided as
a CLI argument. Otherwise, by default, all tests will be run.

EOF

exit
}

function attack() {
    echo "GET http://127.0.0.1:$PORT/" | \
        vegeta attack -name=$1 "${=VEGETA_OPTS}" > $REPORT_DIR/$1.bin

    (( VERBOSE )) && vegeta report $REPORT_DIR/$1.bin

    return 0
}

function describe() {
    (( VERBOSE )) && print "$fg_bold[blue]$*$fg_no_bold[white]"

    return 0
}

zparseopts -D -A opts -duration: d: -verbose v -log: l: -port: p: -help h || error "Failed to parse args"

for i in ${(k)opts}; do
    case $i in
        ("--duration|-d")
            DURATION=$opts[$i];;
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

(( ! debugfd )) && exec {debugfd}>/dev/null
: ${DURATION:="5s"}
: ${VERBOSE:=0}

VEGETA_OPTS="-duration=$DURATION -http2=false -timeout=10s"

# Preserve TESTROOT across tests
root=$TESTROOT
readonly -g root

# For single file stress tests
for i in {1..10000}; str+="lorem ipsum"
print $str > $TESTROOT/test.html

# For directory listing stress tests
for i in {a..z}; print -n "Hello World!" > $TESTROOT/$i.html

# Prep output directories
mkdir -p $REPORT_DIR $HTML_DIR
rm -rf $REPORT_DIR/*.bin(N) $HTML_DIR/*.html(N)

# If we don't specify an individual test file, run everything
for i in ${1:-$STRESS_DIR/stress_*.sh}; do
    print "$fg_bold[magenta]${i:t}$fg_no_bold[white]"
    source $i
done

vegeta plot $REPORT_DIR/*.bin > $HTML_DIR/full.html
