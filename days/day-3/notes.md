# Day 3 學習筆記

## Day 3：Reverse Proxy、Upstream 與擴展性

### Hour 1：`proxy_pass` URI

#### 核心規則

不帶 URI Part 的 `proxy_pass` 保留完整 URI：

```nginx
location /api/ {
    proxy_pass http://backend;
}
```

```text
/api/users?page=2 -> /api/users?page=2
```

帶 URI Part 時，以該 URI Part 取代匹配的 Normalized Location Prefix：

```nginx
location /api/ {
    proxy_pass http://backend/;
}
```

```text
/api/users?page=2 -> /users?page=2
```

Nginx 不會替 URI 做語意化 Join；Slash 必須精確設計：

```text
proxy_pass http://backend/v1/; -> /v1/users
proxy_pass http://backend/v1;  -> /v1users
```

#### Regex 與 Named Location 限制

以下 Config 會讓 `nginx -t` 失敗：

```nginx
location ~ ^/api/(.*)$ {
    proxy_pass http://backend/v1/;
}
```

錯誤原因是 Regex Location 沒有固定 Prefix 可供 Nginx 替換。Named Location、`if` 與 `limit_except` 中也有相同限制：`proxy_pass` 不可帶 URI Part。

#### Rewrite 後 URI

```nginx
location /api/ {
    rewrite ^/api/(.*)$ /v2/$1 break;
    proxy_pass http://backend;
}
```

不帶 URI Part 的 `proxy_pass` 會傳送 Rewrite 後的完整 URI：

```text
/api/users?page=2 -> /v2/users?page=2
```

#### 實際作答修正

1. 誤認 `proxy_pass http://backend/` 會在原 URI 前增加 `/`；實際是用 `/` 取代 `/api/`。
2. 誤認 Regex Location 可搭配 `/v1/` URI Part；實際在 Config Validation 階段就會失敗。

#### Actual Result Lab

完整 Matrix：[Upstream URI Matrix](labs/upstream-uri-matrix.md)。

完整 Lab：[proxy_pass URI](labs/hour-1/proxy-pass-uri-experiment.md)。

```text
Result: 7/7 upstream URI cases passed.
```

Invalid Regex Config：`nginx -t` 如預期失敗。

Hour 1 狀態：**完成**。Prefix Replacement、Slash、Regex、Named Location 與 Rewrite 後 URI 均已驗證。

### Hour 2：Proxy Headers 與 Trust Boundary

#### 預設 Upstream Host

若沒有 `proxy_set_header Host ...`，Nginx 預設將 Upstream `Host` 設為 `$proxy_host`，也就是 `proxy_pass` 中的 Host 與 Port，而不是 Client 原始 Host。

```nginx
proxy_pass http://backend:8080;
```

```text
Upstream Host: backend:8080
```

若 Backend 需要原始網站 Host，必須明確設定：

```nginx
proxy_set_header Host $host;
```

#### 常見 Proxy Headers

```nginx
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

| Header | 意義 |
|---|---|
| `Host` | 使用者請求的網站名稱 |
| `X-Real-IP` | 目前認定的單一 Client IP |
| `X-Forwarded-For`（XFF） | Client 與 Proxy IP Chain |
| `X-Forwarded-Proto` | Client 對目前 Proxy 使用的 `http` 或 `https` |

典型 TLS Termination 架構：

```text
Browser --HTTPS--> Nginx --HTTP--> Backend
```

Backend 雖然收到 HTTP Connection，仍可透過 `X-Forwarded-Proto: https` 知道外部原始協定。

#### Trust Boundary

Client 可以自行偽造：

```http
X-Forwarded-For: 1.2.3.4
```

`$proxy_add_x_forwarded_for` 會保留 Incoming XFF，再附加 `$remote_addr`：

```text
1.2.3.4, 192.168.215.1
```

最左邊的值仍可能是攻擊者輸入。只有在前方 Proxy Chain 與可信 IP 範圍都已明確設定時，才能依規則解析 XFF。

若目前 Nginx 是直接面對 Internet 的第一層 Edge，可覆寫 Client 傳入值：

```nginx
proxy_set_header X-Forwarded-For $remote_addr;
```

#### 實際作答修正

誤認 `$proxy_add_x_forwarded_for` 產生的最左邊 IP 可直接信任。實際上 Nginx 只負責串接 Header，並不驗證 Incoming Value 的真實性。

#### Actual Result Lab

完整 Lab：[Proxy Headers 與 Trust Boundary](labs/hour-2/proxy-headers-experiment.md)。

```text
Default -> host=127.0.0.1:8080, xff=1.2.3.4
Append  -> host=app.example.com, xff=1.2.3.4, 192.168.215.1
Edge    -> host=app.example.com, xff=192.168.215.1

Result: 3/3 proxy header modes passed.
```

Hour 2 狀態：**完成**。Host、X-Real-IP、XFF、Proto 與 Edge Trust Boundary 均已驗證。

### Hour 3：Timeouts

#### 三段 Timeout

| Directive | 控制範圍 |
|---|---|
| `proxy_connect_timeout` | Nginx 與 Upstream 建立 Connection |
| `proxy_send_timeout` | Nginx 將 Request 傳送給 Upstream |
| `proxy_read_timeout` | Nginx 等待並讀取 Upstream Response |

Client 將 Request Body 上傳給 Nginx 的等待則屬於 `client_body_timeout`，不是 `proxy_send_timeout`。

#### Timeout 通常不是總時限

`proxy_send_timeout` 與 `proxy_read_timeout` 通常限制兩次連續 I/O 操作之間的等待時間。若 Upstream 每 4 秒送出一段資料，而 `proxy_read_timeout` 是 5 秒，即使整體 Response 持續 60 秒也不一定 Timeout。

#### Status 與 Failure Phase

本 Lab 的 Actual Results：

```text
Healthy          -> 200
Connection Refused -> 502
Read Timeout     -> 504
Send Timeout     -> 504
```

Connection Refused 是 Connect Phase Failure，但不是等待 `proxy_connect_timeout` 到期；OS 立即回報 Port 無服務，因此快速得到 502。

#### Send Timeout 的前置條件

第一次使用 32 MiB Request Body 測試時得到 `413 Request Entity Too Large`。Request 被 `client_max_body_size` 擋下，尚未進入 Proxy Send Phase。

Lab 將限制提高：

```nginx
client_max_body_size 64m;
proxy_request_buffering off;
proxy_send_timeout 1s;
```

之後 Nginx 才會即時將 Body 傳給「接受 Connection 但不讀資料」的 Upstream，最終觸發 Send Timeout。

#### Actual Result Lab

完整 Lab：[Proxy Timeouts](labs/hour-3/proxy-timeouts-experiment.md)。

```text
Result: 4/4 proxy timeout cases passed.
```

Hour 3 狀態：**完成**。Connect Failure、Slow Send、Slow Response 與 Healthy Control 均已驗證。
