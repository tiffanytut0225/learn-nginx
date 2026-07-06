#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

check_uri() {
    case_number="$1"
    request_uri="$2"
    expected_uri="$3"

    actual_uri="$(
        curl --silent --show-error --path-as-is \
            --output /dev/null \
            --dump-header - \
            "${base_url}${request_uri}" \
        | awk 'BEGIN { IGNORECASE = 1 } /^X-Upstream-URI:/ {
              sub(/^[^:]+:[[:space:]]*/, "")
              sub(/\r$/, "")
              print
          }'
    )"

    if [ "$actual_uri" != "$expected_uri" ]; then
        printf 'FAIL %d %-32s expected=%s actual=%s\n' \
            "$case_number" "$request_uri" "$expected_uri" "${actual_uri:-<missing>}"
        return 1
    fi

    printf 'PASS %d %-32s upstream=%s\n' \
        "$case_number" "$request_uri" "$actual_uri"
    passed=$((passed + 1))
}

check_uri 1 '/preserve/users?page=2' '/preserve/users?page=2'
check_uri 2 '/strip/users?page=2'    '/users?page=2'
check_uri 3 '/service/users'         '/v1/users'
check_uri 4 '/joined/users'          '/v1users'
check_uri 5 '/rewrite/users?page=2'  '/v2/users?page=2'
check_uri 6 '/regex/users'           '/regex/users'
check_uri 7 '/named/users'           '/named/users'

printf '\nResult: %d/7 upstream URI cases passed.\n' "$passed"
