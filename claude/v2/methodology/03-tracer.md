# Agent: Tracer
> Responsibility: Prove complete, exploitable paths from untrusted source to dangerous sink.
> Output: projectname_master/03-tracer.md

---

## TRACER JOB

You prove (or disprove) paths. You do not discover new attack surface — Hunter did that.
You do not write exploits — Exploiter does that.

Your input: every provisional finding in the master index Finding Lifecycle Tracker marked `⏳ Pending`.
Your output: for each finding, either a confirmed taint path or a documented dead end.

**Priority order:**
1. Provisional findings from Hunter (confirmation or denial)
2. High-value entry points not yet traced (unauthenticated, file upload, external-facing APIs)
3. Second-order taint sources (written in one request, read in another)
4. Remaining entry points

---

## PHASE 1 — LOAD CONTEXT

Before writing a single grep, read:
- `projectname_master/01-mapper.md` — framework patterns, ORM, template engine, module map
- `00-master-index.md § Attack Surface Map` — your source list
- `00-master-index.md § Finding Lifecycle Tracker` — all provisional findings to confirm/deny
- `projectname_master/02-hunter.md § BAC Findings` + `§ Assumption Gaps` — specific paths Hunter flagged

Extract and note (do not re-enumerate):
- Exact framework request ingestion patterns: `request.args['x']`, `req.body.x`, `$_GET['x']`
- How data moves between layers in THIS codebase: controller → service → repository
- ORM parameterization pattern: `cursor.execute(query, params)` vs `cursor.execute(f"... {x}")`
- Template engine + whether auto-escape is on

---

## PHASE 2 — SECOND-ORDER TAINT IDENTIFICATION

This is the only new source enumeration in this step. Everything else loads from Mapper/Hunter.

Second-order taint: user data is **written** to persistent store in request A, **read back** in request B, and reaches a sink in request B. Scanners almost universally miss this.

```bash
# Writes near user input
grep -rn "\.save(\|\.create(\|\.bulk_create(\|\.insert(" . | grep -v "node_modules\|test" | head -30
grep -rn "cache\.set\|redis\.set\|r\.set\|memcache\.set" . | grep -v "node_modules\|test" | head -20
grep -rn "session\[.*\] =\|session\.update\|request\.session\[" . | grep -v "node_modules\|test" | head -20
grep -rn "open(.*'w'\|writeFile\|fs\.write\|ioutil\.Write\|os\.Write" . | grep -v "node_modules\|test" | head -20

# Reads of the same fields (find the field names from writes above, then search for reads)
grep -rn "\.filter(\|\.find(\|\.get(\|\.all(\|\.query(" . | grep -v "node_modules\|test" | head -30
grep -rn "cache\.get\|redis\.get\|r\.get\|session\.get\|request\.session\[" . | grep -v "node_modules\|test" | head -20
```

For each second-order path found:
- Document write location (source request) and read location (sink request) separately
- Identify the field name / DB column / cache key that links them
- Add to Sources table with type `Second-Order`

---

## PHASE 3 — SINK GAP-FILL

Scanners already found common sinks. Only fill gaps they miss:

