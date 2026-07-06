# Day 2 學習筆記

## Day 2：Location、Static Files、SPA 與 Rewrite

### Hour 1：Location Algorithm

#### 學習目標

- 預測 Exact、Prefix、Preferred Prefix 與 Regex Location 的勝出者。
- 理解 Prefix 邊界、URI Normalization 與 Named Location。
- 將「最長 Prefix」從最終答案修正為 Regex 檢查前的候選者。

#### Location Selection Algorithm

```text
1. 尋找 Exact Location（=）
   命中 -> 立即使用

2. 尋找最長 Prefix Location
   若最長 Prefix 帶有 ^~ -> 立即使用，不檢查 Regex

3. 依 Config 宣告順序檢查 Regex Location（~、~*）
   第一個匹配者 -> 勝出

4. 沒有 Regex 匹配
   -> 使用第 2 步找到的最長 Prefix
```

`~` 區分大小寫，`~*` 不區分大小寫。Regex 的勝出規則不是最長匹配，而是 Config 中第一個匹配者。

#### 實際預測修正

普通 Prefix 即使是最長匹配，仍可能被 Regex 覆蓋：

```nginx
location /images/thumbnails/ { return 200 "prefix"; }
location ~* \.(jpg|png)$     { return 200 "image-regex"; }
```

`/images/thumbnails/logo.png` 最後使用 Regex。若 Prefix 必須阻止 Regex 介入，需使用：

```nginx
location ^~ /images/thumbnails/ {
    return 200 "preferred-prefix";
}
```

#### Prefix 沒有路徑區段邊界

`location /foo` 是字串 Prefix，因此會同時匹配 `/foo`、`/foo/bar` 與 `/foobar`。若只接受 `/foo` 本身與其子路徑，可拆成：

```nginx
location = /foo { ... }
location /foo/  { ... }
```

#### URI Normalization

Nginx 會先正規化 URI，再執行 Location Selection。重要行為包含：

- 解碼 `%XX` Percent Encoding。
- 合併重複的 `/`（預設 `merge_slashes on`）。
- 解析 `.` 與 `..` Path Segments。

因此以下 URI 在 Location Selection 時都會形成 `/images/logo.png`：

```text
/images//logo.png
/images/./logo.png
/images/icons/../logo.png
/images/%6cogo.png
/images/logo%2Epng
```

#### Named Location

Named Location 不參與 Client URI 的一般比對。Client 請求 `/@fallback` 不會直接命中 `location @fallback`；它只能由 Nginx 內部流程跳轉，例如：

```nginx
try_files $uri @fallback;
error_page 404 = @fallback;
```

#### Hour 1 心智模型

```text
Exact 立即勝出
  -> 否則找最長 Prefix
  -> 最長 Prefix 是 ^~ 時停止
  -> 否則按順序找第一個匹配的 Regex
  -> Regex 都不匹配才回到最長 Prefix
```

Hour 1 狀態：**完成**。

### Hour 2：Location Prediction Matrix

#### 學習目標

- 在執行 Nginx 前，先預測 15 個 Requests 的 Location Selection。
- 同時考慮 Exact、普通 Prefix、`^~`、大小寫敏感／不敏感 Regex、URI Normalization 與 Named Location。
- 將錯誤預測轉成可重用的判斷規則。

#### Prediction 結果

- 第一組：5／5。
- 第二組：4／5。
- 第三組：3／5。
- 合計：12／15。

完整矩陣記錄於 [Location Prediction Matrix](labs/location-matrix.md)。

#### 三個誤判與修正

1. `/apix` 會匹配 `location /api`。普通 Prefix 沒有 Path Segment 邊界。
2. `/api/app.PHP` 不匹配 `location ~ \.php$`，因為 `~` 區分大小寫；最後使用 `prefix-api`。
3. `/assets/../api/test.php` 會先正規化成 `/api/test.php`，因此 `^~ /assets/` 不會入選，最後由 `regex-php` 勝出。

#### Named Location 與 `try_files`

當 `/files/missing.txt` 不存在時：

```text
先選 location /files/
  -> try_files 查找失敗
  -> 內部跳轉至 @missing
  -> 最終 X-Location 為 named-missing
```

這裡需要區分「初次 URI 選中的 Location」與「最終產生 Response 的 Location」。

#### Hour 2 心智模型

每次預測都依序回答：

