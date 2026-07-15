# 特別章節：在 K3s／Kubernetes 部署 Nginx

這一章把前五天學到的 Nginx 知識放進 Kubernetes 環境。重點不是背 YAML，而是理解：哪些責任仍由 Nginx 負責，哪些責任已經交給 Kubernetes Service 與入口控制器。

實作過程與 Fault Log 會持續整理在[學習筆記](notes.md)。

## 學習目標

完成本章後，應能用自己的話說明：

- K3s 與 Kubernetes 的關係。
- Pod、Deployment、Service、Ingress 與 Ingress Controller 各自負責什麼。
- 為什麼 Nginx 不應直接使用 Pod IP 當 Upstream。
- 外部 Request 如何經過入口控制器、Service、Nginx 與 Backend。
- `proxy_pass http://backend;` 中的 `backend` 如何由 Kubernetes DNS 解析。
- 如何驗證設定，以及如何區分入口、Service、Pod 與 Nginx Upstream 故障。

## 本章名詞表

| 名詞 | 用途 | 常見故障現象 |
|---|---|---|
| K3s | 輕量、符合 Kubernetes 規範的發行版，預先整合常用元件。 | 節點或內建元件未正常啟動。 |
| Pod | Kubernetes 執行 Container 的最小單位。 | `Pending`、`CrashLoopBackOff`、`ImagePullBackOff`。 |
| Deployment | 管理 Pod 數量、版本更新與故障重建。 | Desired Replicas 與 Ready Replicas 不一致。 |
| Service | 為一組 Pod 提供穩定的虛擬 IP、DNS 名稱與流量分配。 | Service 沒有 Endpoints，Request 無法到 Pod。 |
| Ingress | 宣告 Host 與 Path 要轉送到哪個 Service。 | 規則存在，但沒有 Controller 時不會真的處理流量。 |
| Ingress Controller | 實際監看 Ingress 並接收、轉送外部流量的程式。K3s 預設使用 Traefik。 | 外部連不上，但 Service 在叢集內可以存取。 |
| Gateway API | 比 Ingress 更具表達力的新一代 Kubernetes 流量路由 API。 | 尚未安裝 CRD 或相容的 Gateway Controller。 |
| ConfigMap | 保存非機密設定，例如 Nginx Config。 | Config 掛載錯誤或更新後 Pod 尚未重建。 |
| Secret | 保存 TLS Private Key、憑證或密碼等機密資料。 | Secret 名稱、Namespace 或 Key 不正確。 |
| EndpointSlice | 記錄 Service 目前可轉送到哪些 Pod IP 與 Port。 | Slice 為空通常代表 Selector 或 Readiness 有問題。 |
| Readiness Probe | 判斷 Pod 是否準備好接收 Service 流量。 | Probe 失敗時 Pod 存活，但不會收到 Service 流量。 |

## 先建立正確的流量模型

本章使用以下架構：

```text
Client
  -> Node 的 80/443
  -> Traefik Ingress Controller
  -> web-nginx Service
  -> web-nginx Pod
  -> backend Service
  -> backend Pod
```

每一層的責任如下：

| 層級 | 責任 |
|---|---|
| Traefik | 接收叢集外流量，依 Host、Path 與 TLS 規則選擇 Service。 |
| `web-nginx` Service | 找到目前 Ready 的 Nginx Pods，並把流量送到其中一個。 |
| Nginx | 提供 SPA／Static Files，或執行應用層 Rewrite、Headers、Cache 與 Reverse Proxy。 |
| `backend` Service | 為 Backend Pods 提供穩定 DNS 與負載分配。 |
| Backend Pod | 真正處理 API 商業邏輯。 |

這裡可能有兩次負載分配：入口控制器選擇 Nginx Pod，`backend` Service 再選擇 Backend Pod。這不代表一定要保留中間的 Nginx；如果不需要 SPA、Cache 或特殊 Rewrite，也可以讓入口控制器直接把 `/api` 路由到 Backend Service。

## K3s 與一般 Kubernetes 的差異

兩者使用相同的 Deployment、Service 與 Ingress YAML。主要差異是安裝後有哪些元件可立即使用：

- K3s 預設包含 CoreDNS、Traefik、ServiceLB 與 Local Path Provisioner。
- 一般 Kubernetes 叢集不保證預先安裝 Ingress／Gateway Controller。
- 雲端 Kubernetes 通常會搭配雲端 Load Balancer 或平台提供的 Controller。
- K3s 預設 Traefik 的 LoadBalancer Service 會使用節點的 80、443 Port，因此不要再讓應用 Pod 使用相同的 `hostPort`。

