# Module to compress server output using gzip
###


# Declare our module defaults
typeset -gi COMPRESS COMPRESS_LEVEL COMPRESS_MIN_SIZE COMPRESS_CACHE
typeset -g COMPRESS_TYPES COMPRESS_CACHE_DIR

: ${COMPRESS:=0}
: ${COMPRESS_TYPES:="text/html,text/css,text/javascript"}
: ${COMPRESS_LEVEL:=6}
: ${COMPRESS_MIN_SIZE:=1000}
: ${COMPRESS_CACHE:=1}
: ${COMPRESS_CACHE_DIR:=/tmp/.czhttpd-$$}

if [[ $COMPRESS != [01] ]]; then
    log_err "Invalid integer for COMPRESS"
    return 1
fi

if [[ $COMPRESS_CACHE != [01] ]]; then
    log_err "Invalid integer for COMPRESS_CACHE"
    return 1
fi

if (( COMPRESS_CACHE )) && [[ ! -d $COMPRESS_CACHE_DIR ]]; then
    mkdir $COMPRESS_CACHE_DIR
fi

typeset -ga COMPRESS_TYPES_ARRAY=(${(s.,.)COMPRESS_TYPES})

rename_fn send cz::send

function send() {
    if ! check_if_compression $1; then
        cz::send $1; return $?
    fi

    if (( COMPRESS_CACHE )) && [[ -n $1 ]]; then
        private -a gzip_fsize
        private cache_file="$COMPRESS_CACHE_DIR/${1:gs/\//}.gz"

        if [[ ! -f $cache_file || $cache_file -ot $1 ]]; then
            mklock $cache_file
            gzip -$COMPRESS_LEVEL -c $1 > $cache_file
            rmlock $cache_file
        fi

        stat -A gzip_fsize -L +size $cache_file

        if (( HTTP_CACHE )); then
            private -a cache_headers=("Cache-Control: max-age=$HTTP_CACHE_AGE" \
                                       "Etag: $etag")
        fi

        return_headers 200 \
                       "Content-type: ${mtype:-application:octet-stream}; charset=UTF-8" \
                       "Content-Encoding: gzip" "Content-Length: $gzip_fsize" \
                       $cache_headers
        send_file $cache_file
    else
        return_headers 200 \
                       "Content-type: ${mtype:-application:octet-stream}; charset=UTF-8" \
                       "Content-Encoding: gzip" "Transfer-Encoding: chunked"
        gzip -$COMPRESS_LEVEL -c $1 | send_chunk
    fi

    log_f 200
}

function check_if_compression() {
    if (( ! COMPRESS )) || [[ -z ${(SM)req_headers[accept-encoding]#gzip} ]]; then
        return 1
    fi

    if [[ -n $1 ]] && (( fsize < COMPRESS_MIN_SIZE )); then
        return 1
    fi

    return 0
}