1. 正規化後的 URI 是什麼？
2. 是否有 Exact Match？
3. 最長 Prefix 是誰，是否帶有 `^~`？
4. 哪一個 Regex 依宣告順序最先匹配？大小寫規則是什麼？
5. Content Handler 是否會觸發 Internal Redirect 或 Named Location？

Hour 2 狀態：**完成**。Prediction 正確率：**12／15**。

### Hour 3：Location Lab

#### 實驗方法

將 Hour 2 的 Location Matrix 實作為 Nginx Config。每個 Location 都回傳可辨識的 `X-Location` Header，再由驗證腳本逐一比較 Expected 與 Actual。

完整步驟與檔案：

- [Location Actual Result Lab](labs/hour-3/location-experiment.md)
- [Nginx Config](labs/hour-3/nginx.conf)
- [驗證腳本](labs/hour-3/verify-location-matrix.sh)

#### TDD 驗證

RED：在 Nginx Lab 尚未啟動時執行驗證腳本，第 1 題因 8085 沒有可連線服務而失敗。

GREEN：啟動 Config 後，15 個 Cases 的 `X-Location` 全部符合 Expected：

```text
Result: 15/15 cases passed.
```

#### 實驗中的環境診斷

原定的 Host Port `8085` 已由 Day 1 的 `learn-nginx-fault` Container 占用。保留既有 Container，不直接停止它；Hour 3 改用 `8086`。

此外，Container 與 Nginx 正常運行時，Sandbox 內仍無法連到 Host Port；在允許的本機網路環境執行同一支腳本後，完整 Matrix 通過。這區分了 Nginx Config Failure 與執行環境的 Network Boundary。

#### `curl --path-as-is`

測試 `/assets/../api/test.php` 時使用：

```bash
curl --path-as-is http://127.0.0.1:8086/assets/../api/test.php
```

`--path-as-is` 可避免 `curl` 在送出 Request 前自行正規化路徑，確保觀察到的是 Nginx 的 URI Normalization。

#### Prediction 與 Actual

- 原始 Prediction：12／15。
- 修正後 Expected：15／15。
- Nginx Actual：15／15。

Hour 3 狀態：**完成**。全部 Cases 已由 Response Header 實測。

### Hour 4：`root`、`alias` 與 Filesystem Path

#### 核心 Path Transformation

`root` 保留完整 URI：

```text
Filesystem Path = root 值 + 完整 Normalized URI
```

`alias` 取代匹配的 Location Prefix：

```text
Filesystem Path = alias 值 + 移除 Location Prefix 後的剩餘 URI
```

例如 Request `/images/logo.png`：

```nginx
location /images/ { root /srv/site; }
# /srv/site/images/logo.png

location /images/ { alias /srv/site/; }
# /srv/site/logo.png
```

#### 實際作答修正

最初只將 `root`、`alias` 的 Directive 值當成答案，漏掉 URI Transformation。修正後，六個預測 Paths 全部正確。

關鍵問題不是「設定值是什麼」，而是：

```text
Location 選定後，Nginx 如何把 Normalized URI 轉換成完整 Filesystem Path？
```

#### Regex Location 中的 `alias`

Regex Location 沒有可直接移除的固定 Prefix，因此使用 Captures 明確組合路徑：

```nginx
location ~ ^/exports/([^/]+)/(.+\.csv)$ {
    alias /archive/$1/$2;
}
```

Request `/exports/2026/reports/july.csv`：

```text
$1 = 2026
$2 = reports/july.csv
Filesystem Path = /archive/2026/reports/july.csv
```

#### Actual Result Lab

實驗透過 Response Header 暴露 `$request_filename`，直接觀察 Nginx 最後使用的 Path：

```nginx
add_header X-File-Path $request_filename always;
```

完整 Lab：[root 與 alias Path Mapping](labs/hour-4/path-mapping-experiment.md)。

結果：

```text
Result: 6/6 path mappings passed.
```

Hour 4 狀態：**完成**。六個 Filesystem Paths 均已預測並實測。

### Hour 5：SPA 與 `try_files`

#### `try_files` 的執行方式

```nginx
try_files $uri $uri/ /index.html;
```

Nginx 依序檢查 `$uri` 與 `$uri/` 對應的 Filesystem Entry。前兩者都不存在時，最後的 `/index.html` 是 URI，會觸發 Internal Redirect，而不是在原 Location 直接讀檔。

最後一個參數常見的三種形式：

