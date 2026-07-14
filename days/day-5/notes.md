# Day 5 學習筆記

## Day 5：併發、效能、Observability 與總攻錯

## 今日名詞表

| 名詞 | 用途 |
|---|---|
| Worker Process | 實際處理連線與請求的 Nginx process；通常會依 CPU core 與 workload 設計。 |
| `worker_connections` | 每個 worker 最多可同時開啟的 connections 數量，不等於每秒 request 數。 |
| File Descriptor | OS 層級的開啟檔案/Socket 資源；connections、logs、upstream sockets 都會消耗 FD。 |
| Client Connection | Client 到 Nginx 的連線。 |
| Upstream Connection | Nginx 到 Backend 的連線；Reverse Proxy 時常要同時考慮 client-side 與 upstream-side connections。 |
| Keepalive | 連線重用，降低重複建連成本，但也會佔用 idle connections。 |
| Blocking I/O | 會讓 worker 等待的操作，例如慢磁碟、同步 DNS、慢 upstream、阻塞型 module。 |
| Thread Pool | Nginx 可把部分可能阻塞的 file I/O 丟到 thread pool，避免 worker 被卡住。 |
| Buffering | Nginx 暫存 response/request 的能力，可隔離慢 client 與 upstream，但會消耗 memory/disk。 |
| Compression | 壓縮 response 降低傳輸量，但會消耗 CPU。 |
| Observability | 透過 logs/metrics/traces 看懂系統發生什麼事。 |
| Request ID | 每個 request 的追蹤 ID，用來串 Nginx、Backend 與錯誤紀錄。 |
| Graceful Reload | 不粗暴中斷現有連線，讓新舊 workers 交接 config。 |
| Capacity | 系統在特定資源限制下能承受的併發、吞吐與延遲範圍；必須量測，不能只背公式。 |

### Hour 1：Worker 與 Connection Capacity

#### 起始心智模型

```text
最大連線容量不是只看 worker_connections。
還要看 workers、file descriptors、client/upstream ratio、keepalive、memory、CPU 與 workload。
```

#### `worker_processes * worker_connections` 的限制

例如：

```nginx
worker_processes 4;

events {
    worker_connections 1024;
}
```

粗估 connection slots：

```text
4 * 1024 = 4096
```

但這不是保證可同時服務 4096 個使用者，也不是 RPS 保證。學習者回答：「還有其他因素會影響。」完整來說，還要看：

- File descriptor limit。
- Reverse proxy 時的 upstream connections。
- Client / upstream keepalive idle connections。
- 每條 connection、buffer 與 large response 的 memory。
- TLS、compression、logging 對 CPU 的消耗。
- Workload 是 static、proxy API、streaming、large upload 還是 long-lived connections。

#### Reverse Proxy 連線模型

```text
Client <--connection 1--> Nginx <--connection 2--> Backend
```

一個 active proxied request 可能同時消耗 client-side connection 與 upstream-side connection。若 keepalive 開啟，idle connections 也會占 FD、memory 與 worker connection slot。

#### Connection Slots vs RPS

```text
worker_connections = 同時可開啟的 connection slots
requests per second = 每秒處理多少 request
```

Keepalive idle connection 可能占 connection slot 但沒有產生 request；短連線快速進出時 RPS 可能高，但同時 active connections 不一定高。

#### Capacity Worksheet

完整 worksheet：[Worker 與 Connection Capacity Worksheet](labs/hour-1/capacity-worksheet.md)。

#### Hour 1 狀態

Hour 1 狀態：**完成**。已建立 CPU、Workers、Worker Connections、File Descriptors、Client/Upstream Ratio、Keepalive、Memory 與 Workload 的 capacity worksheet，並能說明為什麼不能只用 `worker_processes * worker_connections` 當作真實 capacity。

### Hour 2：Blocking 與 Thread Pool

#### Blocking 對 Event-driven Worker 的影響

Nginx worker 是 event-driven。若某個操作把 worker 卡住太久，最直接的風險是：

```text
這個 worker 不能及時處理其他 ready connections
```

因此 blocking 的傷害不是只慢一個 request，而是可能拖累同一個 worker 上的其他連線。

