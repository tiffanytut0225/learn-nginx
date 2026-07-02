# Hour 2：Location Prediction Matrix

## 測試 Config

```nginx
location = /             { add_header X-Location exact-root always; }
location /               { add_header X-Location prefix-root always; }
location /api            { add_header X-Location prefix-api always; }
location ^~ /assets/     { add_header X-Location preferred-assets always; }
location ~ \.php$        { add_header X-Location regex-php always; }
location ~* \.(png|jpg)$ { add_header X-Location regex-image always; }

location /files/ {
    add_header X-Location prefix-files always;
    try_files $uri @missing;
}

location @missing {
    add_header X-Location named-missing always;
    return 404;
}
```

假設只有 `/files/exists.txt` 實際存在。

## Prediction

| # | Request URI | 作答 | 正確結果 | 結果 | 關鍵原因 |
|---:|---|---|---|---|---|
| 1 | `/` | `exact-root` | `exact-root` | ✓ | Exact Match 立即勝出 |
| 2 | `/api` | `prefix-api` | `prefix-api` | ✓ | 最長 Prefix |
| 3 | `/api/users` | `prefix-api` | `prefix-api` | ✓ | 最長 Prefix |
| 4 | `/api/test.php` | `regex-php` | `regex-php` | ✓ | Regex 覆蓋普通 Prefix |
| 5 | `/assets/logo.JPG` | `preferred-assets` | `preferred-assets` | ✓ | `^~` 阻止 Regex |
| 6 | `/API` | `prefix-root` | `prefix-root` | ✓ | Prefix 比對區分大小寫 |
| 7 | `/api/photo.PNG` | `regex-image` | `regex-image` | ✓ | `~*` 不區分大小寫 |
| 8 | `/assets/test.php` | `preferred-assets` | `preferred-assets` | ✓ | `^~` 阻止 PHP Regex |
| 9 | `/api//users` | `prefix-api` | `prefix-api` | ✓ | 重複 Slash 正規化 |
| 10 | `/apix` | `prefix-root` | `prefix-api` | ✗ | Prefix 沒有 Path Segment 邊界 |
| 11 | `/api/app.PHP` | `regex-php` | `prefix-api` | ✗ | `~ \.php$` 區分大小寫 |
| 12 | `/assets/../api/test.php` | `preferred-assets` | `regex-php` | ✗ | 先解析 `..`，再做 Location Selection |
| 13 | `/assetsx/logo.jpg` | `regex-image` | `regex-image` | ✓ | `/assets/` 不匹配，Image Regex 勝出 |
| 14 | `/files/exists.txt` | `prefix-files` | `prefix-files` | ✓ | 檔案存在，不觸發 Fallback |
| 15 | `/files/missing.txt` | `named-missing` | `named-missing` | ✓ | `try_files` 跳至 Named Location |

總結果：**12／15**。

Hour 3 將為每個 Location 加入可觀察的 Response，執行全部 Requests，比較 Prediction 與 Actual。
