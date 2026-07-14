# Hour 8：主管簡報 Walkthrough

## 15 分鐘結構

1. Request Lifecycle：DNS / TCP / TLS / HTTP / Server / Location。
2. Location Fault：用 normalized URI 和 final response location 找問題。
3. Proxy Failure：用 502 / 504 / 500 和 upstream logs 分層。
4. Domain/IP/TLS：先 certificate，再 HTTP status；`curl -k` 不能代表 TLS 正確。
5. Capacity：`worker_processes * worker_connections` 只是粗估 slots，不是 production capacity。
6. Observability：request_id、upstream status/address/time，且不要記敏感資料。
7. Config Review：每個 finding 都要有 evidence 和 verification method。

## 一句話總結

```text
我現在看 Nginx 問題會先分層，再用 response、logs、nginx -t 和最小 request 驗證，不會只憑感覺猜。
```

## 可現場展示的能力

- 預測一個 request 會落到哪個 server/location。
- 解釋 `root` / `alias` 的 filesystem path。
- Trace `proxy_pass` 後 backend 收到的 URI 與 headers。
- 區分 502、504、500。
- 解釋 direct-IP HTTPS 為何 redirect 救不了 certificate mismatch。
- 設計不洩漏 token/cookie 的 reverse proxy log format。
- 做 config review finding，包含 evidence、impact、minimal fix、verification method。
