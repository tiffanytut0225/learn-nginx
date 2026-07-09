# Day 1 學習筆記

## Day 1：架構、Request Lifecycle 與 Config 骨架

## 今日名詞表

| 名詞 | 用途 |
|---|---|
| DNS | 將使用者輸入的 Domain Name 解析成可連線的 IP。 |
| TCP | 在 Client 與 Server 之間建立可靠連線，讓 HTTP Request 可以傳輸。 |
| TLS | 在 HTTPS 中加密連線並驗證憑證，保護傳輸內容。 |
| HTTP Request | Client 實際送給 Nginx 的 Method、URI、Headers 與 Body。 |
| Kernel Socket | 作業系統管理網路連線、封包與 I/O 狀態的介面。 |
| Nginx Master | 讀取設定、管理 Worker、處理 Reload 與 Process Lifecycle。 |
| Nginx Worker | 實際接受連線、讀取 Request、選擇 Server/Location 並產生 Response。 |
| Event Loop | 讓少量 Worker 能同時管理大量連線的非阻塞 I/O 模型。 |
| Server Block | 根據 Listen Port、`server_name` 與 Default Server 決定 Request 進入哪個虛擬主機。 |
| Location Block | 在選定 Server 後，決定某個 URI 要由哪段設定處理。 |

### Hour 1：Client 到 Nginx

#### 學習目標

- 分辨 DNS、TCP、TLS、HTTP 與 Nginx 的責任邊界。
- 說明一個 HTTPS Request 在到達 Nginx HTTP 處理邏輯前發生什麼事。
- 分辨 Linux Kernel、Nginx Master 與 Worker 在連線處理中的角色。

#### Request Lifecycle 骨架

```mermaid
flowchart TD
    A["使用者輸入 URL"] --> B["DNS：Domain 解析為 IP"]
    B --> C["TCP：建立可靠連線"]
    C --> D{"是否為 HTTPS？"}
    D -- "是" --> E["TLS Handshake：協商加密並驗證 Certificate"]
    D -- "否" --> F["HTTP Request：Method、URI、Headers、Body"]
    E --> F
    F --> G["Linux Kernel：Socket、封包、連線狀態與 I/O Readiness"]
    G --> H["Nginx Worker：Accept Connection 並讀取 Request"]
    H --> I["Server Selection"]
    I --> J["Location Selection"]
    J --> K{"如何產生 Response？"}
    K -- "Static Content" --> L["讀取並回傳 Static File"]
    K -- "Reverse Proxy" --> M["將 Request 轉送至 Upstream"]
    L --> N["Response 經 Kernel、TCP 傳回 Client"]
    M --> N
    N --> O["HTTPS 時由 TLS 加密傳輸"]
```

#### 責任邊界

| 元件 | 主要責任 |
|---|---|
| Client | 解析 URL、查 DNS、建立連線、送出 HTTP Request、處理 Response |
| DNS | 將 Domain Name 解析成可連線的 IP Address |
| Linux Kernel | Network Packet、TCP State、Socket、Listen/Accept Queue 與 I/O Readiness |
| Nginx Master | 讀取 Config、管理 Worker、Reload、Signal 與 Process Lifecycle |
| Nginx Worker | Accept Connection、讀取 Request、執行 HTTP Processing、寫回 Response |

#### 待實驗驗證

- [ ] 使用 DNS／Host 測試觀察 Name Resolution 與 HTTP Host 的差異。
- [x] 使用 `curl -v` 觀察 Connection 與 HTTP Request。
- [x] 啟動 Nginx Lab 後觀察 Master 與 Worker Processes。

#### 實驗一紀錄：`curl -v http://127.0.0.1:8080/`

| 觀察項目 | 實際值 | 所屬層次 |
|---|---|---|
| 連線目標 | `127.0.0.1:8080` | TCP |
| Request Line | `GET / HTTP/1.1` | HTTP |
| Method | `GET` | HTTP |
| URI | `/` | HTTP |
| Host Header | `127.0.0.1:8080` | HTTP |
| Response Status | `200 OK` | HTTP |
| Content-Type | `text/html` | HTTP |

