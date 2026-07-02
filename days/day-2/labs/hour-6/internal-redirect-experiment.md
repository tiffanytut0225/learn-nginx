# Hour 6 實驗：Rewrite 與 Internal Redirect

## 目標

比較 `return`、`rewrite`、`try_files` 與 `error_page` 的控制流程，使用 Status、Body 與 `X-Location` 判斷是否重新執行 Location Selection。

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-redirects \
  -p 8086:80 \
  -v "$PWD/days/day-2/labs/hour-6/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/days/day-2/labs/hour-6/site:/usr/share/nginx/html:ro" \
  nginx:stable
```

## 2. External Redirect

```bash
curl -i http://127.0.0.1:8086/old
curl -iL http://127.0.0.1:8086/old
```

第一個命令只看到 301；第二個命令跟隨 Redirect，才會另外請求 `/new` 並看到 `X-Location: exact-new`。

## 3. Internal Rewrite

```bash
curl -i http://127.0.0.1:8086/legacy
```

Nginx 內部改寫為 `/new` 並重新選擇 Location：

```text
200 OK
X-Location: exact-new
```

## 4. `error_page` Status 比較

```bash
curl -i http://127.0.0.1:8086/missing-preserve
curl -i http://127.0.0.1:8086/missing-convert
```

預期：

```text
/missing-preserve -> 404, X-Location: error-preserve
/missing-convert  -> 200, X-Location: error-convert
```

## 5. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-2/labs/hour-6/verify-internal-redirects.sh
```

實際結果：

```text
Result: 6/6 redirect and fallback cases passed.
```

## 6. 清理

```bash
docker stop learn-nginx-redirects
```
