# K3s／Kubernetes 特別章節學習筆記

## 2026-07-15：OrbStack Kubernetes、Traefik 與第一個 Service 故障實驗

### 今日環境

| 項目 | 實際值 |
|---|---|
| Kubernetes Context | `orbstack` |
| Kubernetes Version | `v1.34.8+orb1` |
| Node | `orbstack`，`Ready` |
| Node / Traefik External IP | `192.168.139.2` |
| Helm | `v4.2.3` |
| Traefik Helm Chart | `41.0.2` |
| Traefik App Version | `v3.7.6` |
| Traefik IngressClass | `traefik` |

這次使用的是 OrbStack Kubernetes，不是 K3s。Deployment、Service、Ingress 與 Nginx Config 的行為相同；差異是 K3s 預設附帶 Traefik，而 OrbStack 叢集原本沒有 Ingress Controller，因此另外使用 Helm 安裝。

### 今日名詞表

| 名詞 | 用途 | 本次觀察 |
|---|---|---|
| Helm Repository | 提供可供 Helm 取得的 Charts。 | 加入 `https://traefik.github.io/charts`。 |
| Chart Version | Kubernetes 安裝模板的版本。 | Traefik Chart `41.0.2`。 |
| App Version | Chart 實際部署的應用程式版本。 | Traefik `v3.7.6`。 |
| Helm Release | Chart 安裝到叢集後的一個實例。 | Release `traefik` 狀態為 `deployed`。 |
| IngressClass | 指定哪一類 Ingress Controller 處理 Ingress。 | `ingressClassName: traefik` 對應 Traefik Controller。 |
| ClusterIP | 供叢集內部使用的穩定 Service IP。 | `backend` 與 `web-nginx` 都使用 ClusterIP。 |
| EndpointSlice | Service 目前可轉送到的 Ready Pod IP 與 Port。 | 正常時兩個 Services 各有兩個 Endpoints。 |
| Fault Injection | 主動製造可恢復的故障，以驗證診斷模型。 | 將 Backend Service Selector 改成不存在的 Label。 |
| Regression Check | 修正後再次執行原本失敗的路徑，證明功能恢復。 | `/api/` 從 502 恢復成 200。 |

### 正常流量驗證

Lab 使用：

```text
Client
  -> Traefik
  -> web-nginx Service
  -> Nginx Pod
  -> backend Service
  -> Backend Pod
```

正常 EndpointSlice：

```text
backend    -> 192.168.194.13:8080, 192.168.194.12:8080
web-nginx  -> 192.168.194.14:80,   192.168.194.15:80
```

已驗證：

| Request | 結果 | 證明 |
|---|---|---|
| 叢集內 `http://web-nginx/` | `200 hello from nginx` | Service 到 Nginx 正常。 |
| 叢集內 `http://web-nginx/api/` | `200 hello from backend` | Nginx、Backend Service 與 Backend Pod 正常。 |
| External IP + 正確 Host `/` | `200 hello from nginx` | Traefik 與 Ingress Host Routing 正常。 |
| External IP + 正確 Host `/api/` | `200 hello from backend` | 完整外部 Proxy Path 正常。 |
| External IP + 錯誤 Host | Traefik `404 page not found` | Request 未匹配 Ingress，也未進入 Nginx。 |
| `curl --resolve` + Domain | `200 hello from nginx` | 暫時指定 DNS 後，Domain 與 Host Routing 正常。 |

Nginx Logs 顯示叢集內測試與外部測試分配到不同 Nginx Pods。錯誤 Host 的 404 沒有出現在 Nginx Access Log，證明 Response 在 Traefik 層產生。

### Fault Log：Backend Service 沒有 Endpoint

#### 故障注入

將 Backend Service Selector 從：

```yaml
selector:
  app: backend
```

故意改成：

```yaml
selector:
  app: backend-broken
```

#### Evidence

- 兩個 Backend Pods 仍為 `Running`、`Ready 1/1`。
- Backend ClusterIP Service 仍存在於 `192.168.194.197:8080`。
- Backend EndpointSlice 的 `PORTS` 與 `ENDPOINTS` 都變成 `<unset>`。
- `/` 仍回 `200 hello from nginx`。
- `/api/` 回 `502 Bad Gateway`。
- Nginx Error Log：