```text
/index.html -> Internal Redirect，重新執行 Location Selection
@fallback   -> 跳至 Named Location
=404        -> 直接回傳 HTTP Status
```

#### 實際作答修正

第一個誤判：認為 `/assets/missing.js` 在通用 SPA Fallback 下會回 404。實際上它會 Fallback 到 `/index.html`，回傳 `200` 與 HTML。

第二個誤判：認為 `/dashboard` Fallback 後仍由原本的 `location /` 直接讀取 `index.html`。實際上 `/index.html` 會造成 Internal Redirect；重新比對後命中 `location = /index.html`，最終 Header 是 `exact-index`。

#### Unsafe SPA Config

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

這會把不存在的 Assets、API-like Paths 與真正的 SPA Deep Links 全部當成 SPA Route。Missing JavaScript 收到 HTML 時，Browser 常出現 MIME Type Error 或 `Unexpected token '<'`。

#### Safe SPA Config

```nginx
location ^~ /assets/ {
    try_files $uri =404;
}

location ^~ /api/ {
    return 404;
}

location / {
    try_files $uri $uri/ /index.html;
}
```

Routing Contract：

- Existing Asset：回傳 Asset。
- Missing Asset：404，不可回 HTML。
- SPA Deep Link：Internal Redirect 到 `/index.html`。
- API Path：由獨立 Location 處理，不可落入 SPA。

#### Actual Result Lab

完整 Lab：[Safe SPA 與 `try_files`](labs/hour-5/spa-routing-experiment.md)。

```text
Unsafe Missing Asset -> 200, exact-index
Safe Missing Asset   -> 404, safe-assets
Safe Deep Link       -> 200, exact-index
Safe API Path        -> 404, safe-api

Result: 6/6 SPA routing cases passed.
```

Hour 5 狀態：**完成**。Deep Link、Existing/Missing Asset 與 API-like Path 均已驗證。

### Hour 6：Rewrite 與 Internal Redirect

#### Directive 責任分界

| Directive | 適合解決的問題 |
|---|---|
| `return` | 直接回傳 Status 或固定 Redirect |
| `rewrite` | 使用 Regex 改寫 URI |
| `try_files` | 依 Filesystem 是否存在選擇處理方式 |
| `error_page` | 將特定錯誤交給自訂頁面或另一個 Location |

能用 `return` 表達的固定 Redirect，不需要使用較複雜的 `rewrite`。能用 `try_files` 表達的檔案／SPA 選擇，也不應堆疊 Rewrite Rules。

#### External Redirect 與 Internal Rewrite

```nginx
location = /old {
    return 301 /new;
}
```

`return 301` 結束目前 Request。Client 收到 `Location` 後，必須自行發送第二個 Request；未使用 `curl -L` 時，原 Response 不包含 `/new` Location 的 Header。

```nginx
location = /legacy {
    rewrite ^ /new last;
}
```

`rewrite ... last` 在 Nginx 內部改變 URI 並重新執行 Location Selection。Client 只送一個 Request，最終命中 `location = /new`。

#### `error_page` 與 Status

```nginx
error_page 404 /404.html;
```

這會 Internal Redirect 到 `/404.html`，重新選擇 Location 並使用其 Body／Headers，但保留原始 `404`。

```nginx
error_page 404 = /404.html;
```

帶 `=` 時採用新處理結果的 Status；若 `/404.html` 正常處理，最終通常為 `200`。

#### 實際作答修正

1. 將 `/old` 的 301 Response 與 Client 跟隨 Redirect 後的 200 Response 混在一起。修正後先分辨「目前 Response」與「第二個 Request」。
2. 正確預測 `error_page` 保留 404，但誤判不會帶目標 Location Header。實際上它會 Internal Redirect，因此最終包含 `X-Location: error-page`。

#### Actual Result Lab

完整 Lab：[Rewrite 與 Internal Redirect](labs/hour-6/internal-redirect-experiment.md)。

```text
return 301          -> 301, no X-Location
rewrite last        -> 200, exact-new
try_files existing  -> 200, try-files
try_files fallback  -> 404, named-fallback
error_page preserve -> 404, error-preserve
error_page convert  -> 200, error-convert

Result: 6/6 redirect and fallback cases passed.
```

Hour 6 狀態：**完成**。External Redirect、Internal Redirect 與 Status Preservation 均已驗證。

### Hour 7：Static Delivery

