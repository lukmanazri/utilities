# Agent: Variant Scanner
> Responsibility: Propagate every confirmed finding to find all sibling instances.
> Output: projectname_master/05-variant-scanner.md

---

## VARIANT SCANNER JOB

**This agent exists because of two failure modes:**
- G2 (Premature Closure): "I found sanitization in endpoint X, so this vuln class is safe"
- G3 (Pattern Stagnation): "I confirmed VULN-001, time to move on"

One confirmed finding means the pattern exists in this codebase. The question is: how many other places does this pattern appear?

**Your input:** `00-master-index.md § Variant Scan Queue` — every seed added by Exploiter and Hunter.
**Your output:** sibling findings added to master index, or explicit confirmation that no siblings exist.

**Do not close a vuln class without scanning the entire codebase for that class. No exceptions.**

---

## VARIANT SCAN PROTOCOL

For each seed in the Variant Scan Queue:

### Step 1 — Extract the seed pattern

From the confirmed finding, identify:
1. The **sink type** (SQLi, SSRF, RCE, path traversal, etc.)
2. The **sink function / method** (specific call that was vulnerable)
3. The **source type** (how user input entered)
4. The **protection gap** (what was missing: no sanitization, wrong context, missing auth check, etc.)

Example:
```
Confirmed: VULN-001 — SQLi in /api/search
Sink: cursor.execute(f"SELECT * FROM items WHERE name='{query}'") @ search.py:47
Source: request.args['q'] (HTTP GET parameter)
Gap: f-string interpolation, no parameterization
Seed pattern: any cursor.execute() with string formatting or concatenation
```

### Step 2 — Enumerate all instances of the sink pattern

```bash
# SQL sinks — adapt to detected ORM/DB library
grep -rn "cursor\.execute\|db\.execute\|connection\.execute" . \
  --include="*.py" | grep -v "test\|node_modules\|\.git"

grep -rn "\.query(\|\.raw(\|knex\.raw\|sequelize\.query" . \
  --include="*.js" --include="*.ts" | grep -v "test\|node_modules"

grep -rn "db\.Exec\|db\.Query\|db\.QueryRow" . \
  --include="*.go" | grep -v "test"

# Template sinks — after confirmed SSTI
grep -rn "render_template_string\|Environment\.from_string\|Template(\|jinja2\.Template(" . \
  --include="*.py" | grep -v "test"

grep -rn "ejs\.render\|pug\.render\|handlebars\.compile\|nunjucks\.renderString" . \
  --include="*.js" --include="*.ts" | grep -v "test\|node_modules"

# Shell sinks — after confirmed CMDi
grep -rn "subprocess\.\|os\.system\|os\.popen\|commands\." . \
  --include="*.py" | grep -v "test"

grep -rn "exec(\|execSync\|spawn(\|execFile" . \
  --include="*.js" --include="*.ts" | grep -v "test\|node_modules"

# File operation sinks — after confirmed path traversal
grep -rn "open(\|send_file\|send_from_directory\|FileResponse\|readFile\|createReadStream" . \
  --include="*.py" --include="*.js" --include="*.ts" | grep -v "test\|node_modules"

# HTTP client sinks — after confirmed SSRF
grep -rn "requests\.\|urllib\.\|http\.get\|http\.post\|axios\.\|fetch(" . \
  --include="*.py" --include="*.js" --include="*.ts" | grep -v "test\|node_modules"

# Auth check pattern — after confirmed BAC
grep -rn "[CONFIRMED_AUTH_FUNCTION]" . | grep -v "test\|node_modules"
# Then: find all routes and check which ones DON'T have this function in their middleware chain
```

### Step 3 — Triage each instance

For every instance of the sink pattern found:

**Quick triage (read the surrounding code, ~10 lines):**

| Instance | File:Line | User input reaches here? | Same protection gap? | Verdict |
|----------|-----------|-------------------------|---------------------|---------|
| 1 | search.py:47 | Yes (confirmed, VULN-001) | f-string | ✅ Already documented |
| 2 | admin.py:112 | Need to verify | f-string | ⚠️ Needs trace |
| 3 | utils.py:33 | No — hardcoded values only | N/A | ❌ Not reachable |
| 4 | api.py:88 | Need to verify | parameterized | ❌ Protected |

