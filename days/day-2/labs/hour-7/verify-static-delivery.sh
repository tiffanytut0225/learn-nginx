#!/bin/sh

set -eu

base_url="${BASE_URL:-http://127.0.0.1:8086}"
header_file="$(mktemp)"
body_file="$(mktemp)"
trap 'rm -f "$header_file" "$body_file"' EXIT
passed=0

fetch() {
    curl --silent --show-error \
        --dump-header "$header_file" \
        --output "$body_file" \
        "$@"
}

header_value() {
    header_name="$1"
    awk -v name="$header_name" '
        BEGIN { IGNORECASE = 1 }
        index($0, name ":") == 1 {
            sub(/^[^:]+:[[:space:]]*/, "")
            sub(/\r$/, "")
            print
        }
    ' "$header_file" | tail -n 1
}

pass() {
    passed=$((passed + 1))
    printf 'PASS %s\n' "$1"
}

fetch "${base_url}/index.html"
[ "$(header_value Cache-Control)" = 'no-cache' ]
pass 'index.html requires revalidation'

fetch "${base_url}/assets/app.a1b2c3.js"
asset_cache="$(header_value Cache-Control)"
case "$asset_cache" in
    *public*max-age=31536000*immutable*) ;;
    *) printf 'FAIL hashed asset Cache-Control=%s\n' "$asset_cache"; exit 1 ;;
esac
pass 'hashed asset is immutable for one year'

content_type="$(header_value Content-Type)"
case "$content_type" in
    *javascript*) ;;
    *) printf 'FAIL JavaScript Content-Type=%s\n' "$content_type"; exit 1 ;;
esac
pass 'JavaScript MIME type is correct'

etag="$(header_value ETag)"
last_modified="$(header_value Last-Modified)"
[ -n "$etag" ] && [ -n "$last_modified" ]
pass 'ETag and Last-Modified are present'

status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --header "If-None-Match: $etag" \
    "${base_url}/assets/app.a1b2c3.js")"
[ "$status" = '304' ]
pass 'If-None-Match returns 304'

status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --header "If-Modified-Since: $last_modified" \
    "${base_url}/assets/app.a1b2c3.js")"
[ "$status" = '304' ]
pass 'If-Modified-Since returns 304'

fetch --header 'Accept-Encoding: gzip' "${base_url}/assets/app.a1b2c3.js"
[ "$(header_value Content-Encoding)" = 'gzip' ]
[ "$(header_value Vary)" = 'Accept-Encoding' ]
pass 'Gzip negotiation sets Content-Encoding and Vary'

printf '\nResult: %d/7 static delivery checks passed.\n' "$passed"
