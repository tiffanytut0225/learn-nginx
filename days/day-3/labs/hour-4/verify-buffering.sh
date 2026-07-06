#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

measure() {
    request_uri="$1"
    curl --silent --show-error \
        --max-time 8 \
        --output /dev/null \
        --write-out '%{time_starttransfer} %{time_total}' \
        "${base_url}${request_uri}"
}

assert_greater_than() {
    value="$1"
    threshold="$2"
    awk -v value="$value" -v threshold="$threshold" \
        'BEGIN { exit !(value > threshold) }'
}

assert_less_than() {
    value="$1"
    threshold="$2"
    awk -v value="$value" -v threshold="$threshold" \
        'BEGIN { exit !(value < threshold) }'
}

buffered="$(measure /buffered)"
buffered_ttfb="${buffered%% *}"
buffered_total="${buffered##* }"
assert_greater_than "$buffered_ttfb" 1.2
printf 'PASS buffered       ttfb=%ss total=%ss\n' "$buffered_ttfb" "$buffered_total"
passed=$((passed + 1))

unbuffered="$(measure /unbuffered)"
unbuffered_ttfb="${unbuffered%% *}"
unbuffered_total="${unbuffered##* }"
assert_less_than "$unbuffered_ttfb" 0.8
assert_greater_than "$unbuffered_total" 1.2
printf 'PASS unbuffered     ttfb=%ss total=%ss\n' "$unbuffered_ttfb" "$unbuffered_total"
passed=$((passed + 1))

header_controlled="$(measure /header-controlled)"
header_ttfb="${header_controlled%% *}"
header_total="${header_controlled##* }"
assert_less_than "$header_ttfb" 0.8
assert_greater_than "$header_total" 1.2
printf 'PASS x-accel-no     ttfb=%ss total=%ss\n' "$header_ttfb" "$header_total"
passed=$((passed + 1))

printf '\nResult: %d/3 buffering modes passed.\n' "$passed"
