#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8085}"
passed=0

check_location() {
    case_number="$1"
    request_uri="$2"
    expected="$3"

    actual="$(
        curl --silent --show-error --path-as-is \
            --output /dev/null \
            --dump-header - \
            "${base_url}${request_uri}" \
        | awk 'BEGIN { IGNORECASE = 1 } /^X-Location:/ { print $2 }' \
        | tr -d '\r'
    )"

    if [ "$actual" != "$expected" ]; then
        printf 'FAIL %02d %-30s expected=%s actual=%s\n' \
            "$case_number" "$request_uri" "$expected" "${actual:-<missing>}"
        return 1
    fi

    printf 'PASS %02d %-30s X-Location=%s\n' \
        "$case_number" "$request_uri" "$actual"
    passed=$((passed + 1))
}

check_location 1  /                              exact-root
check_location 2  /api                           prefix-api
check_location 3  /api/users                     prefix-api
check_location 4  /api/test.php                  regex-php
check_location 5  /assets/logo.JPG               preferred-assets
check_location 6  /API                           prefix-root
check_location 7  /api/photo.PNG                 regex-image
check_location 8  /assets/test.php               preferred-assets
check_location 9  /api//users                    prefix-api
check_location 10 /apix                          prefix-api
check_location 11 /api/app.PHP                   prefix-api
check_location 12 /assets/../api/test.php         regex-php
check_location 13 /assetsx/logo.jpg               regex-image
check_location 14 /files/exists.txt               prefix-files
check_location 15 /files/missing.txt              named-missing

printf '\nResult: %d/15 cases passed.\n' "$passed"
