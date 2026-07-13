#!/usr/bin/env bash
set -u

http_port="${HTTP_PORT:-8088}"
https_port="${HTTPS_PORT:-8443}"
domain="${DOMAIN:-faceid.example.com}"
cert_path="${CERT_PATH:-days/day-4/labs/hour-3/certs/faceid.example.com.crt}"

pass_count=0
total_count=0

pass() {
  echo "PASS $1"
  pass_count=$((pass_count + 1))
}

fail() {
  echo "FAIL $1"
}

check_status() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  total_count=$((total_count + 1))
  if [ "$actual" = "$expected" ]; then
    pass "$label -> $actual"
  else
    fail "$label -> expected $expected, got $actual"
  fi
}

domain_https_response="$(curl -sS --max-time 8 \
  --resolve "$domain:$https_port:127.0.0.1" \
  --cacert "$cert_path" \
  -D - "https://$domain:$https_port/" 2>&1 || true)"
domain_https_status="$(printf '%s' "$domain_https_response" | awk 'toupper($1) ~ /^HTTP/ {status=$2} END {print status}')"
check_status "domain HTTPS via --resolve keeps SNI/Host/cert target" "200" "$domain_https_status"

domain_http_response="$(curl -sS --max-time 8 \
  --resolve "$domain:$http_port:127.0.0.1" \
  -D - -o /tmp/nginx-day4-hour4-http-domain-body.txt \
  "http://$domain:$http_port/" 2>&1 || true)"
domain_http_status="$(printf '%s' "$domain_http_response" | awk 'toupper($1) ~ /^HTTP/ {status=$2} END {print status}')"
check_status "domain HTTP has no TLS and redirects" "301" "$domain_http_status"

ip_https_error="$(curl -sS --max-time 8 \
  --cacert "$cert_path" \
  "https://127.0.0.1:$https_port/" 2>&1 >/tmp/nginx-day4-hour4-ip-https-body.txt)"
ip_https_exit=$?

total_count=$((total_count + 1))
if [ "$ip_https_exit" -ne 0 ] && printf '%s' "$ip_https_error" | grep -Eiq 'certificate|SSL|subject|no alternative|not match'; then
  pass "direct-IP HTTPS verifies certificate target 127.0.0.1 and fails"
else
  fail "direct-IP HTTPS should fail certificate verification -> exit $ip_https_exit, error: $ip_https_error"
fi

ip_https_insecure_response="$(curl -k -sS --max-time 8 \
  -D - "https://127.0.0.1:$https_port/" 2>&1 || true)"
ip_https_insecure_status="$(printf '%s' "$ip_https_insecure_response" | awk 'toupper($1) ~ /^HTTP/ {status=$2} END {print status}')"
check_status "curl -k skips certificate and only proves HTTP layer" "200" "$ip_https_insecure_status"

http_to_https_port_response="$(curl -sS --max-time 8 \
  -D - "http://127.0.0.1:$https_port/" 2>&1 || true)"
http_to_https_port_status="$(printf '%s' "$http_to_https_port_response" | awk 'toupper($1) ~ /^HTTP/ {status=$2} END {print status}')"
check_status "HTTP request to HTTPS port gets nginx protocol mismatch response" "400" "$http_to_https_port_status"

echo
echo "Result: $pass_count/$total_count domain/IP matrix cases passed."

if [ "$pass_count" -ne "$total_count" ]; then
  exit 1
fi
