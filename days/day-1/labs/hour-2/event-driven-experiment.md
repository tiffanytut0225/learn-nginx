# Hour 2 實驗：一個 Worker 如何面對多個慢速 Connections

## 假設

Lab 強制只使用一個 Worker。先建立三個 TCP Connections，但不送出完整 HTTP Request；如果 Worker 會阻塞等待其中一個 Connection，第四個正常 Request 就無法立即得到 Response。

## 1. 啟動單一 Worker Lab

在專案根目錄執行：

```bash
docker run --rm -d \
  --name learn-nginx-event-loop \
  -p 8081:80 \
  -v "$PWD/days/day-1/labs/hour-2/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable
```

確認只有一個 Worker：

```bash
docker top learn-nginx-event-loop -eo pid,ppid,user,comm,args
```

## 2. 建立三個未完成的 HTTP Connections

開三個 Terminal，每個都執行：

```bash
nc 127.0.0.1 8081
```

連線後不要輸入內容。這三個 `nc` 都已建立 TCP Connection，但尚未送出完整 HTTP Request。

## 3. 發送第四個正常 Request

在第四個 Terminal 執行：

```bash
curl -i --max-time 3 http://127.0.0.1:8081/
```

預期：三秒內立即取得：

```http
HTTP/1.1 200 OK

single worker is responsive
```

## 4. 推論

這個結果支持：

- 單一 Worker 沒有阻塞在第一個未完成 Request 上。
- 未 Ready 的 Connections 可以保持等待。
- 新的 Ready Event 仍可由同一個 Worker 處理。

這個實驗不能單獨證明 Nginx 的全部內部實作，但它與 Event-driven、Non-blocking I/O 模型的預測一致。

## 5. 清理

在三個 `nc` Terminals 按 `Ctrl+C`，然後執行：

```bash
docker stop learn-nginx-event-loop
```

