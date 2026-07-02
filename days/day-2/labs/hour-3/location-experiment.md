# Hour 3 實驗：Location Actual Results

## 目標

使用真實 Nginx 驗證 Hour 2 的 15 個 Location Cases。每個 Location 回傳 `X-Location` Header，驗證腳本比較 Expected 與 Actual。

## 1. 啟動

本機的 `8085` 已被 Day 1 Lab 使用，因此本實驗使用 `8086`：

```bash
docker run --rm -d \
  --name learn-nginx-location \
  -p 8086:80 \
  -v "$PWD/days/day-2/labs/hour-3/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/days/day-2/labs/hour-3/site:/usr/share/nginx/html:ro" \
  nginx:stable
```

## 2. 單題觀察

```bash
curl -i --path-as-is http://127.0.0.1:8086/assets/../api/test.php
```

預期：

```text
X-Location: regex-php
```

`--path-as-is` 防止 `curl` 先正規化 URI，讓 Nginx 收到原始的 `..` Path Segment。

## 3. 執行完整 Matrix

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-2/labs/hour-3/verify-location-matrix.sh
```

實際結果：

```text
Result: 15/15 cases passed.
```

## 4. 觀察 Named Location

```bash
curl -i http://127.0.0.1:8086/files/exists.txt
curl -i http://127.0.0.1:8086/files/missing.txt
```

預期：

```text
/files/exists.txt  -> X-Location: prefix-files
/files/missing.txt -> X-Location: named-missing
```

第二個 Request 先進入 `/files/`，`try_files` 查找失敗後再內部跳轉到 `@missing`。

## 5. 清理

```bash
docker stop learn-nginx-location
```