本章使用標準 Ingress，方便先建立心智模型。新正式環境也應評估 Gateway API。Kubernetes 社群維護的 Ingress NGINX Controller 已在 2026 年 3 月退役，不應把它當成新環境的預設選擇；注意這不代表 `Ingress` API 本身已被移除，也不代表所有使用 Nginx 技術的商業 Controller 都相同。

## 最小可執行範例

以下 Manifest 建立：

1. 一個簡單的 Backend Deployment 與 Service。
2. 一個 Nginx ConfigMap。
3. 兩個 Nginx Pods 與其 Service。
4. 一條由 Traefik 處理的 Ingress 規則。

可直接使用本章提供的 [`labs/k3s-nginx-lab.yaml`](labs/k3s-nginx-lab.yaml)。其完整內容如下：

延伸的 502／504 對照實驗位於 [`labs/timeout-lab.yaml`](labs/timeout-lab.yaml)。

ConfigMap `subPath` 更新實驗使用 [`labs/configmap-reload/web-nginx-v2.conf`](labs/configmap-reload/web-nginx-v2.conf)。

Rolling Update 故障實驗使用 [`labs/invalid-rollout/invalid.conf`](labs/invalid-rollout/invalid.conf)，其中刻意保留 Syntax Error。

HTTPS 實驗使用 [`labs/tls/openssl-nginx-local.cnf`](labs/tls/openssl-nginx-local.cnf) 產生自簽憑證，並套用 [`labs/tls/tls-ingress.yaml`](labs/tls/tls-ingress.yaml)。Private Key 只建立在本機暫存目錄，不應提交到 Git。

Forwarded Headers 實驗使用 [`labs/forwarded-proto/web-nginx-debug.conf`](labs/forwarded-proto/web-nginx-debug.conf)，以 Response Headers 對照 Nginx `$scheme` 與可信入口傳入的 `X-Forwarded-Proto`。

Gateway API 實驗使用 [`labs/gateway-api/http-route.yaml`](labs/gateway-api/http-route.yaml)，先觀察跨 Namespace Route 被 `allowedRoutes: Same` 拒絕，再由 Helm 管理 Gateway Listener Policy。

Gateway API HTTPS 使用 [`labs/gateway-api/traefik-gateway-values.yaml`](labs/gateway-api/traefik-gateway-values.yaml) 管理 `web`／`websecure` Listeners，並以 [`labs/gateway-api/openssl-gateway-local.cnf`](labs/gateway-api/openssl-gateway-local.cnf) 產生只存於本機暫存目錄的測試憑證。

NetworkPolicy 實驗使用 [`labs/network-policy/allow-traefik-to-web-nginx.yaml`](labs/network-policy/allow-traefik-to-web-nginx.yaml)，限制只有 `traefik` Namespace 中帶有穩定 Traefik Label 的 Pods 能連入 `web-nginx:80`。

> 本次 OrbStack Kubernetes 實測可建立 NetworkPolicy Resource，但一般 Pod 在套用後仍能直接存取 `web-nginx`，表示目前這個叢集沒有對該 Policy 產生有效 Enforcement。此 Manifest 用來學習與帶到支援 NetworkPolicy 的 CNI 驗證，不能把「Apply 成功」當成安全控制已生效。

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-lab
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: nginx-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: hashicorp/http-echo:1.0
          args:
            - -listen=:8080
            - -text=hello from backend
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /
              port: http
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: nginx-lab
spec:
  selector:
    app: backend
  ports:
    - name: http
      port: 8080
      targetPort: http
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-nginx-config
  namespace: nginx-lab
