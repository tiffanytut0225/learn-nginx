# Day 4 總驗收：HTTPS、Domain/IP 與安全

## 驗收目標

完成 Day 4 後，應能用自己的話說明：

- TCP、TLS/SNI、Certificate、HTTP Host 與 Redirect 的正確順序。
- 為什麼 direct-IP HTTPS 不能靠 redirect 解決 certificate mismatch。
- 如何用 `curl --resolve` 測 domain HTTPS，又保留正確 SNI、Host 與 certificate target。
- 為什麼 `curl -k` 只能隔離 HTTP 層，不能證明 TLS certificate 正確。
- Security Headers 的目的與 compatibility cost。
- Request limits、rate limits 與 upstream timeout 的錯誤碼差異。

## 核心順序

```text
TCP
-> TLS handshake
-> SNI
-> Nginx 選 certificate
-> Client 驗 certificate
-> TLS 成功
-> HTTP request
-> Host header
-> server/location
-> content、redirect、security headers 或 upstream
```

最重要分界：

```text
TLS 還沒過 -> 不要先談 HTTP status / redirect / location
TLS 過了 -> 才看 Host / server block / location / headers
HTTP 過了 -> 才看 backend / upstream
```

## 六種 Domain/IP/TLS Cases

假設 certificate 只包含：

```text
faceid.example.com
```

| Case | TLS Certificate Result | HTTP Result / 判斷 |
|---|---|---|
| `https://faceid.example.com/` with `--resolve` | 通過 | TLS 後才看 HTTP status；本 Lab 回 200 |
| `http://faceid.example.com/` with `--resolve` | 不適用，HTTP 沒有 TLS | 本 Lab 回 301 redirect 到 canonical HTTPS |
| `https://127.0.0.1/` | 失敗 | certificate 不包含 `127.0.0.1`，正常瀏覽器先看到 warning |
| `curl -k https://127.0.0.1/` | 被跳過 | 只能說忽略憑證驗證後 HTTP 層可回 200 |
| `https://unknown.example.com/` | 通常失敗 | certificate 不包含 unknown hostname；若 `-k` 後才看 unknown Host 落到哪個 server |
| `http://127.0.0.1:8443/` | 不適用，但 protocol mismatch | HTTP 打到 HTTPS port，Nginx 回 400 |

## 常見攻錯題

| 現象 | 優先檢查 |
|---|---|
| certificate name mismatch | URL hostname / SNI / certificate SAN 是否一致 |
| certificate chain incomplete | `ssl_certificate` 是否使用 fullchain，Intermediate CA 是否完整 |
| direct-IP HTTPS warning | certificate 是否包含該 IP；redirect 救不了 TLS 驗證失敗 |
| HTTP unknown host 進正式站 | `default_server` / `server_name` 設計 |
| redirect 到奇怪 domain | 是否使用不可信 `$host` 產生 `Location` |
| `curl -k` 看到 200 | 只能證明 HTTP 層；不能證明 TLS certificate 正確 |
| HSTS 誤用 | `max-age`、`includeSubDomains`、`preload` 是否過早或影響未準備好的子網域 |
| Security Header 衝突 | CSP/frame/referrer/permissions 是否破壞前端功能或第三方整合 |

## 主管問答驗收

主管問：

> 為什麼我們不能只用 `curl -k` 測 HTTPS？看到 200 不就好了嗎？

可回答：

> `curl -k` 會跳過 HTTPS 的憑證檢查，所以它不能證明 certificate、hostname、chain 都正確。看到 200 只能代表「忽略 TLS 驗證後，HTTP 層可以回應」。正式驗證 HTTPS 時不能只看 `-k` 的結果，還要在不使用 `-k` 的情況下驗證 certificate 是否正確。

## Day 4 已驗證 Lab

| Hour | Lab | 驗證結果 |
|---|---|---|
| 3 | Local HTTPS | `Result: 6/6 local HTTPS cases passed.` |
| 4 | Domain/IP Matrix | `Result: 5/5 domain/IP matrix cases passed.` |
| 6 | Security Headers Policy Matrix | 已記錄目的與 compatibility cost |
| 7 | Limits 與 Rate Limiting | `Result: 6/6 limit and rate cases passed.` |

## Day 4 結論

Day 4 的核心不是背 HTTPS 指令，而是能先判斷問題卡在哪一層：

```text
是 TLS certificate / chain / SNI？
是 HTTP Host / default_server / redirect？
是 browser security header 行為？
是 request 太大、太快、連線太多？
還是 upstream 太慢或不通？
```

能分層判斷，才不會把 certificate mismatch 誤判成 redirect 問題，也不會把 `curl -k` 的 200 誤當成 HTTPS 完整正確。
