# Nginx 密集學習執行計畫

**目標：** 五天、40 小時內完成 Nginx 原理、Config、驗證與攻錯訓練。

**規則：** 每項實驗都先寫 Prediction，再保存 Actual Result。每個 Fault 都記錄 Symptom、Evidence、Root Cause、Minimal Fix 與 Regression Check。每天的 `notes.md` 都要包含「今日名詞表」，說明當天專有名詞的用途與實務判斷方式。

## Day 0：課前準備（不計時）

- [ ] 執行 `docker version`，確認可用於啟動可重現的 Nginx Lab。
- [ ] 執行 `curl --version` 與 `openssl version`。
- [ ] 向主管取得移除 Secret 後的 FaceID Nginx Config、Deployment Topology 與流量特徵。
- [ ] 若沒有實檔，Day 5 使用刻意設計的 Flawed Config。

## Day 1：架構、Request Lifecycle 與 Config 骨架（8 小時）

### Hour 1：Client 到 Nginx

- [x] 研讀初級 1.3 第 16 題，以及專家級 4.1 第 1 題。
- [x] 在 `days/day-1/notes.md` 畫出：

```text
URL -> DNS -> TCP -> TLS（HTTPS）-> HTTP Request
    -> Kernel Socket -> Worker Event Notification
    -> accept/read -> Server Selection -> Processing -> Response
```

- [x] 標示 Client、Kernel、Master、Worker 的責任邊界。

### Hour 2：Event-driven Concurrency

- [x] 回答高級 3.1 第 1 題，以及專家級 4.1 第 2 至 4 題。
- [x] 解釋 Event Loop、Non-blocking I/O 與 epoll。
- [x] 比較 Connection-per-thread/process 模型，但不將其錯誤描述成所有 Apache 的固定架構。

### Hour 3：Process Model

- [x] 回答初級 1.1 第 2 題、高級 3.1 第 2 至 6 題，以及專家級 4.1 第 5 題。
- [x] 畫出 Master、Workers、Connections、Optional Thread Pool 的關係。
- [x] 說明 Reload 時新舊 Workers 如何交接。

### Hour 4：Config Context

- [x] 回答初級 1.1 第 3、4 題，以及專家級 4.1 第 8 題。
- [x] 建立 `days/day-1/labs/hour-4/nginx-valid.conf`，包含 main、events、http、server 與 location。
- [x] 標註每個 Directive 合法 Context 與 Inheritance。

### Hour 5：Server Selection

- [x] 建立兩個 Virtual Hosts 及 Explicit `default_server`。
- [x] 先預測再執行：

```bash
curl -i -H 'Host: a.local.test' http://127.0.0.1:8080/
curl -i -H 'Host: b.local.test' http://127.0.0.1:8080/
curl -i -H 'Host: unknown.local.test' http://127.0.0.1:8080/
```

### Hour 6：Validation、Reload 與 Logs

- [x] 使用 `nginx -t` 驗證 Syntax。
- [x] 使用 `nginx -T` 檢查 Include 展開結果。
- [x] 執行 Graceful Reload，觀察 Process 變化。
- [x] 產生 200 與 404，觀察 Access/Error Logs。

### Hour 7：Fault Injection

- [x] 製造並修復 Syntax Error。
- [x] 製造 Valid Config 但 Wrong Server Selection。
- [x] 製造 Correct Routing 但 Missing File。
- [x] 寫入 `days/day-1/labs/hour-7/fault-log.md`。

### Hour 8：驗收

- [x] 三分鐘內說明 Master／Worker／Event Loop。
- [x] 正確預測三個 Host Requests。
- [x] 使用 `nginx -t`、Response 與 Logs 區分三類故障。

## Day 2：Location、Static Files、SPA 與 Rewrite（8 小時）

### Hour 1：Location Algorithm

- [x] 回答 E1-E7。
- [x] 寫出 Exact、Longest Prefix、`^~`、Regex 的 Selection Algorithm。

### Hour 2：Prediction Matrix

- [x] 建立 `days/day-2/labs/location-matrix.md`。
- [x] 至少 15 個 Cases，涵蓋 `=`、Prefix、`^~`、`~`、`~*`、Named Location。
- [x] 實作前先填 Prediction。

### Hour 3：Location Lab

- [x] 每個 Location 回傳識別 Header。
- [x] 執行全部 Cases，比較 Prediction 與 Actual。
- [x] 對錯誤預測補寫心智模型修正。

### Hour 4：`root`、`alias` 與 Filesystem Path