關鍵結論：TCP 的連線目標與 HTTP `Host` Header 在本次實驗中內容相同，但它們屬於不同協定層，未來可以故意讓兩者不同。

#### 實驗二紀錄：相同 IP、不同 Host

執行的兩個 Requests：

```http
GET / HTTP/1.1
Host: a.local.test
```

```http
GET / HTTP/1.1
Host: unknown.local.test
```

兩次都連到相同的 `127.0.0.1:8080`，但 HTTP Host 不同。目前 Official Image 的 Config 沒有任何 `server_name` 匹配這兩個 Host，因此兩者都落入同一個 Default Server，最後由同一個 `root` 提供相同的 `index.html`。

關鍵因果：

```text
Host 沒有匹配
  -> 使用 Default Server
  -> 使用同一個 Location 與 Root
  -> 回傳相同內容
```

#### 實驗三紀錄：Master 與 Worker Processes

本次觀察到：

- 1 個 Master Process，PID 為 `395`。
- 8 個 Worker Processes，PID 為 `437` 至 `444`。
- 每個 Worker 的 PPID 都是 `395`，等於 Master PID。

範例讀法：

```text
PID  PPID  COMMAND
395  371   nginx: master process
437  395   nginx: worker process
```

`437` 是 Worker 自己的 PID；`395` 是它的 Parent PID，因此 Worker 是由 Master 管理的 Child Process。Master 自己的 PPID `371` 則是 Container 內啟動它的上層 Process。

Config 使用 `worker_processes auto;`，本次環境產生 8 個 Workers。這代表 Nginx 在目前執行環境偵測並採用了 8 個可用處理單位；不代表所有電腦都固定產生 8 個 Workers。

#### 實驗四紀錄：相同連線路徑，不同 HTTP 結果

```text
GET /           -> 200
GET /not-found  -> 404
```

兩個 Requests 都成功連到 `127.0.0.1:8080`，因此 `404` 不是 TCP Connection Failure。差異發生在 Nginx 解析 URI 並查找 Content 之後：`/` 有對應的 Index File，`/not-found` 沒有對應資源。

Hour 1 狀態：**完成**。

### Hour 2：Event-driven Concurrency

#### 核心問題

如果同時有 10,000 個 Clients 保持連線，但大部分時間都沒有資料可讀，Nginx 是否需要建立 10,000 個 Threads，讓每個 Thread 阻塞等待？

Nginx 的答案是：不需要。Worker 將 Connections 註冊到 Event Mechanism，只有 Connection 進入「可接受、可讀、可寫」等 Ready State 時，Kernel 才通知 Worker 處理。

```mermaid
flowchart LR
    C1["Connection 1：等待資料"] --> E["Kernel Event Mechanism"]
    C2["Connection 2：可讀"] --> E
    C3["Connection 3：等待資料"] --> E
    C4["Connection 4：可寫"] --> E
    E -->|"通知 Ready Events"| W["Nginx Worker Event Loop"]
    W --> R2["讀取 Connection 2"]
    W --> R4["寫入 Connection 4"]
    W --> E
```

#### 三個必要概念

| 概念 | 意義 |
|---|---|
| Event-driven | 依據 Connection 發生的 Event 決定下一步工作 |
| Non-blocking I/O | I/O 尚未 Ready 時，不讓 Worker 停在該 Connection 上等待 |
| Event Loop | Worker 反覆取得 Ready Events、處理少量工作，再回去等待下一批 Events |

Linux 上常見的 Event Mechanism 是 `epoll`。它的重點不是替 Nginx 處理 HTTP，而是有效率地告訴 Worker：「你關心的眾多 File Descriptors 中，哪些現在 Ready？」

#### 不要混淆

- Event-driven 不代表完全沒有 Processes 或 Threads。
- Non-blocking 不代表 Request 永遠不需要等待；而是等待期間 Worker 可以處理其他 Connections。
- epoll 不理解 HTTP、Location 或 Upstream；那些是 Nginx 的工作。
- Worker 數量少不代表同時只能服務少數 Connections。

#### 檢核題答案

