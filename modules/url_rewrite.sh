# Module for url rewrite
###

: ${URL_REWRITE:=0}
zmodload zsh/pcre

rename_fn srv cz::srv

function srv() {
    if [[ $URL_REWRITE == 1 ]]; then
        for i in ${(k)URL_PATTERNS}; do
            if [[ $req_headers[url] -pcre-match $i ]]; then
                log_f "rewrite match: $req_headers[url] -> ${URL_PATTERNS[$i]}"
                cz::srv ${URL_PATTERNS[$i]}; return $?
            fi
        done
    fi

    cz::srv $req_headers[url]; return $?
}
