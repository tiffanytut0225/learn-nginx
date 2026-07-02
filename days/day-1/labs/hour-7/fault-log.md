# Day 1 Fault Log

## Fault 1：Syntax Error

- Symptom：`nginx -t` 失敗，Config 無法載入。
- Evidence：`unexpected "}"`，指向缺少分號附近行號。
- Root Cause：`worker_connections 1024` 後缺少 `;`。
- Minimal Fix：補上分號。
- Regression Check：`nginx -t` 必須成功；Reload 後服務仍可回應。

## Fault 2：Missing File

- Symptom：TCP Connection 成功，但 `/not-found` 回傳 404。
- Evidence：curl Status 與 Access Log 都是 404。
- Root Cause：選到有效 Server／Location，但 Filesystem 沒有對應資源。
- Minimal Fix：若 URI 應存在，補上正確檔案或修正 URI Mapping；若本來就不存在，404 是正確行為。
- Regression Check：存在的 `/` 回 200；不存在的 URI 維持 404。

## Fault 3：Wrong Server Selection

- Symptom：`Host: api.local.test` 回傳 Default Site，而非 FaceID API Site。
- Evidence：Response Header 是 `X-Selected-Server: default`；Config 的 API Server 宣告為 `server_name app.local.test`。
- Root Cause：沒有任何 `server_name` 匹配 `api.local.test`，因此依 Server Selection 規則落入 `default_server`。
- Minimal Fix：若正確且唯一的 Domain 是 `api.local.test`，將 `server_name` 改為它；若 `app.local.test` 仍需相容，則同時列出兩個 Names。
- Regression Check：`api.local.test` 命中 API；Unknown Host 與 Direct IP 命中 Default；`app.local.test` 的行為符合明確的相容性決策。
