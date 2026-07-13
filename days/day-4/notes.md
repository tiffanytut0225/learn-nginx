# Day 4 學習筆記

## Day 4：HTTPS、Domain/IP 與安全

## 今日名詞表

| 名詞 | 用途 |
|---|---|
| TCP | TLS 與 HTTP 之前的連線基礎；沒有 TCP 連線就不會進入 HTTPS/HTTP 流程。 |
| TLS | HTTPS 的加密層，負責加密、協商參數與驗證伺服器憑證。 |
| Certificate | 伺服器用來證明「我是這個網域」的憑證；Browser 會檢查信任鏈與名稱是否匹配。 |
| Certificate Chain | 從網站憑證一路連到可信 Root CA 的鏈；Chain 缺失會讓瀏覽器不信任。 |
| SNI | TLS Handshake 中 Client 先告訴 Server 想連哪個 hostname，讓 Nginx 選正確憑證。 |
| HTTP Host | HTTP Request Header，用來告訴 Nginx 使用者要哪個網站；它在 TLS 成功後才會被讀到。 |
| Redirect | HTTP 層的回應，例如 301/302；必須等 TLS 成功、HTTP Request 進來後才可能發生。 |
| Default Server | 當 `listen`/SNI/Host 找不到明確匹配時，Nginx 使用的預設 server block。 |
| `curl --resolve` | 測試指定 domain 連到指定 IP/port，同時保留 URL hostname 供 SNI、Host 與憑證驗證使用。 |
| Direct-IP HTTPS | 直接用 IP 存取 HTTPS；若憑證沒有包含該 IP，通常會在 TLS 憑證驗證階段失敗。 |
| HSTS | 告訴瀏覽器未來固定使用 HTTPS；設定錯誤可能讓錯誤 HTTPS 狀態被瀏覽器長期記住。 |
| Security Header | HTTP Response Header，用來降低 XSS、MIME sniffing、Clickjacking、Referrer 洩漏等風險。 |
| Rate Limiting | 限制單位時間內的 Request 數量，保護服務避免被濫用或突發流量打爆。 |

### Hour 1：TLS、SNI 與 Host

#### 核心順序

HTTPS Request 不是一開始就有 HTTP Host 可以用。正確順序是：

```text
1. TCP connection
2. TLS handshake starts
3. Client sends SNI hostname
4. Nginx uses SNI/listen default to choose certificate
5. Client verifies certificate
6. TLS succeeds
7. Client sends HTTP request with Host header
8. Nginx performs HTTP server/location logic
9. Nginx may return content or HTTP redirect
```

#### 第一個心智模型

```text
SNI 決定 TLS 階段「要拿哪張憑證」
Host 決定 HTTP 階段「要進哪個網站」
Redirect 是 HTTP 回應，救不了 TLS 憑證驗證失敗
```

#### Direct-IP HTTPS

若使用者直接連：

```text
https://127.0.0.1/
```

但憑證只包含：

```text
faceid.example.com
```

正常瀏覽器會先在 TLS 憑證驗證階段遇到 certificate name mismatch。因為使用者要連的是 IP，但伺服器拿出的憑證沒有證明自己屬於該 IP。

學習者回答：「因為憑證可能沒有綁 IP。」這是正確核心。完整化後：

```text
憑證驗證發生在 HTTP redirect 之前。
如果憑證沒有包含該 IP，瀏覽器會先擋下 HTTPS 連線。
因此不能期待 Nginx 先回 redirect，把 direct-IP HTTPS 救回正確 domain。
```

#### TLS Termination 與 `$scheme`

若架構是：

```text
Browser --HTTPS--> Nginx --HTTP--> Backend
```

Backend 直接看到的是 HTTP。若 Backend 需要知道外部原始協定，Nginx 通常會傳：

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

但若架構變成：

```text
Browser --HTTPS--> External LB --HTTP--> Nginx --HTTP--> Backend
```

Nginx 看到的 `$scheme` 是 `http`，不是使用者外部原始的 `https`。這時要由可信的 External LB 傳入 `X-Forwarded-Proto: https`，並由 Nginx 依 Trust Boundary 正確處理。

#### Hour 1 狀態

Hour 1 狀態：**完成**。已能說明 TCP → TLS/SNI/Certificate → HTTP Host → Redirect 的順序，並能解釋 Direct-IP HTTPS 為何不能靠 Redirect 解決 certificate mismatch。

### Hour 2：Request Matrix

#### 為什麼要分開 Certificate Result 與 HTTP Status

學習者回答：「TLS Certificate Result 只有 HTTPS 可以用。」這是正確起點。完整心智模型是：

```text
HTTP request:
  TCP -> HTTP Host -> HTTP Status
  沒有 TLS Certificate Result

HTTPS request:
  TCP -> TLS/SNI/Certificate Result
      -> TLS 成功後才有 HTTP Host
      -> HTTP Status
```

