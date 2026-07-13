#!/usr/bin/env bash
set -u

base_url="${BASE_URL:-http://127.0.0.1:8089}"
pass_count=0
total_count=0

check_status() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  total_count=$((total_count + 1))
  if [ "$actual" = "$expected" ]; then
    echo "PASS $label -> $actual"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL $label -> expected $expected, got $actual"
  fi
}

health_status="$(curl -sS --max-time 5 -o /tmp/nginx-day4-hour7-health.txt -w "%{http_code}" "$base_url/health" || true)"
check_status "healthy request" "200" "$health_status"

large_body_status="$(dd if=/dev/zero bs=2048 count=1 2>/dev/null | curl -sS --max-time 5 -o /tmp/nginx-day4-hour7-upload.txt -w "%{http_code}" -X POST --data-binary @- "$base_url/upload" || true)"
check_status "client_max_body_size rejects oversized body" "413" "$large_body_status"

sleep 2
first_rate_status="$(curl -sS --max-time 5 -o /tmp/nginx-day4-hour7-rate-1.txt -w "%{http_code}" "$base_url/rate" || true)"
second_rate_status="$(curl -sS --max-time 5 -o /tmp/nginx-day4-hour7-rate-2.txt -w "%{http_code}" "$base_url/rate" || true)"
check_status "first rate-limited request is allowed" "200" "$first_rate_status"
check_status "second immediate rate-limited request is rejected" "429" "$second_rate_status"

curl -sS --max-time 8 -o /tmp/nginx-day4-hour7-hold-1.txt "$base_url/hold" >/tmp/nginx-day4-hour7-hold-1.log 2>&1 &
hold_pid=$!
sleep 0.3
second_hold_status="$(curl -sS --max-time 5 -o /tmp/nginx-day4-hour7-hold-2.txt -w "%{http_code}" "$base_url/hold" || true)"
wait "$hold_pid"
first_hold_exit=$?

total_count=$((total_count + 1))
if [ "$first_hold_exit" -eq 0 ]; then
  echo "PASS first held connection eventually completes"
  pass_count=$((pass_count + 1))
else
  echo "FAIL first held connection -> curl exit $first_hold_exit"
fi

check_status "second concurrent connection is rejected" "429" "$second_hold_status"

echo
echo "Result: $pass_count/$total_count limit and rate cases passed."

if [ "$pass_count" -ne "$total_count" ]; then
  exit 1
fi
