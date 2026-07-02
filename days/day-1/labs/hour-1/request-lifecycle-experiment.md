# Hour 1 實驗：觀察 Client 到 Nginx

## 實驗目標

用三個小實驗觀察 Request Lifecycle，不把「收到 200」當成唯一結果：

1. 使用 `curl -v` 觀察 TCP 與 HTTP。
2. 證明同一個 IP 可以帶不同 Host Header。
3. 查看 Nginx Master 與 Worker Processes。

## 前置狀態

教學容器名稱：`learn-nginx-day1`

若容器尚未啟動：

```bash
docker run --rm -d \
  --name learn-nginx-day1 \
  -p 8080:80 \
  nginx:stable
```

確認狀態：

```bash
docker ps --filter name=learn-nginx-day1
```

## 實驗一：使用 `curl -v` 觀察 TCP 與 HTTP

執行：

```bash
curl -v http://127.0.0.1:8080/
```

依序找出：

```text
* Trying 127.0.0.1:8080...
* Connected to 127.0.0.1 ...
> GET / HTTP/1.1
> Host: 127.0.0.1:8080
< HTTP/1.1 200 OK
< Server: nginx/...
< Content-Type: text/html
```

解讀：

- `Trying`：curl 準備連線到解析後的 IP 與 Port。
- `Connected`：TCP Connection 已建立。
- `>`：Client 傳給 Nginx 的 HTTP Request。
- `<`：Nginx 回給 Client 的 HTTP Response。
- 本次使用 HTTP，因此不會看到 TLS Handshake。

回答並記錄：

1. Request Method 是什麼？
2. URI 是什麼？
3. Host Header 是什麼？
4. Status Code 與 Content-Type 是什麼？

## 實驗二：區分「連線 IP」與「HTTP Host」

兩次 Request 都連到相同 IP 與 Port，只改 Host Header：

```bash
curl -i -H 'Host: a.local.test' http://127.0.0.1:8080/
curl -i -H 'Host: unknown.local.test' http://127.0.0.1:8080/
```

目前兩次都會進入 Official Image 的 Default Server，因此回傳相同頁面。這個結果證明：

- 連線目的地都是 `127.0.0.1:8080`。
- Host Header 是 HTTP Request 的一部分。
- 只有 Config 定義不同 `server_name` 與 Default 行為後，Host 才會讓 Nginx 選擇不同站台。

Day 1 Hour 5 會修改 Config，讓這兩個 Requests 命中不同 Server Blocks。

## 實驗三：查看 Master 與 Worker

執行：

```bash
docker top learn-nginx-day1 -eo pid,ppid,user,comm,args
```

找出：

- `nginx: master process`
- 一個或多個 `nginx: worker process`
- 每個 Worker 的 PPID 是否等於 Master PID
- Master 與 Worker 是否使用相同 User

再執行：

```bash
docker exec learn-nginx-day1 nginx -T
```

在輸出中找出：

```nginx
worker_processes auto;

events {
    worker_connections 1024;
}
```

目前只需要觀察，不要急著把兩個數值相乘當作實際吞吐量。這會在 Day 5 詳細推導。

## 實驗四：觀察 Access Log

另開一個 Terminal：

```bash
docker logs -f learn-nginx-day1
```

回到原 Terminal：

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/not-found
```

預期第一個輸出 `200`，第二個輸出 `404`；Log 應各出現一筆對應紀錄。

停止追蹤 Log：按 `Ctrl+C`。

## 清理

完成後停止容器：

```bash
docker stop learn-nginx-day1
```

因為啟動時使用 `--rm`，停止後 Container 會自動移除。

## Hour 1 驗收題

1. `Connected` 表示 DNS、TCP 還是 HTTP 已完成？
2. `> Host:` 是 TCP 資訊還是 HTTP 資訊？
3. Master 是否直接處理每一個 Request？
4. 為什麼兩個不同 Host Header 目前仍回傳相同頁面？
