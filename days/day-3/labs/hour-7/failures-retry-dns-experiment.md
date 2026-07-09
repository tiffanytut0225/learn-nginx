# Hour 7 Lab：Failure、Retry 與 DNS

本 Lab 驗證 Nginx 作為 Reverse Proxy 時，常見 Upstream Failure 會如何映射到 HTTP Status，以及 Retry 對 GET 與 POST 的差異。

## 名詞用途

| 名詞 | 用途 |
|---|---|
| Connection Refused | Nginx 連到 Upstream IP/Port，但該 Port 沒有服務；通常是 502。 |
| Read Timeout | Nginx 已連上 Upstream，但等待 Response 太久；通常是 504。 |
| Upstream HTTP 500 | Backend 自己回 500；Nginx 預設會把 500 原樣轉回 Client。 |
| Runtime DNS Failure | Nginx 在執行期間解析 Hostname 失敗；通常是 502。 |
| `proxy_next_upstream` | 控制遇到 error、timeout、特定 HTTP 狀態時，是否改試下一台 Upstream。 |
| Idempotent Request | 重試通常較安全，例如 GET 查詢資料。 |
| Non-idempotent Request | 重試可能造成重複寫入，例如付款、建單、扣庫存。 |

## Expected Result

| Request | Expected | 原因 |
|---|---:|---|
| `GET /connect-refused` | 502 | Nginx 無法建立 Upstream Connection。 |
| `GET /read-timeout` | 504 | Backend 接到 Request 但太久沒回。 |
| `GET /upstream-500` | 500 | Backend 主動回 500，Nginx 原樣轉回。 |
| `GET /dns-failure` | 502 | Runtime resolver 找不到 Hostname。 |
| `GET /retry-get` | 200, `X-Backend: B` | 第一台連線失敗後，GET 可改試下一台。 |
| `POST /payments` | 504 | Backend A 已收到寫入請求但太慢，Nginx 不應預設重試 non-idempotent POST。 |
| `GET /stats-a` | `payments=1` | A 收到一次付款寫入嘗試。 |
| `GET /stats-b` | `payments=0` | B 沒收到重複付款寫入。 |

`payment_pool` 刻意將 Backend A 設為 primary、Backend B 設為 backup，避免重複執行 Lab 時被 round-robin 狀態影響，確保 POST 測試固定觀察「A 已收到寫入但 Response Timeout」的情境。

## Run

啟動 upstream fixture：

```bash
python3 days/day-3/labs/hour-7/failure-upstreams.py
```

啟動 Nginx：

```bash
docker run --rm -d \
  --name learn-nginx-failures \
  -p 8087:80 \
  -v "$PWD/days/day-3/labs/hour-7/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

執行驗證：

```bash
days/day-3/labs/hour-7/verify-failures-retry-dns.sh
```

## Actual Result

```text
PASS connection-refused maps to bad gateway -> 502
PASS slow upstream response maps to gateway timeout -> 504
PASS upstream http 500 is preserved -> 500
PASS runtime dns failure maps to bad gateway -> 502
PASS idempotent get can retry next upstream -> 200
PASS retry-get reaches backend B -> X-Backend=B
PASS non-idempotent post is not retried after timeout -> 504
PASS payment backend A saw one write attempt -> contains payments=1
PASS payment backend B saw no duplicate write -> contains payments=0

Result: 9/9 failure retry DNS cases passed.
```

## Debug Note：Runtime DNS Failure

第一次驗證 `/dns-failure` 時，Client 先因 `curl --max-time 8` 放棄，Nginx access log 顯示 `499`。Root Cause 是 runtime resolver 查詢沒有被較短時間限制住。

加入：

```nginx
resolver_timeout 1s;
```

後，DNS Failure 可快速轉成 `502 Bad Gateway`。這代表 DNS Failure 的概念判斷仍是 502，但實務設定上要同時控制 Resolver Timeout，避免請求卡太久。
