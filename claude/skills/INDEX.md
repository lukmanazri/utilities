# Skills Reference Index

Technique reference library for Hunter/Exploiter. Consult these before
declaring a vulnerability class exhausted (G2/G7) or when constructing
payloads (P4).

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
