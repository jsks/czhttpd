# Debugging module
#
# Everything in here is a hack. It would be nice to get function tracing, but
# since xtrace is sent to stderr, it ends up getting caught by log_err.
#####

: ${DEBUG:=0}

if (( $DEBUG != 1 )); then
    return
fi

###
# DBG_IN -> array[child pid] = bytes read
# DBG_OUT -> array[child pid] = bytes sent
#   - Both are extremely rough estimates since we won't actually measuring how
#     many bytes read/sent through socket
typeset -gA DBG_IN DBG_OUT
typeset -gi DBG_CONN_COUNT

typeset -gi dbg_fifofd
typeset -g dbg_sfile

dbg_sfile="/tmp/czhttpd-stats-$$.$RANDOM"

mkfifo $dbg_sfile || { print "Unable to initialize debug.sh"; return }
exec {dbg_fifofd}<>$dbg_sfile
rm $dbg_sfile 2>/dev/null

function log_dbg() {
    local cur_time
    get_time

    print "[$cur_time] [pid: ${pid:-$sysparams[pid]}] Debug -> $*" >&$logfd
}

function log_headers() {
    local -a str
    local -i size

    for i in ${(k)req_headers}; do
        str+=("${(C)i}: $req_headers[$i]")

        if [[ $i =~ ("method"|"url"|"querystr"|"version"|"msg-body") ]]; then
            (( size += ${#req_headers[$i]} ))
        else
            (( size += ${#i} + ${#req_headers[$i]} + 4 ))
        fi
    done

    print -u $dbg_fifofd "$sysparams[pid] read $size"
    log_dbg "request headers...\n${(pj.\n.)str}"
}

# This function will be run everywhere, take special care with namespace
function TRAPDEBUG() {
    setopt extended_glob
    unsetopt err_return

    typeset -ga dbg_pos
    local dbg_cmd dbg_args dbg_i

    dbg_cmd=${ZSH_DEBUG_CMD[(w)1]}
    dbg_args=(${(z)ZSH_DEBUG_CMD[(w)2,-1]%%[\|\&<]*})

    # We need to be able to expand the original positional parameters, so save
    # everything to `pos` and override when available
    if [[ -n $dbg_pos ]]; then
        for ((dbg_i = 1; dbg_i <= ${#dbg_pos}; dbg_i++)); do
            eval $dbg_i=${(q)dbg_pos[$dbg_i]}
        done
    fi

    case $dbg_cmd in
        ('conn_list+=$!')
            (( DBG_CONN_COUNT++ ))
            log_dbg "new connection ($!); $((${#conn_list} + 1)) current connection(s)";;
        ('printf')
            if [[ $dbg_args == "'%x"* ]]; then
                print -u $dbg_fifofd "$sysparams[pid] sent $(( ${#buff} + 2 ))"
            fi;;
        ('srv')
            srv_hook "${DOCROOT}$(urldecode $req_headers[url])";;
        ('send_file')
            print -u $dbg_fifofd "$sysparams[pid] sent $fsize"
            log_dbg "$dbg_cmd: $pathname";;
        ('send_chunk')
            log_dbg "$dbg_cmd: $pathname";;
        ('return_header')
            return_header_hook ${(eQ)dbg_args};;
    esac

    if functions $dbg_cmd >/dev/null; then
        dbg_pos=()
        for dbg_i in ${(e)dbg_args}; do
            dbg_pos+=($dbg_i)
        done
    fi
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

function return_header_hook() {
    local buf
    local -a headers response

    buff="$(return_header ${(e)@})"
    for i in ${(f)buff}; [[ $i =~ [a-zA-Z0-9] ]] && response+=("$i")

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