```text
connect() failed (111: Connection refused) while connecting to upstream
upstream: "http://192.168.194.197:8080/"
```

#### Root Cause

Service Selector 沒有匹配 Backend Pod Label，因此 Service 雖然存在，卻沒有可用 Endpoint。Nginx 已成功把 `backend` 解析成 Service Cluster IP，但無法建立 Upstream TCP Connection。

#### Minimal Fix

把 Service Selector 恢復為：

```yaml
selector:
  app: backend
```

本次使用宣告式 Manifest 恢復：

```bash
kubectl apply -f special-topics/k3s-kubernetes/labs/k3s-nginx-lab.yaml
```

#### Regression Check

- Backend EndpointSlice 恢復兩個 IP 與 Port `8080`。
- `/api/` 恢復 `200 hello from backend`。

### 今日診斷結論

```text
Pod Running 不代表 Service 一定能送到它。
Service 存在不代表 Service 一定有 Endpoint。
看到 502 時，先用最後成功的位置與 Logs 找出失敗層級。
修正後必須重新執行原本失敗的 Request。
```

## 2026-07-15：502 與 504 Timing 對照實驗

### 實驗設計

使用獨立的 `nginx-timeout-lab` Namespace：

```text
Client
  -> Traefik
  -> timeout-nginx
  -> slow-backend
```

Slow Backend 固定等待約 3 秒才送出 Response Header。Nginx 提供兩條路徑：

| Path | `proxy_read_timeout` | 預期 |
|---|---:|---|
| `/success/` | 5 秒 | 等到 Backend Response，回 200。 |
| `/timeout/` | 1 秒 | 等待逾時，回 504。 |

### 實際結果

```text
/success/ -> status=200 total=3.018261s
/timeout/ -> status=504 total=1.005914s
```

Nginx Timing Log：

```text
GET /success/ status=200
upstream=192.168.194.200:8080
upstream_status=200
connect_time=0.002
header_time=3.010
response_time=3.010
```

```text
GET /timeout/ status=504
upstream=192.168.194.200:8080
upstream_status=504
connect_time=0.000
header_time=-
response_time=1.002
```

Error Log：

```text
upstream timed out (110: Operation timed out)
while reading response header from upstream
```

### Evidence 解讀

- 兩條路徑都連到相同 Upstream `192.168.194.200:8080`。
- 504 的 `connect_time=0.000`，表示 Nginx 幾乎立即完成 Upstream TCP Connection。
- `header_time=-`，表示 Timeout 發生前沒有讀到完整 Response Header。
- `response_time=1.002` 與 `proxy_read_timeout 1s` 對應。
- 200 的 `header_time=3.010` 與 Slow Backend 的 3 秒延遲對應。

因此本次 504 的 Root Cause 不是 DNS、Service Endpoint 或 TCP Connection，而是 Backend 回 Response Header 的時間超過 `proxy_read_timeout`。

### Container 啟動警告

Official Nginx Image 啟動時顯示：

```text
can not modify /etc/nginx/conf.d/default.conf (read-only file system?)
```

原因是 ConfigMap 以 `readOnly: true` 掛載。Entry Point Script 嘗試調整該檔案時無法寫入，但 Nginx 隨後成功啟動，Readiness、200 與 504 實驗也都通過。這是啟動腳本的提示，不是本次 Timeout 的 Root Cause。

### 502／504 對照

| Status | 本次 Root Cause | 關鍵 Evidence |
|---|---|---|
| 502 | Service Selector 錯誤，Backend Service 沒有 Endpoint。 | `connect() failed`、EndpointSlice 為空。 |
| 504 | Backend 3 秒才回 Header，但 Nginx 只等 1 秒。 | `upstream timed out`、`connect_time=0.000`、`header_time=-`。 |

## 2026-07-15：Scaling、Service 與 Upstream Keepalive

### Scaling 實驗

使用 Imperative Command 將 Nginx Pods 從 2 擴展為 3：

```bash
kubectl scale deployment/web-nginx --replicas=3 -n nginx-lab
```

結果：

```text
web-nginx Pods：2 -> 3
web-nginx Endpoints：2 -> 3
Service 名稱與 ClusterIP：不變
Ingress：不需修改
```