因此 Day 4 的 Request Matrix 要分開記：

| 欄位 | 用途 |
|---|---|
| TLS Certificate Result | 只存在於 HTTPS；判斷 SNI/URL hostname 是否與憑證匹配。 |
| HTTP Status | TLS 成功後才看得到；判斷 Nginx server/location/redirect/backend 結果。 |

如果 HTTPS 憑證驗證已經失敗，正常瀏覽器不會繼續進入 HTTP，因此不能同時說「certificate mismatch 但 HTTP 301 成功救回」。只有在測試時刻意使用 `curl -k` 忽略憑證錯誤，才是在隔離觀察 post-handshake 的 HTTP 行為。

#### Request Matrix 判斷

假設憑證只包含：

```text
faceid.example.com
```

| Request | TLS Certificate Result | HTTP 階段 |
|---|---|---|
| `https://faceid.example.com/` | 通過，hostname 與 certificate name 匹配 | TLS 通過後才進 HTTP；是否 redirect/回 content 要看 config |
| `https://127.0.0.1/` | 失敗，certificate 不包含 `127.0.0.1` | 正常瀏覽器不會先看到 HTTP redirect/status |
| `http://faceid.example.com/` | 不適用，HTTP 沒有 TLS | 直接進 HTTP，可由 Nginx 回 content 或 redirect |
| `https://unknown.example.com/` | 通常失敗，certificate 不包含 unknown hostname | 若用 `curl -k` 才能繼續觀察 Host `unknown.example.com` 落到哪個 server |

#### `curl --resolve`

本機測試 domain 對到指定 IP 時，使用：

```bash
curl --resolve faceid.example.com:443:127.0.0.1 https://faceid.example.com/
```

用途是「連線 IP 指到本機，但 URL hostname 保留 `faceid.example.com`」。因此 SNI、HTTP Host 與 Certificate 驗證目標都仍是 `faceid.example.com`。

直接使用：

```bash
curl https://127.0.0.1/
```

則是在測 Direct-IP HTTPS，SNI/Host/Certificate 驗證目標都會偏向 `127.0.0.1`，若憑證沒有包含 IP，會遇到 certificate name mismatch。

#### Hour 2 狀態

Hour 2 狀態：**完成**。已能將 HTTP/HTTPS、Domain/IP、Unknown Host 的 TLS Certificate Result 與 HTTP Status 分開預測。

### Hour 3：Local HTTPS Lab

#### Lab 目標

建立一個 development-only HTTPS Nginx，驗證：

| Case | 結果 |
|---|---|
| `https://faceid.example.com/` 搭配 `curl --resolve` 與信任 dev cert | TLS certificate 通過，HTTP `200` |
| `http://faceid.example.com/` 搭配 `curl --resolve` | HTTP `301` redirect 到 `https://faceid.example.com/` |
| `https://127.0.0.1/` 搭配信任 dev cert | certificate name mismatch，curl exit `60` |

#### Development-only Certificate

憑證 SAN 只包含：

```text
DNS:faceid.example.com
```

因此它可以證明 `faceid.example.com`，但不能證明 `127.0.0.1`。這讓 Lab 能明確驗證：

```text
domain HTTPS 正常
direct-IP HTTPS 憑證驗證失敗
```

#### Nginx Config

HTTP server：

```nginx
server {
    listen 80 default_server;
    server_name faceid.example.com;

    return 301 https://faceid.example.com$request_uri;
}
```

HTTPS server：

```nginx
server {
    listen 443 ssl default_server;
    server_name faceid.example.com;

    ssl_certificate /etc/nginx/certs/faceid.example.com.crt;
    ssl_certificate_key /etc/nginx/certs/faceid.example.com.key;

    location / {
        return 200 "secure faceid site\n";
    }
}
```

#### Actual Result Lab

完整 Lab：[Local HTTPS](labs/hour-3/local-https-experiment.md)。

```text
nginx: configuration file /etc/nginx/nginx.conf test is successful
Result: 6/6 local HTTPS cases passed.
```

#### Hour 3 狀態

Hour 3 狀態：**完成**。已產生 development-only certificate，設定 Canonical HTTPS Server、HTTP Redirect 與 Explicit Default Server，並在啟動後通過 `nginx -t` 與 6 個 HTTPS/HTTP 驗證 cases。

### Hour 4：驗證 Domain/IP 行為

#### `--resolve`、Direct-IP 與 `-k`

