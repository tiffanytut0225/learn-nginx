# Hour 4：Reverse Proxy Log Format Design

## 目標

一個好的 Nginx reverse proxy access log，應該能回答：

```text
這個 request 是誰？
打到哪個 host / URI？
最後 client 看到什麼 status？
Nginx 實際 proxy 到哪個 upstream？
upstream 回什麼 status？
connect/header/response 各花多久？
整體 request 花多久？
能不能用 request_id 追到 backend app log？
```

同時要避免記錄：

```text
完整 Cookie
Authorization header
token / password / code / session 等敏感 query string
```

## 建議 Log Format

```nginx
log_format reverse_proxy
  'request_id=$request_id '
  'remote_addr=$remote_addr '
  'host=$host '
  'method=$request_method '
  'uri=$uri '
  'status=$status '
  'bytes_sent=$bytes_sent '
  'request_length=$request_length '
  'request_time=$request_time '
  'upstream_addr=$upstream_addr '
  'upstream_status=$upstream_status '
  'upstream_connect_time=$upstream_connect_time '
  'upstream_header_time=$upstream_header_time '
  'upstream_response_time=$upstream_response_time '
  'user_agent="$http_user_agent"';
```

## 為什麼不用完整 `$request_uri`

`$request_uri` 包含 query string。若 URL 是：

```text
/api/users?token=secret123
```

完整記錄 `$request_uri` 會把 token 寫進 log。若 production 需要 query 來診斷，應先定義敏感 key 遮罩策略。

## 欄位用途

| 欄位 | 用途 |
|---|---|
| `$request_id` | 串 Nginx、Backend app、Sentry/APM/tracing。 |
| `$host` | 判斷進入哪個 virtual host。 |
| `$uri` | 記錄 path，降低 query string 洩漏風險。 |
| `$status` | Client 最後看到的 HTTP status。 |
| `$upstream_addr` | Nginx 實際連到哪個 upstream。 |
| `$upstream_status` | Upstream 回的 status；retry 時可能有多個值。 |
| `$upstream_connect_time` | Nginx 連 upstream 花多久。 |
| `$upstream_header_time` | 等 upstream response header 花多久。 |
| `$upstream_response_time` | Upstream response 整體花多久。 |
| `$request_time` | Nginx 處理整個 client request 的總時間。 |

## 診斷例子

| 現象 | 可能方向 |
|---|---|
| `$status=504` 且 `$upstream_response_time` 高 | Backend 太慢或 upstream timeout。 |
| `$request_time` 高但 `$upstream_response_time` 不高 | 可能是慢 client、大 response、buffering 或傳輸問題。 |
| `$upstream_status=502, 200` | 第一個 upstream 失敗，retry 後成功。 |
| `$upstream_addr` 集中某一台且 latency 高 | 單一 backend 節點可能異常。 |
