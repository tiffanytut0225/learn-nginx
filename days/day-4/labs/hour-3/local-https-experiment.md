# Hour 3 Lab：Local HTTPS

本 Lab 建立 development-only certificate，驗證 HTTPS 的 TLS/SNI/Certificate 與 HTTP Redirect 順序。

## Expected Result

| Case | Expected |
|---|---|
| `https://faceid.example.com/` with `--resolve` and trusted dev cert | TLS certificate 驗證通過，HTTP status `200` |
| `http://faceid.example.com/` with `--resolve` | HTTP status `301`，redirect 到 `https://faceid.example.com/` |
| `https://127.0.0.1/` with trusted dev cert | TLS certificate name mismatch，HTTP 階段不應被當作主要結果 |

## Run

產生 development-only certificate：

```bash
days/day-4/labs/hour-3/generate-dev-cert.sh
```

啟動 Nginx：

```bash
docker run --rm -d \
  --name learn-nginx-local-https \
  -p 8088:80 \
  -p 8443:443 \
  -v "$PWD/days/day-4/labs/hour-3/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/days/day-4/labs/hour-3/certs:/etc/nginx/certs:ro" \
  nginx:stable
```

驗證 Nginx config：

```bash
docker exec learn-nginx-local-https nginx -t
```

執行驗證：

```bash
days/day-4/labs/hour-3/verify-local-https.sh
```

## Actual Result

```text
PASS https domain certificate and http status -> 200
PASS https domain lab header -> contains X-Lab: day4-hour3-https
PASS https domain body -> contains secure faceid site
PASS http domain redirects -> 301
PASS http redirect location -> contains Location: https://faceid.example.com/
PASS direct-ip https certificate mismatch -> curl exit 60

Result: 6/6 local HTTPS cases passed.
```

`curl exit 60` 代表 TLS certificate verification failed。本 Lab 的 direct-IP HTTPS case 期望它失敗，因為 development certificate 只包含 `faceid.example.com`，不包含 `127.0.0.1`。
