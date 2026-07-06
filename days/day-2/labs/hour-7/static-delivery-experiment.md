# Hour 7 實驗：Static Delivery

## 目標

驗證 HTML 與 Hashed Asset 的 Cache Policy、ETag、Last-Modified、Conditional Request、JavaScript MIME Type 與 Gzip。

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-static \
  -p 8086:80 \
  -v "$PWD/days/day-2/labs/hour-7/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/days/day-2/labs/hour-7/site:/usr/share/nginx/html:ro" \
  nginx:stable
```

## 2. 比較 Cache Policy

```bash
curl -I http://127.0.0.1:8086/index.html
curl -I http://127.0.0.1:8086/assets/app.a1b2c3.js
```

預期：

```text
index.html       -> Cache-Control: no-cache
app.a1b2c3.js    -> Cache-Control: public, max-age=31536000, immutable
```

## 3. Conditional Request

先從 Asset Response 取得 `ETag` 與 `Last-Modified`，再分別送出：

```http
If-None-Match: <ETag value>
If-Modified-Since: <Last-Modified value>
```

兩者在檔案未修改時都應得到 `304 Not Modified`，且不包含檔案 Body。

## 4. Gzip

```bash
curl -I \
  -H 'Accept-Encoding: gzip' \
  http://127.0.0.1:8086/assets/app.a1b2c3.js
```

預期 Headers：

```text
Content-Encoding: gzip
Vary: Accept-Encoding
```

## 5. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-2/labs/hour-7/verify-static-delivery.sh
```

實際結果：

```text
Result: 7/7 static delivery checks passed.
```

## 6. 清理

```bash
docker stop learn-nginx-static
```
