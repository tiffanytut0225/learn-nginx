# Hour 1：Worker 與 Connection Capacity Worksheet

## 粗估公式

```text
rough_connection_slots = worker_processes * worker_connections
```

這只是 Nginx worker connection slots 的粗估，不是真實 production capacity。

## 必須一起檢查的因素

| 因素 | 為什麼會影響 capacity |
|---|---|
| CPU cores | Worker 數量與 CPU scheduling、TLS、compression、logging 都會受 CPU 影響。 |
| `worker_processes` | 決定有幾個 worker 可處理 connections。 |
| `worker_connections` | 每個 worker 可同時開啟的 connections slots。 |
| File Descriptor limit | Client sockets、upstream sockets、logs、temporary files 都會消耗 FD。 |
| Client/Upstream Ratio | Reverse proxy active request 可能同時占 1 條 client connection 與 1 條 upstream connection。 |
| Client keepalive | Idle client connections 仍會占 connection slot、FD 與 memory。 |
| Upstream keepalive | Idle upstream connections 也會占 FD 與 memory，但能降低重複建連成本。 |
| Memory / buffers | 每條 connection、buffering、large response、temporary file 都可能增加 memory/disk 壓力。 |
| Workload | Static file、TLS-heavy、proxy API、streaming、large upload/download 對資源需求不同。 |

## Reverse Proxy Connection Model

```text
Client <-- client connection --> Nginx <-- upstream connection --> Backend
```

對 Nginx 來說，一個 active proxied request 可能同時需要：

```text
1 client connection
+ 1 upstream connection
+ logs / files / buffers
```

因此不能將 `worker_processes * worker_connections` 直接解讀成「可同時服務這麼多使用者」或「每秒處理這麼多 requests」。

## 心智模型

```text
worker_connections = connection slots
RPS = throughput
capacity = 在 CPU / FD / memory / upstream / workload 限制下的可承受範圍
```

## 初步估算清單

- [ ] `worker_processes`
- [ ] `worker_connections`
- [ ] OS / container FD limit
- [ ] `worker_rlimit_nofile`
- [ ] client keepalive timeout
- [ ] upstream keepalive pool
- [ ] 是否大量 proxy 到 backend
- [ ] 是否有 TLS / compression
- [ ] 是否有 buffering / large response
- [ ] 是否有 streaming / long-lived connections
- [ ] 是否有 slow client / slow upstream
- [ ] memory 與 temporary file 空間
