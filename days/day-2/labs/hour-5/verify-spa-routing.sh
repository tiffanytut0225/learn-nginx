#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

check_response() {
    case_name="$1"
    host="$2"
    request_uri="$3"
    expected_status="$4"
    expected_location="$5"
    expected_body="$6"

    header_file="$(mktemp)"
    body_file="$(mktemp)"
    trap 'rm -f "$header_file" "$body_file"' EXIT

    actual_status="$(
        curl --silent --show-error --path-as-is \
            --header "Host: $host" \
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
        printf 'FAIL %-22s status=%s location=%s\n' \
            "$case_name" "$actual_status" "${actual_location:-<missing>}"
        return 1
    fi

    printf 'PASS %-22s status=%s X-Location=%s\n' \
        "$case_name" "$actual_status" "$actual_location"
    passed=$((passed + 1))
    rm -f "$header_file" "$body_file"
    trap - EXIT
}

check_response unsafe-missing-asset unsafe.local.test /assets/missing.js 200 exact-index 'SPA shell'
check_response unsafe-deep-link    unsafe.local.test /dashboard         200 exact-index 'SPA shell'
check_response safe-existing-asset safe.local.test   /assets/app.js     200 safe-assets 'console.log'
check_response safe-missing-asset  safe.local.test   /assets/missing.js 404 safe-assets '404 Not Found'
check_response safe-deep-link      safe.local.test   /dashboard         200 exact-index 'SPA shell'
check_response safe-api-path       safe.local.test   /api/users         404 safe-api 'API route unavailable'

printf '\nResult: %d/6 SPA routing cases passed.\n' "$passed"
