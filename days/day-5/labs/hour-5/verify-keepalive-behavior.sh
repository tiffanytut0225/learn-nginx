#!/usr/bin/env bash
set -u

base_url="${BASE_URL:-http://127.0.0.1:8090}"

collect_ports() {
  local path="$1"
  local count="$2"
  local ports=""

  for _ in $(seq 1 "$count"); do
    body="$(curl -sS --max-time 5 "$base_url$path" || true)"
    port="$(printf '%s' "$body" | awk -F= '/client_port=/ {print $2; exit}')"
    ports="$ports $port"
  done

  echo "$ports" | xargs
}

unique_count() {
  printf '%s\n' "$1" | tr ' ' '\n' | sed '/^$/d' | sort -u | wc -l | tr -d ' '
}

short_ports="$(collect_ports /short 4)"
keepalive_ports="$(collect_ports /keepalive 4)"

short_unique="$(unique_count "$short_ports")"
keepalive_unique="$(unique_count "$keepalive_ports")"

pass_count=0
total_count=2

if [ "$short_unique" -gt 1 ]; then
  echo "PASS short-lived requests used multiple upstream ports -> $short_ports"
  pass_count=$((pass_count + 1))
else
  echo "FAIL short-lived requests expected multiple upstream ports, got -> $short_ports"
fi

if [ "$keepalive_unique" -eq 1 ]; then
  echo "PASS keepalive requests reused upstream port -> $keepalive_ports"
  pass_count=$((pass_count + 1))
else
  echo "FAIL keepalive requests expected one reused upstream port, got -> $keepalive_ports"
fi

echo
echo "Result: $pass_count/$total_count keepalive behavior checks passed."

if [ "$pass_count" -ne "$total_count" ]; then
  exit 1
fi
