#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

check_status() {
    case_name="$1"
    request_uri="$2"
    expected_status="$3"

    actual_status="$(
        curl --silent --show-error \
            --max-time 8 \
            --output /dev/null \
            --write-out '%{http_code}' \
            "${base_url}${request_uri}"
    )"

    if [ "$actual_status" != "$expected_status" ]; then
        printf 'FAIL %-18s expected=%s actual=%s\n' \
            "$case_name" "$expected_status" "$actual_status"
        return 1
    fi

    printf 'PASS %-18s status=%s\n' "$case_name" "$actual_status"
    passed=$((passed + 1))
}

check_send_timeout() {
    actual_status="$(
        head -c 33554432 /dev/zero \
        | curl --silent --show-error \
            --max-time 8 \
            --request POST \
            --header 'Content-Type: application/octet-stream' \
            --data-binary @- \
            --output /dev/null \
            --write-out '%{http_code}' \
            "${base_url}/send-timeout"
    )"

    if [ "$actual_status" != '504' ]; then
        printf 'FAIL send-timeout       expected=504 actual=%s\n' "$actual_status"
        return 1
    fi

    printf 'PASS send-timeout       status=%s\n' "$actual_status"
    passed=$((passed + 1))
}

check_status healthy         /healthy         200
check_status connect-failure /connect-failure 502
check_status read-timeout    /read-timeout    504
check_send_timeout

printf '\nResult: %d/4 proxy timeout cases passed.\n' "$passed"