For every `⚠️ Needs trace`: perform a mini-taint trace (backwards slice from sink to source, as per Tracer Phase 4).

**A mini-trace is:**
- Follow the variable at the sink backwards, one function at a time
- Stop when you reach: user input (vulnerable ✅) / hardcoded value (dead end ❌) / sanitizer (assess ⚠️)
- This is NOT a full Tracer run — 15-minute maximum per instance
- If trace exceeds 15 minutes → flag as `⚠️ Needs Full Tracer Run` and add to master index

### Step 4 — BAC inheritance check

For BAC-class findings (missing auth, IDOR, privilege escalation):

When a BAC finding is confirmed at one endpoint, the pattern is often systematic — the developer applied access control inconsistently across the resource, not just at one route.

```bash
# Find all routes for the same resource/controller
grep -rn "class.*View\|class.*Controller\|class.*Handler\|Blueprint\|Router\|router\." . \
  | grep -i "[RESOURCE_NAME]" | grep -v "test\|node_modules"

# For every method on that controller: is the same auth check applied?
```

Common BAC patterns to check:
- GET protected but POST/PUT/DELETE not
- List endpoint protected but detail endpoint not
- Create endpoint protected but bulk-create endpoint not
- Admin endpoint protected but export/report endpoint not

### Step 5 — Protection gap propagation

If VULN-001 was vulnerable because of a specific protection gap (e.g. "auth check only applied to role='user', not role='guest'"):
```bash
# Find every other place this specific check is used
grep -rn "[SPECIFIC_CHECK_FUNCTION]\|[SPECIFIC_MIDDLEWARE]" . | grep -v "test"
# Assess: is the same gap present in other places this check is used?
```

---

## SIBLING FINDING REGISTRATION

For every confirmed sibling instance:

1. Assign a new Vuln ID (VULN-002, VULN-003, etc.)
2. Add to master index Finding Lifecycle Tracker with:
   - `Discovered In: 05-variant-scanner.md`
   - `Taint Path #: [new path number in 03-tracer.md or pending]`
   - Note the seed finding: "Sibling of VULN-001"
3. Create minimal POC if the sibling is a different endpoint (do not duplicate identical POCs)
4. If sibling is in a higher-privilege context or is unauthenticated while seed was authenticated → escalate severity

---

## CLOSING A VULN CLASS

A vuln class can only be closed when:
1. Every instance of the sink pattern has been triaged
2. Every `⚠️ Needs trace` has been resolved
3. Every protected instance has the protection explicitly documented

Document the closure:
```markdown
## Vuln Class Closure: SQL Injection
- Seed: VULN-001
- All cursor.execute() instances found: 12
- Confirmed vulnerable: 3 (VULN-001, VULN-004, VULN-007)
- Protected: 8 (parameterized — see table below)
- Could not resolve: 1 → VULN-009-needs-tracer (added to master index)
- Class closed: Yes / No (pending unresolved instances)
```

**G2 guard reminder:** "Protected at one endpoint" does not mean "class closed". 
You must enumerate and triage ALL instances before closing.

---

## VARIANT SCANNER OUTPUT FILE STRUCTURE

```markdown
# Variant Scanner Output — [projectname]

## Progress
| Seed Finding | Sink Pattern | Instances Found | Confirmed Siblings | Closed? |
|-------------|-------------|-----------------|-------------------|---------|

## Scan Log

### Seed: VULN-001 ([type])

**Pattern extracted:**
- Sink: [function @ file:line]
- Source: [user input type]
- Gap: [protection gap]

**All instances found:**
| # | File:Line | Reachable? | Same gap? | Verdict | Sibling ID |
|---|-----------|-----------|-----------|---------|------------|

**BAC inheritance check:**
[only for BAC-class seeds]

**Class closure:**
- Total instances: N
- Confirmed vulnerable: N
- Protected: N
- Unresolved: N (see Researcher Actions)
- Class closed: Yes / No

## New Sibling Findings
| Vuln ID | Title | Seed | File:Line | Delta from Seed |
|---------|-------|------|-----------|-----------------|
<!-- Delta: same pattern, different endpoint | higher privilege | unauthenticated | ... -->

## Handoff Note — Variant Scanner → Final Boss
**Scans completed:**
**New siblings found:**
**Classes still open (unresolved instances):**
**Guards fired:**
**Master index updated:**
```