有 10,000 個 Keepalive Connections、只有 3 個送來資料時，Worker 不需要逐一 Poll 全部 Connections。Linux Kernel 的 Event Mechanism（本課以 `epoll` 為例）會回報目前 Ready 的 File Descriptors，Worker 再處理對應的 3 個 Connections。

#### 實驗結果：單一 Worker 與慢速 Connections

實驗條件：

- `worker_processes 1;`
- 三個 TCP Connections 已建立，但沒有送出完整 HTTP Request。
- 第四個 Client 發送正常 HTTP Request。

實際結果：第四個 Request 仍立即取得 `200 OK`。

這與以下模型一致：

```text
三個 Connections 尚未有完整資料
  -> Worker 不阻塞等待
  -> Kernel 回報第四個 Connection 已 Ready
  -> 同一個 Worker 處理第四個 Request
  -> 回傳 200 OK
```

#### Event-driven 不是魔法

Worker 能服務大量等待中的 Connections，前提是每次被喚醒後執行的工作不長時間阻塞 Event Loop。如果 Worker 執行長時間 CPU-heavy 計算、Blocking File I/O 或不良 Third-party Module，該 Worker 仍可能暫時無法處理其他 Ready Events。

```mermaid
flowchart LR
    E1["Ready Event A"] --> W["Worker"]
    W --> B{"工作是否阻塞？"}
    B -- "否" --> LOOP["快速回到 Event Loop"]
    B -- "是" --> WAIT["其他 Ready Events 被延遲"]
```

檢核結論：若唯一的 Worker 阻塞 5 秒，即使 Kernel 已回報其他 Ready Events，它們仍要等 Worker 回到 Event Loop。若有其他未阻塞 Workers，部分工作可能由其他 Workers 處理。

Hour 2 狀態：**完成**。

### Hour 3：Process Model

#### Process 關係

```mermaid
flowchart TD
    OS["OS / Container Runtime"] --> M["Nginx Master Process"]
    M --> W1["Worker 1：Event Loop"]
    M --> W2["Worker 2：Event Loop"]
    M --> WN["Worker N：Event Loop"]
    W1 -. "特定 File I/O 場景" .-> TP1["Optional Thread Pool"]
    W2 -. "特定 File I/O 場景" .-> TP2["Optional Thread Pool"]
    C1["Client Connections"] --> W1
    C2["Client Connections"] --> W2
    C3["Client Connections"] --> WN
```

#### Master Process

- 讀取並驗證 Config。
- 建立、監督與終止 Workers。
- 接收 Reload、Reopen Logs、Quit、Terminate 等 Signals。
- Reload 時啟動使用新 Config 的 Workers，並要求舊 Workers Graceful Exit。
- 一般不負責逐一執行 HTTP Request Processing。

#### Worker Process

- 執行 Event Loop。
- Accept Connections。
- 讀取與解析 HTTP Requests。
- 執行 Server／Location／Module Processing。
- 讀取 Static Content 或與 Upstream 通訊。
- 寫回 Response。

#### Optional Thread Pool

Nginx 的核心模型仍是多個 Worker Processes，各自運行 Event Loop。Thread Pool 不是「每個 Connection 一條 Thread」，而是讓特定可能阻塞的 File I/O 工作有機會交由背景 Threads 執行，完成後再通知 Worker。

它不能自動修復所有 Blocking 問題，例如任意 Third-party Module 的 CPU-heavy 計算。

#### Reload 的新舊世代

```mermaid
sequenceDiagram
    participant Admin
    participant Master
    participant Old as 舊 Workers
    participant New as 新 Workers

    Admin->>Master: 發送 Reload Signal
    Master->>Master: 讀取並驗證新 Config
    alt Config 有效
        Master->>New: 啟動新 Workers
        Master->>Old: 要求 Graceful Shutdown
        Old->>Old: 完成既有 Connections
        Old-->>Master: Exit
    else Config 無效
        Master->>Master: 保留舊 Config 與舊 Workers
    end
```

檢核結論：新 Config 有 Syntax Error 時，Master 保留舊 Workers 與已載入的舊 Config。修正後應先執行 `nginx -t`，再發送 Reload；Master 會自動管理新舊 Worker 世代，不需要管理者手動刪除舊 Workers。

