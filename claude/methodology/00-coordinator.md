# Coordinator — Agent Workflow & Master Index

---

## AGENT SPAWN PROTOCOL

Each agent is a focused, context-bounded job. When spawning an agent:

1. Write the current master index state to disk (single-writer rule, below)
2. The new agent reads CLAUDE.md → this file → 00-master-index.md → its own methodology file
3. The agent (and its subagents) executes its job
4. The agent runs INDEX LINT, then writes a HANDOFF NOTE to its output file before stopping
5. The handoff note lists: what was completed, what is unresolved, what the next agent must know

**Single-writer rule (prevents index corruption under parallel subagents):**
- Subagents write ONLY their own files (e.g. `comprehension/subsystem/X.md`, a chainer scratch
  file, a per-finding note). A subagent NEVER edits the master index directly.
- The active STAGE agent is the SOLE writer to `00-master-index.md`; it merges its subagents'
  outputs into the index AFTER they finish. Stages are sequential at the top level → exactly
  one index writer at any instant → no locking needed.

**Index lint (run before every handoff):** every finding has a row; no reference points at a
missing finding/file; no table carries a "never updated" timestamp; Comprehension Coverage /
Chain Graph / Triage tables are internally consistent. Fix before handing off.

**Resumable per-stage sub-state:** each stateful stage records its own progress so a crash
resumes precisely. Sub-state lives in the stage's own master file and the relevant index table:
Analyst → which subsystems are `✅ Understood` (Comprehension Coverage); Hunter/Tracer → which
findings are processed; Variant → which seeds scanned; Chain Strategist → chain-graph status +
feedback-loop position. The boot sequence reads this, not just the step-level table.

**Context budget (stage-aware, per G4):** checkpoint unit = per-subsystem (Analyst, ~25 files
ok), per-finding (Hunter/Tracer, ~3 findings), per-seed (Variant), per-chain (Strategist),
per-POC (Exploiter). At the unit, checkpoint to index and consider handing off. Fresh context
produces better analysis — this is the design, not a limitation.

**Parallelism (fan out WITHIN a stage, never ACROSS a dependency edge):** Analyst fans out one
subagent per subsystem. Hunter sub-tasks (auth, logic, scanning) are independent agents. Tracer
runs per-finding-cluster. Exploiter is one agent per POC/chain. Variant Scanner is one agent per
seed. Chain Strategist spawns narrow single-objective link-hunts. Never start a stage whose
inputs an earlier stage hasn't finished.

---

## MASTER INDEX — FULL STRUCTURE

