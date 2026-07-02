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