#### HTML 與 Hashed Asset 的 Cache Policy

```nginx
location = /index.html {
    add_header Cache-Control "no-cache" always;
}

location ^~ /assets/ {
    add_header Cache-Control "public, max-age=31536000, immutable" always;
}
```

`index.html` 應能快速取得新版本，因為它負責引用最新的 Hashed Assets。`no-cache` 不是禁止儲存，而是要求重用前向 Server 驗證。

帶 Content Hash 的 Asset 內容改變時檔名也會改變，因此舊 URL 可安全快取一年並標記 `immutable`。

#### Conditional Request

Response Validators 與 Request Headers 的對應：

```text
ETag          <-> If-None-Match
Last-Modified <-> If-Modified-Since
```

檔案未改變時，Server 回傳 `304 Not Modified`，不重新傳送 Body，Browser 繼續使用本地快取內容。

#### MIME Type

```nginx
include /etc/nginx/mime.types;
```

Nginx 依副檔名選擇 Content-Type。JavaScript 應回傳 JavaScript MIME Type，而不是 `text/html` 或通用 Binary Type；否則 Browser 可能拒絕執行。

#### Gzip Negotiation

Client 宣告支援的 Encoding：

```http
Accept-Encoding: gzip
```

Server 實際壓縮後回傳：

```http
Content-Encoding: gzip
Vary: Accept-Encoding
```

`Vary` 告訴 Cache：支援與不支援 Gzip 的 Clients 可能取得不同 Response 版本。

#### Actual Result Lab

完整 Lab：[Static Delivery](labs/hour-7/static-delivery-experiment.md)。

```text
PASS index.html requires revalidation
PASS hashed asset is immutable for one year
PASS JavaScript MIME type is correct
PASS ETag and Last-Modified are present
PASS If-None-Match returns 304
PASS If-Modified-Since returns 304
PASS Gzip negotiation sets Content-Encoding and Vary

Result: 7/7 static delivery checks passed.
```

Hour 7 狀態：**完成**。Cache、Conditional Request、MIME 與 Compression 均已驗證。

### Hour 8：攻錯與總驗收

#### 四類 Fault Diagnosis

1. SPA Deep Link 404：通用 Location 以 `=404` 結束，沒有 Fallback 到 `/index.html`。
2. Missing Asset 回 HTML：Assets 落入通用 SPA Fallback，Internal Redirect 到 `/index.html`。
3. `alias` Path 錯誤：Location 以 `/` 結尾但 Alias Target 沒有，產生 `/srv/mediacat.jpg`。
4. Regex 順序衝突：多個 Regex 同時匹配時，第一個匹配者勝出，不比較誰看起來更精確。

完整紀錄：[Hour 8 Fault Log](labs/hour-8/fault-log.md)。

#### 弱點複測

```text
Missing Asset 安全結果               -> 404
alias /srv/media + /media/cat.jpg     -> /srv/mediacat.jpg
多個 Regex 同時匹配                  -> 第一個匹配者勝出
try_files 最後使用 /index.html        -> Internal Redirect，重跑 Location Selection
```

Internal Redirect 最後一題確認：`/dashboard` Fallback 到 `/index.html` 後，最終命中 `location = /index.html`，Response Header 為 `exact-index`。

#### Routing Checklist

診斷 Nginx Routing 時依序檢查：

1. Normalized URI 是什麼？
2. Server Block 是否正確？
3. Exact、最長 Prefix、`^~`、Regex 最終誰勝出？
4. `root` 或 `alias` 產生的完整 Filesystem Path 是什麼？
5. `try_files` 每個 Candidate 是否存在？最後參數會做什麼？
6. 是否發生 Internal Redirect，導致 Location Re-selection？
7. Asset、API、SPA Route 是否有分開的 Failure Contract？
8. Status、Content-Type、Cache-Control、ETag、Last-Modified 與 Content-Encoding 是否符合預期？

#### Day 2 驗收結果

- Location Prediction：12／15，達到門檻；修正後 Actual 15／15。
- Filesystem Path Mapping：6／6。
- Safe SPA Routing：6／6。
- Redirect 與 Fallback：6／6。
- Static Delivery：7／7。
- 四類 Fault 均完成診斷，弱點複測完成。

Hour 8 狀態：**完成**。

Day 2 狀態：**完成**。Location、Static Files、SPA、Rewrite 與 Static Delivery 均已完成知識驗收與實機驗證。
