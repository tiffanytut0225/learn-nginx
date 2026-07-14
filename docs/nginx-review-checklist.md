# Nginx Config Review Checklist

Use this checklist for unfamiliar Nginx configs. Every finding should include evidence and a verification method.

## Finding Categories

| Category | Meaning |
|---|---|
| Confirmed Defect | Evidence shows the config is wrong or unsafe in the current known context. |
| Contextual Risk | Risk depends on deployment topology, traffic source, trust boundary, or product requirements. |
| Hardening Opportunity | Not necessarily broken, but can improve safety, stability, observability, or maintainability. |
| Need Context | Missing information prevents a reliable judgment. |

## Required Finding Fields

- Category
- Evidence
- Impact
- Minimal Fix / Recommendation
- Verification Method
- Needed Context, if any

## Review Areas

### Config Validity

- Does `nginx -t` pass?
- Are all referenced upstreams, files, certificates, and includes present?
- Are directives in valid contexts?

### Server / Host / Redirect

- Is `default_server` explicit?
- Are unknown hosts handled intentionally?
- Are redirects built from canonical domains rather than untrusted `$host`?
- Are HTTP and HTTPS server blocks consistent?

### TLS / Certificate

- Does `ssl_certificate` use fullchain in production?
- Does the certificate match the expected domain/IP cases?
- Are TLS protocol and cipher policies maintained by org baseline?
- Is HSTS introduced gradually and safely?

### Location / URI / Filesystem

- Are regex and prefix locations ordered intentionally?
- Are `root` and `alias` path transformations correct?
- Are missing static assets prevented from falling back to SPA HTML?

### Reverse Proxy / Upstream

- Is `proxy_pass` URI behavior intentional?
- Are `Host`, `X-Forwarded-For`, `X-Forwarded-Proto`, and trust boundaries explicit?
- Are timeouts set deliberately?
- Is non-idempotent retry avoided unless explicitly safe?

### Security Headers

- Is CSP appropriate for served content?
- Are `nosniff`, Referrer-Policy, Permissions-Policy, and frame protection considered?
- Are compatibility costs documented?

### Limits / Abuse Protection

- Are body size, request rate, connection limits, and timeouts defined where needed?
- Are status codes meaningful for clients, such as 413 and 429?

### Observability

- Does log format include request ID, host, status, upstream address/status/timing?
- Does it avoid Authorization, Cookie, token query strings, and sensitive data?
- Can Nginx logs be correlated with backend logs?

### Operations

- Is there a safe change process: `nginx -t`, reload, response check, rollback?
- Is the rollback config tested before reload?
