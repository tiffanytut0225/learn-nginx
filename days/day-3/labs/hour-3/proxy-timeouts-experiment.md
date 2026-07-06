# Hour 3 實驗：Proxy Timeouts

## 目標

使用可控 Python Upstream 分別製造 Connection Refused、不讀 Request Body、延遲 Response，以及正常 Response。

## 1. 啟動可控 Upstream

```bash
python3 days/day-3/labs/hour-3/timeout-upstream.py
```

它會啟動：

- Port 9001：`/healthy` 立即回覆，`/read-timeout` 延遲 2 秒。
- Port 9002：接受 Connection，但 10 秒內不讀取任何資料。

## 2. 啟動 Nginx

另一個 Terminal：

```bash
docker run --rm -d \
  --name learn-nginx-proxy-timeouts \
  -p 8086:80 \
  -v "$PWD/days/day-3/labs/hour-3/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 3. Config 重點

```nginx
proxy_connect_timeout 1s;
proxy_send_timeout 1s;
proxy_read_timeout 1s;
client_max_body_size 64m;
```

Send Case 另外使用 `proxy_request_buffering off`，讓 Nginx 即時向 Upstream 傳送 Request Body。

## 4. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-3/labs/hour-3/verify-proxy-timeouts.sh
```

實際結果：

```text
PASS healthy            status=200
PASS connect-failure    status=502
PASS read-timeout       status=504
PASS send-timeout       status=504

Result: 4/4 proxy timeout cases passed.
```

## 5. 重要觀察

若 `client_max_body_size` 沒有提高，大型 Send Case 會先得到 413，無法測到 `proxy_send_timeout`。

## 6. 清理

```bash
docker stop learn-nginx-proxy-timeouts
```

回到 Python Upstream Terminal 按 `Ctrl-C`。