#### Blocking / Slow Operation Risk

| 風險來源 | 為什麼要注意 |
|---|---|
| File I/O | 慢磁碟、large file、network storage 可能卡住 worker。 |
| DNS | 同步或錯誤設計的 DNS 查詢可能造成等待。 |
| Upstream | Backend 很慢會占用 upstream connection，造成等待與 timeout。 |
| Logging | 高流量下 access log/error log 是大量 I/O；慢磁碟或阻塞 logging pipeline 可能拖慢 worker。 |
| Third-party Module | 若 module 執行阻塞操作，可能破壞 event-driven 模型。 |
| CPU-heavy work | TLS、compression 或昂貴計算若過重，也會讓 worker 忙不過來。 |

#### Thread Pool 適用邊界

學習者回答：

```text
可把部分可能阻塞的 file I/O 丟到 thread pool，避免 worker 被卡住。
但不能解決 backend app 緩慢的問題。
```

這是正確的核心。Nginx thread pool 不是把 Nginx 變成 one-thread-per-request，而是讓 worker 將部分可能阻塞的 file I/O 交給 thread pool，自己回去處理其他 events。

Thread pool 可以幫忙：

- 某些 static file / disk I/O 類工作。
- 降低 worker 被慢速 file I/O 卡住的機率。

Thread pool 不能直接解決：

- Backend application 慢。
- Database query 慢。
- 外部 API 慢。
- TLS certificate 錯。
- CSP / Security Header 設錯。
- Worker connections / FD limit 太低。

若 upstream/backend 很慢，應該看：

- `proxy_read_timeout`
- upstream response time
- backend logs
- DB / app metrics
- queue / worker saturation

#### Hour 2 狀態

Hour 2 狀態：**完成**。已盤點 File I/O、DNS、Upstream、Logging 與 Third-party Module 的 blocking risk，並能說明 Thread Pool 適用於部分 file I/O，但不能修復 backend app 緩慢。

### Hour 3：Keepalive、Buffering 與 Compression

#### 三種效能工具的取捨

| 機制 | 主要好處 | 主要代價 |
|---|---|---|
| Keepalive | 重用 connection，減少 TCP/TLS 重複建連成本 | Idle connections 仍占 connection slot、FD、memory |
| Buffering | Nginx 先接住 upstream response，隔離慢 client 對 backend 的影響 | 消耗 memory；大 response 可能用 temporary file；不適合即時 streaming |
| Compression | 用 CPU 換較小傳輸量，降低 network bandwidth | 消耗 CPU；對已壓縮格式收益低 |

#### Keepalive

Keepalive 的主要好處：

```text
減少重複 TCP/TLS handshake 成本
```

但 `keepalive_timeout` 不是越長越好：

```text
太短 -> 重複建連成本增加
太長 -> idle connections 占用 connection slot / FD / memory
```

#### Buffering

Proxy buffering 開啟時：

```text
Backend 快速吐 response
-> Nginx 暫存
-> Backend connection 可較早釋放
-> Nginx 依 client 速度送出
```

它能降低慢 client 長時間占用 backend connection 的風險。

但 SSE / streaming 通常不適合 buffering，因為它需要資料即時送到 client：

```nginx
proxy_buffering off;
```

或由 upstream 回：

```http
X-Accel-Buffering: no
```

#### Compression

Compression 的 trade-off：

```text
用 CPU 換取較小傳輸量
```

通常適合：

- HTML
- CSS
- JavaScript
- JSON
- Text

通常不適合或收益很低：

- JPG / PNG / WebP
- MP4
- ZIP / gzip 已壓縮檔

#### 為什麼不能只問最佳設定值

學習者回答：「跟硬體關係較大。」這是其中一部分。完整來說，最佳設定取決於：

- CPU
- Memory
- Disk I/O
- Network bandwidth
- Client 數量與速度
- Request 間隔
- Response 大小與格式
- Backend connection 成本
- 是否有 streaming / long-lived connections
- TLS 與 compression 成本

心智模型：

```text
效能設定沒有唯一最佳值，只有在特定 workload 和資源限制下的取捨。
```

#### Hour 3 狀態

