# Day 3 學習筆記

## Day 3：Reverse Proxy、Upstream 與擴展性

## 今日名詞表

| 名詞 | 用途 |
|---|---|
| Reverse Proxy | Nginx 站在 Client 與 Backend 中間，代替 Client 將 Request 轉送到後端服務。 |
| Upstream | Nginx 背後真正提供服務的 Backend Server 或 Server Group。 |
| `proxy_pass` | 指定某個 Location 要把 Request 轉送到哪個 Upstream，以及 URI 要如何轉換。 |
| URI Part | `proxy_pass http://backend/xxx/` 中 Host 後面的路徑；會影響 Prefix Location 的 URI 替換。 |
| Proxy Header | Nginx 轉送給 Backend 的 Header，例如 `Host`、`X-Real-IP`、`X-Forwarded-For`。 |
| Trust Boundary | 判斷哪些 Header/IP 是可信來源，哪些可能由 Client 偽造。 |
| `X-Forwarded-For` | 記錄 Client 與 Proxy Chain 的 IP 清單，但最左邊不一定可信。 |
| `X-Forwarded-Proto` | 告訴 Backend 使用者對外原始協定是 HTTP 還是 HTTPS。 |
| Timeout | 限制 Nginx 連後端、送 Request、等 Response 的最大等待時間。 |
| Buffering | Nginx 是否先暫存 Upstream Response，再依 Client 速度送出。 |
| Streaming/SSE | 後端持續逐段輸出資料，通常需要關閉 Buffering 才能即時抵達 Client。 |
| WebSocket Upgrade | HTTP 連線升級成雙向長連線，需要明確轉送 `Upgrade` 與 `Connection` Headers。 |
| Round-robin | 預設 Upstream 分配方式，依序輪替後端節點。 |
| Least Connections | 將新 Request 分給目前 Active Connections 較少的節點。 |
| Sticky / Affinity | 嘗試讓同一來源固定到同一節點，但不能取代共享 Session Store。 |
| Keepalive | 讓 Nginx 與 Upstream 的連線可被重用，減少重複 TCP 建連成本。 |
| DNS Resolver | 讓 Nginx 在執行期間查詢 Hostname 對應的 IP，常見於 Docker/Kubernetes 動態環境。 |
| Retry | Upstream 失敗時，Nginx 嘗試改送下一台後端。 |
| Idempotent | 同一個請求重做多次仍不改變最終狀態；通常較適合 Retry，例如 GET。 |
| Non-idempotent | 重做可能造成副作用或重複寫入；POST payment/order 這類請求不能隨便 Retry。 |
| 502 Bad Gateway | Nginx 作為 Proxy 時連不上、找不到或收到壞的 Upstream Response。 |
| 504 Gateway Timeout | Nginx 有等待 Upstream，但 Upstream 太久沒有回應。 |

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

### Hour 4：Buffering 與 Streaming

#### Buffering 的責任

一般 Response 保留 Proxy Buffering 時：

```text
Upstream 快速產生完整 Response
  -> Nginx 暫存於 Memory，必要時使用 Temporary File
  -> Upstream Connection 可較早釋放
  -> Nginx 依 Client 速度傳送
```

關閉 Buffering 時，Nginx 邊讀 Upstream 邊傳 Client。若 Client 很慢，Upstream Connection 可能被占用更久。因此不應看到 Streaming 就全站設定 `proxy_buffering off`。

#### 情境比較

| 情境 | 一般方向 | 原因 |
|---|---|---|
| 一般 JSON／HTML | 保留 Buffering | 隔離 Upstream 與慢速 Client |
| Large Response | 依 Size、Disk I/O、Client Speed 測量 | 不能只因檔案大就盲目關閉 |
| SSE／Streaming | 關閉 Buffering | Event 必須及時抵達 Client |
| WebSocket | 使用 Upgrade Flow | 長連線、雙向即時傳輸 |

Streaming Location 可設定：

```nginx
proxy_buffering off;
```

Upstream 也可針對單一 Response 回傳：

```http
X-Accel-Buffering: no
```

#### WebSocket Upgrade

WebSocket 先以 HTTP/1.1 Handshake 開始，Server 回 `101 Switching Protocols` 後切換為雙向協定。

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

`Upgrade` 與 `Connection` 是 Hop-by-hop Headers，不會由 Proxy 自動轉送到下一跳，因此必須明確設定。

#### Actual Result Lab

完整 Lab：[Buffering 與 Streaming](labs/hour-4/buffering-streaming-experiment.md)。

```text
Buffered        -> TTFB 2.02s, Total 2.02s
Unbuffered      -> TTFB 0.003s, Total 2.02s
X-Accel no      -> TTFB 0.004s, Total 2.02s

Result: 3/3 buffering modes passed.
```

相同 Upstream 都持續約 2 秒；差異在 Client 何時收到第一個 Byte。