連續 12 個 `/` Requests 剛好分配為三個 Nginx Pods 各 4 個，證明新增的 Ready Pod 自動加入 Service EndpointSlice。

### 兩層流量分配

```text
Traefik
  -> web-nginx Service
  -> 3 個 Nginx Pods
  -> backend Service
  -> 2 個 Backend Pods
```

12 個 `/api/` Requests 在 Backend Logs 中約分成 4／8，而不是 6／6。Nginx Config 啟用了 Upstream Keepalive：

```nginx
upstream backend_upstream {
    server backend:8080;
    keepalive 32;
}
```

Logs 顯示三個 Nginx Pods 各自重用 Upstream TCP Connection：

```text
Nginx 192.168.194.20:33418 -> Backend 192.168.194.12
Nginx 192.168.194.14:52318 -> Backend 192.168.194.13
Nginx 192.168.194.15:49158 -> Backend 192.168.194.13
```

Kubernetes Service 在建立 TCP Connection 時選擇 Endpoint；同一條 Keepalive Connection 裡的後續 HTTP Requests 不會被重新分配到另一個 Backend。因此少量長連線下，HTTP Request 數量不一定平均。

### 恢復 Declarative State

Git 中的 Manifest 仍宣告 `replicas: 2`。重新 `kubectl apply` 後：

```text
Deployment READY：2/2
web-nginx EndpointSlice：2 個 Endpoints
```

這次實驗區分：

```text
kubectl scale -> 臨時改變 Live State
Manifest      -> Declarative Source of Truth
```

### ConfigMap `subPath` 更正

本 Lab 用 `subPath` 將 ConfigMap 的單一 Key 掛成 `/etc/nginx/conf.d/default.conf`。這類 Container 不會收到 ConfigMap 後續更新；修改 ConfigMap 後必須建立新 Pod。若不使用 `subPath`、改掛整個 ConfigMap Volume，投影檔案最終可能更新，但 Nginx 仍需要 Reload 才會使用新設定。

## 2026-07-15：ConfigMap `subPath` 與 Nginx Reload 實驗

### 實驗目標

把 ConfigMap 中的首頁 Response 從：

```text
hello from nginx
```

更新成：

```text
hello from nginx v2
```

並區分 ConfigMap、Pod 掛載檔案、Nginx Runtime 與 Client Response。

### 階段一：只更新 ConfigMap

ConfigMap 已顯示：

```nginx
return 200 "hello from nginx v2\n";
```

但既有 Pod 的 `/etc/nginx/conf.d/default.conf` 仍顯示：

```nginx
return 200 "hello from nginx\n";
```

Client Response 也仍是：

```text
hello from nginx
```

這證明使用 ConfigMap `subPath` 時，更新 ConfigMap 不會更新既有 Pod 的掛載檔案。

### 階段二：在舊 Pod 執行 Reload

```text
signal process started
```

代表 `nginx -s reload` 已送出 Signal，但 Response 仍是 v1。Reload 只會重新讀取 Pod 內現有檔案，而該檔案仍是舊版本。

此外，`kubectl exec deployment/web-nginx -- ...` 只會選擇其中一個 Pod 執行，不會自動在所有 Replicas 執行相同命令。

### 階段三：Rollout Restart

執行：

```bash
kubectl rollout restart deployment/web-nginx -n nginx-lab
```

新 Pods 建立後，Client Response 變成：

```text
hello from nginx v2
```

新 Pod 在建立時重新取得 ConfigMap，因此能掛載 v2。

### 恢復與 Regression Check

重新套用 Git 中的主 Manifest，把 ConfigMap 恢復成 v1，再執行 Rollout Restart。三層 Evidence 均回到 v1：

```text
ConfigMap data -> hello from nginx
Pod mounted file -> hello from nginx
Client Response -> hello from nginx
```

### 實驗結論

```text
ConfigMap 更新成功，不代表 Pod File 已更新。
Nginx Reload 成功，不代表讀到 ConfigMap 最新版本。
單一 Pod Reload，不代表所有 Replicas 都已更新。
subPath Config 更新後，需要建立新 Pod。
修正完成後，應同時檢查宣告、Runtime File 與 Client Response。
```

