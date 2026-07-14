# Hour 5 Lab：Short-lived vs Keepalive Requests

本 Lab 比較 short-lived upstream connections 與 upstream keepalive connection reuse。

## 重要限制

這是本機行為觀察，不是 production benchmark。結果可用來理解 connection reuse，但不能代表 production latency、throughput 或容量。

## Expected Result

Backend 會回傳它看到的 Nginx source port：

```text
client_port=xxxxx
```

| Case | Expected |
|---|---|
| `/short` 連續 4 次 | 多個不同 upstream source ports |
| `/keepalive` 連續 4 次 | 重用同一個 upstream source port |

## Actual Result

```text
PASS short-lived requests used multiple upstream ports -> 50913 50915 50917 50919
PASS keepalive requests reused upstream port -> 50889 50889 50889 50889

Result: 2/2 keepalive behavior checks passed.
```

Source port 會依環境改變；重點是 `/short` 看到多個不同 ports，而 `/keepalive` 重用同一個 port。
