# Hour 4 Lab：Domain/IP 行為驗證

本 Lab 沿用 Hour 3 的 Local HTTPS Nginx，專門驗證 Domain、IP、`curl --resolve` 與 `curl -k` 的差異。

## 核心規則

```text
Domain case 用 curl --resolve。
IP case 直接打 127.0.0.1。
正常驗證 certificate 時不要用 -k。
只有要隔離 HTTP 層行為時才用 -k。
```

## Expected Matrix

| Case | Expected |
|---|---|
| `curl --resolve faceid.example.com:8443:127.0.0.1 https://faceid.example.com:8443/ --cacert cert` | SNI、Host、Certificate target 都是 `faceid.example.com`，結果 `200` |
| `curl --resolve faceid.example.com:8088:127.0.0.1 http://faceid.example.com:8088/` | HTTP 沒有 TLS certificate result，結果 `301` redirect |
| `curl --cacert cert https://127.0.0.1:8443/` | Direct-IP HTTPS，certificate 不含 IP，驗證失敗 |
| `curl -k https://127.0.0.1:8443/` | 跳過 certificate 驗證，只能證明 HTTP 層可回 `200` |
| `curl http://127.0.0.1:8443/` | HTTP 打到 HTTPS port，Nginx 回 `400 Bad Request`，body 顯示 plain HTTP request was sent to HTTPS port |

## Actual Result

```text
PASS domain HTTPS via --resolve keeps SNI/Host/cert target -> 200
PASS domain HTTP has no TLS and redirects -> 301
PASS direct-IP HTTPS verifies certificate target 127.0.0.1 and fails
PASS curl -k skips certificate and only proves HTTP layer -> 200
PASS HTTP request to HTTPS port gets nginx protocol mismatch response -> 400

Result: 5/5 domain/IP matrix cases passed.
```

Debug note：原本預期 `curl http://127.0.0.1:8443/` 會以 curl error 結束；實測 Nginx 回 `400 Bad Request`，body 顯示 `The plain HTTP request was sent to HTTPS port`。因此此 case 的精確預期是 protocol mismatch response，而不是沒有 HTTP status。
