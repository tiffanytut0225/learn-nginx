# Day 1 總驗收

請先獨立回答，再回頭查看筆記。

## Q1：Request Lifecycle

請按順序排列並標示主要負責者：DNS、TCP、TLS、HTTP Request、Kernel Socket、Nginx Worker、Server Selection。

## Q2：Event-driven

一個 Worker 管理 5,000 個 Keepalive Connections，目前只有 2 個可讀。誰通知 Worker？Worker 是否需要逐一檢查 5,000 個 Connections？

## Q3：Process Model

Reload 後新 Config 有效時，Master PID、新 Worker PIDs、舊 Workers 分別會如何變化？

## Q4：Context

找出錯誤並說明：

```nginx
events {
    worker_connections 1024;
    listen 80;
}
```

## Q5：Server Selection

Config 有三個 Servers：

- `listen 80 default_server; server_name _;`
- `listen 80; server_name a.example.com;`
- `listen 80; server_name b.example.com;`

`Host: c.example.com` 會命中哪一個？為什麼？

## Q6：Fault Classification

將情境分類為 Syntax／Context、Server Selection、Filesystem Content：

1. `nginx -t` 顯示 `listen directive is not allowed here`。
2. TCP 成功，Host 沒匹配任何 `server_name`，回傳 Default Site。
3. 已命中正確 Server 與 Location，但 Request 回 404，Log 顯示檔案不存在。

## 作答紀錄與講評

### Q1

作答主線正確，但 HTTPS 與 HTTP 不是二選一：HTTPS 會先完成 TLS，再透過加密通道傳送 HTTP Request。

```text
HTTP：  DNS -> TCP -> HTTP Request
HTTPS： DNS -> TCP -> TLS -> HTTP Request
```

Kernel 負責 TCP／Socket 並不是只在 HTTP Request 之後才出現；流程圖將 Kernel Socket 放在 Server 接收端，是為了表達 Bytes 到達 Server 後如何交給 Nginx Worker。

### Q2

回答 Linux Kernel 正確；更完整答案是 Linux Kernel 透過 `epoll` 回報 Ready File Descriptors，Worker 不必逐一檢查全部 5,000 個 Connections。

### Q3

Master PID 不變、新 Worker PIDs 出現，方向正確。舊 Workers 不是立即被「刪除」，而是停止接受新工作、完成既有 Connections，再自行 Exit。

### Q4

回答「不被允許」正確；完整答案是 `listen` 不允許出現在 `events`，它應放在 `server` Context，`nginx -t` 會失敗。

### Q5

Fallback 到 Default Server 正確，但不是因為 `_` 是萬用名稱。`server_name _;` 只是慣用的、不太可能被正常 Host 匹配的名稱；真正決定 Fallback 的是 `listen 80 default_server;`。

### Q6

三項分類全部正確：Syntax／Context、Server Selection、Filesystem Content。

## 最終確認

- TLS Handshake 後傳送：HTTP Request。
- Unknown Host Fallback 的決定因素：`default_server`。

結果：Day 1 知識驗收通過。
