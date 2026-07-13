# Hour 6：Security Headers Policy Matrix

Security Headers 不是「越嚴格越好」的固定貼紙，而是瀏覽器端安全控制。每個 header 都需要同時記錄目的與 compatibility cost。

| Header | 主要目的 | 常見設定方向 | Compatibility Cost |
|---|---|---|---|
| `Content-Security-Policy` | 降低 XSS 與惡意資源載入風險 | 從 report-only 或較小範圍開始，逐步收斂 `script-src`、`style-src`、`img-src`、`connect-src` | 可能阻擋前端 bundle、inline script/style、第三方 SDK、API endpoint、font/image CDN |
| `X-Content-Type-Options` | 防止 MIME sniffing | `nosniff` | 若 server 回錯 `Content-Type`，原本「靠瀏覽器猜」可運作的資源會失敗；正確修法是修 Content-Type |
| `Referrer-Policy` | 控制跨站跳轉時帶多少 referrer | `strict-origin-when-cross-origin` 常作為平衡選擇 | 可能影響 analytics、外部跳轉追蹤、合作方 attribution |
| `Permissions-Policy` | 限制 camera、microphone、geolocation 等瀏覽器功能 | 對不需要的功能設定 `()` | 若產品需要定位、相機、付款、全螢幕等功能，可能被阻擋 |
| `X-Frame-Options` / CSP `frame-ancestors` | 降低 clickjacking 風險 | `DENY`、`SAMEORIGIN`，或用 `frame-ancestors` 指定允許來源 | 可能破壞合法 iframe 嵌入、後台 portal、第三方整合 |
| HSTS | 要求瀏覽器未來固定使用 HTTPS | 先短 max-age，確認穩定後再增加；preload 要非常謹慎 | 錯設會讓瀏覽器長期強制 HTTPS，若憑證或子網域未準備好會造成長期故障 |

## 實務檢查順序

1. 先列出頁面需要的 script、style、image、font、connect/API、iframe 來源。
2. 先用低風險 header，例如 `X-Content-Type-Options`、`Referrer-Policy`。
3. CSP 先用 `Content-Security-Policy-Report-Only` 觀察，再逐步 enforcement。
4. HSTS 先用短 `max-age`，確認所有 domain/subdomain HTTPS 正常後再拉長。
5. 每次調整後用瀏覽器 console、network tab、error logs 驗證是否破壞功能。
