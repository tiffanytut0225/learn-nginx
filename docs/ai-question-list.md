# FaceID Central Web：Nginx 系統化學習問題清單

## 使用方式

問題依理解深度分為初級、中級、高級、專家級。建議依序學習；每次選擇 3 至 5 題，要求 AI 回答時同時提供：

1. 原理與精確術語
2. 最小可運行 Config
3. 常見錯誤與安全風險
4. 驗證指令或實驗
5. 對 FaceID Central Web 情境的建議

完成一級的驗收題後再進入下一級。分級代表知識依賴與推理深度，不代表職稱或年資。

---

## Level 1：初級——能讀懂並寫出基本 Config

### 1.1 基礎架構與 Config

1. Nginx 是什麼？作為 Static File Server、Reverse Proxy 與 Load Balancer 時，分別負責什麼？
2. Master Process 與 Worker Process 最基本的分工為何？
3. main、events、http、server、location、upstream 等 Context 的用途與合法巢狀關係為何？
4. Directive、Context、Block、Module、Include 分別是什麼？
5. `nginx -t` 可以驗證什麼？通過檢查是否代表網站行為一定正確？
6. 如何使用 `nginx -T` 查看 Include 展開後的完整 Config？
7. Nginx 啟動、停止、Reload 與 Graceful Shutdown 有何不同？
8. Access Log 與 Error Log 分別記錄什麼？遇到問題時應先看哪一個？

### 1.2 Server Selection 與 Static Files

9. `listen`、`server_name`、HTTP Host 與 `default_server` 如何共同決定使用哪個 Server Block？
10. 同一個 IP 與 Port 為什麼可以提供多個 Domain 的網站？
11. `root` 如何把 URI 轉成 Filesystem Path？請用三個 URI 範例逐步說明。
12. `index` Directive 的作用是什麼？它與 `/` 的處理有何關係？
13. `location /` 是什麼意思？Nginx 找不到檔案時通常如何回應？
14. `try_files` 會依什麼順序檢查檔案？最後一個參數有何特殊意義？
15. 如何提供一個最小 Static Website，並驗證 HTML、CSS、JavaScript 與 404？

### 1.3 HTTP 與基本 Redirect

16. Client 從輸入 URL 到 Nginx 收到 HTTP Request，會依序經過 DNS、TCP、TLS 與 HTTP 的哪些步驟？
17. HTTP Request Method、URI、Headers、Body 分別如何影響 Nginx Routing？
18. `return 301 https://example.com$request_uri;` 的每一部分代表什麼？
19. `301`、`302`、`307`、`308` 的主要差異為何？
20. 為什麼 Redirect 到固定 Canonical Domain 通常比直接使用 Request Host 更安全？

### 初級驗收

- 能畫出 main → http → server → location 的 Config 結構。
- 能預測三個不同 Host Request 會進入哪個 Server Block。
- 能用 `nginx -t`、HTTP Status 與 Logs 區分 Syntax Error、Wrong Server 與 Missing File。
- 能寫出一個 Static Site 與 HTTP-to-HTTPS Redirect 的最小 Config。

---

## Level 2：中級——能處理 SPA、Routing 與 Reverse Proxy

### 2.1 Location Matching

1. Exact (`=`)、Prefix、Preferred Prefix (`^~`)、Regex (`~`／`~*`) 與 Named Location 的用途為何？
2. Location Matching 的完整勝出順序為何？
3. 為何「最長 Prefix」不一定是最後執行的 Location？Regex Scan 何時介入？
4. 多個 Regex Location 同時匹配時如何勝出？宣告順序有何影響？
5. `location /foo` 與 `location /foo/` 有哪些邊界差異？
6. URI Normalization 如何處理 Percent Encoding、重複 Slash、`.` 與 `..`？
7. 如何建立 Location Test Matrix，先預測，再用 Response Header 或 Log 驗證？

### 2.2 Static Files、SPA、root 與 alias

8. `root` 與 `alias` 的 Path Mapping 有何本質差異？
9. `alias` 搭配 Regex Location 時有哪些特殊規則與常見錯誤？
10. 如何讓 SPA 的 Client-side Route 回到 `index.html`，又讓不存在的 Asset 正確回傳 404？
11. `try_files $uri $uri/ /index.html` 每一步如何執行？可能對 API 或 Asset 造成哪些副作用？
12. `return`、`rewrite`、`try_files` 與 `error_page` 各自適合解決什麼問題？
13. Internal Redirect 何時會讓 Nginx 重新執行 Location Selection？
14. `index.html` 與帶 Content Hash 的 Asset 應採用哪些不同 Cache Policy？
15. ETag、Last-Modified 與 Conditional Request 如何降低重複傳輸？

### 2.3 Reverse Proxy 基礎