Hour 3 狀態：**完成**。已能以 Request Lifecycle 說明 Keepalive、Buffering 與 Compression 如何影響 CPU、Memory、Connections 與 Latency，並理解不能以單一「最佳值」取代量測。

### Hour 4：Observability

#### Request ID

若要讓 Nginx log 可以跟 backend app log 串起來，最重要的是 Request ID：

```text
request_id=abc123
```

它讓同一個 request 可以在不同系統中被追蹤：

- Nginx access log
- Backend app log
- Error log
- Sentry / APM / tracing

#### Reverse Proxy 必記欄位

| 欄位 | 用途 |
|---|---|
| `$status` | Client 最後看到的 status。 |
| `$upstream_status` | Upstream 回的 status；retry 多台 upstream 時可能有多個值。 |
| `$upstream_addr` | Nginx 實際連到哪個 upstream。 |
| `$request_time` | Nginx 處理整個 client request 的總時間。 |
| `$upstream_connect_time` | 連 upstream 花多久。 |
| `$upstream_header_time` | 等 upstream response header 花多久。 |
| `$upstream_response_time` | Upstream response 整體花多久。 |

`$request_time` 與 `$upstream_response_time` 不一定一樣：

```text
request_time 高、upstream_response_time 也高 -> backend/upstream 慢
request_time 高、upstream_response_time 不高 -> 可能是 slow client、大 response、buffering 或傳輸問題
```

#### 避免記錄敏感資料

不要直接記錄完整：

- Cookie
- Authorization header
- access token / refresh token
- password / code / session
- 敏感 query string

`$request_uri` 包含 query string，因此：

```text
/api/users?token=secret123
```

若直接記錄 `$request_uri`，token 會進 access log。Production log 應優先考慮 `$uri`，或建立 query masking 策略。

#### Log Format Design

完整設計：[Reverse Proxy Log Format Design](labs/hour-4/log-format-design.md)。

學習者回答：「能追溯 request 並追到 backend app。」完整化後：

```text
好的 reverse proxy log 要能用 request_id 追一條 request，
知道 client 最後看到什麼、Nginx proxy 到哪台 upstream、
upstream 回什麼、各階段花多久，
同時避免把 token/cookie/敏感 query 寫進 log。
```

#### Hour 4 狀態

Hour 4 狀態：**完成**。已設計包含 Request ID、Host、Status、Request Time、Upstream Address、Upstream Status、Connect/Header/Response Time 的 log format，並記錄避免 Token、Cookie 與 Sensitive Query Data 的原則。

### Hour 5：小型行為測試

#### 測試目的

比較 short-lived upstream requests 與 upstream keepalive requests 的連線重用差異。

這是本機行為觀察，不是 production benchmark。它能證明 connection reuse 行為，但不能代表 production latency、throughput 或 capacity。

#### 方法

Backend 回傳它看到的 Nginx source port：

```text
client_port=xxxxx
```

若每次都新建 upstream connection，backend 會看到不同 source ports。若 upstream keepalive 重用同一條 connection，backend 會看到相同 source port。

#### Actual Result Lab

完整 Lab：[Short-lived vs Keepalive](labs/hour-5/keepalive-behavior-experiment.md)。

```text
Short-lived -> 50913 50915 50917 50919
Keepalive   -> 50889 50889 50889 50889

Result: 2/2 keepalive behavior checks passed.
```

Port 數字會依環境改變；判讀重點是「多個不同 ports」與「同一個 port 被重用」。

#### Hour 5 狀態

Hour 5 狀態：**完成**。已比較 Short-lived 與 Keepalive Requests，記錄指令、環境限制與行為觀察，並明確註明此結果不是 Production Benchmark。

### Hour 6：Graceful Operations

#### 安全變更流程

```text
修改 config
-> nginx -t
-> test 成功才 graceful reload
-> response / header 驗證
-> 必要時 rollback config
```

`nginx -t` 的價值是讓 invalid config 在 reload 前被擋下。本 Lab 中 invalid config `nginx -t` 失敗後，服務仍繼續使用 v1 回應。

#### Graceful Reload

Graceful reload 不是粗暴中斷服務。心智模型：

