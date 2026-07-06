# Learn Nginx

這是一套五天、40 小時的 Nginx 密集學習教材。它不只整理設定語法，而是透過「先預測、再實驗、故意破壞、最後驗證」的方式，建立能用於實務設定與攻錯的心智模型。

> 目前 **Day 1、Day 2 已完成教材、實驗與驗收**；Day 3–5 已建立學習路線，實驗內容會隨進度補上。

## 適合誰

- 第一次接觸 Nginx，想從 Request Lifecycle、Worker Model 與 Config 結構開始學習的人。
- 已懂基本語法，想加強 Location、Reverse Proxy、HTTPS、效能與故障診斷的人。
- 想用 Docker 重現實驗，又不希望先在本機安裝或修改 Nginx 的人。

完成五日內容後，你應該能預測 Nginx 如何選擇 `server` 與 `location`、解釋 URI 如何轉換、驗證設定是否安全載入，並根據 Response、Logs 與 `nginx -t` 找出問題所在。

## 教材進度

| Day | 主題 | 狀態 | 教材 |
|---|---|---|---|
| Day 1 | 架構、Request Lifecycle 與 Config 骨架 | 完整教材 | [開始 Day 1](days/day-1/README.md) |
| Day 2 | Location、Static Files、SPA 與 Rewrite | 完整教材 | [開始 Day 2](days/day-2/README.md) |
| Day 3 | Reverse Proxy、Upstream 與擴展性 | 課綱 | [查看 Day 3](days/day-3/README.md) |
| Day 4 | HTTPS、Domain/IP 與安全 | 課綱 | [查看 Day 4](days/day-4/README.md) |
| Day 5 | 併發、效能、Observability 與總攻錯 | 課綱 | [查看 Day 5](days/day-5/README.md) |

## 使用前準備

建議先安裝並確認以下工具可用：

- Git：取得與管理教材。
- Docker：啟動可重現的 Nginx Lab。
- curl：發送 HTTP Request 並觀察 Response。
- OpenSSL：Day 4 驗證 TLS 與憑證時使用。
- `nc`（選用）：Day 1 模擬保持開啟的 Connection 時使用。

在 Terminal 執行：

```bash
git --version
docker version
curl --version
openssl version
```

Docker 指令需要 Docker Engine 或 Docker Desktop 已經啟動。

## 快速開始

取得專案後，先切換到專案根目錄：

```bash
cd learn-ngnix
```

初次學習請打開 [Day 1 教材入口](days/day-1/README.md)，並從第一個 Request Lifecycle 實驗開始：

```bash
docker run --rm -d \
  --name learn-nginx-day1 \
  -p 8080:80 \
  nginx:stable

curl -v http://127.0.0.1:8080/
```

觀察完成後停止容器：

```bash
docker stop learn-nginx-day1
```

完整步驟、預期結果與觀察問題請以 [Request Lifecycle 實驗](days/day-1/labs/hour-1/request-lifecycle-experiment.md)為準。

## 建議學習方式

每個 Lab 都依照同一個循環進行：

1. **理解**：先讀原理，釐清 Client、Kernel、Master、Worker 與 Upstream 的責任。
2. **預測**：執行指令前，先寫下預期的 Status、Header、Content、Log 或 Process 變化。
3. **實驗**：使用最小 Config 與 Request 驗證預測。
4. **故障注入**：故意製造 Syntax、Routing、Filesystem、TLS 或 Upstream 問題。
5. **診斷**：使用 `nginx -t`、`nginx -T`、Response 與 Logs 蒐集證據。
6. **記錄**：保存 Evidence、Root Cause、Minimal Fix 與 Regression Check。
7. **驗收**：完成當日 Assessment，確認自己能解釋與重現結果。

建議不要只複製指令。真正有價值的部分，是在看到結果前先做出可被驗證的預測。

## 五日學習路線

- **Day 1 — 架構與 Config 骨架**：Request Lifecycle、Event-driven Model、Master/Worker、Directive Context、Server Selection、Reload 與 Logs。
- **Day 2 — Location 與 Static Files**：Location Matching、`root`、`alias`、`try_files`、SPA、Rewrite、Cache 與 Compression。
- **Day 3 — Reverse Proxy 與 Upstream**：`proxy_pass` URI、Headers、Timeouts、Buffering、Upstream Algorithm、Keepalive、Retry 與 DNS。
- **Day 4 — HTTPS 與安全**：TLS、SNI、Certificate、Domain/IP、Security Headers、Request Limits 與 Rate Limiting。
- **Day 5 — 效能與總攻錯**：Connection Capacity、Blocking、Keepalive、Observability、Graceful Operations 與完整 Config Review。

需要完整的逐時安排時，請查看[五日執行計畫](docs/superpowers/plans/2026-07-01-nginx-intensive-learning-plan.md)。需要依主題深入問答時，使用[分級問題清單](docs/ai-question-list.md)。

## 專案結構

```text
learn-ngnix/
├── README.md                     # 專案入口與使用方式
├── days/
│   ├── README.md                 # 每日教材索引
│   ├── day-1/                    # 已完成的筆記、Labs 與驗收
│   ├── day-2/                    # 已完成的筆記、Labs、Fault Log 與驗收
│   ├── day-3/                    # Day 3 課綱
│   ├── day-4/                    # Day 4 課綱
│   └── day-5/                    # Day 5 課綱
└── docs/
    ├── ai-question-list.md        # 依難度與主題整理的問題
    └── superpowers/
        ├── plans/                 # 執行計畫
        └── specs/                 # 學習方案與文件設計
```

重要入口：

- [每日教材索引](days/README.md)
- [Day 1 學習筆記](days/day-1/notes.md)
- [Day 1 總驗收](days/day-1/day-1-assessment.md)
- [Day 2 學習筆記](days/day-2/notes.md)
- [Day 2 總驗收](days/day-2/day-2-assessment.md)
- [Nginx 密集學習方案設計](docs/superpowers/specs/2026-07-01-nginx-intensive-learning-design.md)
- [README 文件設計](docs/superpowers/specs/2026-07-02-project-readme-design.md)

## 常用驗證指令

以下指令是 Lab 中最常使用的觀察工具。容器名稱與 Port 會依實驗不同，請以各 Lab 文件為準。

```bash
# 查看執行中的 Lab 容器
docker ps

# 驗證目前容器中的 Nginx Config
docker exec <container-name> nginx -t

# 展開並輸出完整 Runtime Config
docker exec <container-name> nginx -T

# 通過驗證後進行 Graceful Reload
docker exec <container-name> nginx -s reload

# 觀察 Container Logs
docker logs -f <container-name>

# 發送帶有指定 Host Header 的 Request
curl -i -H 'Host: a.local.test' http://127.0.0.1:<port>/

# 停止並清理使用 --rm 啟動的 Lab
docker stop <container-name>
```

尖括號中的值需要替換成各 Lab 使用的容器名稱與 Port。例如 Server Selection Lab 使用 `learn-nginx-server-selection` 與 `8084`。

## 注意事項

- Docker 在這個專案中只是可重現 Lab 的啟動工具，不是學習主題本身。
- 本機實驗與 Load Test 用來驗證行為，不代表 Production Capacity。
- 執行 Reload 前先用 `nginx -t` 驗證 Config；驗證失敗時不要 Reload。
- `docker run` 使用的 Port 必須沒有被其他程式占用。
- 實驗完成後執行 Lab 文件中的停止指令，避免容器或 Port 殘留。
- Production 設定仍需依實際部署拓撲、流量、憑證、安全規範與 Nginx 版本重新評估。