```bash
# Custom wrappers — scanners see the wrapper, not the underlying dangerous call
grep -rn "def .*query\|def .*execute\|def .*run_cmd\|function.*Query\|function.*Exec\|func.*Query\|func.*Exec" . \
  | grep -v "node_modules\|test" | head -20

# Dynamic dispatch / reflection
grep -rn "getattr(\|__getattr__\|call_user_func\|invokeMethod\|eval(\|Function(" . \
  | grep -v "node_modules\|test" | head -20

# ORM raw() escape hatches — parameterized ORM in use but raw() called somewhere
grep -rn "\.raw(\|\.extra(\|\.RawSQL\|createNativeQuery\|nativeQuery\|execute(" . \
  | grep -v "node_modules\|test" | head -20

# Template rendering with string formatting (bypasses auto-escape)
grep -rn "render_string\|from_string\|Template(\|Markup(\|mark_safe\|html_safe\|raw(" . \
  | grep -v "node_modules\|test" | head -20

# Shell execution
grep -rn "subprocess\.\|os\.system\|os\.popen\|exec(\|execSync\|spawn(\|child_process" . \
  | grep -v "node_modules\|test" | head -20

# File operations
grep -rn "open(\|readFile\|path\.join\|os\.path\.join\|send_file\|send_from_directory\|FileResponse" . \
  | grep -v "node_modules\|test" | head -20

# Deserialization
grep -rn "pickle\.loads\|yaml\.load(\|yaml\.unsafe_load\|unserialize\|Marshal\.load\|ObjectInputStream\|JSON\.parse" . \
  | grep -v "node_modules\|test" | head -20

# HTTP client (SSRF)
grep -rn "requests\.get\|requests\.post\|urllib\.\|http\.get\|axios\.\|fetch(\|curl_exec\|file_get_contents" . \
  | grep -v "node_modules\|test" | head -20
```

---

## PHASE 4 — CALL GRAPH TRAVERSAL

For every provisional finding and every source→sink pair, perform bidirectional traversal.
This is the core of taint analysis. No shortcuts.

### Backwards slice — from sink to source:

```
1. Identify the variable(s) consumed at the sink
2. Find where that variable was last assigned — read the assignment in full
3. Was it assigned from a function return?
   → Read that function's full body (not just the signature)
4. Was it assigned from a parameter?
   → Find ALL callers of this function:
      grep -rn "function_name(" . --include="*.py"  (adapt extension)
5. For each caller: what argument is passed at that position?
   → Repeat from step 1 in the caller's scope
6. Continue until:
   a. Entry point from Attack Surface Map → COMPLETE PATH ✅
   b. Hardcoded / static value → dead end ❌
   c. Sanitization function → assess in Phase 5 ⚠️
   d. DB/cache read → check if that stored value was user-supplied (second-order) 🔄
```

### Forward slice — from source to sink:

```
1. Find every usage of the source variable in scope
2. Is it passed to a function? → Read that function's full body
3. Is it stored (DB/session/cache/file)? → Find where it's read back
4. Is it returned from current function? → Find all callers, trace in their scope
5. Is it transformed? → Does the transform sanitize (Phase 5) or just change form?
6. Continue until: reaches sink ✅ | fully sanitized ✅ | dead end ❌
```

### Document each path:

```
Path [N] — [Source file:line] → [Sink file:line]
Traversal chain:
  sink @ file:line — consumes variable X
  └── X assigned at file:line: X = some_function(param)
      └── some_function defined at file:line
          └── param ← from arg[0] at call site
              └── call site: some_function(request_data) @ file:line
                  └── request_data = request.args['user_input'] ← SOURCE ✅
```

---

## PHASE 4.5 — SINK & SANITIZER ZERO-DAY ASSESSMENT

**After** tracing a path, **before** assessing the sanitizer:

For every sink and sanitizer in a confirmed path:
1. Find the actual implementation (not just the call site)
2. Read it — does it actually do what its name implies?
3. Does the sink have a "safe mode" that isn't being used here?
4. Does the sanitizer's documentation explicitly claim to prevent THIS attack class?
   - If not explicitly documented as a security control → it is NOT a security control
5. Is the version in use older than a version where security fixes were made?

```bash
# Find library source
find . -path "*site-packages/[libname]*" -name "*.py" | head -5
python3 -c "import [libname]; import inspect; print(inspect.getfile([libname]))"
# For Node.js
node -e "console.log(require.resolve('[libname]'))"
```

If behavior cannot be verified: mark path as `⚠️ Needs Manual Verification`, add to `§ Unverified Behaviors`.

---

## PHASE 5 — SANITIZATION ASSESSMENT