16. `proxy_pass http://backend;` 與 `proxy_pass http://backend/;` 如何產生不同 Upstream URI？
17. Nginx Proxy Request 時，預設會如何處理 Host Header？何時需要明確設定？
18. X-Forwarded-For、X-Forwarded-Proto、X-Real-IP 分別表示什麼？
19. `proxy_connect_timeout`、`proxy_send_timeout`、`proxy_read_timeout` 分別控制哪一段等待？
20. WebSocket Proxy 為什麼需要 HTTP Version 與 Upgrade／Connection Headers？
21. 如何從 Error Log 區分 Upstream DNS Error、Connection Refused、Timeout 與 Upstream 5xx？
22. FaceID Central Web 使用 Same-origin API Proxy，與 Browser 直接呼叫 Cross-origin API，各有哪些優缺點？

### 2.4 HTTPS 基礎

23. TLS Certificate、Private Key、Certificate Chain 各自扮演什麼角色？
24. TLS SNI 與 HTTP Host 有何不同？Nginx 在什麼時間取得兩者？
25. Nginx 如何依 Listen Address、SNI 與 Host 選擇 HTTPS Server Block？
26. 為什麼以 IP 直接訪問 HTTPS 時，Certificate Error 會發生在 HTTP Redirect 之前？
27. HTTP Direct-IP Request 可以選擇 Redirect、Reject 或固定頁面；各有何取捨？
28. 如何建立 Domain、Unknown Host、HTTP IP、HTTPS IP 的本地測試矩陣？

### 中級驗收

- 至少正確預測 12/15 個 Location Cases。
- 能解釋 `root`、`alias` 與 `proxy_pass` 的實際 Path／URI Transformation。
- 能設定安全的 SPA Fallback，Missing Asset 不會錯回 HTML。
- 能 Trace 一個 `/api/users` Request 到精確的 Upstream URI 與 Headers。
- 能解釋 Direct-IP HTTPS 為何不能單靠 Redirect 解決。

---

## Level 3：高級——能設計擴展性、安全性與可觀測性

### 3.1 Worker、Connection 與容量

1. Nginx 的 Event-driven、Non-blocking I/O 與 Connection-per-thread/process 模型有何本質差異？
2. `worker_processes auto` 如何決定 Worker 數量？CPU Core、Affinity 與資源限制有何影響？
3. `worker_connections` 的精確含義是什麼？為何不等於可服務的 Client 數量？
4. Reverse Proxy 情境中，一個 Client Request 可能同時占用多少 Connections？
5. `worker_processes × worker_connections` 為何只是容量估算起點，而不是吞吐量保證？
6. `worker_rlimit_nofile`、OS File Descriptor Limit 與 Listen Backlog 有何關係？
7. CPU 與 Memory 受限時，應如何設定並驗證 Nginx 平行度？
8. 哪些指標可用來進行 Evidence-based Tuning，而不是抄寫「高效能 Config」？

### 3.2 Upstream、Keepalive 與 Failure Handling

9. Round-robin、Least Connections、IP Hash 與 Generic Hash 各適合哪些需求？
10. Client Keepalive 與 Upstream Keepalive 是哪兩組不同 Connections？
11. `upstream keepalive` 還需要哪些 `proxy_http_version` 或 Connection 設定配合？
12. Proxy Buffering 對慢速 Client、Large Response、Streaming 與 SSE 有何影響？
13. Passive Failure Handling 與 Retry 如何運作？
14. 為何 Retry Non-idempotent Request 可能造成重複寫入？
15. 後端有多個 Nodes，且 Nginx 前方另有 Load Balancer 時，責任應如何切分？
16. DNS 更新與 Nginx Hostname Resolution 有哪些生命週期問題？

### 3.3 Security Hardening

17. `server_tokens off` 可以隱藏什麼？為何不能把它當成主要安全措施？
18. `client_max_body_size`、Header Timeout、Connection Limit 與 Rate Limit 應如何依業務需求設定？
19. CSP、X-Content-Type-Options、Referrer-Policy、Permissions-Policy 與 Frame Protection 各解決什麼問題？
20. Security Headers 為何不能直接複製一份「最安全設定」？可能破壞哪些功能？
21. TLS Protocol、Cipher 與 Certificate Chain 應依哪些組織或產業基準維護？
22. HSTS 應在什麼前提下啟用？`includeSubDomains` 與 Preload 有哪些難以回復的風險？
23. Unknown Host、無 SNI 與 Direct-IP Request 應如何由 Default Server 處理？
24. 如何避免錯誤 `alias`、Symlink 或 Path Traversal 暴露非預期檔案？

### 3.4 Logging 與 Troubleshooting

