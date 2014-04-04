# Module to compress server output using gzip

# Declare our module defaults
: ${COMPRESS:=1}
: ${COMPRESS_TYPES:="text/html,text/css,text/javascript"}
: ${COMPRESS_LEVEL:=6}
: ${COMPRESS_MIN_SIZE:=1000}

function compression_filter() {
    if check_if_compression $1; then
        return_header "200 Ok" "Content-type: $mtype; charset=UTF-8" "Content-Encoding: gzip" "Transfer-Encoding: chunked"
        if [[ $req_headers[method] != "HEAD" ]]; then
            if [[ -n $1 ]]; then
                gzip -$COMPRESS_LEVEL -c $1 | send_chunk
            else
                gzip -$COMPRESS_LEVEL -c | send_chunk
            fi
        fi
    else
        return 1
    fi
}

function check_if_compression() {
    [[ -z ${(SM)req_headers[accept-encoding]#gzip} || $COMPRESS == 0 ]] && return 1

    [[ $COMPRESS_LEVEL != <-> ]] && { log_err "Invalid integer for COMPRESS_LEVEL"; return 1 }
    [[ $COMPRESS_MIN_SIZE != <-> ]] && { log_err "Invalid integer for COMPRESS_MIN_SIZE"; return 1 }

    if [[ -f $1 ]]; then
        for i in ${(s.,.)COMPRESS_TYPES}; [[ $mtype == $i ]] && break

        if [[ $? != 0 ]] || (( $file_array[size] < $COMPRESS_MIN_SIZE )); then
            return 1
        fi
    fi

    return 0
}
