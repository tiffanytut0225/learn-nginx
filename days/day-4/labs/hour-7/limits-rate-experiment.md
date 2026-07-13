# Hour 7 Lab：Limits 與 Rate Limiting

本 Lab 驗證 Nginx 入口保護設定，並將 client-side limit 與 upstream timeout 分開。

## Expected Result

| Case | Expected | 原因 |
|---|---:|---|
| `GET /health` | 200 | baseline |
| `POST /upload` with body > `client_max_body_size 1k` | 413 | request body 太大，被 Nginx 入口擋下 |
| 第一個 `GET /rate` | 200 | rate bucket 尚可接受 |
| 第二個立即 `GET /rate` | 429 | 超過 `limit_req` 設定 |
| 第一個 `GET /hold` | 200 | 慢速 upstream 最後完成 |
| 第二個同時 `GET /hold` | 429 | 超過 `limit_conn per_ip_conn 1` |

## Config 重點

```nginx
client_max_body_size 1k;

limit_req_zone $binary_remote_addr zone=api_rate:10m rate=1r/s;
limit_req_status 429;

limit_conn_zone $binary_remote_addr zone=per_ip_conn:10m;
limit_conn_status 429;
```

## Actual Result

```text
PASS healthy request -> 200
PASS client_max_body_size rejects oversized body -> 413
PASS first rate-limited request is allowed -> 200
PASS second immediate rate-limited request is rejected -> 429
PASS first held connection eventually completes
PASS second concurrent connection is rejected -> 429

Result: 6/6 limit and rate cases passed.
```

Debug note：第一次將 `/rate` 寫成 `return 200` 時，第二個 request 沒有被 `limit_req` 擋下。原因是 `return` 在 rewrite phase 太早產生 response，沒有形成適合觀察 `limit_req` 的處理流程。改成 proxy 到測試 upstream 後，`limit_req` 正常生效。
