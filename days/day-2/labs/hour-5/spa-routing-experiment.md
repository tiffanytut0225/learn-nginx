# Hour 5 實驗：Safe SPA 與 `try_files`

## 目標

比較通用 SPA Fallback 與安全拆分 Config，驗證 Deep Link、Existing Asset、Missing Asset、API Path 與 Internal Redirect。

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-spa \
  -p 8086:80 \
  -v "$PWD/days/day-2/labs/hour-5/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/days/day-2/labs/hour-5/site:/usr/share/nginx/html:ro" \
  nginx:stable
```

## 2. Unsafe 與 Safe Hosts

- `unsafe.local.test`：所有 Missing Paths 都可能 Fallback 到 `index.html`。
- `safe.local.test`：Assets、API 與 SPA Routes 使用不同 Location Contracts。

## 3. 單題比較

```bash
curl -i -H 'Host: unsafe.local.test' \
  http://127.0.0.1:8086/assets/missing.js

curl -i -H 'Host: safe.local.test' \
  http://127.0.0.1:8086/assets/missing.js
```

預期：

```text
Unsafe -> 200, X-Location: exact-index, HTML Body
Safe   -> 404, X-Location: safe-assets
```

## 4. 觀察 Internal Redirect

```bash
curl -i -H 'Host: safe.local.test' \
  http://127.0.0.1:8086/dashboard
```

最初命中 `location /`，但 `try_files` Fallback 到 `/index.html` 後重新執行 Location Selection，最終 Response：

```text
200 OK
X-Location: exact-index
```

## 5. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-2/labs/hour-5/verify-spa-routing.sh
```

實際結果：

```text
Result: 6/6 SPA routing cases passed.
```

## 6. 清理

```bash
docker stop learn-nginx-spa
```
