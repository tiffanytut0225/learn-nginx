# Hour 1：Upstream URI Matrix

## 核心預測

| Case | Location | `proxy_pass` | Client URI | Upstream URI |
|---|---|---|---|---|
| A | `/api/` | `http://backend` | `/api/users?page=2` | `/api/users?page=2` |
| B | `/api/` | `http://backend/` | `/api/users?page=2` | `/users?page=2` |
| C | `/api/` | `http://backend/v1/` | `/api/users/42` | `/v1/users/42` |
| D | `/api/` | `http://backend/v1` | `/api/users/42` | `/v1users/42` |

## Actual Lab Matrix

| # | Frontend URI | 行為 | Expected Upstream URI | Actual |
|---:|---|---|---|---|
| 1 | `/preserve/users?page=2` | 無 URI Part | `/preserve/users?page=2` | ✓ |
| 2 | `/strip/users?page=2` | URI Part `/` | `/users?page=2` | ✓ |
| 3 | `/service/users` | URI Part `/v1/` | `/v1/users` | ✓ |
| 4 | `/joined/users` | URI Part `/v1` | `/v1users` | ✓ |
| 5 | `/rewrite/users?page=2` | Rewrite + 無 URI Part | `/v2/users?page=2` | ✓ |
| 6 | `/regex/users` | Regex + 無 URI Part | `/regex/users` | ✓ |
| 7 | `/named/users` | Named + 無 URI Part | `/named/users` | ✓ |

總結果：**7／7**。

## Invalid Case

Regex Location 使用 `proxy_pass http://backend/v1/;` 時，`nginx -t` 失敗：

```text
"proxy_pass" cannot have URI part in location given by regular expression
```