```text
master 收到 reload signal
-> 驗證並載入新 config
-> 啟動新 workers
-> 新 workers 接新連線
-> 舊 workers 處理完既有連線後退出
```

#### Actual Result Lab

完整 Lab：[Graceful Operations](labs/hour-6/graceful-operations-experiment.md)。

```text
Result: 11/11 graceful operation checks passed.
```

Lab 驗證：

- 初始 v1 正常回應。
- invalid config 被 `nginx -t` 擋下，沒有 reload。
- v2 config 通過 `nginx -t` 後 graceful reload 成功。
- reload 前後 master PID 維持穩定，代表不是重啟整個 master process。
- rollback 到 v1 config 通過 `nginx -t` 後 reload 成功。
- `nginx -s quit` graceful shutdown 後 container 停止。

#### Rollback Check

安全變更時，rollback 不是「心裡知道可以退」，而是要有可執行檢查：

```text
保留上一版 config
rollback config 也要 nginx -t
reload 後用 response/header/log 驗證已回到上一版
```

#### Hour 6 狀態

Hour 6 狀態：**完成**。已練習 Config Test、Graceful Reload、Rollback Reload，並寫出安全變更步驟與 rollback check。

### Hour 7：完整 Config Attack Review

#### Finding 分類

| 分類 | 意思 |
|---|---|
| Confirmed Defect | 已能從 config / lab 明確證明會出錯的問題。 |
| Contextual Risk | 嚴重程度取決於部署拓撲、trust boundary 或產品需求。 |
| Hardening Opportunity | 目前不一定錯，但可以加強安全、穩定或可觀測性。 |
| Need Context | 缺少資訊，不能可靠判斷，需要詢問或查證。 |

#### Review 原則

學習者回答：「要寫 Evidence 和 Verification Method，才能確定錯誤的方向。」這是本 Hour 核心。

完整化後：

```text
Evidence 讓 finding 不是憑感覺猜。
Verification Method 讓修正後能證明問題真的解決。
```

#### Review Checklist

新增全域 checklist：[Nginx Config Review Checklist](../../docs/nginx-review-checklist.md)。

每個 finding 至少包含：

- Category
- Evidence
- Impact
- Minimal Fix / Recommendation
- Verification Method
- Needed Context, if any

#### Attack Review Lab

完整 Review：[Config Attack Review](labs/hour-7/config-attack-review.md)。

Review target：[flawed-nginx.conf](labs/hour-7/flawed-nginx.conf)。

主要 findings：

- Undefined upstream `backend`。
- Access log 記錄 Authorization、Cookie 與完整 query string。
- Redirect 使用不可信 `$host`。
- Production HTTPS server 同時是 `default_server`。
- HSTS `includeSubDomains; preload` 風險。
- Security Headers 需要依服務型態補 context。
- `X-Forwarded-For` trust boundary 不明確。

#### Hour 7 狀態

Hour 7 狀態：**完成**。已建立 review checklist，使用 flawed config 完成 attack review，並將 findings 分為 Confirmed Defect、Contextual Risk、Hardening Opportunity 與 Need Context，每項包含 Evidence 與 Verification Method。

### Hour 8：總驗收與主管簡報

#### 15 分鐘 Walkthrough

完整簡報稿：[主管簡報 Walkthrough](labs/hour-8/final-walkthrough.md)。

建議結構：

1. Request Lifecycle。
2. Location Fault。
3. Proxy Failure。
4. Domain / IP / TLS。
5. Capacity 與 Performance。
6. Observability 與 Operations。
7. Config Review。

一句話總結：

```text
我現在看 Nginx 問題會先分層，再用 response、logs、nginx -t 和最小 request 驗證，不會只憑感覺猜。
```

#### 未知 Config Case

完整 case：[Day 5 總驗收](day-5-assessment.md#現場未知-config-case)。

現場流程：

```text
Prediction
-> Request
-> Log / Evidence
-> Root Cause
-> Minimal Fix
-> Regression Check
```

#### Hour 8 狀態

Hour 8 狀態：**完成**。已準備 15 分鐘 Walkthrough，並完成未知 Config Case 的 Prediction → Request → Log → Root Cause → Fix → Regression Check 演練。
