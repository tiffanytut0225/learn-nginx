# Hour 6 Lab：Graceful Operations

本 Lab 驗證安全變更流程：

```text
修改 config
-> nginx -t
-> test 成功才 graceful reload
-> response / header 驗證
-> 必要時 rollback config
```

## Expected Result

| Step | Expected |
|---|---|
| 初始 config v1 | `/version` 回 `version=v1` |
| 複製 invalid config 後執行 `nginx -t` | validation 失敗 |
| invalid config 不 reload | service 繼續回 `version=v1` |
| 複製 v2 config，`nginx -t` 成功後 reload | `/version` 回 `version=v2`，header `X-Config-Version: v2` |
| rollback 到 v1，`nginx -t` 成功後 reload | `/version` 回 `version=v1` |

## Actual Result

```text
PASS initial v1 status -> 200
PASS initial v1 body -> version=v1
PASS invalid config test fails -> 1
PASS service still serves v1 after invalid test -> 200
PASS invalid config was not reloaded -> version=v1
PASS v2 status after graceful reload -> 200
PASS v2 body after graceful reload -> version=v2
PASS v2 header after graceful reload -> v2
PASS master pid stays stable across reload -> 1
PASS rollback to v1 after test and reload -> version=v1
PASS graceful shutdown stops container -> removed

Result: 11/11 graceful operation checks passed.
```

Debug note：此 Lab 不能用 read-only bind mount 掛 `/etc/nginx/nginx.conf`，因為 graceful reload/rollback 測試需要在 container 內替換 config。正確做法是先啟動 container，再用 `docker cp` 複製 v1/v2/invalid config，並用 `nginx -t` 控制是否 reload。