## 2026-07-15：Invalid Nginx Config 與 Rolling Update 保護

### 故障注入

把缺少分號的 Nginx Config 放入 ConfigMap：

```nginx
return 200 "this config is invalid\n"
```

接著執行 `kubectl rollout restart`。`rollout status --timeout=20s` 顯示：

```text
1 out of 2 new replicas have been updated
timed out waiting for the condition
```

這裡的 Timeout 表示 Deployment 未在 20 秒內完成更新，不是 Nginx `proxy_read_timeout`。

### Rollout Evidence

Deployment：

```text
READY=2/2
UP-TO-DATE=1
AVAILABLE=2
```

ReplicaSets：

```text
舊 ReplicaSet web-nginx-6cfdcf6dbc：DESIRED=2 READY=2
新 ReplicaSet web-nginx-7598d58559：DESIRED=1 READY=0
```

新 Pod：

```text
READY=0/1
STATUS=CrashLoopBackOff
```

Nginx Log：

```text
unexpected "}" in /etc/nginx/conf.d/default.conf:10
```

Client 同時仍收到：

```text
HTTP 200
hello from nginx
```

因此錯誤新 Pod 沒有成為 Ready Endpoint，Rolling Update 保留舊 ReplicaSet 的兩個健康 Pods 繼續服務。

### 恢復

先重新套用主 Manifest 恢復 ConfigMap，再執行 Rollout Restart。只恢復 ConfigMap 不足以修正既有的錯誤 Pod，因為 Config 使用 `subPath` 掛載。

恢復後：

```text
Deployment web-nginx：READY=2/2 UP-TO-DATE=2 AVAILABLE=2
新 ReplicaSet web-nginx-b496d6df9：DESIRED=2 READY=2
錯誤 ReplicaSet web-nginx-7598d58559：DESIRED=0 READY=0
```

Regression Check：

```text
GET /      -> 200 hello from nginx
GET /api/  -> 200 hello from backend
```

### 實驗結論

```text
Rolling Update 可在新 Pod 無法 Ready 時保留舊 Pods。
Deployment READY=2/2 不代表最新 Rollout 已完成，還要看 UP-TO-DATE。
Kubernetes 不會自動修正 Nginx Syntax Error。
語法錯誤通常能阻止 Nginx 啟動；語法正確但行為錯誤則需要 Smoke Test 才能發現。
恢復 ConfigMap 後，subPath Pod 仍需重建。
```

## 2026-07-15：Traefik TLS Termination 與 SNI

### 憑證與 Secret

使用本機 OpenSSL Config 產生七天有效的 Self-signed Certificate，Private Key 只保存在 `/tmp/nginx-tls-lab`，沒有提交到 Git。

```text
Subject：CN=nginx.local.test
Issuer：CN=nginx.local.test
SAN：DNS:nginx.local.test
Valid：2026-07-15 至 2026-07-22
Key：RSA 2048 bit
```

`Subject` 與 `Issuer` 相同，符合 Self-signed Certificate。Kubernetes Secret：

```text
Name：nginx-local-tls
Type：kubernetes.io/tls
Data Keys：2
```

Ingress 顯示：

```text
nginx-local-tls terminates nginx.local.test
```

### Client Trust 驗證

Client 未指定 CA 時：

```text
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

這表示 Client 不信任 Self-signed Issuer，不代表 Traefik、Ingress 或 Nginx 無法處理 Request。

使用 `--cacert /tmp/nginx-tls-lab/tls.crt` 後：

```text
HTTPS GET /     -> HTTP/2 200 hello from nginx
HTTPS GET /api/ -> HTTP/2 200 hello from backend
```

### TLS Handshake Evidence

`openssl s_client` 使用 `-servername nginx.local.test` 傳送 SNI，結果：

```text
Verification：OK
Protocol：TLSv1.3
Cipher：TLS_AES_128_GCM_SHA256
Key Exchange Group：X25519MLKEM768
Server Public Key：RSA 2048 bit
Verify return code：0 (ok)
```

`openssl s_client` 顯示 `No ALPN negotiated`，是因為這次指令沒有宣告 ALPN Protocol；Curl 的實際 HTTPS Request 則成功協商並使用 HTTP/2。TLS Version 與 HTTP Version 是不同層級，不應混為一談。

### 流量模型

```text
Client
  -- TLS 1.3 / HTTPS --> Traefik
  -- 叢集內 HTTP ----> web-nginx Service
  --> Nginx Pod
