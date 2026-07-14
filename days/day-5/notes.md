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