Hour 4 狀態：**完成**。一般 Response、Large Response、SSE 與 WebSocket 的 Buffering 需求均已比較。

### Hour 5：Upstream Algorithm

#### Round-robin

預設演算法依序輪替 Upstream Servers，不考慮當下 Active Connection 數量：

```text
A -> B -> A -> B
```

適合 Request 成本相近、節點能力相近的基礎情境。可使用 `weight` 表達節點能力差異。

#### Least Connections

```nginx
upstream backend {
    least_conn;
    server backend-a;
    server backend-b;
}
```

`least_conn` 偏向目前 Active Connections 較少的節點，並考慮 Weight。它不知道 CPU、Memory 或真實 Response Cost，也不是「選最快機器」。

本次實驗先讓 Slow Request 占用 Backend A，再送 Fast Request：

```text
Slow Request -> A
Fast Request -> B
```

#### IP Hash 與 Sticky 限制

`ip_hash` 讓同一來源 IP 通常映射到同一節點，但不能保證永久固定：

- Client IP 可能改變。
- NAT 後大量使用者可能集中到相同節點。
- Backend 故障、移除或擴縮容會改變 Mapping。

重要 Session 應使用 Stateless Token 或 Redis／Database 等 Shared Session Store，不能只存在某台 Backend Memory。

#### 實際作答修正

1. 誤認 `least_conn` 會選 Active Connections 最多的 A；正確是選最少的 B。
2. 誤認 Round-robin 會考慮 Active Connections；實際只依輪替與 Weight。
3. 誤認 `ip_hash` 足以保證 Server-side Session；實際只提供有限的 Affinity。

#### Actual Result Lab

完整 Lab：[Upstream Algorithms](labs/hour-5/upstream-algorithms-experiment.md)。

```text
PASS round-robin sequence=ABAB
PASS least-conn slow=A fast=B
PASS ip-hash same-source=A

Result: 3/3 upstream algorithm checks passed.
```

Hour 5 狀態：**完成**。Round-robin、Least Connections 與 Sticky Behavior 均已驗證或界定限制。

### Hour 6：Upstream Keepalive

#### 兩組獨立 Connections

Reverse Proxy 不是一條 TCP Connection 穿過 Nginx：

```text
Browser <-- Client Connection --> Nginx <-- Upstream Connection --> Backend
```

Client Keepalive 與 Upstream Keepalive 各自有獨立的 Lifecycle、Timeout 與 Capacity。Browser 重用 Client Connection，不代表 Nginx 自動重用 Upstream Connection；反過來也一樣。

#### Upstream Keepalive Config

```nginx
upstream backend {
    server backend:8080;
    keepalive 32;
}

location / {
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_pass http://backend;
}
```

`keepalive 32` 表示每個 Worker 最多快取 32 條 Idle Upstream Keepalive Connections，不是整個 Upstream 同時只能處理 32 個 Requests。

`proxy_http_version 1.1` 讓 Upstream 使用 HTTP/1.1；清空 `Connection` 避免傳送 `close`，使 Connection 有機會回到 Idle Cache 被重用。

#### Actual Result Lab

Backend 回傳它看到的 Nginx Source Port。四次獨立 Client Requests 的結果：

```text
No Keepalive -> 56571 56573 56575 56577
Keepalive    -> 56579 56579 56579 56579
```

Source Port 會依環境改變；關鍵是 No Keepalive 有多個不同 Ports，而 Keepalive 重用同一 Port。

完整 Lab：[Upstream Keepalive](labs/hour-6/upstream-keepalive-experiment.md)。

```text
Result: 2/2 upstream keepalive modes passed.
```

#### 實際作答修正

誤認 Browser Keepalive 會自動延伸到 Backend。修正後將 Client 與 Upstream 視為兩組獨立 Connections。

Hour 6 狀態：**完成**。HTTP Version、Connection Header 與 Upstream Connection Reuse 均已驗證。

### Hour 7：Failure、Retry 與 DNS

#### 故障種類與 Status

Reverse Proxy 的錯誤碼判斷先問：「Nginx 是連不上、等太久，還是 Backend 自己回錯？」

| 情境 | Status | 判斷方式 |
|---|---:|---|
| Connection Refused | 502 | Nginx 嘗試連 Upstream Port，但該 Port 沒有服務。 |
| Slow Upstream Response | 504 | Nginx 已連上 Backend，但等待 Response Header 太久。 |
| Upstream HTTP 500 | 500 | Backend 自己產生 500，Nginx 預設原樣轉回。 |
| Runtime DNS Failure | 502 | Nginx 執行期間解析 Hostname 失敗，無法找到 Upstream。 |

#### DNS Resolver Timeout

Runtime DNS Failure 需要注意兩件事：

