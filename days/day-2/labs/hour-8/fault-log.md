# Hour 8 Fault Log

## Fault 1：SPA Deep Link 404

**症狀：** `/` 正常，直接開啟 `/dashboard` 得到 404。

**根因：** `/dashboard` 沒有實體檔案，`try_files $uri =404` 沒有 SPA Entry Point Fallback。

**最小修正：**

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

## Fault 2：Missing Asset 回 HTML

**症狀：** `/assets/app-old.js` 回傳 `200 text/html`，Browser 出現 MIME Type Error。

**根因：** Missing Asset 落入通用 SPA Fallback，Internal Redirect 到 `/index.html`。

**最小安全修正：**

```nginx
location ^~ /assets/ {
    try_files $uri =404;
}

location / {
    try_files $uri $uri/ /index.html;
}
```

## Fault 3：錯誤 `alias` Slash

**症狀：** `/media/cat.jpg` 存在於 `/srv/media/cat.jpg`，但 Nginx 回 404。

**根因：**

```nginx
location /media/ {
    alias /srv/media;
}
```

Location Prefix 移除後剩下 `cat.jpg`，與 Alias Target 直接組成錯誤 Path `/srv/mediacat.jpg`。

**最小修正：**

```nginx
location /media/ {
    alias /srv/media/;
}
```

## Fault 4：Regex 順序衝突

**症狀：** `/private/photo.jpg` 回傳 Generic Image Handler，而不是 Private Handler。

**根因：** 兩個 Regex 都匹配，Nginx 使用 Config 中第一個匹配者。

**修正選項：** 將 Private Regex 放到前面；若整段 `/private/` 都應跳過 Regex，改用 `location ^~ /private/` 表達更清楚的 Routing Contract。
