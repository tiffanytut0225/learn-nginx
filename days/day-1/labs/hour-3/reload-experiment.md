# Hour 3 實驗：Valid／Invalid Config 與 Graceful Reload

## 1. 啟動 V1

```bash
docker run --rm -d \
  --name learn-nginx-reload \
  -p 8082:80 \
  nginx:stable

docker cp days/day-1/labs/hour-3/nginx-v1.conf \
  learn-nginx-reload:/etc/nginx/nginx.conf

docker exec learn-nginx-reload nginx -t
docker exec learn-nginx-reload nginx -s reload
curl -i http://127.0.0.1:8082/
```

預期 Body：

```text
config version: v1
```

記錄 Process：

```bash
docker top learn-nginx-reload -eo pid,ppid,user,comm,args
```

## 2. 驗證 Invalid Config 不應上線

```bash
docker cp days/day-1/labs/hour-3/nginx-invalid.conf \
  learn-nginx-reload:/etc/nginx/nginx.conf

docker exec learn-nginx-reload nginx -t
```

預期：失敗並指出缺少分號。不要把 `nginx -t` Failure 當成服務已停止；執行：

```bash
curl -i http://127.0.0.1:8082/
```

預期仍回傳 V1，因為執行中的 Workers 仍使用已載入的舊 Config。

## 3. 修正為 V2 並 Graceful Reload

```bash
docker cp days/day-1/labs/hour-3/nginx-v2.conf \
  learn-nginx-reload:/etc/nginx/nginx.conf

docker exec learn-nginx-reload nginx -t
docker exec learn-nginx-reload nginx -s reload
curl -i http://127.0.0.1:8082/
```

預期：

- `nginx -t` 成功。
- Response Header 包含 `X-Config-Version: v2`。
- Body 是 `config version: v2`。

再次查看 Process：

```bash
docker top learn-nginx-reload -eo pid,ppid,user,comm,args
```

觀察 Worker PIDs 與 V1 是否不同。Master PID 應維持不變；舊 Workers 由 Master 要求 Graceful Exit，不需手動刪除。

## 4. 清理

```bash
docker stop learn-nginx-reload
```