25. Access Log 應記錄哪些 Request ID、Host、Status、Request Time 與 Upstream Timing？
26. 如何記錄足夠的 Debug Context，又避免 Token、Cookie 或敏感 Query 外洩？
27. `$request_time`、`$upstream_connect_time`、`$upstream_header_time`、`$upstream_response_time` 如何協助定位延遲？
28. 如何區分 Configuration、Routing、Filesystem Permission、TLS、DNS、Connection、Timeout 與 Upstream Application Failure？
29. Graceful Reload 時 Master／Workers 發生什麼事？既有 Connections 如何完成？
30. 如何設計安全的 Config Change、Validation、Reload、Smoke Test 與 Rollback 流程？

### 高級驗收

- 能建立 Worker／Connection／File Descriptor Capacity Worksheet。
- 能對四種 Upstream Failure 從 Log 提出可驗證的判斷。
- 能為每個 Security Setting 說明目的、成本與驗證方法。
- 能設計包含 Request 與 Upstream Timing、但不洩露敏感資訊的 Log Format。
- 能執行 Graceful Reload 並驗證既有 Connection 行為。

---

## Level 4：專家級——能從內部機制推導行為並審查 Production Config

### 4.1 Event Loop 與 Request Processing Internals

1. Linux Kernel 的 Socket、Listen Queue、Accept 與 Nginx Worker 如何協作？
2. epoll 解決什麼問題？Level-triggered／Edge-triggered 概念與 Nginx Event Handling 有何關係？
3. 一個 Worker 如何在單一 Event Loop 中處理大量 Slow Client 與 Keepalive Connections？
4. 哪些操作仍可能阻塞 Worker？File I/O、DNS、Upstream、Logging 與 Third-party Module 各有哪些風險？
5. Nginx Thread Pool 適用哪些 Blocking File I/O 場景？它不能解決哪些 Blocking 問題？
6. Request 從進入到回傳，Server Selection、Rewrite、Access、Content、Filter、Log Phases 如何串接？
7. Internal Redirect、Subrequest 與 Phase Re-entry 如何改變直覺上的執行順序？
8. Directive Inheritance 為何不是單純的父層覆蓋？Module 如何決定 Merge 行為？

### 4.2 複雜 Proxy 與可靠性

9. URI 經過 Rewrite、Regex Location 或 Variable 後，`proxy_pass` 的 URI Resolution 有哪些特殊行為？
10. Real IP Module、Forwarded Headers 與多層 Proxy Chain 應如何建立可信任邊界？
11. Slow Client、Slow Upstream、Backpressure、Buffering 與 Memory／Disk Temporary Files 如何互相影響？
12. Upstream Failure、Retry、Request Buffering 與 Idempotency 應如何共同設計？
13. Dynamic DNS、Resolver Cache、TTL 與既有 Keepalive Connections 之間有何關係？
14. 如何設計可重現實驗，分別測量 Accept Capacity、Connection Capacity、Request Throughput 與Tail Latency，而不混為一談？

### 4.3 Production Config Review

15. 常見 Anti-patterns 有哪些：重複 Config、過度 Rewrite、危險 `if`、錯誤 root/alias、Host Header 信任、寬鬆 CORS、Resolver 與 Timeout 問題？
16. 審查現有 FaceID Config 時，必須取得哪些 Topology、Traffic、Certificate、Upstream、Failure Model 與 Ownership 資訊？
17. 如何區分 Confirmed Defect、Contextual Risk、Hardening Opportunity 與 Need More Context？
18. 如何讓每一個 Review Finding 都包含 Evidence、Impact、Minimal Fix 與 Regression Test？
19. 如何設計一份不依賴特定專案、但能涵蓋 Correctness、Security、Performance 與 Operability 的 Review Checklist？
20. 面對網路上的「最佳化 Config」，如何透過 Source、Version、Workload Assumption 與實驗判斷是否適用？

### 專家級驗收

- 能由 Event Loop 與 Request Phases 推導一個複雜 Config 的執行結果。
- 能分離 Client、Nginx、DNS、Network 與 Upstream 導致的 Latency／Failure。
- 能設計具控制變因的小型實驗，而不是只比較 Requests per Second。
- 能審查陌生 Production Config，且每個 Finding 都有證據、影響、最小修正與回歸驗證。
- 能清楚說出哪些結論已確認、哪些只是風險、哪些需要更多 Context。

---

## 主管檢查時建議確認

- 四個級別是否符合目前職務需要及一週學習深度。
- 是否有 Sanitized Nginx Config 可作為中級、高級與專家級攻錯材料。
- 公司由哪一層終止 TLS：外部 Load Balancer、Gateway 或 Nginx。
- Nginx 前方是否還有 WAF、CDN 或其他 Reverse Proxy。
- API 是否走 Same-origin Proxy，或由 Browser 直接呼叫不同 Origin。
- 預期 Request Rate、Concurrent Connections、Response Size 與 Timeout 特徵。
- 哪些 Location、Upstream、Redirect 與 Security Rules 是現行必要行為。
