#!/usr/bin/env bash
set -u

http_port="${HTTP_PORT:-8088}"
https_port="${HTTPS_PORT:-8443}"
domain="${DOMAIN:-faceid.example.com}"
cert_path="${CERT_PATH:-days/day-4/labs/hour-3/certs/faceid.example.com.crt}"

pass_count=0
total_count=0

check_equals() {
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

check_contains() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  total_count=$((total_count + 1))
  if printf '%s' "$actual" | grep -Fq "$expected"; then
    echo "PASS $label -> contains $expected"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL $label -> expected to contain $expected, got: $actual"
  fi
}

https_response="$(curl -sS --max-time 8 \
  --resolve "$domain:$https_port:127.0.0.1" \
  --cacert "$cert_path" \
  -D - "https://$domain:$https_port/" 2>&1 || true)"
https_status="$(printf '%s' "$https_response" | awk 'toupper($1) ~ /^HTTP/ {status=$2} END {print status}')"
check_equals "https domain certificate and http status" "200" "$https_status"
check_contains "https domain lab header" "X-Lab: day4-hour3-https" "$https_response"
check_contains "https domain body" "secure faceid site" "$https_response"

redirect_response="$(curl -sS --max-time 8 \
  --resolve "$domain:$http_port:127.0.0.1" \
  -D - -o /tmp/nginx-day4-hour3-redirect-body.txt \
  "http://$domain:$http_port/" 2>&1 || true)"
redirect_status="$(printf '%s' "$redirect_response" | awk 'toupper($1) ~ /^HTTP/ {status=$2} END {print status}')"
check_equals "http domain redirects" "301" "$redirect_status"
check_contains "http redirect location" "Location: https://faceid.example.com/" "$redirect_response"

ip_error="$(curl -sS --max-time 8 \
  --cacert "$cert_path" \
  "https://127.0.0.1:$https_port/" 2>&1 >/tmp/nginx-day4-hour3-ip-body.txt)"
ip_exit=$?

total_count=$((total_count + 1))
if [ "$ip_exit" -ne 0 ] && printf '%s' "$ip_error" | grep -Eiq 'certificate|SSL|subject|no alternative|not match'; then
  echo "PASS direct-ip https certificate mismatch -> curl exit $ip_exit"
  pass_count=$((pass_count + 1))
else
  echo "FAIL direct-ip https certificate mismatch -> exit $ip_exit, error: $ip_error"
fi

echo
echo "Result: $pass_count/$total_count local HTTPS cases passed."

if [ "$pass_count" -ne "$total_count" ]; then
  exit 1
fi