```

TLS Certificate 與 Private Key 位於 Kubernetes TLS Secret，由 Traefik執行 TLS Termination；應用 Nginx 不需要直接掛載該 Secret。

### 錯誤 SNI 與 Default Certificate

使用 `wrong.local.test` 作為 SNI 時，Traefik 回傳：

```text
subject=CN=TRAEFIK DEFAULT CERT
issuer=CN=TRAEFIK DEFAULT CERT
```

接著 HTTP Host `wrong.local.test` 沒有匹配 Ingress，因此回：

```text
HTTP/2 404
404 page not found
```

Response 沒有 Nginx Server Header，表示 404 由 Traefik 產生。

### SNI／Host 交叉測試

| TLS SNI | HTTP Host | 結果 | 解讀 |
|---|---|---|---|
| `nginx.local.test` | `wrong.local.test` | TLS 驗證成功，HTTP 404 | SNI 選到正確憑證，但 Host 未匹配 Ingress。 |
| `wrong.local.test` | `nginx.local.test` | Default Certificate；使用 `-k` 後 HTTP 200 | TLS 與 HTTP Routing 是兩個階段；Host 仍可匹配 Ingress。 |

第二個案例只用來拆解協定層級；正式 Client 不應使用 `-k` 忽略 Certificate 驗證。

```text
TLS ClientHello / SNI -> Traefik 選 Certificate
TLS Handshake 完成
HTTP Request / Host   -> Traefik 選 Ingress Route
```

### `$scheme` 與 `X-Forwarded-Proto` 實驗

Debug Nginx Config 把兩個值放入 Response Headers：

```nginx
add_header X-Debug-Nginx-Scheme $scheme always;
add_header X-Debug-Forwarded-Proto $http_x_forwarded_proto always;
```

外部 HTTP：

```text
X-Debug-Nginx-Scheme：http
X-Debug-Forwarded-Proto：http
```

外部 HTTPS：

```text
x-debug-nginx-scheme：http
x-debug-forwarded-proto：https
```

HTTP/2 Response Header 名稱顯示為小寫是正常行為。HTTPS 案例證明：

```text
Client -- HTTPS --> Traefik -- HTTP --> Nginx
```

Nginx 的 `$scheme` 描述 Traefik 到 Nginx 的直接連線；可信入口帶入的 `X-Forwarded-Proto` 才描述 Client 原始 Scheme。Backend 若需要產生外部 Redirect URL、判斷 Secure Cookie 或記錄原始 Protocol，應使用經過明確 Trust Boundary 處理的 Forwarded Header。

如果 Nginx 可被不可信 Client 直接存取，Client 可以偽造 `X-Forwarded-Proto`；因此應維持應用 Service 為 ClusterIP，並視環境使用 NetworkPolicy 限制只有入口 Controller 能連入。

## 2026-07-15：Traefik Gateway API 與跨 Namespace Route

### 啟用 Gateway API

OrbStack Kubernetes 原本不認識 `gateway.networking.k8s.io` Resources，Traefik Gateway Provider 也為停用狀態。

安裝 Gateway API v1.5.1 Standard CRDs 後，API Server 開始提供：

```text
GatewayClass
Gateway
HTTPRoute
GRPCRoute
TLSRoute
BackendTLSPolicy
ReferenceGrant
ListenerSet
```

使用 Helm Upgrade 啟用：

```yaml
providers:
  kubernetesGateway:
    enabled: true
```

結果：

```text
Traefik Helm Revision：2
GatewayClass traefik：Accepted=True
Gateway traefik-gateway：Programmed=True
Gateway Address：192.168.139.2
Traefik Pod：Ready 1/1
```

### `allowedRoutes: Same` 拒絕跨 Namespace Route

Gateway 位於 `traefik` Namespace，HTTPRoute 位於 `nginx-lab`。Listener 最初設定：

```yaml
allowedRoutes:
  namespaces:
    from: Same
