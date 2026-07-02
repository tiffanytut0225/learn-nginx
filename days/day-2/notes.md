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
