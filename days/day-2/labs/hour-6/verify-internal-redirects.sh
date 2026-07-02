#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

check_response() {
    case_name="$1"
    request_uri="$2"
    expected_status="$3"
    expected_location="$4"
    expected_body="$5"

    header_file="$(mktemp)"
    body_file="$(mktemp)"
    trap 'rm -f "$header_file" "$body_file"' EXIT

    actual_status="$(
        curl --silent --show-error --path-as-is \
            --dump-header "$header_file" \
            --output "$body_file" \
            --write-out '%{http_code}' \
            "${base_url}${request_uri}"
    )"

    actual_location="$(
        awk 'BEGIN { IGNORECASE = 1 } /^X-Location:/ { print $2 }' "$header_file" \
        | tr -d '\r'
    )"

    if [ "$actual_status" != "$expected_status" ] || \
       [ "$actual_location" != "$expected_location" ] || \
       ! grep -Fq "$expected_body" "$body_file"; then
        printf 'FAIL %-20s status=%s location=%s\n' \
            "$case_name" "$actual_status" "${actual_location:-<missing>}"
        return 1
    fi

    printf 'PASS %-20s status=%s X-Location=%s\n' \
        "$case_name" "$actual_status" "${actual_location:-<missing>}"
    passed=$((passed + 1))
    rm -f "$header_file" "$body_file"
    trap - EXIT
}

check_response return-redirect    /old              301 ''              '301 Moved Permanently'
check_response rewrite-last       /legacy           200 exact-new       'new content'
check_response try-files-existing /files/exists.txt 200 try-files       'existing file'
check_response try-files-fallback /files/missing.txt 404 named-fallback  'named fallback'
check_response error-preserve     /missing-preserve 404 error-preserve  'custom 404'
check_response error-convert      /missing-convert  200 error-convert   'converted to 200'

printf '\nResult: %d/6 redirect and fallback cases passed.\n' "$passed"
