# Module to compress server output using gzip

# Declare our module defaults
: ${COMPRESS:=0}
: ${COMPRESS_TYPES:="text/html,text/css,text/javascript"}
: ${COMPRESS_LEVEL:=6}
: ${COMPRESS_MIN_SIZE:=1000}
: ${COMPRESS_CACHE:=1}
: ${COMPRESS_CACHE_DIR:=/tmp/.czhttpd-$$}

function compression_init() {
    [[ ! -d $COMPRESS_CACHE_DIR ]] && mkdir $COMPRESS_CACHE_DIR
    [[ $COMPRESS_LEVEL != <-> ]] && { log_err "Invalid integer for COMPRESS_LEVEL"; return 1 }
    [[ $COMPRESS_MIN_SIZE != <-> ]] && { log_err "Invalid integer for COMPRESS_MIN_SIZE"; return 1 }
    [[ $COMPRESS_CACHE != [01] ]] && { log_err "Invalid integer for COMPRESS_CACHE"; return 1}

    function send() { compression_filter $* }
}

function compression_filter() {
    setopt null_glob

    if check_if_compression $1; then
        if [[ $COMPRESS_CACHE == "1" && -f $1 ]]; then
            local cache_file="$COMPRESS_CACHE_DIR/${1:gs/\//}-$(stat +mtime $1).gz"

            : >> $cache_file
            mklock $cache_file

            if [[ ! -s $cache_file ]]; then
                rm $COMPRESS_CACHE_DIR/${1:gs/\//.}-*.gz 2>/dev/null || :
                gzip -$COMPRESS_LEVEL -c $1 > $cache_file
            fi

            rmlock

            return_header "200 Ok" "Content-type: ${mtype:-application:octet-stream}; charset=UTF-8" "Content-Encoding: gzip" "Content-Length: $(stat -L +size $cache_file)"
            send_file $cache_file

        else
             return_header "200 Ok" "Content-type: ${mtype:-application:octet-stream}; charset=UTF-8" "Content-Encoding: gzip" "Transfer-Encoding: chunked"
            gzip -$COMPRESS_LEVEL -c $1 | send_chunk
        fi

        log_f "200"
    else
        __send $1
    fi
}

function check_if_compression() {
    [[ -z ${(SM)req_headers[accept-encoding]#gzip} || $COMPRESS == 0 ]] && return 1

    [[ ! -d $COMPRESS_CACHE_DIR ]] && { log_err "Compression cache directory does not exist"; return 1 }

    if [[ -f $1 ]]; then
        for i in ${(s.,.)COMPRESS_TYPES}; [[ $mtype == $i ]] && break

        if [[ $? != 0 ]] || (( $fsize < $COMPRESS_MIN_SIZE )); then
            return 1
        fi
    fi

    return 0
}

compression_init
