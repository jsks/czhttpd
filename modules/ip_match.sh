# IP filtering module. Reject client connections from IPs not matching
# `$IP_ACCEPT`.
###

# Declare module defaults
typeset -gi IP_MATCH
typeset -g IP_ACCEPT

: ${IP_MATCH:=0}
: ${IP_ACCEPT:=.*}

if [[ $IP_MATCH != [01] ]]; then
    log_err "Invalid integer for IP_MATCH"
    return 1
fi

rename_fn parse_ztcp cz::parse_ztcp

function parse_ztcp() {
    cz::parse_ztcp
    (( ! IP_MATCH )) && return

    if [[ $client_ip != "0.0.0.0" && ! $client_ip =~ $IP_ACCEPT ]]; then
        log_f "Disconnected unmatched ip"
        ztcp -c $fd

        # Gotta love shell. Continue the main loop in czhttpd
        continue
    fi
}
