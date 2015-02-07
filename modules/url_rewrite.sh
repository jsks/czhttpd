# Module for url rewrite

: ${URL_REWRITE:=1}
zmodload zsh/pcre
! typeset -f srv >/dev/null && function srv() { url_rewrite $* }

function url_rewrite() {
    if [[ $URL_REWRITE == 1 ]]; then
        for i in ${(k)URL_PATTERNS}; do
            if [[ $req_headers[url] -pcre-match $i ]]; then
                log_f "rewrite match: $req_headers[url] -> ${URL_PATTERNS[$i]}"
                __srv ${URL_PATTERNS[$i]}; return $?
            fi
        done
    fi

    __srv $req_headers[url]; return $?
}
