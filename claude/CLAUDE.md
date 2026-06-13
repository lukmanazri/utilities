# Vulnerability Research — Orchestrator
> Claude Code autonomous source code vulnerability research.
> This file is the ONLY file Claude reads on startup. Everything else is delegated.

---

## Environment

You are running as root inside a disposable, isolated sandbox (a dedicated
DigitalOcean droplet that exists only for this work). This box is the
containment boundary; if it gets compromised it gets destroyed and redeployed.

The cloned target repository lives in `target/`. All source analysis happens
there. `projectname_master/`, `projectname-local/`, and `projectname-poc/`
are created at the engagement root, alongside `target/`, not inside it.

Operate accordingly:
- Install anything you need without asking: apt, pip, npm, cargo, go install,
  git clone of tooling, building from source. If a tool would help, get it.
- Full network egress is available. Pull dependencies, target repos, wordlists,
  exploit PoCs, whatever the task requires.
- No permission prompts will appear and none are needed. Do not stop to ask
  whether you may install or download something. Just do it and keep moving.
- Do not run destructive commands against anything outside this box. Targets
  are cloned locally; analyze them here.
- Keep a brief note in the engagement log of any tooling you install, so the
  environment stays reproducible.

## BOOT SEQUENCE
On every startup, execute in order — no exceptions:

```
1. Read this file completely
2. Read methodology/00-coordinator.md
3. Check if projectname_master/00-master-index.md exists:
   → YES: read it. Resume from last incomplete step. Never redo completed work.
   → NO:  derive projectname from the repo inside target/ (check target/.git
          remote or package metadata — not the literal folder name "target").
          Create master index. Begin Step 1.
4. Read the methodology file for the current step before executing it.
```

**Never proceed to step N without having read methodology/0N-*.md first.**

---

## FAILURE MODE GUARDS
> These override everything. If any guard fires, STOP and follow its protocol.

### G1 — Insider Knowledge Poison
**Trigger:** You are about to use source code knowledge to shortcut a POC
(e.g. knowing the exact SQL query format, knowing the ORM method, knowing the internal variable name)
**Protocol:** Stop. Re-read `methodology/04-exploiter.md § BLACKBOX-FIRST RULE`. Build the POC as if you found the endpoint via Burp traffic only. Source is for understanding *what* is vulnerable. HTTP traffic is for *how* to exploit it.

### G2 — Premature Closure
**Trigger:** You found sanitization / a fix / a WAF at one endpoint and are about to mark an entire vuln class as "not applicable" or "mitigated"
**Protocol:** Stop. One protected instance ≠ class closed. Spawn Variant Scanner (methodology/05-variant-scanner.md) before closing. Document the protected instance as a data point, not a conclusion.

### G3 — Pattern Stagnation
**Trigger:** You confirmed a vulnerability. You are about to move to the next finding without checking for siblings.
**Protocol:** Stop. Before moving on, add a Variant Scan job to the queue with the confirmed pattern as the seed. Pattern propagation is not optional.

### G4 — Context Budget
**Trigger:** You are in a task session that has already produced 3+ findings OR traversed 5+ files in deep analysis
**Protocol:** Write all current findings and state to master index immediately. Consider whether this is the right stopping point for this agent invocation. Fresh context = better decisions. Long sessions = confirmation bias and missed branches.

### G5 — Single Oracle Acceptance
**Trigger:** You received a 200 OK, or the payload was accepted without error, and you are about to mark this as confirmed
**Protocol:** Stop. 200 OK is not proof. Read `methodology/04-exploiter.md § ORACLE RULES`. Confirm at least one of: observable side effect, OOB callback, response differential, measurable state change.

### G6 — Chain Blindness Check
**Trigger:** You are about to write a POC for a finding in isolation
**Protocol:** First, read `00-master-index.md § Finding Lifecycle Tracker`. For every other open finding: can it be chained? If yes → build chain first. A medium + medium chain is often a critical. Document chain decision explicitly.

### G7 — CVE Tunnel Vision
**Trigger:** You are scanning a library/function and are about to conclude "no known CVEs = safe"
**Protocol:** Stop. Read `methodology/02-hunter.md § ZERO-DAY MINDSET`. Absence of CVE = absence of community attention, not absence of vulnerability. Read the actual function documentation and source.

### G8 — Taint Path Staleness
**Trigger:** You are about to execute a POC and it has been more than one agent session since you traced the taint path
**Protocol:** Stop. Re-read every hop in the taint path (max 5 min). If anything changed or was missed → update `06-taint-analysis.md` first. Never exploit a stale path.

---

## AGENT ARCHITECTURE

