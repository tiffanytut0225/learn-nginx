#!/usr/bin/env bash
set -euo pipefail

container="${CONTAINER:-learn-nginx-graceful}"
base_url="${BASE_URL:-http://127.0.0.1:8091}"
lab_dir="${LAB_DIR:-days/day-5/labs/hour-6}"
docker_bin="${DOCKER:-/usr/local/bin/docker}"

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

copy_config() {
  local src="$1"
  "$docker_bin" cp "$lab_dir/$src" "$container:/etc/nginx/nginx.conf"
}

status="$(curl -sS --max-time 5 -o /tmp/nginx-day5-hour6-version.txt -w "%{http_code}" "$base_url/version" || true)"
body="$(cat /tmp/nginx-day5-hour6-version.txt 2>/dev/null || true)"
check_equals "initial v1 status" "200" "$status"
check_equals "initial v1 body" "version=v1" "$body"
initial_master_pid="$("$docker_bin" exec "$container" cat /var/run/nginx.pid)"

copy_config "nginx-invalid.conf"
set +e
invalid_test_output="$("$docker_bin" exec "$container" nginx -t 2>&1)"
invalid_test_exit=$?
set -e
check_equals "invalid config test fails" "1" "$invalid_test_exit"

status_after_invalid="$(curl -sS --max-time 5 -o /tmp/nginx-day5-hour6-version-invalid.txt -w "%{http_code}" "$base_url/version" || true)"
body_after_invalid="$(cat /tmp/nginx-day5-hour6-version-invalid.txt 2>/dev/null || true)"
check_equals "service still serves v1 after invalid test" "200" "$status_after_invalid"
check_equals "invalid config was not reloaded" "version=v1" "$body_after_invalid"

copy_config "nginx-v2.conf"
"$docker_bin" exec "$container" nginx -t >/tmp/nginx-day5-hour6-nginx-test.txt 2>&1
"$docker_bin" exec "$container" nginx -s reload
sleep 1
master_pid_after_reload="$("$docker_bin" exec "$container" cat /var/run/nginx.pid)"

status_v2="$(curl -sS --max-time 5 -o /tmp/nginx-day5-hour6-version-v2.txt -w "%{http_code}" "$base_url/version" || true)"
body_v2="$(cat /tmp/nginx-day5-hour6-version-v2.txt 2>/dev/null || true)"
header_v2="$(curl -sS --max-time 5 -D - -o /tmp/nginx-day5-hour6-header-v2.txt "$base_url/version" | awk 'tolower($1) == "x-config-version:" {gsub("\r", "", $2); print $2; exit}')"
check_equals "v2 status after graceful reload" "200" "$status_v2"
check_equals "v2 body after graceful reload" "version=v2" "$body_v2"
check_equals "v2 header after graceful reload" "v2" "$header_v2"
check_equals "master pid stays stable across reload" "$initial_master_pid" "$master_pid_after_reload"

copy_config "nginx-v1.conf"
"$docker_bin" exec "$container" nginx -t >/tmp/nginx-day5-hour6-nginx-rollback-test.txt 2>&1
"$docker_bin" exec "$container" nginx -s reload
sleep 1

rollback_body="$(curl -sS --max-time 5 "$base_url/version" || true)"
check_equals "rollback to v1 after test and reload" "version=v1" "$rollback_body"

"$docker_bin" exec "$container" nginx -s quit
sleep 1
container_running="$("$docker_bin" inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)"
total_count=$((total_count + 1))
if [ "$container_running" = "false" ] || [ -z "$container_running" ]; then
  echo "PASS graceful shutdown stops container -> ${container_running:-removed}"
  pass_count=$((pass_count + 1))
else
  echo "FAIL graceful shutdown stops container -> expected false/removed, got $container_running"
fi

echo
echo "Result: $pass_count/$total_count graceful operation checks passed."

if [ "$pass_count" -ne "$total_count" ]; then
  exit 1
fi
