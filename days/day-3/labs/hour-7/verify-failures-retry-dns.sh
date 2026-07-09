#!/usr/bin/env bash
set -u

base_url="${BASE_URL:-http://127.0.0.1:8087}"
pass_count=0
total_count=0

check_status() {
  local label="$1"
  local method="$2"
  local path="$3"
  local expected="$4"
  local status

  total_count=$((total_count + 1))
  if [ "$method" = "POST" ]; then
    status="$(curl -sS --max-time 8 -o /tmp/nginx-hour7-body.txt -w "%{http_code}" -X POST "$base_url$path" || true)"
  else
    status="$(curl -sS --max-time 8 -o /tmp/nginx-hour7-body.txt -w "%{http_code}" "$base_url$path" || true)"
  fi

  if [ "$status" = "$expected" ]; then
    echo "PASS $label -> $status"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL $label -> expected $expected, got $status"
  fi
}

check_header() {
  local label="$1"
  local path="$2"
  local header_name="$3"
  local expected="$4"
  local actual

  total_count=$((total_count + 1))
  actual="$(curl -sS --max-time 8 -D - -o /tmp/nginx-hour7-body.txt "$base_url$path" | awk -v name="$header_name:" 'tolower($1) == tolower(name) {gsub("\r", "", $2); print $2; exit}' || true)"

  if [ "$actual" = "$expected" ]; then
    echo "PASS $label -> $header_name=$actual"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL $label -> expected $header_name=$expected, got $actual"
  fi
}

check_body_contains() {
  local label="$1"
  local path="$2"
  local expected="$3"
  local body

  total_count=$((total_count + 1))
  body="$(curl -sS --max-time 8 "$base_url$path" || true)"

  if printf '%s' "$body" | grep -Fq "$expected"; then
    echo "PASS $label -> contains $expected"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL $label -> expected body to contain $expected, got: $body"
  fi
}

check_status "connection-refused maps to bad gateway" "GET" "/connect-refused" "502"
check_status "slow upstream response maps to gateway timeout" "GET" "/read-timeout" "504"
check_status "upstream http 500 is preserved" "GET" "/upstream-500" "500"
check_status "runtime dns failure maps to bad gateway" "GET" "/dns-failure" "502"
check_status "idempotent get can retry next upstream" "GET" "/retry-get" "200"
check_header "retry-get reaches backend B" "/retry-get" "X-Backend" "B"
check_status "non-idempotent post is not retried after timeout" "POST" "/payments" "504"
check_body_contains "payment backend A saw one write attempt" "/stats-a" "payments=1"
check_body_contains "payment backend B saw no duplicate write" "/stats-b" "payments=0"

echo
echo "Result: $pass_count/$total_count failure retry DNS cases passed."

if [ "$pass_count" -ne "$total_count" ]; then
  exit 1
fi
