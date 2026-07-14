# Day 5 總驗收：併發、效能、Observability 與總攻錯

## 驗收目標

完成 Day 5 後，應能用自己的話說明：

- 為什麼 `worker_processes * worker_connections` 不是 production capacity。
- Blocking operation 如何拖累 event-driven worker。
- Keepalive、Buffering、Compression 的效能 trade-off。
- Reverse proxy log 應如何設計，才能追到 backend app 且不洩漏敏感資料。
- 如何安全執行 `nginx -t`、graceful reload、rollback 與 graceful shutdown。
- 如何用 Evidence 與 Verification Method 做 Nginx config attack review。

## 15 分鐘 Walkthrough

### 1. Request Lifecycle（2 分鐘）

```text
URL -> DNS -> TCP -> TLS/SNI/Certificate -> HTTP Host
-> Nginx Server Selection -> Location Selection
-> Static / Proxy / Redirect / Error
-> Response / Logs
```

重點：先分層，不要把 TLS、HTTP、upstream 問題混在一起。

### 2. Location Fault（2 分鐘）

說明：

- Exact 先勝出。
- Prefix 先找最長。
- `^~` 可阻止 regex。
- Regex 依宣告順序第一個匹配勝出。
- `try_files` / `error_page` / named location 可能造成 internal redirect。

攻錯句：

```text
我會先問 normalized URI 是什麼，再問初始 location 與最終 response location 是否相同。
```

### 3. Proxy Failure（2 分鐘）

核心判斷：

```text
502 = Nginx 找不到、連不上，或無法正常跟 backend 溝通
504 = Nginx 有等 backend，但 backend 太久沒回
500 = backend 自己回錯，Nginx 預設原樣轉回
```

觀察欄位：

- `$status`
- `$upstream_status`
- `$upstream_addr`
- `$upstream_connect_time`
- `$upstream_header_time`
- `$upstream_response_time`

### 4. Domain / IP / TLS（2 分鐘）

核心順序：

```text
TCP -> TLS/SNI/Certificate -> HTTP Host -> Redirect
```

重點：

- `curl --resolve` 用來測 domain 行為但指定 IP。
- Direct-IP HTTPS 若憑證不含 IP，會先 certificate mismatch。
- `curl -k` 只代表跳過憑證驗證後 HTTP 層可回應。

### 5. Capacity 與 Performance（2 分鐘）

不要只背設定：

```text
capacity = CPU + FD + memory + client/upstream ratio + keepalive + workload
```

Trade-off：

- Keepalive：省建連成本，但 idle connection 占 FD/memory。
- Buffering：保護 backend，但耗 memory/disk，不適合 streaming。
- Compression：用 CPU 換 bandwidth。

### 6. Observability 與 Operations（2 分鐘）

好的 reverse proxy log 能回答：

```text
這個 request 是誰？
打到哪個 host/uri？
client 最後看到什麼 status？
Nginx proxy 到哪個 upstream？
upstream 回什麼？
各階段花多久？
能不能用 request_id 追到 backend app？
```

安全操作：

```text
nginx -t -> reload -> response/header check -> rollback check
```

### 7. Config Review（3 分鐘）

Finding 分類：

- Confirmed Defect
- Contextual Risk
- Hardening Opportunity
- Need Context

每個 finding 要包含：

- Evidence
- Impact
- Minimal Fix / Recommendation
- Verification Method
- Needed Context

## 現場未知 Config Case

未知 config：

```nginx
server {
    listen 80 default_server;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl default_server;
    server_name faceid.example.com;

    ssl_certificate /etc/nginx/certs/leaf-only.crt;
    ssl_certificate_key /etc/nginx/certs/faceid.example.com.key;

    access_log /var/log/nginx/access.log '$request_uri $http_authorization $http_cookie';

    location /api/ {
        proxy_pass http://backend/v1/;
    }
}
```

### Prediction

- `nginx -t` 可能因 `access_log` 參數格式或 unresolved `backend` 失敗，需實測。
- HTTP redirect 使用 `$host`，若 public-facing 可能有 untrusted Host redirect risk。
- HTTPS default server 是正式站，unknown host 行為需要檢查。
- `ssl_certificate` 看起來像 leaf-only，可能有 chain incomplete。
- access log 可能寫入 sensitive URI / Authorization / Cookie。

### Request

```bash
nginx -t
curl -I -H 'Host: evil.example' http://127.0.0.1/
curl --resolve unknown.example.com:443:127.0.0.1 https://unknown.example.com/
curl -H 'Authorization: Bearer secret' -H 'Cookie: sid=secret' 'https://faceid.example.com/api/users?token=secret'
```

### Log / Evidence

觀察：

- `nginx -t` 是否通過。
- Redirect `Location` 是否被 Host header 影響。
- Certificate result 是否符合 hostname。
- Access log 是否包含 token/cookie/Authorization。
- `$status`、`$upstream_status`、`$upstream_addr`、timing 是否足以定位 upstream。

### Root Cause

不要只說「怪怪的」。每個問題都要落到具體 root cause，例如：

- redirect 用不可信 `$host`。
- access log 記敏感 header/query。
- upstream 未定義或 DNS/trust boundary 不明。
- TLS certificate chain/SAN 不符合使用情境。

### Minimal Fix

- 使用 canonical redirect：`https://faceid.example.com$request_uri`。
- 建立 explicit unknown-host default server。
- 使用 fullchain certificate。
- 移除 Authorization/Cookie，避免完整 `$request_uri`。
- 定義 upstream 或 resolver strategy。

### Regression Check

- `nginx -t` 通過。
- `Host: evil.example` 不會產生 attacker-controlled redirect。
- 不使用 `-k` 的 domain HTTPS certificate 驗證通過。
- 帶 token/cookie 的 request 不會把敏感資料寫入 log。
- `/api/...` 有可觀察 upstream status/address/time。

## Day 5 已完成材料

| Hour | Material |
|---|---|
| 1 | [Capacity Worksheet](labs/hour-1/capacity-worksheet.md) |
| 4 | [Reverse Proxy Log Format Design](labs/hour-4/log-format-design.md) |
| 5 | [Short-lived vs Keepalive Lab](labs/hour-5/keepalive-behavior-experiment.md) |
| 6 | [Graceful Operations Lab](labs/hour-6/graceful-operations-experiment.md) |
| 7 | [Config Attack Review](labs/hour-7/config-attack-review.md) |

## Review Status

```text
AI-guided five-day learning review: completed.
Supervisor review: not performed in this repo session; ready for external review using the walkthrough and checklist.
```

## Day 5 結論

Day 5 的核心是：

```text
不要只背數字或 directive。
要能用 request lifecycle、logs、resource limits、verification method
把問題定位到正確層次，並證明修正有效。
```
