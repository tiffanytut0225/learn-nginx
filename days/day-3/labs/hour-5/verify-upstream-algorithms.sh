#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

backend_for() {
    request_uri="$1"
    curl --silent --show-error \
        --max-time 5 \
        --output /dev/null \
        --dump-header - \
        "${base_url}${request_uri}" \
    | awk 'BEGIN { IGNORECASE = 1 } /^X-Backend:/ { print $2 }' \
    | tr -d '\r'
}

rr_sequence=""
for number in 1 2 3 4; do
    backend="$(backend_for "/round-robin/request-${number}")"
    rr_sequence="${rr_sequence}${backend}"
done

if [ "$rr_sequence" != 'ABAB' ]; then
    printf 'FAIL round-robin expected=ABAB actual=%s\n' "$rr_sequence"
    exit 1
fi
printf 'PASS round-robin sequence=%s\n' "$rr_sequence"
passed=$((passed + 1))

slow_headers="$(mktemp)"
trap 'rm -f "$slow_headers"' EXIT

curl --silent --show-error \
    --max-time 5 \
    --output /dev/null \
    --dump-header "$slow_headers" \
    "${base_url}/least/slow" &
slow_pid=$!

sleep 0.3
fast_backend="$(backend_for /least/fast)"
wait "$slow_pid"
slow_backend="$(
    awk 'BEGIN { IGNORECASE = 1 } /^X-Backend:/ { print $2 }' "$slow_headers" \
    | tr -d '\r'
)"

if [ -z "$slow_backend" ] || [ -z "$fast_backend" ] || [ "$slow_backend" = "$fast_backend" ]; then
    printf 'FAIL least-conn slow=%s fast=%s\n' "$slow_backend" "$fast_backend"
    exit 1
fi
printf 'PASS least-conn slow=%s fast=%s\n' "$slow_backend" "$fast_backend"
passed=$((passed + 1))

sticky_backend="$(backend_for /sticky/request-1)"
for number in 2 3 4; do
    backend="$(backend_for "/sticky/request-${number}")"
    if [ "$backend" != "$sticky_backend" ]; then
        printf 'FAIL ip-hash expected=%s actual=%s\n' "$sticky_backend" "$backend"
        exit 1
    fi
done
printf 'PASS ip-hash same-source=%s\n' "$sticky_backend"
passed=$((passed + 1))

printf '\nResult: %d/3 upstream algorithm checks passed.\n' "$passed"
