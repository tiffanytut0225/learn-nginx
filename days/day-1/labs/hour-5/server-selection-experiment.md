# Hour 5 實驗：相同 IP/Port，不同 Host

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-server-selection \
  -p 8084:80 \
  -v "$PWD/days/day-1/labs/hour-5/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 2. 執行前先預測

| Request Host | 預測 `X-Selected-Server` | 實際結果 |
|---|---|---|
| `a.local.test` | `site-a` | `site-a` ✓ |
| `b.local.test` | `site-b` | `site-b` ✓ |
| `unknown.local.test` | `default` | `default` ✓ |

## 3. 執行

```bash
curl -i -H 'Host: a.local.test' http://127.0.0.1:8084/
curl -i -H 'Host: b.local.test' http://127.0.0.1:8084/
curl -i -H 'Host: unknown.local.test' http://127.0.0.1:8084/
```

觀察 `X-Selected-Server` Header 與 Body。

## 4. 清理

```bash
docker stop learn-nginx-server-selection
```
