#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
passed=0

check_path() {
    case_name="$1"
    request_uri="$2"
    expected_path="$3"

    headers="$(
        curl --silent --show-error --path-as-is \
            --output /dev/null \
            --dump-header - \
            "${base_url}${request_uri}"
    )"

    actual_path="$(
        printf '%s\n' "$headers" \
        | awk 'BEGIN { IGNORECASE = 1 } /^X-File-Path:/ { sub(/^[^:]+:[[:space:]]*/, ""); print }' \
        | tr -d '\r'
    )"

    if [ "$actual_path" != "$expected_path" ]; then
        printf 'FAIL %s %-34s expected=%s actual=%s\n' \
            "$case_name" "$request_uri" "$expected_path" "${actual_path:-<missing>}"
        return 1
    fi

    printf 'PASS %s %-34s X-File-Path=%s\n' \
        "$case_name" "$request_uri" "$actual_path"
    passed=$((passed + 1))
}

check_path A /root-images/logo.png              /srv/site/root-images/logo.png
check_path B /alias-images/logo.png             /srv/site/logo.png
check_path C /root-downloads/reports/july.pdf    /data/root-downloads/reports/july.pdf
check_path D /alias-downloads/reports/july.pdf   /data/reports/july.pdf
check_path E /users/alice.png                    /data/images/alice.png
check_path F /exports/2026/reports/july.csv      /archive/2026/reports/july.csv

printf '\nResult: %d/6 path mappings passed.\n' "$passed"