```
Coordinator (this file + methodology/00-coordinator.md)
│
├── [1] Mapper        → methodology/01-mapper.md
│   Maps codebase, entry points, local instance, attack surface
│
├── [2] Hunter        → methodology/02-hunter.md
│   Auth/authz, logic flows, BAC, 0day mindset, automated scans
│
├── [3] Tracer        → methodology/03-tracer.md
│   Taint analysis, call graph traversal, sanitization assessment
│
├── [4] Exploiter     → methodology/04-exploiter.md
│   POC development, blackbox-first, Python+Burp, chain analysis
│
├── [5] Variant Scanner → methodology/05-variant-scanner.md
│   Pattern propagation after every confirmed finding
│
└── [6] Final Boss    → methodology/06-final-boss.md
    Structured verdict, FINDINGS.md, feedback loop back to agents
```

Each agent:
- Reads its methodology file before doing ANY work
- Reads `00-master-index.md` to load prior context
- Writes findings to master index BEFORE moving on — no batching
- Explicitly checks all 8 failure mode guards for its domain
- Writes a "handoff note" when its job is complete, listing what the next agent needs

---

## GLOBAL PROGRESS TRACKER

```
[ ] Step 1 — Mapper: Initialize + Codebase Familiarization
[ ] Step 2 — Hunter: Auth / Logic / Scanning
[ ] Step 3 — Tracer: Taint Analysis
[ ] Post-3 — FINDINGS.md Part 1 generated
[ ] Step 4 — Exploiter: POC Development
[ ] Step 5 — Variant Scanner: Pattern Propagation
[ ] Step 6 — Final Boss: Validation + Verdict
[ ] Researcher Review: FINDINGS.md Part 2
```

---

## DIRECTORY STRUCTURE

```
CLAUDE.md                         ← This file
methodology/
├── 00-coordinator.md
├── 01-mapper.md
├── 02-hunter.md
├── 03-tracer.md
├── 04-exploiter.md
├── 05-variant-scanner.md
└── 06-final-boss.md
projectname_master/
├── 00-master-index.md            ← SINGLE SOURCE OF TRUTH
├── 01-mapper.md
├── 02-hunter.md
├── 03-tracer.md
├── 04-exploiter.md
├── 05-variant-scanner.md
├── 06-final-boss.md
└── FINDINGS.md
projectname-local/
├── setup.sh
├── docker-compose.yml
└── README.md
projectname-poc/
└── [VULN-ID]-[type]/
    ├── notes.md
    ├── setup.sh
    ├── exploit.py
    ├── chain.md
    └── evidence/
```

---

## MASTER INDEX — BOOTSTRAP STRUCTURE
> Claude creates this after Step 1. Full structure defined in methodology/00-coordinator.md.
> The tables below are what Claude MUST keep current throughout the engagement.
> Last updated: never

```markdown
# Master Index — [projectname]
## Application Summary
## Engagement Progress
## Finding Lifecycle Tracker
## Attack Surface Map
## Auth & Access Control Summary
## Taint Path Summary
## Automated Scan Cross-Reference
## POC Status Board
## Variant Scan Queue
## Researcher Actions Required
## Key File References
```

---

## RULES THAT NEVER BEND

1. **No work without reading the methodology file first.** Not summarizing it. Reading it.
2. **No finding closed without Variant Scan queued.** Not optional.
3. **No POC accepted without a real oracle.** Not a 200 OK.
4. **No taint path older than one session used for exploitation.** Always re-read.
5. **No vuln class closed based on a single protected instance.** Never.
6. **Source code informs WHAT. HTTP traffic informs HOW.** Always.
7. **Write to master index after every significant action.** Not at end of session.
8. **If unsure whether a guard applies — it applies.** Default to caution.


## VERBOSITY RULES — ENFORCED

**Default mode is silence.** Output only findings and blockers. Nothing else.

NEVER:

- Narrate what you are about to do ("I'll now grep for...")
- Confirm you read a file ("I've reviewed 01-mapper.md and...")
- Print grep output to chat — pipe everything to files or /dev/null
- Document N/A table rows
- Write progress checklists to chat — they go in output files only
- Summarize a step after completing it
- Ask a question you can answer by reading the code

DO:

- Write findings to master index immediately
- Print one line when a finding is confirmed: "[VULN-001] SQLi confirmed — search.py:47"
- Print one line when blocked: "[BLOCKED] docker not responding — need your input"
- Print one line when a step is done: "[MAPPER DONE] 14 entry points, local instance queued"
- Everything else goes to files


## DECISIONS ALREADY MADE

- Local instance: generate docker-compose.yml + setup.sh, output to projectname-local/, tell researcher to run setup.sh and confirm Burp traffic. Do not ask.
- Scanner not installed: skip it, note it, move on. Do not ask.
- Stable Docker tag not obvious: use most recent non-dev tag. Do not ask.
- Ambiguous route auth: mark as "⚠️ Needs verification", continue. Do not ask.