| 測試目的 | 指令方向 | 可證明什麼 |
|---|---|---|
| 測 domain HTTPS | `curl --resolve faceid.example.com:8443:127.0.0.1 https://faceid.example.com:8443/ --cacert cert` | SNI、Host、Certificate target 都是 `faceid.example.com` |
| 測 direct-IP HTTPS | `curl --cacert cert https://127.0.0.1:8443/` | Certificate 是否包含 `127.0.0.1` |
| 隔離 HTTP 層 | `curl -k https://127.0.0.1:8443/` | 忽略 certificate 驗證後，Nginx HTTP 層能否回應 |

學習者回答：「用 `curl -k` 測到 200 不能代表 HTTPS 設定完全正確，因為它忽略 TLS。」這是本 Hour 的核心結論。

```text
驗證 certificate：不要用 -k
隔離 HTTP 行為：可以用 -k，但結果不能代表 TLS 正確
```

#### Domain/IP Matrix Actual

完整 Lab：[Domain/IP Matrix](labs/hour-4/domain-ip-matrix-experiment.md)。

```text
Result: 5/5 domain/IP matrix cases passed.
```

特別修正：HTTP request 打到 HTTPS port 時，Nginx 實測回：

```text
400 Bad Request
The plain HTTP request was sent to HTTPS port
```

所以這不是 certificate mismatch，也不是 backend 問題，而是 client 使用的 URL scheme 與 port 上的 Nginx listener protocol 不匹配。

#### Hour 4 狀態

Hour 4 狀態：**完成**。已用 `curl --resolve` 驗證 Domain Cases、直接 IP 驗證 IP Cases，並能說明 `curl -k` 只能隔離 HTTP 層，不能證明 TLS certificate 正確。

### Hour 5：TLS Configuration

#### TLS 設定不要只背值，要知道責任

| 設定／概念 | 負責什麼 |
|---|---|
| `ssl_protocols` | 允許哪些 TLS protocol versions，例如 TLS 1.2 / TLS 1.3。 |
| Cipher Suite | 決定加密、金鑰交換與驗證演算法組合。 |
| `ssl_certificate` | Server 送給 Client 的 certificate chain；Production 通常應使用 fullchain。 |
| `ssl_certificate_key` | 對應 certificate 的 private key；不可 commit 到 repo。 |
| Session Reuse / Resumption | 減少重複 TLS handshake 的成本。 |
| OCSP | Client 查詢 certificate 是否被撤銷的機制。 |
| OCSP Stapling | Server 先附上 certificate revocation status，減少 client 自己查 CA。 |

#### Protocol Version

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

這控制 Client 可以使用哪些 TLS 版本與 Nginx 建立 HTTPS 連線。它不控制 certificate 包含哪些 domain，也不控制 HTTP redirect 或 backend upstream。

#### Certificate Chain

若瀏覽器或 client 顯示：

```text
certificate chain incomplete
unable to get local issuer certificate
```

常見原因是 Nginx 沒有送出完整中繼憑證鏈。Production 中 `ssl_certificate` 通常應指向 fullchain：

```nginx
ssl_certificate /path/to/fullchain.pem;
ssl_certificate_key /path/to/private.key;
```

Chain 的目標是讓 client 能一路驗證：

```text
網站憑證 -> Intermediate CA -> Root CA
```

#### Session Reuse / Resumption

Session reuse / resumption 的目標是減少重複 TLS handshake 的成本。它不會修復錯誤憑證，也不會讓 POST retry 變安全。

心智模型：

```text
HTTPS 不要每次都從零開始握手
```

#### OCSP Stapling

OCSP 用於查詢 certificate 是否被撤銷。OCSP Stapling 則是 Nginx 先取得 OCSP response，並在 TLS handshake 時附給 client。

用途：

```text
client 不一定要自己去查 CA
減少額外查詢延遲
也降低 client 對外查詢造成的隱私暴露
```

但 OCSP Stapling 需要 certificate chain、resolver、`ssl_stapling`、`ssl_stapling_verify` 等設定搭配，不是單純打開一個 directive 就代表完整正確。

#### Cipher Policy

不建議硬背一串 cipher list。Cipher policy 會隨著以下因素改變：

- Nginx 版本
- OpenSSL 版本
- 組織資安基準
- 法規或稽核要求
- Client 相容性需求

實務上應依組織基準與版本維護，而不是把網路文章中的 cipher list 永久複製進 production config。

#### Hour 5 狀態

Hour 5 狀態：**完成**。已能說明 Protocol、Certificate Chain、Session Reuse、OCSP Stapling 與 Cipher Policy 的責任邊界，並理解 TLS 設定應依版本與資安基準維護。

### Hour 6：Security Headers

#### Header 用途

