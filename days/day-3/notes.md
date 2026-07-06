# Day 3 學習筆記

## Day 3：Reverse Proxy、Upstream 與擴展性

### Hour 1：`proxy_pass` URI

#### 核心規則

不帶 URI Part 的 `proxy_pass` 保留完整 URI：

```nginx
location /api/ {
    proxy_pass http://backend;
}
```

```text
/api/users?page=2 -> /api/users?page=2
```

帶 URI Part 時，以該 URI Part 取代匹配的 Normalized Location Prefix：

```nginx
location /api/ {
    proxy_pass http://backend/;
}
```

```text
/api/users?page=2 -> /users?page=2
```

Nginx 不會替 URI 做語意化 Join；Slash 必須精確設計：

```text
proxy_pass http://backend/v1/; -> /v1/users
proxy_pass http://backend/v1;  -> /v1users
```

#### Regex 與 Named Location 限制

以下 Config 會讓 `nginx -t` 失敗：

```nginx
location ~ ^/api/(.*)$ {
    proxy_pass http://backend/v1/;
}
```

錯誤原因是 Regex Location 沒有固定 Prefix 可供 Nginx 替換。Named Location、`if` 與 `limit_except` 中也有相同限制：`proxy_pass` 不可帶 URI Part。

#### Rewrite 後 URI

```nginx
location /api/ {
    rewrite ^/api/(.*)$ /v2/$1 break;
    proxy_pass http://backend;
}
```

不帶 URI Part 的 `proxy_pass` 會傳送 Rewrite 後的完整 URI：

```text
/api/users?page=2 -> /v2/users?page=2
```

#### 實際作答修正

1. 誤認 `proxy_pass http://backend/` 會在原 URI 前增加 `/`；實際是用 `/` 取代 `/api/`。
2. 誤認 Regex Location 可搭配 `/v1/` URI Part；實際在 Config Validation 階段就會失敗。

#### Actual Result Lab

完整 Matrix：[Upstream URI Matrix](labs/upstream-uri-matrix.md)。

完整 Lab：[proxy_pass URI](labs/hour-1/proxy-pass-uri-experiment.md)。

```text
Result: 7/7 upstream URI cases passed.
```

Invalid Regex Config：`nginx -t` 如預期失敗。

Hour 1 狀態：**完成**。Prefix Replacement、Slash、Regex、Named Location 與 Rewrite 後 URI 均已驗證。