```nginx
resolver 127.0.0.11 valid=1s ipv6=off;
resolver_timeout 1s;
```

`resolver` 決定 Nginx 執行期間要問誰查 DNS；`resolver_timeout` 決定查詢最多等多久。本次第一次測試沒有設定 `resolver_timeout`，Client 先超時離開，Nginx access log 顯示 `499`。加入 `resolver_timeout 1s` 後，DNS Failure 可快速回 `502`。

#### Retry 與 Idempotency

```nginx
proxy_next_upstream error timeout;
```

`proxy_next_upstream` 允許 Nginx 在遇到 error 或 timeout 時改試下一台 Upstream。GET 查詢通常較適合 Retry，因為多查一次通常不改變資料狀態。

但付款、建單、扣庫存這類 POST 屬於 Non-idempotent Request。若 Backend A 已經收到 Request 並執行寫入，只是 Response 太慢，Nginx 若再轉給 Backend B，可能造成重複付款或重複建單。

本 Lab 中：

```text
POST /payments -> Backend A 收到一次寫入並延遲
Nginx 等待 Response 超時 -> 504
Backend B payments=0
```

這證明預設沒有把已送出的 POST 任意重試到下一台，避免 duplicate write。

#### Actual Result Lab

完整 Lab：[Failure、Retry 與 DNS](labs/hour-7/failures-retry-dns-experiment.md)。

```text
Result: 9/9 failure retry DNS cases passed.
```

#### 實際作答修正

原本將 Connection Refused 判成 504、Response Timeout 判成 502、Runtime DNS Failure 判成 504。修正後的心智模型：

```text
連不上 / 找不到 upstream -> 502
連上了但等太久 -> 504
backend 自己回 500 -> 500
```

Hour 7 狀態：**完成**。Connection Refused、Read Timeout、Upstream 500、Runtime DNS Failure、GET Retry 與 POST Non-idempotent Retry Risk 均已驗證。

### Hour 8：FaceID 擴展情境與驗收

#### 架構責任分界

三種常見部署方式要先分清楚「正在擴展哪一層」：

```text
A. Browser -> Nginx -> Backend
B. Browser -> Nginx -> Backend A/B/C
C. Browser -> External LB -> Nginx 1/2 -> Backend A/B/C
```

| 架構 | 主要用途 | 限制 |
|---|---|---|
| A | 最小 Reverse Proxy 架構 | Nginx 與 Backend 都可能是單點 |
| B | 擴展 Backend 層 | Nginx 本身仍是單點 |
| C | 擴展 Nginx 與 Backend 層 | Header、TLS Termination 與 Trust Boundary 需要更明確 |

若目標是「流量變大，需要水平擴展 Nginx 本身」，應使用 External LB 或 Ingress 將流量分到多台 Nginx。

#### Request Trace

題目 Config：

```nginx
location /api/ {
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_pass http://backend/v1/;
}
```

Client Request：

```http
GET /api/users?page=2
Host: faceid.example.com
```

若使用者用 HTTPS 連到 Nginx，Backend 最後看到：

```http
GET /v1/users?page=2
Host: faceid.example.com
X-Forwarded-Proto: https
```

判斷理由：

1. `/api/` 被 `proxy_pass` 的 URI Part `/v1/` 取代。
2. `Host $host` 保留使用者原始 Host。
3. `X-Forwarded-Proto $scheme` 傳遞 Nginx 看到的 Client-side Scheme。

若 TLS 在 External LB 終止，而 LB 到 Nginx 是 HTTP，則 Nginx 的 `$scheme` 可能是 `http`。此時必須依 Trust Boundary 設計，由可信的 LB 傳入並由 Nginx 正確處理 `X-Forwarded-Proto`。

#### 502 與 504 初步判斷

學習者原始回答：「Nginx -> Backend 這段不通。」這是 502 的重要判斷方向。完整回答需再補上 504 的差異：

```text
502：Nginx 找不到、連不上，或無法正常跟 Backend 溝通。
504：Nginx 有連到 Backend 並等待 Response，但 Backend 太久沒回。
```

常見 log 對照：

| Log / 現象 | 初步定位 |
|---|---|
| `connect() failed ... while connecting to upstream` | Nginx -> Backend 連線失敗，常見 502 |
| `host not found in upstream` / `could not be resolved` | Upstream DNS / Resolver 問題，常見 502 |
| `upstream timed out while reading response header from upstream` | Backend 太久沒回，常見 504 |
| Backend Response Status 是 500 | Backend 自己出錯，Nginx 預設原樣轉回 500 |

#### Day 3 總驗收

完整驗收整理：[Day 3 總驗收](day-3-assessment.md)。

Hour 8 狀態：**完成**。已能 Trace `/api/users` 到精確 Upstream URI 與 Headers，並能用 502／504／500 與 Error Log 初步定位 Upstream Failure。
