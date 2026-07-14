# Hour 7：完整 Config Attack Review

Review target：[flawed-nginx.conf](flawed-nginx.conf)

Checklist：[Nginx Config Review Checklist](../../../../docs/nginx-review-checklist.md)

## Findings

### F1：Undefined Upstream

- Category：Confirmed Defect
- Evidence：`location /api/` uses `proxy_pass http://backend/v1/;` but no `upstream backend` is defined in this config, and no resolver strategy is shown.
- Impact：`nginx -t` may fail with an unresolved upstream host, or runtime proxying may fail depending on environment.
- Minimal Fix：Define `upstream backend { ... }`, use a resolvable DNS name with an intentional `resolver`, or replace with the correct upstream host.
- Verification Method：Run `nginx -t`; request `/api/...`; confirm expected `$upstream_addr`, `$upstream_status`, and backend response.
- Needed Context：Whether `backend` is resolvable by container DNS or injected by include files not shown.

### F2：Sensitive Data in Access Logs

- Category：Confirmed Defect
- Evidence：`log_format risky` records `$http_authorization`, `$http_cookie`, and `$request_uri`.
- Impact：Authorization tokens, session cookies, and sensitive query strings may be written to long-lived logs and external log systems.
- Minimal Fix：Remove Authorization and Cookie from access logs; prefer `$uri` over `$request_uri`; add query masking if query diagnostics are required.
- Verification Method：Send a request with `Authorization`, `Cookie`, and `?token=secret`; confirm logs do not contain those sensitive values.

### F3：Redirect Uses Untrusted Host

- Category：Contextual Risk
- Evidence：default HTTP server uses `return 301 https://$host$request_uri;`.
- Impact：If this Nginx is public-facing and Host is not sanitized upstream, a malicious Host header may influence the `Location` response.
- Minimal Fix：Redirect to a canonical domain such as `https://faceid.example.com$request_uri`; handle unknown hosts explicitly.
- Verification Method：`curl -I -H 'Host: evil.example' http://.../` and confirm `Location` does not point to attacker-controlled host.
- Needed Context：Whether an LB/WAF/Ingress already enforces allowed hosts.

### F4：Unknown HTTPS Host Falls into Production Default Server

- Category：Contextual Risk
- Evidence：`listen 443 ssl default_server;` is on the production `faceid.example.com` server block.
- Impact：Unknown SNI/Host may receive the production certificate/server behavior instead of an explicit reject/default response.
- Minimal Fix：Create an explicit HTTPS default server for unknown hosts with a safe certificate and reject/404 behavior; keep canonical domain in its own server block.
- Verification Method：Use `curl --resolve unknown.example.com:443:IP https://unknown.example.com/` and inspect certificate/result; use `-k` only to inspect HTTP fallback behavior.
- Needed Context：Actual TLS certificate SANs, LB behavior, and desired unknown-host policy.

### F5：Aggressive HSTS with includeSubDomains and preload

- Category：Contextual Risk
- Evidence：`Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`.
- Impact：Browsers may enforce HTTPS for the domain and all subdomains for a long time; preload can make rollback difficult if any subdomain is not HTTPS-ready.
- Minimal Fix：Start with a short `max-age`; add `includeSubDomains` only after all subdomains are verified; use preload only after explicit readiness review.
- Verification Method：Inventory subdomains and HTTPS certificates; test HTTP->HTTPS behavior; confirm preload requirements before enabling preload.
- Needed Context：Subdomain inventory and HTTPS readiness.

### F6：No Security Header Compatibility Plan

- Category：Hardening Opportunity / Need Context
- Evidence：No CSP, Referrer-Policy, Permissions-Policy, `X-Content-Type-Options`, or frame protection is shown.
- Impact：If this server serves HTML, browser-side protections may be missing. If it is pure API, some headers may be less relevant.
- Minimal Fix：Identify whether HTML is served; if yes, design CSP/report-only rollout and add low-risk headers with compatibility checks.
- Verification Method：Fetch representative HTML/API responses and inspect headers; use browser console/report-only telemetry for CSP.
- Needed Context：Whether this server serves SPA HTML, pure API, or both.

### F7：X-Forwarded-For Trust Boundary Not Explicit

- Category：Contextual Risk
- Evidence：`proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` appends any incoming XFF.
- Impact：If Nginx is edge-facing, clients can spoof the leftmost XFF value.
- Minimal Fix：At the edge, overwrite XFF with `$remote_addr`; behind trusted proxies, configure real IP handling and document trusted ranges.
- Verification Method：Send a request with forged `X-Forwarded-For`; confirm backend receives only trusted chain semantics.
- Needed Context：Whether Nginx is edge-facing or behind trusted LB/Ingress.

## Review Summary

This config contains multiple confirmed defects or high-priority risks around upstream resolution, sensitive logs, untrusted Host redirects, default server behavior, HSTS rollout, security headers, and forwarded header trust boundaries.

The key practice is not to list suspicious lines only. Every finding should include evidence and a verification method so the team can confirm the problem, implement the smallest safe fix, and prove the fix worked.
