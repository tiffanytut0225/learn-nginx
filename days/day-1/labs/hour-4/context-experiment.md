# Hour 4 實驗：Directive Context 與 Inheritance

## 1. Valid Config

```bash
docker run --rm \
  -v "$PWD/days/day-1/labs/hour-4/nginx-valid.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable nginx -t
```

預期：`syntax is ok`、`test is successful`。

## 2. Invalid Context

```bash
docker run --rm \
  -v "$PWD/days/day-1/labs/hour-4/nginx-invalid-context.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable nginx -t
```

預期失敗：

```text
"listen" directive is not allowed here
```

原因：`listen` 放在 `http` Context；它只能出現在 `server` Context。

## 3. 觀察 `root` Inheritance

啟動 Valid Config：

```bash
docker run --rm -d \
  --name learn-nginx-context \
  -p 8083:80 \
  -v "$PWD/days/day-1/labs/hour-4/nginx-valid.conf:/etc/nginx/nginx.conf:ro" \
  nginx:stable

curl -i http://127.0.0.1:8083/
```

Config 的 `server` 與 `location` 沒有宣告 `root`，但仍能找到 Official Image 的 `/usr/share/nginx/html/index.html`。在這個案例中，它們使用了上層 `http` 的 `root`。

這只能證明 `root` 的此項行為，不能推論所有 Directives 都會同樣繼承。

## 4. 清理

```bash
docker stop learn-nginx-context
```

## 問題

1. Invalid Config 的錯誤訊息指出哪個 Directive？
2. 它目前被放在哪個 Context？正確 Context 是什麼？
3. Valid Config 的 `location /` 沒有 `root`，為何仍找到 `index.html`？
