# Day 2 總驗收

## 驗收範圍

- Exact、Prefix、`^~`、Regex 與 Named Location。
- URI Normalization 與 Internal Redirect。
- `root`、Prefix `alias` 與 Regex `alias`。
- Safe SPA Fallback 與 Missing Asset 404。
- `return`、`rewrite`、`try_files` 與 `error_page`。
- HTML／Hashed Asset Cache Policy、Conditional Request、MIME 與 Gzip。

## 實際結果

| 項目 | 結果 |
|---|---:|
| Location Prediction | 12／15 |
| Location Actual | 15／15 |
| Filesystem Path Mapping | 6／6 |
| Safe SPA Routing | 6／6 |
| Redirect／Fallback | 6／6 |
| Static Delivery | 7／7 |

## 重要修正

1. 最長 Prefix 是 Regex 掃描前的候選，不保證最終勝出。
2. Prefix 沒有 Path Segment 邊界，`/api` 也匹配 `/apix`。
3. `alias` 是替換匹配部分；Slash 與 Regex Captures 都會影響最終 Path。
4. Missing Asset 必須 404，不能共用 SPA HTML Fallback。
5. `try_files` 最後的 URI、`rewrite ... last` 與 `error_page` 都可能造成 Location Re-selection。
6. External Redirect 是兩個 Client Requests；Internal Redirect 仍是同一個 Client Request。

## 最終確認

```text
GET /dashboard
  -> location /
  -> $uri 不存在
  -> Internal Redirect 到 /index.html
  -> 重新執行 Location Selection
  -> location = /index.html
```

結果：Day 2 知識驗收通過。
