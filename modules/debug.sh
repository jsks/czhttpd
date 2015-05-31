# Debugging module

: ${DEBUG:=0}
: ${DEBUG_NUCLEAR:=0}

if (( $DEBUG != 1 )); then
    return
fi

setopt warn_create_global debug_before_cmd

if (( $DEBUG_NUCLEAR == 1 )); then
    set -x
fi

function log_dbg() {
    print "${(e@)LOG_FORMAT} DEBUG -> $*" >/dev/tty
}

function log_headers() {
    log_dbg $(print -r "request headers...\n"; for i in ${(k)req_headers}; print -r "$i: $req_headers[$i]\n")
}

function TRAPDEBUG() {
    unsetopt err_return
    local cmd args total

    cmd=${ZSH_DEBUG_CMD[(ws. .)1]}
    args=${ZSH_DEBUG_CMD[(ws. .)2,-1]%%[\|\&]*}

    case $cmd in
        ('conn_list+=$!')
            log_dbg "new connection [$!]; $((${#conn_list} + 1)) total connection(s)";;
        ('srv')
            srv_hook "${DOCROOT}$(urldecode $req_headers[url])";;
        ('send_file')
            log_dbg "$cmd: sent $pathname static, size $fsize";;
        ('send_chunk')
            log_dbg "$cmd: sent $pathname chunked";;
        ('return_header')
            return_header_hook $args;;
    esac

    return
}

function TRAPCHLD() {
    for i in $conn_list; do
        if ! kill -0 $i 2>/dev/null; then
            conn_list=(${conn_list#$i})
            log_dbg "[$i] disconnected; ${#conn_list} total connection(s)"
        fi
    done
}

function return_header_hook() {
    local buf
    local -a headers response

    headers=(${(ps.\".)*})
    buff="${$(return_header ${(e@)headers})}"

    for i in ${(f)buff}; [[ $i =~ [a-zA-Z0-9] ]] && response+=("$i")

    log_dbg "$(print -r "$cmd: response headers...\n${(pj.\n.)response[@]//$'\r'/}")"
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

    log_dbg "$cmd: requested resource $1 is $msg"
}

function index_hook() {
    log_dbg "$cmd: found ${(e)*} $PWD"
}
