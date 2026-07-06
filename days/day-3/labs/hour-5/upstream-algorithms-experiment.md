# Hour 5 實驗：Upstream Algorithms

## 目標

使用 Backend A／B 比較 Round-robin、`least_conn` 與 `ip_hash`。Backend 透過 `X-Backend` Header 顯示實際命中節點。

## 1. 啟動 Backends

```bash
python3 days/day-3/labs/hour-5/algorithm-upstreams.py
```

Backend A 使用 Port 9011，Backend B 使用 Port 9012。URI 以 `/slow` 結尾時延遲 2 秒。

## 2. 啟動 Nginx

另一個 Terminal：

```bash
docker run --rm -d \
  --name learn-nginx-upstream-algorithms \
  -p 8086:80 \
  -v "$PWD/days/day-3/labs/hour-5/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 3. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-3/labs/hour-5/verify-upstream-algorithms.sh
```

實際結果：

```text
PASS round-robin sequence=ABAB
PASS least-conn slow=A fast=B
PASS ip-hash same-source=A

Result: 3/3 upstream algorithm checks passed.
```

## 4. Sticky Behavior 注意事項

本實驗只能證明相同來源 IP 在目前拓撲下映射到同一節點；沒有證明 Backend 故障、擴縮容或 Client IP 改變後仍保持一致。

## 5. 清理

```bash
docker stop learn-nginx-upstream-algorithms
```

回到 Python Backend Terminal 按 `Ctrl-C`。
