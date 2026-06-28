# Skills Reference Index

Technique reference library + callable SERVICES for the pipeline. Consult the reference
sections before declaring a vulnerability class exhausted (G2/G7) or when constructing
payloads (P4).

> **Path convention:** skills are copied into each engagement dir at launch, so all stages
> reference them ENGAGEMENT-RELATIVE as `skills/...` (never `~/research/.claude/skills/...`,
> which is the template, not the running copy).
>
> **patt-fetcher and script-generator are SERVICES** (re-entrant, bounded, callable from inside
> a stage — not pipeline stages). See CLAUDE.md § services. patt-fetcher runs on Haiku;
> script-generator on Sonnet.
>
> **Chaining scope decision (WP-14):** this library is APPLICATION-LAYER. There is no `system/`
> (OS privesc / pivot) or `web-app-logic/` tree vendored here. The Chain Strategist (Step 5.5)
> is therefore scoped to app-layer chains; a chain needing an OS-level/pivot primitive is
> recorded as a Researcher Action, not invented. If those trees are later vendored, widen the
> Strategist's scope and add them below.

## reference/access-control/
IDOR (read + action), mass assignment, multi-step bypass, parameter-based
controls, referer/header/method bypass, unprotected functionality,
data-leakage redirects.

## reference/race-conditions/
TOCTOU, single/multi-endpoint collisions, limit overrun, rate-limit bypass,
file-upload races, container-startup admin registration, timestamp collisions.

## reference/ssrf/
Blind detection + portscan, cloud metadata, localhost/IP bypass, gopher
protocol exploitation, proxy path traversal, stored-connector deferred SSRF,
URL parser/allowlist bypass, UTF-8 binary loss limits.

## reference/deserialization/
Per-language gadget chain patterns: Java, .NET, Node.js, PHP, Python/Ruby,
React Server Components Flight protocol.

## reference/jwt/
Algorithm confusion, none-alg, kid path traversal, jku/jwk/x5u/x5c injection,
JWE nested tokens, claim tampering, signature stripping, weak secret cracking,
ECDSA nonce reuse, CVE-2022-21449 (psychic signatures).

## reference/oauth/
Redirect URI manipulation, CSRF state, PKCE downgrade, implicit flow attacks,
scope escalation, code theft via postMessage, SSRF via client registration.

## reference/api-bola/
OWASP BOLA/BOPLA patterns, mass assignment via API, HTTP method enumeration.

## reference/source-scanning/
SAST tooling, dependency CVE scanning, secrets detection, malicious-code
patterns, language-specific review patterns, manual review guidance —
cross-reference for opengrep gaps.

## patt-fetcher/
Fetch PayloadsAllTheThings sections live by category (SQLi, SSTI, SSRF,
deserialization, etc). Use when constructing payloads (P4) and you want
variant coverage beyond what's derived from traffic. Source code informs
WHAT; traffic informs HOW; PATT informs WHAT VARIANTS EXIST.

## script-generator/
Generates and syntax-validates (never executes) supporting PoC tooling —
multi-target scanners, OOB listeners, concurrent setup scripts. Use when
exploit.py/setup.py would exceed ~30 lines or need concurrency.

## reference/path-traversal/
Traversal payloads and encoding tricks, filter bypass techniques, LFI→RCE
chains (log poisoning, session file inclusion, PHP wrappers), Jupyter
nbconvert LFI→RCE, platform-specific quirks, common target files.

## reference/file-upload/
Extension and content-type bypass, magic-byte/polyglot files, web-shell
payloads, upload race conditions — primary RCE vector via arbitrary file write.

## reference/code-injection/
Direct code-execution via language eval/exec — Python eval/format-string,
PHP preg_replace /e modifier, bash symbolic-only command construction.

## reference/ssti/
Server-side template injection — engine detection, bypass techniques,
quote-free/double-render bypass. SSTI is one of the most direct RCE paths
in templated frameworks (Jinja2, Django templates, etc).

## reference/nosql-rce/
MongoDB $where JS-injection (RCE via eval-equivalent), Redis SSRF-to-RCE
via gopher protocol.