data:
  default.conf: |
    upstream backend_upstream {
        server backend:8080;
        keepalive 32;
    }

    server {
        listen 80;
        server_name _;

        location = /healthz {
            access_log off;
            return 200 "ok\n";
        }

        location / {
            return 200 "hello from nginx\n";
        }

        location /api/ {
            proxy_pass http://backend_upstream/;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            proxy_connect_timeout 3s;
            proxy_read_timeout 30s;
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-nginx
  namespace: nginx-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-nginx
  template:
    metadata:
      labels:
        app: web-nginx
    spec:
      containers:
        - name: nginx
          image: nginx:stable-alpine
          ports:
            - name: http
              containerPort: 80
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
          resources:
            requests:
              cpu: 25m
              memory: 32Mi
            limits:
              cpu: 250m
              memory: 128Mi
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
              readOnly: true
      volumes:
        - name: nginx-config
          configMap:
            name: web-nginx-config
---
apiVersion: v1
kind: Service
metadata:
  name: web-nginx
  namespace: nginx-lab
spec:
  selector:
    app: web-nginx
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-nginx
  namespace: nginx-lab
spec:
  ingressClassName: traefik
  rules:
    - host: nginx.local.test
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-nginx
                port:
                  number: 80
```

### 為什麼 Upstream 寫 Service 名稱

Config 中使用：

```nginx
upstream backend_upstream {
    server backend:8080;
}
```

因為 Nginx Pod 與 `backend` Service 位於相同 Namespace，CoreDNS 可以把 `backend` 解析成 Service 的 Cluster IP。不要把 Pod IP 寫死在 Config；Pod 被重建或重新排程後，IP 可能改變。

跨 Namespace 時，應使用例如：

```nginx
server backend.production.svc.cluster.local:8080;
```

### 再確認一次 URI 轉換

目前設定為：

```nginx
location /api/ {
    proxy_pass http://backend_upstream/;
}
```

因此 `/api/users` 傳到 Backend 時會變成 `/users`。若 Backend 預期收到完整的 `/api/users`，移除 `proxy_pass` 最後的 `/`：

```nginx
proxy_pass http://backend_upstream;
```

## 部署與驗證

### 1. 確認叢集與入口控制器

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl get ingressclass
```

K3s 預設應可看到 Traefik。一般 Kubernetes 若沒有 Ingress Controller，即使成功建立 Ingress，也不會有人實際接收流量。

### 2. 套用 Manifest

```bash
kubectl apply -f k3s-nginx-lab.yaml
kubectl rollout status deployment/backend -n nginx-lab
kubectl rollout status deployment/web-nginx -n nginx-lab
```

### 3. 檢查每一層

```bash
kubectl get pods,services,ingress -n nginx-lab
kubectl get endpointslices -n nginx-lab
kubectl describe ingress web-nginx -n nginx-lab
```

Service 的 EndpointSlice 不應為空。如果為空，先檢查 Service Selector 是否匹配 Pod Label，以及 Readiness Probe 是否通過。

### 4. 從叢集內測試 Service

```bash
kubectl run curl-test \
  --rm -it \
  --restart=Never \
  -n nginx-lab \
  --image=curlimages/curl \
  -- http://web-nginx/
```

測試 Nginx 到 Backend 的完整路徑：

```bash
kubectl run curl-test \
  --rm -it \
  --restart=Never \
  -n nginx-lab \
  --image=curlimages/curl \
  -- http://web-nginx/api/
```

預期分別看到：

```text
hello from nginx
hello from backend
```

### 5. 從叢集外測試 Ingress

取得節點 IP：

```bash
kubectl get nodes -o wide
```

尚未設定 DNS 時，以 Host Header 測試：

```bash
curl -i -H 'Host: nginx.local.test' http://<node-ip>/
curl -i -H 'Host: nginx.local.test' http://<node-ip>/api/
```

`<node-ip>` 要替換成實際節點 IP，不要連尖括號一起輸入。

## ConfigMap 更新與 Reload

一般 ConfigMap Volume 的投影內容最終會更新，但應用程式仍要重新讀取設定。本 Lab 進一步使用 `subPath`，只把 `default.conf` 掛到指定檔案；Kubernetes 官方明確說明，使用 ConfigMap `subPath` 的 Container 不會收到 ConfigMap 更新。因此更新 ConfigMap 後必須建立新 Pod，不能只在舊 Pod 執行 Nginx Reload。

學習環境最簡單、可預測的做法是更新 ConfigMap 後重新啟動 Deployment：

```bash
kubectl apply -f k3s-nginx-lab.yaml
kubectl rollout restart deployment/web-nginx -n nginx-lab
kubectl rollout status deployment/web-nginx -n nginx-lab
```

驗證 Runtime Config：

```bash
kubectl exec -n nginx-lab deployment/web-nginx -- nginx -t
kubectl exec -n nginx-lab deployment/web-nginx -- nginx -T
```

如果不使用 `subPath`、而是掛載整個 ConfigMap Volume，檔案內容可能在 Kubelet 同步後更新；但 Nginx仍不會自動 Reload。正式環境可以設計自動 Reload Sidecar、以 Config Hash 觸發 Rollout，或使用會監控設定的 Controller，但必須確保先驗證 Config，避免把錯誤設定同時載入所有 Pods。

## HTTPS 放在哪一層

常見做法是在 Traefik／Gateway 終止 TLS，叢集內再以 HTTP 連到 `web-nginx` Service：

```text
Client -- HTTPS --> Traefik -- HTTP --> web-nginx
```

建立 TLS Secret：

```bash
kubectl create secret tls nginx-local-tls \
  --cert=fullchain.pem \
  --key=privkey.pem \
  -n nginx-lab
```

Ingress 加入：

```yaml
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - nginx.local.test
      secretName: nginx-local-tls
```

因為 TLS 已在入口層終止，Nginx 收到的連線可能是 HTTP，所以範例使用入口控制器帶入的 `X-Forwarded-Proto`：

```nginx
proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
```

正式環境通常搭配 cert-manager 自動申請與更新憑證。若法規或 Trust Boundary 要求叢集內也加密，才需要進一步設計 Re-encryption 或 mTLS。

## 分層故障診斷

不要一看到 502 就直接修改 Nginx。先找出 Request 卡在哪一層：

| 現象 | 優先檢查 | 常用指令 |
|---|---|---|
| Domain 無法解析 | 外部 DNS | `dig nginx.local.test` |
| Node 的 80/443 無法連線 | Firewall、ServiceLB、入口 Controller | `kubectl get service -n kube-system` |
| Ingress 回 404 | Host／Path 規則、Ingress Class | `kubectl describe ingress -n nginx-lab` |
| Ingress 回 502/503 | `web-nginx` Service、Endpoints、Readiness | `kubectl get endpointslices -n nginx-lab` |
| Nginx `/` 正常但 `/api/` 為 502 | Backend Service 名稱、Port、Endpoints | `kubectl logs -n nginx-lab deployment/web-nginx` |
| `/api/` 為 504 | Backend 太慢或 `proxy_read_timeout` 太短 | Nginx Log 與 Backend Log |
| Pod 不斷重啟 | Config Syntax、Probe、資源限制 | `kubectl describe pod`、`kubectl logs --previous` |
| ConfigMap 已更新但行為沒變 | Nginx 尚未 Reload／Pod 尚未重建 | `nginx -T`、`kubectl rollout restart` |

建議按照以下順序縮小問題：

```text
DNS
  -> Node 80/443
  -> Ingress Controller
  -> Ingress Rule
  -> web-nginx Service / EndpointSlice
  -> Nginx Pod
  -> backend Service / EndpointSlice
  -> Backend Pod
```

## Ingress 與 Nginx 不要重複設定所有責任

如果 Traefik 已經負責 Host、TLS 與外部 Path Routing，Nginx 不一定還需要再做一次相同判斷。保留 Nginx 的合理情境包括：

- 提供 SPA 與 Static Files。
- 需要 Nginx 特有的 URI Rewrite。
- 需要應用層 Cache、Buffering 或 Compression 策略。
- 需要與既有 Nginx Config 維持一致。
- 需要在應用前建立明確的 Reverse Proxy 邊界。

可以移除中間 Nginx 的情境包括：

- 入口控制器可直接把 `/api` 送到 Backend Service。
- 沒有 Static Files、Cache 或特殊 Rewrite。
- 多一層 Proxy 只會增加設定、Logs 與故障點。

設計前先問：「這一層解決的是哪個問題？」不要只因為過去使用 Nginx，就在 Kubernetes 裡固定加入一層 Nginx。

## 清理 Lab

本章所有資源都放在 `nginx-lab` Namespace，可以一次清除：

```bash
kubectl delete namespace nginx-lab
```

刪除前先確認 Namespace 內沒有其他需要保留的資源。

## 章節驗收

完成實驗後，嘗試不用看答案回答：

1. 為什麼 Nginx Upstream 應使用 `backend:8080`，而不是 Pod IP？
2. Ingress 已建立，但叢集沒有 Ingress Controller，會發生什麼事？
3. Service 存在但 EndpointSlice 為空，最可能是哪兩類問題？
4. `/` 正常但 `/api/` 回 502，問題比較可能在哪一段？
5. `proxy_pass http://backend_upstream/;` 與沒有尾端 `/` 的 URI 行為差在哪裡？
6. ConfigMap 更新後，為什麼 Nginx 行為可能沒有立刻改變？
7. 哪些情況下可以讓入口控制器直接連 Backend，移除中間的 Nginx？

驗收標準不是背出 YAML，而是能沿著完整 Request Path 找到每一層的責任與證據。

## 延伸閱讀

- [K3s Networking Services](https://docs.k3s.io/networking/networking-services)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Kubernetes Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/)
- [Ingress NGINX Retirement](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/)
