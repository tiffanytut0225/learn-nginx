# Hour 4 實驗：`root` 與 `alias` Path Mapping

## 目標

使用 `$request_filename` 觀察 Nginx 在普通 Prefix 與 Regex Location 中實際查找的完整 Filesystem Path。

## 六個 Expected Paths

| Case | Request URI | Directive | Expected Filesystem Path |
|---|---|---|---|
| A | `/root-images/logo.png` | `root /srv/site` | `/srv/site/root-images/logo.png` |
| B | `/alias-images/logo.png` | `alias /srv/site/` | `/srv/site/logo.png` |
| C | `/root-downloads/reports/july.pdf` | `root /data` | `/data/root-downloads/reports/july.pdf` |
| D | `/alias-downloads/reports/july.pdf` | `alias /data/` | `/data/reports/july.pdf` |
| E | `/users/alice.png` | Regex `alias /data/images/$1` | `/data/images/alice.png` |
| F | `/exports/2026/reports/july.csv` | Regex `alias /archive/$1/$2` | `/archive/2026/reports/july.csv` |

## 1. 啟動

```bash
docker run --rm -d \
  --name learn-nginx-path-mapping \
  -p 8086:80 \
  -v "$PWD/days/day-2/labs/hour-4/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "$PWD/days/day-2/labs/hour-4/fs/srv/site:/srv/site:ro" \
  -v "$PWD/days/day-2/labs/hour-4/fs/data:/data:ro" \
  -v "$PWD/days/day-2/labs/hour-4/fs/archive:/archive:ro" \
  nginx:stable
```

## 2. 驗證 Config

```bash
docker exec learn-nginx-path-mapping nginx -t
```

## 3. 執行完整 Matrix

```bash
BASE_URL=http://127.0.0.1:8086 \
  days/day-2/labs/hour-4/verify-path-mapping.sh
```

實際結果：

```text
Result: 6/6 path mappings passed.
```

## 4. 單題觀察

```bash
curl -i http://127.0.0.1:8086/alias-images/logo.png
```

Response Header：

```text
X-File-Path: /srv/site/logo.png
```

## 5. 清理

```bash
docker stop learn-nginx-path-mapping
```