- [x] 回答 F1-F2、F7。
- [x] 對六個 URI 寫出 Nginx 最後查找的完整 Filesystem Path。
- [x] 驗證 Normal Prefix 與 Regex Location 中的行為。

### Hour 5：SPA 與 `try_files`

- [x] 回答 F3-F4。
- [x] 驗證 `/`、SPA Deep Link、Existing Asset、Missing Asset、API-like Path。
- [x] Missing Asset 必須 404，不可錯回 `index.html`。

### Hour 6：Rewrite 與 Internal Redirect

- [x] 比較 `return`、`rewrite`、`try_files`、`error_page`。
- [x] 觀察 Internal Redirect 造成的 Location Re-selection。
- [x] 避免用複雜 Rewrite 解決可由 `return` 或 `try_files` 表達的需求。

### Hour 7：Static Delivery

- [x] 回答 F5-F6。
- [x] 比較 `index.html` 與 Hashed Asset 的 Cache Policy。
- [x] 驗證 ETag、Last-Modified、Conditional Request、Compression 與 Content-Type。

### Hour 8：攻錯與驗收

- [x] 診斷 SPA 404、Missing Asset 回 HTML、錯誤 alias、Regex 順序衝突。
- [x] 至少正確預測 12/15 個 Location Cases。
- [x] 用 Path Transformation 解釋 `root` 與 `alias`。

## Day 3：Reverse Proxy、Upstream 與擴展性（8 小時）

### Hour 1：`proxy_pass` URI

- [x] 回答 G1-G2。
- [x] 建立 `days/day-3/labs/upstream-uri-matrix.md`。
- [x] 比較有／無 URI Suffix、Prefix Location、Regex Location、Rewrite 後 URI。

### Hour 2：Proxy Headers 與 Trust Boundary

- [x] 回答 G3。
- [x] 驗證 Host、X-Forwarded-For、X-Forwarded-Proto、X-Real-IP。
- [x] 說明哪些 Incoming Headers 不能無條件信任。

### Hour 3：Timeouts

- [x] 回答 G4。
- [x] 分別製造 Connect Failure、Slow Request Send、Slow Upstream Response。
- [x] 區分 `proxy_connect_timeout`、`proxy_send_timeout`、`proxy_read_timeout`。

### Hour 4：Buffering 與 Streaming

- [x] 回答 G5-G6。
- [x] 比較一般 Response、Large Response、Streaming/SSE、WebSocket 的需求。
- [x] 記錄何時不應盲目關閉 Proxy Buffering。

### Hour 5：Upstream Algorithm

- [x] 回答 G7。
- [x] 測試 Round-robin 與 Least Connections。
- [x] 說明 Sticky Behavior 的限制與風險。

### Hour 6：Upstream Keepalive

- [x] 回答 G8。
- [x] 畫出 Client Keepalive 與 Upstream Keepalive 是兩組不同 Connections。
- [x] 驗證 HTTP Version 與 Connection Header 配置。

### Hour 7：Failure、Retry 與 DNS

- [x] 回答 G9-G11。
- [x] 製造 Connection Refused、Timeout、Upstream 500 與 DNS Failure。
- [x] 討論 Non-idempotent Request Retry 的資料風險。

### Hour 8：FaceID 擴展情境與驗收

- [x] 回答 G12。
- [x] 畫出單節點、多 Upstream Nodes、外部 LB／Ingress 三種責任分界。
- [x] Trace `/api/users` 到精確 Upstream URI 與 Headers。
- [x] 從 Logs 區分四種 Upstream Failures。

## Day 4：HTTPS、Domain/IP 與安全（8 小時）

### Hour 1：TLS、SNI 與 Host

- [x] 回答 D3-D6。
- [x] 寫出 TCP → TLS/SNI/Certificate → HTTP Host → Redirect 的順序。

### Hour 2：Request Matrix

- [x] 建立 HTTP Domain、HTTPS Domain、HTTP Unknown Host、HTTPS Unknown SNI/Host、HTTP IP、HTTPS IP Matrix。
- [x] 將 Certificate Result 與 HTTP Status 分開預測。

### Hour 3：Local HTTPS Lab

- [x] 產生 Development-only Certificate。
- [x] 設定 Canonical HTTPS Server、HTTP Redirect 與 Explicit Default Server。
- [x] 啟動前執行 `nginx -t`。

### Hour 4：驗證 Domain/IP 行為

