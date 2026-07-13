#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
cert_dir="$script_dir/certs"

mkdir -p "$cert_dir"

openssl req -x509 -newkey rsa:2048 -nodes \
  -days 7 \
  -keyout "$cert_dir/faceid.example.com.key" \
  -out "$cert_dir/faceid.example.com.crt" \
  -config "$script_dir/openssl-faceid.cnf"

echo "Generated development-only certificate:"
echo "$cert_dir/faceid.example.com.crt"