```markdown
# Master Index — [projectname]
> Single source of truth. Every agent reads this on start. Every agent updates this before stopping.
> Last updated: [timestamp]

---

## Application Summary
<!-- Stack, architecture, entry point overview — populated by Mapper -->

---

## Engagement Progress
| Step | Agent | Status | Output File | Last Updated |
|------|-------|--------|-------------|--------------|
| 1 | Mapper | ⏳ | projectname_master/01-mapper.md | |
| 1.5 | Analyst | ⏳ | projectname_master/01.5-analyst.md | |
| 2 | Hunter | ⏳ | projectname_master/02-hunter.md | |
| 3 | Tracer | ⏳ | projectname_master/03-tracer.md | |
| 4 | Exploiter | ⏳ | projectname_master/04-exploiter.md | |
| 5 | Variant Scanner | ⏳ | projectname_master/05-variant-scanner.md | |
| 5.5 | Chain Strategist | ⏳ | projectname_master/05.5-chain-strategist.md | |
| 6 | Final Boss | ⏳ | projectname_master/06-final-boss.md | |
<!-- ⏳ Pending | 🔄 In Progress | ✅ Complete | ❌ Blocked -->

---

## Comprehension Coverage
<!-- Populated by Analyst (Step 1.5) + targeted-comprehension service calls.
     Hunter/Tracer/Exploiter/Variant/Strategist MUST read this (G9).
     A subsystem not marked ✅ Understood is OFF-LIMITS. -->
| Subsystem | Doc | Teach-back | Status | Off-limits? |
|-----------|-----|------------|--------|-------------|
<!-- Status: ✅ Understood | 🔄 In Progress | ⚠️ Comprehension Blocked -->

---

## Finding Lifecycle Tracker
<!-- Schema is split to avoid an unreadable mega-table: core attributes + P/C/invariant here;
     marginal-verdict in § Triage; chain-membership in § Chain Graph (cross-ref by Vuln ID). -->
| Vuln ID | Title | Type | Severity | Precond-Priv (P) | Capability (C) | Invariant | File:Line | Taint Path # | POC Path | Validation | Variant Scan | FINDINGS.md |
|---------|-------|------|----------|------------------|----------------|-----------|-----------|--------------|----------|------------|--------------|-------------|
<!-- Type: sqli|rce|ssrf|idor|auth-bypass|path-traversal|xss|ssti|deserialize|logic|bac|0day|other -->
<!-- Precond-Priv (P): unauth | user | role-X | admin  (provisional@Hunter → precise@Exploiter) -->
<!-- Capability (C): rce | file-read | cross-tenant-read | privesc→X | data-dump | ...           -->
<!-- Invariant: INV-NNN it violates (from comprehension/invariants.md), or "+new" if Hunter added one back -->
<!-- Validation: ⏳|🔄|✅ Confirmed|❌ Not Reproduced|⚠️ Partial -->
<!-- Variant Scan: ⏳ Queued | 🔄 In Progress | ✅ Done (N siblings found) | N/A -->
<!-- FINDINGS.md: Part 1 | Part 2 | Not yet -->
<!-- Marginal-capability verdict lives in § Triage; chain membership in § Chain Graph -->

---

## Attack Surface Map
| Entry Point | Type | File:Line | Auth Required | Taint Source? | Taint Path # |
|-------------|------|-----------|---------------|---------------|--------------|
<!-- Taint Source?: Yes | No | Partial | Pending -->

---

## Auth & Access Control Summary
| Component | Weakness Type | Severity | File:Line | Agent Ref | Finding ID |
|-----------|--------------|----------|-----------|-----------|------------|

---

## Taint Path Summary
| Path # | Source | Sink | Sanitized? | Bypassable? | Finding ID | Validated? |
|--------|--------|------|------------|-------------|------------|------------|

---

## Automated Scan Cross-Reference
| Tool | Rule | File:Line | Verdict | Finding ID | Manual Confirmed? |
|------|------|-----------|---------|------------|-------------------|
<!-- Verdict: ✅ TP | ❌ FP | ⚠️ Review -->

---

## POC Status Board
| Vuln ID | POC Path | Oracle Type | Dev Status | Validation Status | Evidence |
|---------|----------|-------------|------------|-------------------|----------|
<!-- Dev: 🔄 | ✅ Ready | ❌ Blocked -->
<!-- Validation: ⏳ | ✅ Confirmed | ❌ Not Reproduced | ⚠️ Partial -->

---

## Variant Scan Queue
> Populated after every confirmed finding. Variant Scanner reads this table.

| # | Seed Finding | Seed Pattern | Scan Status | Siblings Found | Notes |
|---|-------------|-------------|-------------|----------------|-------|
<!-- Scan Status: ⏳ Queued | 🔄 In Progress | ✅ Done -->

---

## Chain Graph
> Owned by Chain Strategist (Step 5.5); Exploiter records standalone + obvious chains here too
> (G6). This is the chain-membership home (cross-ref findings by Vuln ID).

| Chain ID | Node Findings (Vuln IDs) | Entry P → Final C | Missing Link? | Combined Severity | Chain POC Path | Status |
|----------|--------------------------|-------------------|---------------|-------------------|----------------|--------|
<!-- Missing Link?: none | "need primitive: unauth→admin" (→ link-hunt or tripwire) -->
<!-- Status: 🔄 Building | ✅ Confirmed | ⚠️ Blocked (missing link) | tripwire-recorded -->

---

## Triage / Boundary Verdicts
> Owned by Final Boss triager (Step 6, G10). Verdict annotates Part 1 findings. Never deletes.

| Vuln ID | Marginal Capability | Boundary Crossed? | Verdict | Tripwire (what would revive it) | Ladder Rungs Tried |
|---------|---------------------|-------------------|---------|----------------------------------|--------------------|
<!-- Verdict: ✅ valid-as-is | 🔗 needs-chain (→5.5) | ⬇ needs-lower-priv (→re-examine) | ℹ informational -->
<!-- Ladder Rungs Tried: 1 lower-entry / 2 chain / 3 re-scope / 4 aggregate — list which were attempted -->

---

## Feedback Queue
> Bounded routing between Final Boss triager and earlier stages. Each entry has a budget + status.

| # | From | To | Hypothesis / Request | Budget | Status |
|---|------|----|-----------------------|--------|--------|
<!-- To: Analyst-service | Tracer-service | Chain Strategist (edge-B, 1 iteration) -->
<!-- Status: open | satisfied | exhausted (budget spent) -->

---

## Researcher Actions Required
| # | Action | Context | Blocking | Added |
|---|--------|---------|----------|-------|

---

## Local Instance
- **Version deployed:**
- **Instance URL:**
- **Ports:**
- **Default credentials:**
- **Burp proxy configured:** Yes / No
- **Last clean reset:**

---

## Key File References
| File | Purpose | Last Updated |
|------|---------|--------------|
| CLAUDE.md | Orchestrator | |
| 00-master-index.md | This file | |
| 01-mapper.md | Entry points, stack, local instance | |
| 01.5-analyst.md | Comprehension index, teach-back, subsystem fan-out | |
| 02-hunter.md | Auth, logic, BAC, scans (hypothesis-driven) | |
| 03-tracer.md | Taint paths | |
| 04-exploiter.md | POC development | |
| 05-variant-scanner.md | Pattern propagation | |
| 05.5-chain-strategist.md | Exhaustive chain graph | |
| 06-final-boss.md | Validation + matured triage verdict | |
| comprehension/invariants.md | Ranked lead list (bidirectional) | |
| comprehension/security-model.md | Intended privilege model (feeds G10) | |
| comprehension/coverage.md | Subsystem understood-status (G9 gate) | |
| FINDINGS.md | Part 1 + Part 2 | |
```

---

## HANDOFF NOTE TEMPLATE

Every agent writes this to its output file before stopping:

```markdown
## Handoff Note — [Agent Name] → [Next Agent Name]

**Completed:**
- [x] ...

**Unresolved / needs follow-up:**
- [ ] ...

**What the next agent MUST know:**
- ...

**Open guards that fired this session:**
- G[N]: [what triggered it, how it was handled]

**Index lint:** [passed — every finding has a row, no orphan refs, no stale timestamps]
**Master index last updated:** [timestamp]
**Output file:** projectname_master/0N-[agent].md
```

---

## FINDING ID CONVENTION

```
VULN-001    sequential numeric, assigned at first discovery
CHAIN-001   for compound multi-finding chains
0DAY-001    for assumption-gap / zero-day candidates before confirmation
INV-001     invariant in comprehension/invariants.md (the lead a finding violates)
```

Severity:
- **CRITICAL** — unauthenticated RCE, auth bypass to full access, full DB dump
- **HIGH** — authenticated RCE, SQLi with auth, significant data exposure
- **MEDIUM** — limited IDOR, stored XSS, business logic with real impact
- **LOW** — reflected XSS, information disclosure, defense-in-depth gaps
- **INFO** — hardcoded test credentials, verbose errors, missing headers