#### Reload 實驗紀錄（V1 → Invalid）

- V1 Config 通過 `nginx -t` 並回傳 `config version: v1`。
- Invalid Config 因 Syntax Error 無法通過 `nginx -t`。
- Invalid Config 檢查失敗後，服務仍正常回傳 V1。

因此 Config File 在 Disk 上被修改，不代表執行中的 Workers 已套用它。只有成功載入或 Reload 後，新 Config 才會成為 Runtime State。

#### Reload 實驗紀錄（V1 → V2）

- V2 通過 `nginx -t`。
- Reload 後 Response 包含 `X-Config-Version: v2`。
- Master PID 維持不變。
- Worker PIDs 換成新世代。

Hour 3 狀態：**完成**。

### Hour 4：Config Context、作用域與 Inheritance

#### Config 骨架

```mermaid
flowchart TD
    MAIN["main context"] --> EVENTS["events context"]
    MAIN --> HTTP["http context"]
    HTTP --> UPSTREAM["upstream context"]
    HTTP --> SERVER1["server context A"]
    HTTP --> SERVER2["server context B"]
    SERVER1 --> LOCATION1["location / context"]
    SERVER1 --> LOCATION2["location /api/ context"]
```

`main` 不是由大括號包起來的 Block；它代表 Config 最外層。其他 Context 由對應 Block 建立。

#### 常見 Context

| Context | 主要責任 | 常見 Directives |
|---|---|---|
| main | Process 與全域設定 | `user`、`worker_processes`、`pid`、`error_log` |
| events | Connection Processing | `worker_connections`、`use`、`multi_accept` |
| http | HTTP Module 共用設定 | `include`、`log_format`、`access_log`、`sendfile` |
| server | Virtual Server | `listen`、`server_name`、`root` |
| location | URI Handling | `try_files`、`return`、`proxy_pass` |
| upstream | 一組 Backend Servers | `server`、`keepalive`、Load-balancing Method |

#### Directive 與 Context

每個 Directive 只能出現在該 Module 允許的 Context。例如：

```nginx
worker_processes auto;  # main

events {
    worker_connections 1024;  # events
}

http {
    server {
        listen 80;  # server

        location /api/ {
            proxy_pass http://backend;  # location
        }
    }
}
```

把合法 Directive 放錯 Context 通常會讓 `nginx -t` 顯示 `directive is not allowed here`。

#### Inheritance 不是單一通則

「子層自動繼承父層全部設定」是危險的簡化。每個 Module 會定義自己的 Merge 行為。常見模式是：子層沒有設定時使用父層值；但有些 Directive 不繼承、有些會整組取代、有些可以在多個層級合併。

因此判斷 Inheritance 時要查該 Directive 的官方 Context 與 Module 行為，不能只靠巢狀外觀猜測。

#### `include` 的本質

`include` 可先理解成在該位置插入另一份 Config 內容。被 Include 的檔案仍必須符合插入位置的 Context；它不會自動建立新的 Context。

#### Context 檢核答案

| Directive | 合法 Context（本課範例） |
|---|---|
| `worker_processes` | main |
| `worker_connections` | events |
| `listen` | server |
| `proxy_pass` | location |

#### Context 實驗紀錄

- Invalid Config 將 `listen` 放在 `http` Context。
- `nginx -t` 回報：`"listen" directive is not allowed here`。
- `listen` 的正確位置是 `server` Context。
- Valid Config 只在 `http` 宣告 `root /usr/share/nginx/html;`。
- `server` 與 `location /` 都沒有重新宣告 `root`，因此此案例的 Effective Root 來自上層 `http` Context。

精確說法：

```text
http.root = /usr/share/nginx/html
server.root 未設定 -> 使用 http.root
location.root 未設定 -> 使用上層 Effective Root
```

這是 `root` Directive 的 Inheritance 行為，不能推論所有 Directives 都採用同一規則。

檢核結論：若 `http` 設定 `/site-a`、`server` 改為 `/site-b`、`location` 未設定，則 Location 的 Effective Root 是最近上層的 `/site-b`。