- [x] Domain Cases 使用 `curl --resolve`。
- [x] IP Cases 直接使用 `127.0.0.1`。
- [x] 正常驗證 Certificate；只有隔離 Post-handshake 行為時使用 `-k`。
- [x] 說明 Direct-IP HTTPS 為何無法靠 Redirect 避免 Certificate Error。

### Hour 5：TLS Configuration

- [x] 研究 Protocol、Certificate Chain、Session Reuse 與 OCSP 的責任。
- [x] 不固定背誦 Cipher List；記錄如何依組織基準與版本維護。

### Hour 6：Security Headers

- [x] 回答 H1-H3。
- [x] 評估 CSP、X-Content-Type-Options、Referrer-Policy、Permissions-Policy、Frame Protection。
- [x] 每項都記錄目的與 Compatibility Cost。

### Hour 7：Limits 與 Rate Limiting

- [x] 測試 `client_max_body_size`、Connection Limit、Request Rate Limit、Timeout。
- [x] 記錄 Status Code、Log 與對正常流量的影響。

### Hour 8：攻錯與驗收

- [ ] 診斷 Wrong Certificate、Unknown Host 落入正式站台、Redirect 使用不可信 Host、HSTS 誤用、Security Header 衝突。
- [ ] 正確解釋六種 Domain/IP/TLS Cases。

## Day 5：併發、效能、Observability 與總攻錯（8 小時）

### Hour 1：Worker 與 Connection Capacity

- [ ] 回答 B8-B10。
- [ ] 建立 `days/day-5/labs/capacity-worksheet.md`。
- [ ] 包含 CPU、Workers、Worker Connections、File Descriptors、Client/Upstream Ratio、Keepalive、Memory。

### Hour 2：Blocking 與 Thread Pool

- [ ] 盤點 File I/O、DNS、Upstream、Logging 與 Third-party Module 的 Blocking Risk。
- [ ] 說明 Thread Pool 適用場景及不能解決的問題。

### Hour 3：Keepalive、Buffering 與 Compression

- [ ] 以 Request Lifecycle 說明三者如何影響 CPU、Memory、Connections 與 Latency。
- [ ] 不以單一「最佳值」取代量測。

### Hour 4：Observability

- [ ] 回答 H4-H7。
- [ ] 設計包含 Request ID、Host、Status、Request Time、Upstream Address、Upstream Status、Connect/Header/Response Time 的 Log Format。
- [ ] 避免記錄 Token、Cookie 或 Sensitive Query Data。

### Hour 5：小型行為測試

- [ ] 比較 Short-lived 與 Keepalive Requests。
- [ ] 記錄指令、環境限制、Errors、Latency 與 Resource Observation。
- [ ] 明確註明結果不是 Production Benchmark。

### Hour 6：Graceful Operations

- [ ] 練習 Config Test、Graceful Reload、Graceful Shutdown。
- [ ] 觀察 Existing Connections 與 Worker Process 變化。
- [ ] 寫出安全變更步驟與 Rollback Check。

### Hour 7：完整 Config Attack Review

- [ ] 使用 `docs/nginx-review-checklist.md` 審查 Sanitized FaceID Config 或 Flawed Config。
- [ ] Findings 分為 Confirmed Defect、Contextual Risk、Hardening Opportunity、Need Context。
- [ ] 每項包含 Evidence 與 Verification Method。

### Hour 8：總驗收與主管簡報

- [ ] 準備 15 分鐘 Walkthrough：Request Lifecycle、Location Fault、Proxy Failure、Domain/IP/TLS、Capacity、Config Review。
- [ ] 現場完成一個未知 Config Case 的 Prediction → Request → Log → Root Cause → Fix。

## 完成條件

- [ ] AI 問題清單已完成主管審查或記錄 Review Status。
- [ ] 所有 Lab Config 通過 `nginx -t`。
- [ ] 每個 Matrix 同時保留 Prediction 與 Actual Result。
- [ ] 每個 Fault 都有 Evidence、Root Cause、Minimal Fix、Regression Check。
- [ ] 能區分 Syntax、Routing、Filesystem、TLS、DNS、Connection、Timeout、Upstream Failure。
- [ ] 能解釋 Worker／Connection Capacity，而非背誦設定值。
- [ ] Final Checklist 可用於陌生 Nginx Config。

## 進度落後時的優先順序

1. Request Lifecycle、Config Context、Server／Location Selection
2. Static／SPA、Reverse Proxy 與 Upstream Failures
3. Domain/IP/TLS 與 Security
4. Config Attack Review 與 Observability
5. Concurrency Experiment 與較深入的 Performance Topics
