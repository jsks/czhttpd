# Debugging module
#
# Allows us to check...
#   - client request
#   - response headers
#   - stats (bytes in/out, total/current connections)
# Also, selectively turn on function tracing.

# Everything in here is a hack.
#####

: ${DEBUG:=0}

if (( $DEBUG != 1 )); then
    return
fi

setopt warn_create_global

###
# DBG_IN -> array[child pid] = bytes read
# DBG_OUT -> array[child pid] = bytes sent
#   - Both are extremely rough estimates since we won't actually be measuring
#     how many bytes read/sent through socket
typeset -gA DBG_IN DBG_OUT
typeset -gi DBG_CONN_COUNT

typeset -gi dbg_fifofd
typeset -g dbg_sfile

# Ignore the following compound statements in TRAPDEBUG
typeset -ga dbg_ignore_list
dbg_ignore_list=(if else elif then while for select repeat until do case function coproc \(\) \( \{)

dbg_sfile="/tmp/czhttpd-stats-$$.$RANDOM"

mkfifo $dbg_sfile || { print "Unable to initialize debug.sh"; return }
exec {dbg_fifofd}<>$dbg_sfile
rm $dbg_sfile 2>/dev/null

function dbg_add() {
    print "$sysparams[pid] $*" >&$dbg_fifofd
}

function log_dbg() {
    local cur_time
    get_time

    print "[$cur_time] [pid: ${pid:-$sysparams[pid]}] Debug -> $*" >&$logfd
}

function log_headers() {
    local -a str
    local -i size
    local i

    for i in ${(k)req_headers}; do
        str+=("${(C)i}: $req_headers[$i]")

        if [[ $i == ("method"|"url"|"querystr"|"version"|"msg-body") ]]; then
            (( size += ${#req_headers[$i]} ))
        else
            (( size += ${#i} + ${#req_headers[$i]} + 4 ))
        fi
    done

    dbg_add "read $size"
    log_dbg "request headers...\n${(pj.\n.)str}"
}

function return_header_hook() {
    local buf
    local -a headers response

    buff="$(return_header $@)"
    for i in ${(f)buff}; do
        if [[ $i =~ [a-zA-Z0-9] ]]; then
            dbg_add "sent $(( ${#i} + 2 ))"
            response+=("$i")
        fi
    done

    log_dbg "$(print -r "$dbg_cmd: response headers...\n${(pj.\n.)response[@]//$'\r'/}")"
}

function srv_hook() {
    local msg

    log_headers

    if [[ ! -e $1 ]]; then
        msg="nonexistent"
    elif [[ -f $1 ]]; then
        msg="file"
    elif [[ -d $1 ]]; then
        msg="directory"
    elif [[ -h $1 ]]; then
        msg="symbolic link"
    else
        msg="unknown type"
    fi

    log_dbg "$dbg_cmd: requested resource $1 is $msg"
}

# This function will be run everywhere, take special care with namespace
function debug_handler() {
    setopt extended_glob
    unsetopt err_return

    local dbg_cmd dbg_args dbg_i

    dbg_cmd=${ZSH_DEBUG_CMD[(w)1]}
    if [[ ${(w)#ZSH_DEBUG_CMD} > 1 ]]; then
        dbg_args=${ZSH_DEBUG_CMD[(w)2,-1]}
    fi

    for dbg_i in $DEBUG_TRACE_FUNCS; do
        if [[ -n $funcstack[(r)$dbg_i] ]]; then
            if [[ $dbg_cmd != ${(~j.|.)dbg_ignore_list} ]]; then
                log_dbg "+$functrace[1]> $dbg_cmd ${(e)dbg_args}"
            fi
        fi
    done

    case $dbg_cmd in
        ('conn_list+=$!')
            (( DBG_CONN_COUNT++ ))
            log_dbg "new connection ($!); $((${#conn_list} + 1)) current connection(s)";;
        ('printf')
            if [[ $dbg_args == "'%x"* ]]; then
                dbg_add "sent $(( ${#buff} + 2 ))"
            fi;;
        ('srv')
            srv_hook "${DOCROOT}$(urldecode $req_headers[url])";;
        ('send_file')
            dbg_add "sent $fsize"
            log_dbg "$dbg_cmd: $pathname";;
        ('send_chunk')
            log_dbg "$dbg_cmd: $pathname";;
        ('return_header')
            return_header_hook ${(eps.\".)dbg_args};;
    esac
}

function TRAPCHLD() {
    local i line

    while read -t 0 -u $dbg_fifofd line; do
        case ${line[(w)2]} in
            ("sent")
                (( DBG_OUT[${line[(w)1]}] += ${line[(w)3]} ));;
            ("read")
                (( DBG_IN[${line[(w)1]}] += ${line[(w)3]} ));;
        esac
    done

    for i in $conn_list; do
        if ! kill -0 $i 2>/dev/null; then
            conn_list=(${conn_list#$i})
            log_dbg "($i) disconnected; ${#conn_list} current connection(s)"
            log_dbg "($i) Sent: ${DBG_OUT[$i]:-0} Read: ${DBG_IN[$i]:-0}"
            log_dbg "TOTAL Sent: $(( ${(vj.+.)DBG_OUT} )) Read: $(( ${(vj.+.)DBG_IN} ))"
            log_dbg "served $DBG_CONN_COUNT connection(s) overall"
        fi
    done
}

# Let's preserve our positional parameters
trap 'debug_handler $@' DEBUG
