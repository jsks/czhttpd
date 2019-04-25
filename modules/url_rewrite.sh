# Module for url rewrite
###

# Declare module defaults
typeset -gi URL_REWRITE

: ${URL_REWRITE:=0}

if [[ $URL_REWRITE != [01] ]]; then
    log_err "Invalid value for URL_REWRITE, expected 0|1"
    return 1
fi

if ! zmodload zsh/pcre 2>/dev/null; then
    log_err "pcre module missing, unable to source url_rewrite"
    return
fi

rename_fn srv cz::srv

function srv() {
    if (( URL_REWRITE )); then
        for i in ${(k)URL_PATTERNS}; do
            if [[ $req_headers[url] -pcre-match $i ]]; then
                log_f "rewrite match: $req_headers[url] -> ${URL_PATTERNS[$i]}"
                cz::srv ${URL_PATTERNS[$i]}; return $?
            fi
        done
    fi

    cz::srv $req_headers[url]; return $?
}
