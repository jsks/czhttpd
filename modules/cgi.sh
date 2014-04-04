# Module to handle cgi scripts

# Declare our default variables
: ${CGI_ENABLE:=1}
: ${CGI_EXTS:="php"}
: ${CGI_TIMEOUT=300}

function cgi_handler() {
    if check_if_cgi $1; then
        exec_cgi $1 || <&p >/dev/null
    else
        return 1
    fi
}

function check_if_cgi() {
    [[ -z $CGI_EXTS || $CGI_ENABLE == 0 ]] && return 1

    [[ $CGI_TIMEOUT != <-> ]] && { log_err "Invalid integer for CGI_TIMEOUT"; return 1 }

    for i in ${(s.,.)CGI_EXTS}; [[ ${1##*.} == $i ]] && break

    [[ $? != 0 || ! -x $1 ]] && return 1

    return 0
}

function exec_cgi() {
    unset cgi_head cgi_status_code
    typeset -ga cgi_head
    typeset -g cgi_status_code

    local cmd pid

    local -x CONTENT_LENGTH="${req_headers[content-length]:-NULL}" CONTENT_TYPE="$req_headers[content-type]" GATEWAY_INTERFACE="$GATEWAY_INTERFACE" QUERY_STRING="${req_headers[querystr]#\?}" REMOTE_ADDR="$client_ip" REMOTE_HOST="NULL" REQUEST_METHOD="$req_headers[method]" SCRIPT_NAME="${1#$DOCROOT}" SERVER_NAME="$SERVER_NAME" SERVER_ADDR="$SERVER_ADDR" SERVER_PORT="$PORT" SERVER_PROTOCOL="$SERVER_PROTOCOL" SERVER_SOFTWARE="$SERVER_SOFTWARE"

    local -x DOCUMENT_ROOT="$DOCROOT" REQUEST_URI="$req_headers[url]$req_headers[querystr]" SCRIPT_FILENAME="$1" REDIRECT_STATUS=1

    for i in ${(k)req_headers}; do
        case $i in
            ("connection"|"content-length"|"content-type"|"querystr")
                continue;;
            ("method"|"version"|"url")
                continue;;
            (*)
                local -x HTTP_${(U)i:gs/\-/\_}="$req_headers[$i]";;
        esac
    done

    [[ ${1##*.} == "php" ]] && cmd="php-cgi"

    log_f "Executing cgi script $1"
    coproc { timeout $cmd "$1" <&$fd }
    pid=$!

    while read -r -p line; do
        [[ -z $line || $line == $'\r' ]] && break
        [[ $line =~ "Status:*" ]] && cgi_status_code=${line#Status: }
        cgi_head+=${line%$'\r'}
    done

    if [[ -z ${(M)${cgi_head:l}:#content-type*} ]]; then
        log_err "cgi script $1 failed to return a mime-type"
        return_header 500
        return
    fi

    log_f ${cgi_status_code:-"200"}
    return_header ${cgi_status_code:-"200 Ok"} "Transfer-Encoding: chunked" $cgi_head[@]
    send_chunk <&p

    if ! wait $pid; then
        log_err "executing cgi script $1 failed"
        return_header 500
        return
    fi
}
