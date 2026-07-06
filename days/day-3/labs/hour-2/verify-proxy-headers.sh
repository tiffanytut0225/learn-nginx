#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

header_value() {
    header_name="$1"
    awk -v name="$header_name" '
        BEGIN { IGNORECASE = 1 }
        index($0, name ":") == 1 {
            sub(/^[^:]+:[[:space:]]*/, "")
            sub(/\r$/, "")
            print
        }
    ' | tail -n 1
}

check_headers() {
    case_name="$1"
    request_uri="$2"
    expected_host="$3"
    expected_xff="$4"
    expected_real_ip="$5"
    expected_proto="$6"

    headers="$(
        curl --silent --show-error \
            --header 'Host: app.example.com' \
            --header 'X-Forwarded-For: 1.2.3.4' \
            --output /dev/null \
            --dump-header - \
            "${base_url}${request_uri}"
    )"

    actual_host="$(printf '%s\n' "$headers" | header_value X-Seen-Host)"
    actual_xff="$(printf '%s\n' "$headers" | header_value X-Seen-XFF)"
    actual_real_ip="$(printf '%s\n' "$headers" | header_value X-Seen-Real-IP)"
    actual_proto="$(printf '%s\n' "$headers" | header_value X-Seen-Proto)"
    front_remote="$(printf '%s\n' "$headers" | header_value X-Front-Remote)"

    if [ "$expected_xff" = '@append' ]; then
        expected_xff="1.2.3.4, $front_remote"
    elif [ "$expected_xff" = '@remote' ]; then
        expected_xff="$front_remote"
    fi

    if [ "$expected_real_ip" = '@remote' ]; then
        expected_real_ip="$front_remote"
    fi

    if [ "$actual_host" != "$expected_host" ] || \
       [ "$actual_xff" != "$expected_xff" ] || \
       [ "$actual_real_ip" != "$expected_real_ip" ] || \
       [ "$actual_proto" != "$expected_proto" ]; then
        printf 'FAIL %-8s host=%s xff=%s real=%s proto=%s\n' \
            "$case_name" "$actual_host" "$actual_xff" "$actual_real_ip" "$actual_proto"
        return 1
    fi

    printf 'PASS %-8s host=%s xff=%s real=%s proto=%s\n' \
        "$case_name" "$actual_host" "$actual_xff" "$actual_real_ip" "$actual_proto"
    passed=$((passed + 1))
}

check_headers default /default/ '127.0.0.1:8080' '1.2.3.4' '' ''
check_headers append  /append/  'app.example.com' '@append' '@remote' 'http'
check_headers edge    /edge/    'app.example.com' '@remote' '@remote' 'http'

printf '\nResult: %d/3 proxy header modes passed.\n' "$passed"
