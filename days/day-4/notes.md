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
