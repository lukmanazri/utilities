# Coordinator — Agent Workflow & Master Index

---

## AGENT SPAWN PROTOCOL

Each agent is a focused, context-bounded job. When spawning an agent:

1. Write the current master index state to disk
2. The new agent reads CLAUDE.md → this file → 00-master-index.md → its own methodology file
3. The agent executes its job
4. The agent writes a HANDOFF NOTE to its output file before stopping
5. The handoff note lists: what was completed, what is unresolved, what the next agent must know

**Context budget rule:** If an agent session touches 8+ files in deep analysis or produces 4+ findings, it MUST checkpoint to master index and hand off. Do not keep going. Fresh context produces better analysis. This is not a limitation — it is the design.

**Parallelism:** Hunter sub-tasks (auth, logic, scanning) can be independent agents. Tracer can run per-finding-cluster. Exploiter is one agent per POC or per chain. Variant Scanner is one agent per confirmed-finding seed.

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
| 2 | Hunter | ⏳ | projectname_master/02-hunter.md | |
| 3 | Tracer | ⏳ | projectname_master/03-tracer.md | |
| 4 | Exploiter | ⏳ | projectname_master/04-exploiter.md | |
| 5 | Variant Scanner | ⏳ | projectname_master/05-variant-scanner.md | |
| 6 | Final Boss | ⏳ | projectname_master/06-final-boss.md | |
<!-- ⏳ Pending | 🔄 In Progress | ✅ Complete | ❌ Blocked -->

---

## Finding Lifecycle Tracker
| Vuln ID | Title | Type | Severity | Discovered In | File:Line | Taint Path # | POC Path | Validation | Variant Scan | FINDINGS.md |
|---------|-------|------|----------|---------------|-----------|--------------|----------|------------|--------------|-------------|
<!-- Type: sqli|rce|ssrf|idor|auth-bypass|path-traversal|xss|ssti|deserialize|logic|bac|0day|other -->
<!-- Validation: ⏳|🔄|✅ Confirmed|❌ Not Reproduced|⚠️ Partial -->
<!-- Variant Scan: ⏳ Queued | 🔄 In Progress | ✅ Done (N siblings found) | N/A -->
<!-- FINDINGS.md: Part 1 | Part 2 | Not yet -->

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

## Vulnerability Chains
| Chain ID | Component Findings | Combined Severity | Chain POC Path | Status |
|----------|--------------------|-------------------|----------------|--------|

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
| 02-hunter.md | Auth, logic, BAC, scans | |
| 03-tracer.md | Taint paths | |
| 04-exploiter.md | POC development | |
| 05-variant-scanner.md | Pattern propagation | |
| 06-final-boss.md | Final verdict | |
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

**Master index last updated:** [timestamp]
**Output file:** projectname_master/0N-[agent].md
```

---

## FINDING ID CONVENTION

```
VULN-001    sequential numeric, assigned at first discovery
CHAIN-001   for compound multi-finding chains
0DAY-001    for assumption-gap / zero-day candidates before confirmation
```

Severity:
- **CRITICAL** — unauthenticated RCE, auth bypass to full access, full DB dump
- **HIGH** — authenticated RCE, SQLi with auth, significant data exposure
- **MEDIUM** — limited IDOR, stored XSS, business logic with real impact
- **LOW** — reflected XSS, information disclosure, defense-in-depth gaps
- **INFO** — hardcoded test credentials, verbose errors, missing headers
