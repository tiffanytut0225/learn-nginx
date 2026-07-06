# Hour 6 實驗：Upstream Keepalive

## 目標

讓 Backend 回傳 Nginx 連入時使用的 Source Port，比較 Upstream Keepalive 開啟與關閉時的 Connection Reuse。

## 1. 啟動 Backend

```bash
python3 days/day-3/labs/hour-6/keepalive-upstream.py
```

Backend 使用 HTTP/1.1 並回傳：

```http
X-Upstream-Client-Port: <source-port>
```

## 2. 啟動 Nginx

另一個 Terminal：

```bash
docker run --rm -d \
  --name learn-nginx-upstream-keepalive \
  -p 8086:80 \
  -v "$PWD/days/day-3/labs/hour-6/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 3. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-3/labs/hour-6/verify-upstream-keepalive.sh
```

實際結果：

```text
PASS no-keepalive unique-ports=4 ports=56571 56573 56575 56577
PASS keepalive reused-port=56579 ports=56579 56579 56579 56579

Result: 2/2 upstream keepalive modes passed.
```

Ports 由 OS 動態分配，不應寫死；驗證腳本只比較 Unique Count 與是否重用。

## 4. 清理

```bash
docker stop learn-nginx-upstream-keepalive
```

回到 Python Backend Terminal 按 `Ctrl-C`。
