# Hour 1 實驗：`proxy_pass` URI Transformation

## 目標

使用 Front Proxy 將 Requests 送到同一個 Container 內的 Echo Backend，透過 `X-Upstream-URI` 觀察 Backend 實際收到的 URI。

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-proxy-uri \
  -p 8086:80 \
  -v "$PWD/days/day-3/labs/hour-1/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 2. 單題觀察

```bash
curl -i 'http://127.0.0.1:8086/strip/users?page=2'
```

預期：

```text
X-Upstream-URI: /users?page=2
```

## 3. 完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-3/labs/hour-1/verify-upstream-uri.sh
```

實際結果：

```text
Result: 7/7 upstream URI cases passed.
```

## 4. Invalid Regex Config

```bash
docker run --rm \
  -v "$PWD/days/day-3/labs/hour-1/nginx-invalid-regex-uri.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable nginx -t
```

預期 Config Validation 失敗，因為 Regex Location 中的 `proxy_pass` 帶有 URI Part。

## 5. 清理

```bash
docker stop learn-nginx-proxy-uri
```
