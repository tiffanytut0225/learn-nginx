#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

upstream_port_for() {
    request_uri="$1"
    curl --silent --show-error \
        --max-time 5 \
        --output /dev/null \
        --dump-header - \
        "${base_url}${request_uri}" \
    | awk 'BEGIN { IGNORECASE = 1 } /^X-Upstream-Client-Port:/ { print $2 }' \
    | tr -d '\r'
}

no_keepalive_ports=""
for number in 1 2 3 4; do
    port="$(upstream_port_for "/no-keepalive/request-${number}")"
    no_keepalive_ports="${no_keepalive_ports} ${port}"
done

unique_no_keepalive="$(
    printf '%s\n' $no_keepalive_ports \
    | sort -u \
    | wc -l \
    | tr -d ' '
)"

if [ "$unique_no_keepalive" -lt 2 ]; then
    printf 'FAIL no-keepalive ports=%s\n' "$no_keepalive_ports"
    exit 1
fi
printf 'PASS no-keepalive unique-ports=%s ports=%s\n' \
    "$unique_no_keepalive" "$no_keepalive_ports"
passed=$((passed + 1))

keepalive_ports=""
first_keepalive_port=""
for number in 1 2 3 4; do
    port="$(upstream_port_for "/keepalive/request-${number}")"
    keepalive_ports="${keepalive_ports} ${port}"

    if [ -z "$first_keepalive_port" ]; then
        first_keepalive_port="$port"
    elif [ "$port" != "$first_keepalive_port" ]; then
        printf 'FAIL keepalive expected-port=%s actual-port=%s\n' \
            "$first_keepalive_port" "$port"
        exit 1
    fi
done

printf 'PASS keepalive reused-port=%s ports=%s\n' \
    "$first_keepalive_port" "$keepalive_ports"
passed=$((passed + 1))

printf '\nResult: %d/2 upstream keepalive modes passed.\n' "$passed"