For every sanitizer encountered in a taint path:

```
1. Read its full implementation
2. Is it context-appropriate?
   HTML encode ≠ SQL escape ≠ shell escape ≠ path sanitize
   HTML encode before a SQL sink = NOT protected ← this is a classic false sense of safety
3. Is it applied BEFORE the sink or AFTER?
   After = useless
4. Is it applied on ALL code paths to the sink?
   grep every branch between source and sink — does every branch go through sanitizer?
5. Bypass possibilities:
   - Double encoding
   - Null bytes / null byte injection
   - Unicode normalization (NFC vs NFD)
   - Type confusion (array where string expected)
   - Length truncation (sanitize then truncate → truncation re-introduces unsafe suffix)
   - Second application (sanitized copy stored, unsanitized copy also stored separately)
```

Verdict per path:
- ✅ **Effective** — context-appropriate, before sink, all branches, not bypassable
- ⚠️ **Weak** — present but bypassable — document the bypass
- ❌ **Missing** — nothing between source and sink

---

## COMPOUND FINDING DETECTION

If a complete path involves an endpoint also flagged in Hunter (BAC gap, auth weakness):
- This is a compound finding → severity likely escalates
- e.g. unauthenticated endpoint (Hunter) + SQLi path (Tracer) = CRITICAL compound
- Link finding IDs in both files and master index
- Add to `## Vulnerability Chains` in master index

---

## TRACER OUTPUT FILE STRUCTURE

```markdown
# Tracer Output — [projectname]

## Progress
- [ ] Phase 1: Context loaded from Mapper and Hunter
- [ ] Phase 2: Second-order sources identified
- [ ] Phase 3: Sink gap-fill complete
- [ ] Phase 4: Call graph traversal complete
- [ ] Phase 4.5: Sink/sanitizer zero-day assessment done
- [ ] Phase 5: Sanitization assessed for all paths
- [ ] Provisional findings confirmed or denied
- [ ] Compound findings identified
- [ ] Master index Taint Path Summary updated

## Sources
| # | Type | File:Line | Variable | Source |
|---|------|-----------|----------|--------|
<!-- Source: Attack Surface Map (Mapper) | Second-Order (Phase 2) -->

## Sinks
| # | Class | File:Line | Variable | Source |
|---|-------|-----------|----------|--------|
<!-- Source: Step5-Scanner | Phase3-Gap-fill -->

## Taint Paths

### Path 1 — [Source @ file:line] → [Sink @ file:line]
- **Traversal chain:**
  ```
  ...
  ```
- **Provisional finding confirmed?** VULN-ID / No / New finding
- **Compound finding?** Yes → VULN-ID-B / No
- **Sanitization:** ✅ Effective / ⚠️ Weak — [bypass] / ❌ Missing
- **Verdict:** ✅ Complete exploitable path / ❌ Dead end / ⚠️ Needs verification

## Sanitization Assessment
| Path # | Sanitizer | Location | Context-OK? | All Branches? | Bypassable? | Verdict |
|--------|-----------|----------|-------------|---------------|-------------|---------|

## Second-Order Cases
| # | Write @ file:line | Read @ file:line | Field | Path # |
|---|------------------|------------------|-------|--------|

## Unverified Behaviors
| # | Function | File:Line | Uncertainty | Researcher Action |
|---|----------|-----------|-------------|-------------------|

## Confirmed Paths → Exploiter Input
| Path # | Finding ID | Source Request | Sink | Payload Type | Sanitization Bypass |
|--------|------------|---------------|------|--------------|---------------------|

## Denied Paths
| Path # | Provisional Finding | Reason Dead End |
|--------|--------------------|-----------------| 

## Handoff Note — Tracer → Exploiter
**Confirmed paths (prioritized):**
**Denied paths:**
**Unresolved (researcher review needed):**
**Guards fired:**
**Master index updated:**
```
