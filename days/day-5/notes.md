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
