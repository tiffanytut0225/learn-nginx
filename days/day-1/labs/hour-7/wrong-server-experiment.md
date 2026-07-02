# Hour 7 攻錯：Wrong Server Selection

## 情境

需求是：`api.local.test` 應命中 FaceID API Server，但目前回傳 Default Site。

## 啟動

```bash
docker run --rm -d \
  --name learn-nginx-fault \
  -p 8085:80 \
  -v "$PWD/days/day-1/labs/hour-7/nginx-wrong-server.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

## 重現

```bash
curl -i -H 'Host: api.local.test' http://127.0.0.1:8085/
```

## 診斷順序

1. 確認 TCP 目的 IP／Port。
2. 確認 Request Host。
3. 找出相同 `listen` 的候選 Servers。
4. 比較 Host 與每個 `server_name`。
5. 說明為何落入 Default Server。
6. 提出最小修正與 Regression Requests。

## 清理

```bash
docker stop learn-nginx-fault
```
