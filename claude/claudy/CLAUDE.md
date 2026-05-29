# CLAUDE.md -- Source Code Bug Hunting Orchestrator

## INSTRUCTIONS

1. **Output directory**: Everything you create goes into `Claudy/` — findings, summaries, notes, auth-maps.
2. **PoC directory**: All Python PoC scripts go into `Poc/` at the project root (e.g., `C:\claudy\Poc\`).
3. **PoC language**: All proof-of-concept scripts MUST be written in **Python 3**.
4. **Language references**: Before auditing a specific language, read the corresponding file in `References/` (e.g., `References/CSharp-Source-Review.md` for C#).
5. **Taint analysis**: Read `References/Taint-Analysis.md` and apply source-to-sink tracking on every code path.
6. **Findings format**: Write each confirmed bug to `Claudy/findings.md` with structure: Title, Severity, Source Location, Taint Path, PoC reference, Impact.
7. **Dead ends**: Track in `Claudy/dead-ends.md` — file:line + reason killed.
8. **Do NOT spawn more than 2 agents at once.**
9. **git clone targets into the project root** — e.g., `git clone https://github.com/craftcms/cms.git` directly into `C:\claudy\craftcms\`.
10. **CRITICAL: NEVER modify the cloned codebase.** This is a READ-ONLY audit. Do not edit, patch, format, lint, or alter any file inside the cloned repo. Use grep, semgrep, read-only static analysis only.

---

## THE ONLY QUESTION THAT MATTERS

> **"Can an attacker do this RIGHT NOW against a real user who has taken NO unusual actions -- and does it cause real harm?"**

If NO -- STOP. Move on.

---

## Quick Start: Clone & Audit (READ-ONLY)

```bash
# Clone target repos into project root (DO NOT modify cloned files!)
git clone https://github.com/craftcms/cms.git  # e.g. -> C:\claudy\craftcms\
#                    OR
git clone https://github.com/TARGET/REPO        # -> C:\claudy\REPO\

cd REPO  # enter the cloned repo

# Security changelog recon
cat SECURITY.md CHANGELOG.md 2>/dev/null | head -200 | grep -i "security\|fix\|CVE\|patch\|vuln"

# Commit history for security fixes (READ THE DIFFS)
git log --oneline --all --grep="security\|CVE\|fix\|vuln\|patch\|auth" | head -30

# Semgrep quick scan (multi-language) — output goes to Claudy/, repo untouched
semgrep --config=p/security-audit . --json -o ../Claudy/semgrep-scan.json 2>/dev/null
semgrep --config=p/owasp-top-ten . --json -o ../Claudy/semgrep-owasp.json 2>/dev/null

# Output critical findings only
cat ../Claudy/semgrep-scan.json | jq '.results[] | select(.extra.severity == "ERROR") | {file:.path, line:.start.line, check:.check_id, msg:.extra.message}'
```

---

## Audit Methodology (4 Phases)

### Phase 1: Recon (20 min)
1. `git clone` the target repo into the project root (NOT into a subdirectory). Example: `git clone https://github.com/craftcms/cms.git` → `craftcms/`
2. `git log --oneline --all --grep="security\|CVE\|fix\|vuln" | head -30` — read the diffs
3. Read `SECURITY.md`, `CHANGELOG.md` for prior vulns
4. Map the tech stack (language, framework, ORM, auth library, caching)
5. **Identify language → read the matching `References/*.md` file**
6. **REMINDER: Do not modify any source files in the cloned repo.**

### Phase 2: Auth Surface Mapping (30 min)
1. Find all route/controller definitions. Map which have auth middleware.
2. Find role/permission checks. Consistent across API versions?
3. Find session/cookie/JWT handling. How are tokens validated?
4. Build a table: endpoint → auth requirement → actual check
5. **Write auth gaps to `Claudy/auth-map.md`**

### Phase 3: Taint Analysis Deep-Dive (1-2 hours)
1. **Read `References/Taint-Analysis.md`**
2. Map all sources (request inputs) and sinks (dangerous operations)
3. Trace each source → sink path, check for sanitizers
4. Focus ONE bug class at a time (auth bypass, IDOR, SSRF, SQLi, deserialization)
5. **Write confirmed findings to `Claudy/findings.md`**

### Phase 4: Clustering (30 min)
When you find one bug, hunt its siblings:
1. Map the module — what other endpoints in the same controller/service?
2. Same bug, different methods — GET blocked? Try PUT/PATCH/DELETE
3. Analogous code — if `verify_signed_vote()` is broken, check `verify_signed_proposal()`
4. Chain forward — Bug A + sibling bug B = higher severity

---

## CVE-Seeded Audit (Highest ROI)

```bash
# Find historical security commits and read their diffs
git log --oneline --all --grep="CVE" | head -20
git show <commit>

# Search current codebase for the SAME anti-pattern
grep -rn "the-buggy-pattern" --include="*.py" --include="*.js" --include="*.cs" .
```

---

## High-Level Grep by Bug Class (Language-Agnostic)

```
Auth Bypass    : grep for route definitions WITHOUT auth decorators
SQL Injection  : grep for string concat/interpolation in query builders
SSRF           : grep for HTTP clients taking request params as URL
Deserialization: grep for Deserialize(), unserialize(), pickle.loads()
XXE            : grep for XML parsers without DTD/schema hardening
XSS            : grep for raw HTML output functions
Path Traversal : grep for file read/open with user-controlled path
Command Inj.   : grep for shell exec with user-controlled input
Mass Assignment: grep for model binding without field whitelist
Race Condition : grep for check-then-act patterns without transactions
```

---

## Reference Files (Load On-Demand Per Language)

| Language | Reference File |
|----------|---------------|
| C# / .NET | `References/CSharp-Source-Review.md` |
| Python | `References/Python-Source-Review.md` |
| JavaScript / TypeScript | `References/JavaScript-Source-Review.md` |
| PHP | `References/PHP-Source-Review.md` |
| Go | `References/Go-Source-Review.md` |
| Ruby | `References/Ruby-Source-Review.md` |
| Rust | `References/Rust-Source-Review.md` |
| Taint Analysis | `References/Taint-Analysis.md` |
| Quick Notes | `References/Notes.md` |

---

## Finding Output Template (in Claudy/findings.md)

```markdown
## [Severity] Title — Target/Repo

**Source**: `path/to/file.cs:42`
**Bug Class**: SQL Injection
**Taint Path**:
  Request.Query["userId"]
    -> UserController.GetUser(string userId)
      -> UserRepository.FindById(userId)
        -> SqlCommand("SELECT * FROM Users WHERE Id=" + userId) [SINK — NO SANITIZER]

**PoC**: [Poc/sqli_exploit.py](Poc/sqli_exploit.py)

**Impact**: Unauthenticated attacker can extract all user PII (names, emails, passwords)
**CVSS**: 9.1 Critical
```

---

## Signal-to-Noise Discipline

**Kill immediately**: Dead/unreachable code, test-only code, feature-flagged-off code, dummy credentials
**Investigate deeper**: Raw SQL reachable from endpoint, user input → Process.Start/exec/eval without sanitizer, inconsistent auth across API versions, TODO/FIXME near auth code

## 10-Minute Rules

- 10 min per file with no signal → move on
- 1 hour per bug class with no finding → switch classes
- 3 hours per repo with no finding → switch target

## Golden Rule

**Source finding WITHOUT a live Python PoC = informational at best.** Always verify with a reachable endpoint and a working exploit script in `Poc/`.