| Header | 用途 |
|---|---|
| `Content-Security-Policy` | 限制頁面可以載入哪些來源的 script、style、image、font、API 等資源，降低 XSS 與惡意資源載入風險。 |
| `X-Content-Type-Options: nosniff` | 防止瀏覽器忽略 declared `Content-Type` 自己猜 MIME type。 |
| `Referrer-Policy` | 控制 Browser 跳到其他網站時，`Referer` header 要帶多少來源資訊。 |
| `Permissions-Policy` | 控制 camera、microphone、geolocation、payment 等瀏覽器功能權限。 |
| `X-Frame-Options` / CSP `frame-ancestors` | 降低網站被 iframe 嵌入造成 clickjacking 的風險。 |
| HSTS | 要求瀏覽器未來固定使用 HTTPS；不是 TLS 設定本身，但常與 HTTPS 安全策略一起規劃。 |

#### CSP

```http
Content-Security-Policy: default-src 'self'; script-src 'self'
```

CSP 主要降低 XSS 風險，但它也最容易破壞前端功能。若頁面需要第三方 SDK、CDN、inline style、font、image 或 API endpoint，CSP 必須依實際需求設計。

#### MIME Sniffing

```http
X-Content-Type-Options: nosniff
```

用途是讓瀏覽器不要自行猜測 MIME type。若 server 回錯 `Content-Type`，正確修法是修 response header，而不是移除 `nosniff`。

#### Referrer 與 Permissions

`Referrer-Policy` 用來減少敏感 URL/path/query 被外部網站透過 `Referer` 看到。常見平衡設定：

```http
Referrer-Policy: strict-origin-when-cross-origin
```

`Permissions-Policy` 則是限制瀏覽器能力，例如：

```http
Permissions-Policy: camera=(), geolocation=(), microphone=()
```

#### Clickjacking

防 clickjacking 可使用：

```http
X-Frame-Options: DENY
```

或使用 CSP：

```http
Content-Security-Policy: frame-ancestors 'self'
```

若產品需要被合法 iframe 嵌入，不能直接全站 `DENY`，需明確列出允許來源。

#### Compatibility Cost

學習者回答：「Security Headers 不能只貼最嚴格設定，因為可能破壞前端功能、第三方資源、iframe、登入流程或瀏覽器相容性。」這是本 Hour 核心。

完整 Policy Matrix：[Security Headers Policy Matrix](labs/hour-6/security-headers-policy.md)。

#### Hour 6 狀態

Hour 6 狀態：**完成**。已能說明 CSP、`nosniff`、Referrer-Policy、Permissions-Policy、Frame Protection 與 HSTS 的目的與 compatibility cost。

### Hour 7：Limits 與 Rate Limiting

#### 入口保護類型

| Directive / Concept | 控制什麼 | 常見 Status |
|---|---|---:|
| `client_max_body_size` | Request body 最大大小 | 413 |
| `client_body_timeout` | Client 傳 body 太慢 | 408 |
| `client_header_timeout` | Client 傳 header 太慢 | 408 |
| `limit_req` | 單位時間 request rate | 429（本 Lab 自訂） |
| `limit_conn` | 同一 key 同時 active connections | 429（本 Lab 自訂） |
| `burst` | 短時間突發 request 的排隊／容忍空間 | 依是否超過 burst |

#### 413 vs 504

學習者原始回答：「504 表示 server 掛掉了，413 表示 server 還在只是不接受 request。」其中 413 的方向正確，但 504 不一定代表 server 掛掉。

完整心智模型：

```text
413 = client 給太大，Nginx 入口擋下，通常還沒送到 backend
504 = Nginx 有等 backend，但 backend 太久沒回
502 = backend 掛掉、port 不通、DNS/upstream 溝通失敗時更常見
```

#### Rate vs Connection

```nginx
limit_req_zone $binary_remote_addr zone=api_rate:10m rate=1r/s;
limit_req_status 429;

limit_conn_zone $binary_remote_addr zone=per_ip_conn:10m;
limit_conn_status 429;
```

`limit_req` 限制的是 request rate，例如每秒幾個 requests。`limit_conn` 限制的是同時 active connections，例如同一 IP 同時最多幾條連線。

#### Actual Result Lab

完整 Lab：[Limits 與 Rate Limiting](labs/hour-7/limits-rate-experiment.md)。

```text
nginx: configuration file /etc/nginx/nginx.conf test is successful
Result: 6/6 limit and rate cases passed.
```

Debug note：第一次將 `/rate` 用 `return 200` 實作時，沒有觀察到 `limit_req` 拒絕第二個 request。改成 proxy 到測試 upstream 後，第二個立即 request 正常得到 `429`。這提醒我們：做 Nginx 行為實驗時，content handler 與 phase 會影響能否觀察到某些 directive。

#### Hour 7 狀態

Hour 7 狀態：**完成**。已驗證 `client_max_body_size`、`limit_req`、`limit_conn` 的 Status Code 與正常流量影響，並能區分 413、429 與 504 的故障層次。