```

HTTPRoute 可以被 API Server 保存，且 Backend Reference 可解析，但 Parent Condition 顯示：

```text
Accepted=False
Reason=NotAllowedByListeners
ResolvedRefs=True
```

Gateway 同時顯示 `Attached Routes: 0`，外部 `gateway.local.test` Request 回 Traefik 404。

這證明：

```text
Resource 存在，不代表已被 Parent 接受。
ResolvedRefs=True，不代表 Route 已生效。
```

### Listener Policy 改為 `All`

Gateway 由 Helm 管理，因此使用 Helm Values 修改，而不是直接 Patch Live Gateway：

```text
gateway.listeners.web.namespacePolicy.from=All
```

結果：

```text
Traefik Helm Revision：3
Gateway Generation：2
Allowed Routes From：All
Attached Routes：1
Gateway Accepted=True / Programmed=True
HTTPRoute Accepted=True / ResolvedRefs=True
GET gateway.local.test/：200 hello from nginx
```

HTTPRoute 本身不需重新建立；Listener Policy 改變後，Traefik重新評估既有 Route。

### Listener Port 與 Service Port

Gateway Listener 顯示 Port `8000`，這是 Traefik Pod 的 `web` EntryPoint；Traefik LoadBalancer Service 對外提供 Port `80`，再映射到內部 EntryPoint。因此 Client 仍使用 `192.168.139.2:80`。

### 安全提醒

`All` 適合本次 Lab，但正式環境可能讓任何 Namespace 的 Route 嘗試掛到共用 Gateway。Production 應評估使用 Namespace Selector、RBAC 與明確的 Route Ownership Policy。

### Gateway API BackendNotFound 故障實驗

將 HTTPRoute Backend 暫時改成不存在的 `missing-backend`：

```text
HTTPRoute Generation：2
Accepted=True
ResolvedRefs=False
Reason=BackendNotFound
Message=service "missing-backend" not found
```

Request 回 `500 Internal Server Error`，且 Body 為空。這和 Route 未被 Listener 接受時的 404 不同：

```text
404 -> 沒有有效 Route 匹配
500 -> Route 已匹配，但 Backend Reference 無效
```

重新套用宣告式 HTTPRoute 後：

```text
Generation：3
Observed Generation：3
Accepted=True
ResolvedRefs=True
```

`Observed Generation` 與 Resource `Generation` 相同，表示 Controller 已處理最新版本，而不是仍顯示舊 Status。

### Gateway API HTTPS

使用獨立 Self-signed Certificate：

```text
Hostname：gateway.local.test
Secret：gateway-local-tls
Secret Namespace：traefik
```

Secret 與 Gateway 位於相同 Namespace，因此 Listener 可以直接引用，不需要 `ReferenceGrant`。

Helm Values 保留 HTTP Listener，並新增：

```yaml
websecure:
  hostname: gateway.local.test
  port: 8443
  protocol: HTTPS
  certificateRefs:
    - name: gateway-local-tls
