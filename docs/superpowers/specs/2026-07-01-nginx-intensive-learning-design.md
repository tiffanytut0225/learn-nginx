# Nginx 密集學習方案設計

## 1. 目標

以五個完整工作日（40 小時），建立 FaceID Central Web 所需的 Nginx 原理、設定、驗證與攻錯能力。完成後應能：

- 解釋 Client Request 如何到達並由 Nginx 處理。
- 理解 Master、Worker、Event Loop、Connection 與 Thread Pool。
- 正確設定 Virtual Host、Location、Static Files、SPA 與 Reverse Proxy。
- 處理 Domain、IP、HTTP Redirect、HTTPS、TLS/SNI 與 Unknown Host。
- 依據證據分析 Concurrency、Timeout、Buffering 與 Keepalive。
- 使用結構化 Checklist 審查並攻錯陌生 Nginx Config。

Docker 只作為可重現的 Nginx Lab 啟動工具，不納入課程知識範圍。

## 2. 學習方法

每個主題都遵循同一循環：

1. 理解原理與術語。
2. 在執行前預測 Config 行為。
3. 執行最小實驗。
4. 故意注入錯誤。
5. 使用 `nginx -t`、`nginx -T`、HTTP Response 與 Logs 診斷。
6. 記錄 Evidence、Root Cause、Minimal Fix 與 Regression Check。

每天 8 小時分配：

- 2 小時：原理與 AI 問答
- 3 小時：Nginx Config 實驗
- 1.5 小時：故障注入與診斷
- 1 小時：文件與 Checklist
- 0.5 小時：驗收

## 3. 五日主線

### Day 1：架構、Request Lifecycle 與 Config 骨架

- DNS、TCP、TLS、HTTP 與 Linux Socket 的概念邊界
- Master／Worker、Event-driven、Non-blocking I/O、epoll
- main、events、http、server、location Context
- Config Validation、Include、Inheritance、Reload
- `listen`、`server_name`、Host 與 `default_server`
- Access Log 與 Error Log

成果：Request Lifecycle 圖、最小雙站台 Config、Server Selection Matrix、三類 Fault Log。

### Day 2：Location、Static Files、SPA 與 Rewrite

- Exact、Prefix、`^~`、Regex、Named Location
- URI Normalization 與 Internal Redirect
- `root`、`alias`、`index`、`try_files`
- SPA Deep Link 與 Asset 404
- `rewrite`、`return`、`error_page` 的責任分界
- Static Cache、ETag、Last-Modified、Compression

成果：Location Prediction Matrix、SPA Config、root/alias Attack Lab、Routing Checklist。

### Day 3：Reverse Proxy、Upstream 與擴展性

- `proxy_pass` URI 轉換
- Host 與 X-Forwarded-* Headers
- Connect／Send／Read Timeout
- Proxy Buffering、Streaming、SSE、WebSocket
- Upstream Algorithm、Keepalive、Retry 與 Failure Handling
- DNS／Service Discovery 的生命週期問題
- 多個 Frontend 或 API Nodes 的擴展邊界

成果：Proxy Lab、Upstream URI Matrix、Timeout/Failure Lab、Reverse Proxy Checklist。

### Day 4：HTTPS、Domain/IP 與安全

- TLS Handshake、SNI、Certificate Hostname Validation
- Canonical Domain Redirect
- Unknown Host 與 Default Server
- HTTP Direct IP 與 HTTPS Direct IP 的差異
- TLS Protocol、Certificate Chain、HSTS
- Request Limit、Rate Limit、Security Headers
- Least Privilege 與資訊洩漏

成果：Domain/IP/TLS Matrix、Local HTTPS Lab、Security Checklist、HTTPS Fault Log。

### Day 5：併發、效能、Observability 與總攻錯

- `worker_processes`、`worker_connections`、File Descriptor
- Client 與 Upstream Connection Capacity
- Keepalive、Buffering、Compression、Static File Delivery
- Blocking Operations 與 Thread Pool
- Log Format、Request ID、Upstream Timing
- Graceful Reload／Shutdown
- 小型行為測試與 Benchmark 限制
- 現有 FaceID Config 或 Flawed Config 的完整審查

成果：Capacity Worksheet、Observability Config、最終 Review Checklist、主管簡報。

## 4. AI 問題架構

1. HTTP Request Lifecycle 與 Event-driven Architecture
2. Master、Worker、Thread Pool 與 Parallelism
3. Config Context、Inheritance、Validation 與 Reload
4. Virtual Host、Domain、IP、HTTP 與 HTTPS
5. Server 與 Location Matching
6. Static Files、SPA、root 與 alias
7. Reverse Proxy、Upstream 與 Scalability
8. Security、Logging、Observability 與 Anti-patterns

每題回答必須包含原理、最小範例、常見 Failure Modes 與驗證方法。

## 5. 文件結構

```text
README.md
docs/
  ai-question-list.md
  nginx-review-checklist.md
  superpowers/
    plans/
    specs/
days/
  day-1/
    README.md
    notes.md
    labs/
      hour-1/
      hour-2/
      hour-3/
      hour-4/
      hour-5/
      hour-7/
  day-2/
    README.md
    labs/
  day-3/
    README.md
    labs/
  day-4/
    README.md
    labs/
  day-5/
    README.md
    labs/
```

## 6. 成功標準

- 不靠口號解釋 Nginx Request Lifecycle 與 Worker Model。
- 執行前能預測 Server、Location、Filesystem Path 與 Upstream URI。
- 能區分 Syntax、Routing、Filesystem、TLS、DNS、Connection、Timeout 與 Upstream Failure。
- 能說明 Direct-IP HTTPS 為何不能單靠 Redirect 解決。
- 能根據資源限制與 Connection Model 推估容量，不盲抄 Tuning 值。
- 能以 Evidence-based Checklist 審查現有 Nginx Config。
- 能在 15 分鐘內向主管展示一個問題的預測、故障、診斷與修正。

## 7. 限制

- Local Load Test 驗證行為，不代表 Production Capacity。
- 真實 FaceID Review 需要 Sanitized Config、Deployment Topology 與流量特徵。
- 不延伸討論前端建置、容器架構、測試替身或平台部署設計。
