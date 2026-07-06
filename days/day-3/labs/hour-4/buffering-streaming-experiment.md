# Hour 4 實驗：Buffering 與 Streaming

## 目標

使用每 0.5 秒 Flush 一個 Event 的 Python Upstream，比較 Buffering On、Off 與 `X-Accel-Buffering: no` 的 Time To First Byte（TTFB）。

## 1. 啟動 Streaming Upstream

```bash
python3 days/day-3/labs/hour-4/streaming-upstream.py
```

## 2. 啟動 Nginx

另一個 Terminal：

```bash
docker run --rm -d \
  --name learn-nginx-buffering \
  -p 8086:80 \
  -v "$PWD/days/day-3/labs/hour-4/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 3. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-3/labs/hour-4/verify-buffering.sh
```

實際結果：

```text
PASS buffered       ttfb=2.020236s total=2.020455s
PASS unbuffered     ttfb=0.003389s total=2.020092s
PASS x-accel-no     ttfb=0.004325s total=2.018499s

Result: 3/3 buffering modes passed.
```

TTFB 會隨機器略有波動；驗證條件使用合理範圍，而不是比對固定時間。

## 4. 觀察即時輸出

```bash
curl --no-buffer http://127.0.0.1:8086/unbuffered
```

每個 Event 會逐步顯示。將 URI 改成 `/buffered` 時，通常會在接近結束時一次看到全部內容。

## 5. 清理

```bash
docker stop learn-nginx-buffering
```

回到 Python Upstream Terminal 按 `Ctrl-C`。
