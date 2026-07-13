# Day 3 總驗收：Reverse Proxy、Upstream 與擴展性

## 驗收目標

完成 Day 3 後，應能用自己的話說明：

- Nginx 如何把 Client Request 轉送到 Backend。
- `proxy_pass` URI Part 如何改變 Upstream URI。
- `Host`、`X-Forwarded-For`、`X-Forwarded-Proto` 的用途與信任邊界。
- Timeout、Buffering、Keepalive、Retry 與 DNS Failure 的實務判斷。
- 如何從 Response Status 與 Nginx Error Log 初步定位故障段落。

## 架構責任分界

### 1. Single Node

```text
Browser -> Nginx -> Backend
```

用途：最簡單的 Reverse Proxy 架構。  
限制：Nginx 與 Backend 都可能成為單點。

### 2. Multiple Upstream Nodes

```text
Browser -> Nginx -> Backend A/B/C
```

用途：擴展 Backend 層，讓 Nginx 可用 Round-robin、Least Connections 等方式分流。  
限制：Nginx 本身仍是單點；Backend session 不應只放在單一節點記憶體。

### 3. External LB / Ingress

```text
Browser -> External LB -> Nginx 1/2 -> Backend A/B/C
```

用途：擴展 Nginx 層，並避免只有單一 Nginx 承接所有入口流量。  
注意：若 TLS 在 External LB 終止，Nginx 看到的 `$scheme` 可能是 `http`，必須明確處理 `X-Forwarded-Proto` 與 Trust Boundary。

## Request Trace 驗收

Config：

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

若 Client 使用 HTTPS 連到 Nginx，Backend 最後應看到：

```http
GET /v1/users?page=2
Host: faceid.example.com
X-Forwarded-Proto: https
```

原因：

- `proxy_pass http://backend/v1/` 會用 `/v1/` 取代 matched prefix `/api/`。
- `proxy_set_header Host $host` 會保留原始使用者 Host。
- `proxy_set_header X-Forwarded-Proto $scheme` 會傳遞 Nginx 看到的 client-side scheme。

## Failure Diagnosis 驗收

| 現象 | 初步判斷 |
|---|---|
| `502 Bad Gateway` | Nginx 找不到、連不上，或無法正常跟 Backend 溝通。常見原因是 Backend 掛掉、Port 不通、DNS Failure、Upstream 設錯。 |
| `504 Gateway Timeout` | Nginx 已經等 Backend，但 Backend 太久沒回。常見 Error Log 是 `upstream timed out while reading response header from upstream`。 |
| Backend 自己回 `500` | Nginx 預設會把 Backend 的 HTTP 500 原樣轉回 Client。 |
| Client 先斷線，Nginx log `499` | Client 在 Nginx 回應前放棄連線；要繼續看當時 Nginx 正在等哪一段。 |

主管問：「Nginx 有時候回 502，有時候回 504，怎麼初步判斷？」

可回答：

> 我會先看 Nginx access/error log。502 比較像 Nginx 到 Backend 這段連線或解析失敗，例如 Backend 掛了、Port 不通、DNS 失敗、Upstream 設錯。504 則表示 Nginx 有連到 Backend 並等待 Response，但 Backend 太久沒回，可能超過 `proxy_read_timeout`。

口語心智模型：

```text
502 = 找不到人 / 連不上 / 溝通壞掉
504 = 有找到人，但對方太久不回
```

## Day 3 已驗證 Lab

| Hour | Lab | 驗證結果 |
|---|---|---|
| 1 | `proxy_pass` URI | `Result: 7/7 upstream URI cases passed.` |
| 2 | Proxy Headers | `Result: 3/3 proxy header modes passed.` |
| 3 | Proxy Timeouts | `Result: 4/4 proxy timeout cases passed.` |
| 4 | Buffering / Streaming | `Result: 3/3 buffering modes passed.` |
| 5 | Upstream Algorithms | `Result: 3/3 upstream algorithm checks passed.` |
| 6 | Upstream Keepalive | `Result: 2/2 upstream keepalive modes passed.` |
| 7 | Failure / Retry / DNS | `Result: 9/9 failure retry DNS cases passed.` |

## Day 3 結論

Day 3 的核心不是背 Directive，而是能追問：

```text
Nginx 要轉給誰？
URI 會變成什麼？
Backend 會看到哪些 Headers？
Nginx 會等多久？
失敗時是連不上、等太久，還是 Backend 自己回錯？
這個 Request 能不能安全 retry？
```

能回答這幾個問題，就已經具備 Reverse Proxy 與 Upstream 的基本攻錯能力。