```

HTTPRoute 同時使用兩個 Parent Refs：

```text
sectionName：web
sectionName：websecure
```

實際狀態：

```text
Traefik Helm Revision：4
Gateway Generation：3
Gateway Accepted=True / Programmed=True
web Listener：Attached Routes=1，Accepted=True，ResolvedRefs=True
websecure Listener：Attached Routes=1，Accepted=True，ResolvedRefs=True
HTTPRoute Generation：4
兩組 Parent Status：Accepted=True，ResolvedRefs=True
HTTPS GET gateway.local.test/：HTTP/2 200 hello from nginx
```

Gateway HTTPS 的責任分工：

```text
Gateway Listener -> Port、Protocol、Hostname、TLS Termination、Certificate
HTTPRoute         -> Host、Path、Backend Service
```

### Service 無 Ready Endpoint 的 503 實驗

將 `web-nginx` Deployment 暫時縮為 0：

```text
Deployment web-nginx：0/0
Service web-nginx：仍存在
EndpointSlice：PORTS=<unset> ENDPOINTS=<unset>
```

HTTPRoute 的兩組 Parent Status 仍為：

```text
Accepted=True
ResolvedRefs=True
```

這表示 `ResolvedRefs` 只確認 Service Reference 可解析，不保證 Service 有 Ready Endpoint。Traefik 回：

```text
HTTP 503 Service Unavailable
no available server
```

重新套用 Base Manifest 恢復 `replicas: 2`，再套用 TLS Ingress Overlay。Deployment Rollout 完成後，進一步執行 Client Regression Check：

```text
HTTP Gateway  -> 200 hello from nginx
HTTPS Gateway -> HTTP/2 200 hello from nginx
```

### Gateway API Status 診斷表

| Status | 實驗證據 | Root Cause |
|---|---|---|
| 404 | `Accepted=False`、`NotAllowedByListeners`、Attached Routes 0 | 沒有生效的 Route 匹配。 |
| 500 | `Accepted=True`、`ResolvedRefs=False`、`BackendNotFound` | Route 已匹配，但 Backend Reference 無效。 |
| 503 | `Accepted=True`、`ResolvedRefs=True`、EndpointSlice 為空 | Service 存在，但沒有 Ready Endpoint。 |
| 200 | Conditions 正常、EndpointSlice 有 IP、Client Request 成功 | 完整 Request Path 正常。 |

診斷時不要只讀 HTTP Status，也不要只看 HTTPRoute Conditions；必須繼續往 Service、EndpointSlice、Pod Readiness 與 Application Logs 追蹤。

## 2026-07-15：NetworkPolicy Resource 與 Enforcement 差異

### Policy 目標

選取 `app=web-nginx` Pods，只允許以下來源連入 TCP 80：

```text
Namespace Label：kubernetes.io/metadata.name=traefik
Pod Label：app.kubernetes.io/name=traefik
```

兩個 Selectors 位於同一個 `from` Entry，因此是 AND；來源必須同時符合 Namespace 與 Pod 條件。

### 實際結果

套用前，一般 `nginx-lab` Pod 可直接存取：

```text
http://web-nginx/ -> hello from nginx
```

NetworkPolicy 成功建立後，相同的一般 Pod 仍可直接存取：

```text
http://web-nginx/ -> hello from nginx
```

Traefik／Gateway 路徑也正常回 200。

### 結論

Kubernetes API Server 支援並保存 `networking.k8s.io/v1 NetworkPolicy`，不代表叢集資料平面一定執行 Policy。Enforcement 由相容的 Network Plugin／CNI 負責。本次實際封包測試顯示目前 OrbStack 叢集沒有對這份 Policy 產生有效隔離，因此不能把它視為已建立的 Trust Boundary。

```text
NetworkPolicy created -> API Object 存在
Connection blocked    -> Enforcement 的真正證據
```

在無法 Enforcement 的叢集上保留 Policy 可能造成錯誤安全感。Production 必須確認 CNI 支援、做 Allowed／Denied 雙向測試，並將結果納入部署驗收。

## 2026-07-15：特別章節最終環境驗收

所有 Fault Injection 已恢復，最終 Live State：

```text
NetworkPolicy：無殘留 Resource
Backend Deployment：2/2 Ready，2 Up-to-date，2 Available
Web Nginx Deployment：2/2 Ready，2 Up-to-date，2 Available
Backend Service：ClusterIP 192.168.194.197:8080
Web Nginx Service：ClusterIP 192.168.194.233:80
Ingress：nginx.local.test，Traefik，Address 192.168.139.2，Ports 80/443
HTTPRoute：gateway.local.test
GatewayClass traefik：Accepted=True
Gateway traefik-gateway：Programmed=True，Address 192.168.139.2
Traefik Helm Release：Revision 4，Status deployed
Traefik Chart：41.0.2
Traefik App：v3.7.6
```

目前同時保留兩條已驗證入口：

```text
nginx.local.test   -> Ingress API -> Traefik -> web-nginx
gateway.local.test -> Gateway API -> Traefik -> web-nginx
```

本章已完成：Service DNS、EndpointSlice、Readiness、Ingress、Traefik、502／504、Scaling、Keepalive、ConfigMap `subPath`、Rolling Update、TLS／SNI、Forwarded Headers、Gateway API、Route Conditions、404／500／503 分層診斷，以及 NetworkPolicy Resource／Enforcement 差異。