Hour 4 狀態：**完成**。

### Hour 5：Server Selection

#### HTTP Server Selection 心智模型

```mermaid
flowchart TD
    R["Request 到達某個 IP:Port"] --> L["找出匹配 listen Address/Port 的 Server 集合"]
    L --> H{"Host 是否匹配 server_name？"}
    H -- "Exact Name" --> E["選擇 Exact Server"]
    H -- "Wildcard / Regex" --> W["依規則選擇 Server"]
    H -- "沒有匹配" --> D["選擇該 Address/Port 的 Default Server"]
```

本課先掌握三步：

1. 先由目的 Address／Port 決定候選 `server` 集合。
2. 再用 HTTP Host 比對集合內的 `server_name`。
3. 沒有任何 Name 匹配時，使用該 Address／Port 的 `default_server`；若未明確標記，通常是該組第一個 Server。

`default_server` 是 `listen` 的屬性，不是 `server_name` 的名稱。

#### Server Selection 預測

| HTTP Host | 預測結果 | 原因 |
|---|---|---|
| `a.local.test` | `site-a` | Exact `server_name` Match |
| `b.local.test` | `site-b` | Exact `server_name` Match |
| `unknown.local.test` | `default` | 沒有 Name Match，使用 `default_server` |

#### Server Selection 實驗結果

三個 Actual Results 與 Prediction 完全相同：`site-a`、`site-b`、`default`。

Hour 5 狀態：**完成**。

### Hour 6：Validation、Reload 與 Logs

Hour 6 的目標已分散在 Hour 1、3、4 完成：

- `nginx -t`：驗證 Valid、Syntax Error、Wrong Context。
- `nginx -T`：查看 Include 展開後的完整 Runtime Candidate Config。
- Graceful Reload：Master PID 不變，Worker PIDs 換代。
- Access/Error Logs：確認 `/` 為 200、`/not-found` 為 404。

Hour 6 狀態：**完成**。

### Hour 7：Fault Injection

#### Wrong Server Selection

需求：`api.local.test` 應命中 FaceID API Server。

實際 Config：API Server 只宣告 `server_name app.local.test;`。

```text
Host: api.local.test
  -> 沒有 server_name Match
  -> 使用 default_server
  -> X-Selected-Server: default
```

最小修正取決於 Domain Contract：

```nginx
# api.local.test 是唯一正確名稱
server_name api.local.test;

# 或兩個名稱都必須相容
server_name api.local.test app.local.test;
```

Regression Matrix 必須包含 Intended Host、Unknown Host、Direct IP，以及被修改的舊 Host 行為。

#### Wrong Server Regression Result

- `api.local.test` → `faceid-api`
- `unknown.local.test` → `default`
- Direct IP → `default`

Hour 7 狀態：**完成**。

### Hour 8：Day 1 總驗收

驗收範圍：

- Client → Kernel → Nginx Request Lifecycle
- Event-driven、Non-blocking I/O、epoll
- Master／Worker／Optional Thread Pool
- Config Context 與 `root` Inheritance
- Server Selection 與 Default Server
- Syntax、Routing 與 Missing File Fault Classification

#### Day 1 驗收待確認的兩個精確觀念

1. HTTPS 流程是 `DNS -> TCP -> TLS -> HTTP Request`；HTTP Request 並未消失，而是經 TLS 加密傳輸。
2. `server_name _` 不是 Wildcard 或特殊 Default 語法；Fallback 的決定因素是 `listen ... default_server`。

最終確認：

- TLS Handshake 後傳送 HTTP Request。
- Unknown Host 使用 Default Server 的原因是 `default_server`，不是 `server_name _`。

Day 1 狀態：**完成。知識驗收、教材檔案與所有有效 Config 均已驗證。**

#### 自我檢核

1. DNS 解析成功，是否代表 Nginx 一定會選到正確的 Server Block？
2. HTTPS 的 Certificate Error 發生時，Nginx 是否已經能回傳 HTTP Redirect？
3. Master Process 是否負責逐一處理每個 HTTP Request？
