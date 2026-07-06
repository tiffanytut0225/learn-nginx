# Hour 2 實驗：Proxy Headers 與 Trust Boundary

## 目標

故意送入偽造的 `X-Forwarded-For`，比較 Default、Append 與 Edge Override 三種模式下 Backend 實際收到的 Headers。

## 三種模式

```text
Default：未設定 proxy_set_header
Append： 使用 $proxy_add_x_forwarded_for
Edge：   使用 $remote_addr 覆寫 XFF
```

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-proxy-headers \
  -p 8086:80 \
  -v "$PWD/days/day-3/labs/hour-2/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 2. 單題觀察

```bash
curl -i \
  -H 'Host: app.example.com' \
  -H 'X-Forwarded-For: 1.2.3.4' \
  http://127.0.0.1:8086/append/
```

Backend 會透過 `X-Seen-*` Response Headers 顯示實際收到的值。

## 3. 執行完整驗證

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-3/labs/hour-2/verify-proxy-headers.sh
```

本次 Docker Network 中，Front Nginx 觀察到的 Remote IP 是 `192.168.215.1`。實際結果：

```text
PASS default  host=127.0.0.1:8080 xff=1.2.3.4 real= proto=
PASS append   host=app.example.com xff=1.2.3.4, 192.168.215.1 real=192.168.215.1 proto=http
PASS edge     host=app.example.com xff=192.168.215.1 real=192.168.215.1 proto=http

Result: 3/3 proxy header modes passed.
```

Remote IP 會依 Docker Network 環境不同；驗證腳本會先讀取 `X-Front-Remote`，不將特定 IP 寫死為成功條件。

## 4. 清理

```bash
docker stop learn-nginx-proxy-headers
```
