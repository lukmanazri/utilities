# Source Code Bug Hunting - Quick Reference Notes

## Core Methodology

1. **Clone & Recon** (20 min) - clone repos, check git log for security fixes, map tech stack
2. **Auth Surface Map** (30 min) - find all routes, map auth coverage, find gaps
3. **Taint Analysis** (1-2h) - trace user input from source to sink, check for sanitizers
4. **Clustering** (30 min) - when finding one bug, hunt siblings in same module
5. **Verify & PoC** - source finding MUST be confirmed with live exploit

## Top Paying Bug Classes in Source Review

| Bug Class | grep Keywords | Avg Payout |
|-----------|--------------|------------|
| Deserialization (C#) | `BinaryFormatter`, `LosFormatter`, `Deserialize` | $5K-$25K |
| SQL Injection | `SqlCommand.*+`, `ExecuteSqlRaw.*+`, `FromSqlRaw` | $2K-$10K |
| SSRF | `HttpClient.Get.*Query`, `WebClient.Download` | $1K-$5K |
| Auth Bypass | `[AllowAnonymous]`, missing `[Authorize]` | $1K-$5K |
| IDOR | Route params without per-object auth check | $500-$3K |
| Mass Assignment | `TryUpdateModel`, missing `[Bind]` | $500-$2K |
| XSS | `Html.Raw`, `MvcHtmlString.Create` | $250-$1.5K |

## High-Signal Patterns (Investigate Always)

- User input flowing into `Process.Start()`, `Assembly.Load()`, `eval()`
- String concatenation in SQL queries (any language)
- `[AllowAnonymous]` on admin/destructive endpoints
- Deserialization without a type binder
- `__VIEWSTATEENCRYPTED=""` in ASP.NET forms
- `trace.axd` or `elmah.axd` reachable
- Secret / key / password in committed config files
- `TODO` / `FIXME` / `not verified` comments near auth code
- V1 API having no auth when V2 does

## Low-Signal Patterns (Kill Immediately)

- Dead code (unreachable from any route)
- `eval()` only in test files
- Deprecated endpoints with 404 in production
- Feature-flag-guarded code where flag is `false`
- Dummy credentials that don't authenticate to anything real
- `.unwrap()` on serialization (not deserialization) paths

## C# Specific Quick Wins

```bash
# 1. Find deserialization sinks
grep -rn "\.Deserialize(" --include="*.cs" | grep "BinaryFormatter\|LosFormatter\|ObjectStateFormatter\|SoapFormatter"

# 2. Find SQL injection
grep -rn "ExecuteSqlRaw\|FromSqlRaw\|new SqlCommand(.*\+" --include="*.cs"

# 3. Find missing auth
grep -rn "class.*Controller" --include="*.cs" | while read line; do
  file=$(echo "$line" | cut -d: -f1)
  if ! grep -q "\[Authorize\]" "$file" 2>/dev/null; then
    echo "NO AUTH: $line"
  fi
done

# 4. Find machineKey in config
grep -rn "machineKey\|validationKey\|decryptionKey" --include="*.config" --include="web.config"

# 5. Find hardcoded secrets
grep -rn "Password\s*=\s*\"\|ApiKey\s*=\s*\"\|Secret\s*=\s*\"" --include="*.cs" --include="*.json" | grep -v "test\|mock\|fake"
```

## Top .NET CVEs to Pattern-Match

| CVE | Year | Pattern | Impact |
|-----|------|---------|--------|
| CVE-2017-11317 | 2017 | Telerik RadAsyncUpload | RCE |
| CVE-2019-18935 | 2019 | Telerik deserialization | RCE |
| CVE-2020-0688 | 2020 | Exchange ECP ViewState | RCE |
| CVE-2021-42237 | 2021 | Sitecore deserialization | RCE |
| CVE-2022-41082 | 2022 | Exchange OWASSRF | RCE |
| CVE-2023-33170 | 2023 | ASP.NET Core XSS (signalr) | XSS |
| CVE-2024-29059 | 2024 | .NET Framework info disclosure | Info |

## Session Discipline

- Track findings in: `C:\claudy\findings.md`
- Dead ends: `C:\claudy\dead-ends.md`
- Anomalies: `C:\claudy\anomalies.md`
- PoC scripts: `C:\claudy\poc\`

## When to Escalate to Live Testing

- Source shows vulnerable pattern -> find the endpoint -> craft curl -> test live
- If endpoint returns 200 -> escalate, document, report
- If 404/403 -> check API version, staging, mobile app
- If firewall/WAF blocks -> try bypass techniques from security-arsenal
