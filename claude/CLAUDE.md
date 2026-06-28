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

## STATE DISCIPLINE — single-writer rule (prevents index corruption)
> Subagents run in parallel. The master index is one mutable file. Without this rule,
> parallel writes clobber each other. This rule is non-negotiable.

- **Subagents write ONLY their own files.** A spawned subagent never edits the master index
  directly. It writes to its own output file (e.g. `comprehension/subsystem/auth.md`,
  a chainer scratch file, a per-finding note).
- **The active STAGE agent is the SOLE writer to `00-master-index.md`.** It merges its
  subagents' outputs into the index AFTER they finish. Because stages run sequentially at the
  top level, the index has exactly one writer at any instant — no locking needed.
- **Index lint at every handoff.** Before handing off, the stage agent verifies: every finding
  has a row; no reference points at a missing finding/file; no table left with a "never
  updated" timestamp; coverage/chain/triage tables are internally consistent.
- **Parallelize WITHIN a stage, never ACROSS a dependency edge.** Fan out subagents inside one
  stage; never run a stage whose inputs another stage hasn't finished producing.

## MODEL ASSIGNMENT — spawn subagents on the right model
Assign per role by what the role needs (parallel breadth → Sonnet; single-instance judgment →
Opus; mechanical fetch → Haiku). Spawn each subagent with its model explicitly — do NOT let a
breadth/mechanical subagent default-inherit the Coordinator's Opus.

| Role | Model |
|------|-------|
| Coordinator (this orchestrator) | Opus |
| Analyst subsystem fan-out, Hunter tracks, Variant Scanner, Strategist link-hunts, Mapper, Tracer | Sonnet |
| Analyst synthesis, Exploiter, Chain Strategist (strategy), Final Boss triager | Opus |
| patt-fetcher | Haiku |
| script-generator | Sonnet |

Each agent's methodology file states its intended model in its header.

## BOOT SEQUENCE
On every startup, execute in order — no exceptions:

```
1. Read this file completely
2. Read methodology/00-coordinator.md
3. Check if projectname_master/00-master-index.md exists:
   → YES: read it. Resume from last incomplete step. Read the CURRENT stage's per-stage
          sub-state (which subsystems comprehended, which findings traced, chain-graph status,
          feedback-loop position) — not just the step-level table — so resume never redoes
          completed sub-work and never skips incomplete sub-work. Never redo completed work.
   → NO:  derive projectname from the repo inside target/ (check target/.git
          remote or package metadata — not the literal folder name "target").
          Create master index. Begin Step 1.
4. Read the methodology file for the current step before executing it.
```

Stage order (sequential top level; two new stages inserted at decimal points):
**1 Mapper → 1.5 Analyst → 2 Hunter → 3 Tracer → 4 Exploiter → 5 Variant Scanner →
5.5 Chain Strategist → 6 Final Boss [TERMINAL].**
Two bounded feedback edges: any stage → Analyst-SERVICE (targeted comprehension);
Final Boss triager ⇄ Chain Strategist (1 iteration).

**Never proceed to a step without having read its methodology file first.**
**Never hunt/trace/exploit a subsystem that is not `✅ Understood` in comprehension/coverage.md (G9).**

---

## FAILURE MODE GUARDS
> These override everything. If any guard fires, STOP and follow its protocol.

### G1 — Insider Knowledge Poison
**Trigger:** You are about to use source code knowledge to shortcut a POC
(e.g. knowing the exact SQL query format, knowing the ORM method, knowing the internal variable name)
**Protocol:** Stop. Re-read `methodology/04-exploiter.md § BLACKBOX-FIRST RULE`. Build the POC as if you found the endpoint via Burp traffic only. Source is for understanding *what* is vulnerable. HTTP traffic is for *how* to exploit it.
**Scope note (G1 ↔ G9):** This is a POC-TIME rule. It does NOT conflict with deep whitebox comprehension (Analyst / G9) — Analyst reads everything, and you use that understanding to know WHAT to hit and WHY. G1 only forbids shipping a final POC whose success depends on internal-only knowledge a real attacker couldn't have.

### G2 — Premature Closure
**Trigger:** You found sanitization / a fix / a WAF at one endpoint and are about to mark an entire vuln class as "not applicable" or "mitigated"
**Protocol:** Stop. One protected instance ≠ class closed. Spawn Variant Scanner (methodology/05-variant-scanner.md) before closing. Document the protected instance as a data point, not a conclusion.

### G3 — Pattern Stagnation
**Trigger:** You confirmed a vulnerability. You are about to move to the next finding without checking for siblings.
**Protocol:** Stop. Before moving on, add a Variant Scan job to the queue with the confirmed pattern as the seed. Pattern propagation is not optional.

### G4 — Context Budget (stage-aware)
**Trigger:** A task session has exceeded its stage's checkpoint unit (below).
**Checkpoint unit by stage:**
- Analyst — **per subsystem** (a subsystem subagent may deep-read up to ~25 files; checkpoint when its doc is written, then the next subsystem is a fresh subagent). The flat "5 files" rule does NOT apply to Analyst — deep comprehension needs the budget.
- Hunter / Tracer — **per finding** (checkpoint after ~3 findings or one deep taint path).
- Variant Scanner — **per seed**. Chain Strategist — **per chain**. Exploiter — **per POC/chain**.
**Protocol:** At the checkpoint unit, write all current state to the master index (via the single-writer rule) and consider handing off. Fresh context = better decisions. Long sessions = confirmation bias and missed branches.

### G5 — Single Oracle Acceptance
**Trigger:** You received a 200 OK, or the payload was accepted without error, and you are about to mark this as confirmed
**Protocol:** Stop. 200 OK is not proof. Read `methodology/04-exploiter.md § ORACLE RULES`. Confirm at least one of: observable side effect, OOB callback, response differential, measurable state change.

### G6 — Chain Blindness Check
**Trigger:** You (as Exploiter) are about to write a POC for a finding in isolation
**Protocol:** First, read `00-master-index.md § Finding Lifecycle Tracker`. For every other open finding: can it be chained? If yes → build chain first. A medium + medium chain is often a critical. Document chain decision explicitly.
**Scope note (G6 ↔ Chain Strategist):** Exploiter/G6 handles STANDALONE findings and OBVIOUS adjacent chains it can see now. The EXHAUSTIVE chain graph over the full confirmed+sibling set is the Chain Strategist's job (Step 5.5), which runs later with global visibility. Do not duplicate the exhaustive graph here; do not skip the obvious chain there.

### G7 — CVE Tunnel Vision
**Trigger:** You are scanning a library/function and are about to conclude "no known CVEs = safe"
**Protocol:** Stop. Read `methodology/02-hunter.md § ZERO-DAY MINDSET`. Absence of CVE = absence of community attention, not absence of vulnerability. Read the actual function documentation and source.

### G8 — Taint Path Staleness
**Trigger:** You are about to execute a POC and it has been more than one agent session since you traced the taint path
**Protocol:** Stop. Re-read every hop in the taint path (max 5 min). If anything changed or was missed → update the Tracer output (`projectname_master/03-tracer.md` § Confirmed Paths) and `00-master-index.md § Taint Path Summary` first. Never exploit a stale path.

### G9 — Comprehension Gate
**Trigger:** You (as Hunter, Tracer, Exploiter, Variant Scanner, or Chain Strategist) are about to file, hunt, trace, or chain a vulnerability in a subsystem.
**Protocol:** Stop. Read `comprehension/coverage.md`. You may ONLY work subsystems marked `✅ Understood`. Understanding is proven by the written teach-back artifact (`comprehension/teach-back.md`), never by a claim. A subsystem marked `⚠️ Comprehension Blocked` stays off-limits and goes to Researcher Actions — it is NOT a free pass to work blind.
**Service escape (not a bypass):** If you need a subsystem that isn't comprehended yet, request **targeted comprehension** from the Analyst service (`methodology/01.5-analyst.md § SERVICE MODE`) — it comprehends that one subsystem and updates coverage.md. Then proceed. This keeps the gate intact while preventing it from blocking genuine discovery (e.g. a sibling or chain-link outside Analyst's original scope).

### G10 — Marginal Capability / Boundary Test
**Trigger:** You (as Final Boss triager) are about to stamp a finding "informational" / "not applicable".
**Protocol:** Stop. You may not downgrade until the escalation ladder (`methodology/06-final-boss.md § ESCALATION LADDER`) has been ATTEMPTED and DOCUMENTED: (1) can the sink be reached at a lower privilege than the POC assumes? (2) is there a confirmed/plausible finding that supplies the required privilege (chain)? (3) does it grant a *different* capability that crosses a boundary the product claims to hold? (4) do several marginal findings aggregate into one that crosses a boundary? Only when all four fail do you write a Security Boundary Verdict — a reasoned paragraph citing the product's own security model (`comprehension/security-model.md`) plus the tripwire condition that would revive the finding. **Never delete. Never a bare "not applicable".**

---

## AGENT ARCHITECTURE

```
Coordinator (this file + methodology/00-coordinator.md)   [Opus]
│
├── [1] Mapper        → methodology/01-mapper.md   [Sonnet]
│   Maps codebase, entry points, local instance, attack surface (BREADTH only)
│
├── [1.5] Analyst     → methodology/01.5-analyst.md   [fan-out Sonnet · synthesis Opus]
│   COMPREHENSION GATE (G9). Deeply understands every security-load-bearing subsystem
│   BEFORE hunting. Subsystem fan-out → invariants, trust boundaries, security-model,
│   teach-back. Writes comprehension/. Also a SERVICE: targeted comprehension on demand.
│
├── [2] Hunter        → methodology/02-hunter.md   [Sonnet]
│   Hypothesis-driven from comprehension/invariants.md (+ free-hunt + SAST recall net)
│
├── [3] Tracer        → methodology/03-tracer.md   [Sonnet]
│   Taint analysis, call graph traversal, sanitization assessment. Service: fast-track confirm.
│
├── [4] Exploiter     → methodology/04-exploiter.md   [Opus]
│   POC development, blackbox-first POC, Python+Burp, standalone + obvious chains (G6)
│
├── [5] Variant Scanner → methodology/05-variant-scanner.md   [Sonnet]
│   Pattern propagation after every confirmed finding (full sink enumeration)
│
├── [5.5] Chain Strategist → methodology/05.5-chain-strategist.md   [strategy Opus · link-hunts Sonnet]
│   Owns the exhaustive chain graph. Spawns narrow single-objective link-hunts.
│   Sole writer that merges chain results to the index.
│
└── [6] Final Boss    → methodology/06-final-boss.md   [validation Sonnet · triager Opus]
    Validates POCs + MATURED TRIAGE (G10: escalation ladder, boundary verdict). FINDINGS.md.

Feedback edges (bounded):
  • any stage → Analyst SERVICE (targeted comprehension, updates coverage.md)
  • Final Boss triager ⇄ Chain Strategist (1 iteration)
```

Each agent:
- Reads its methodology file before doing ANY work
- Reads `00-master-index.md` to load prior context
- Spawns subagents on the model per its header (§ MODEL ASSIGNMENT)
- Subagents write only their own files; the stage agent is the SOLE index writer (§ STATE DISCIPLINE)
- Writes findings to master index BEFORE moving on — no batching
- Explicitly checks all 10 failure mode guards (G1–G10) for its domain
- Runs index lint, then writes a "handoff note" listing what the next agent needs

---

## GLOBAL PROGRESS TRACKER

```
[ ] Step 1 — Mapper: Initialize + Codebase Familiarization (breadth)
[ ] Step 1.5 — Analyst: Deep Comprehension + Teach-back (GATE — G9)
[ ] Step 2 — Hunter: Hypothesis-driven Hunting + free-hunt/SAST recall net
[ ] Step 3 — Tracer: Taint Analysis
[ ] Post-3 — FINDINGS.md Part 1 generated
[ ] Step 4 — Exploiter: POC Development
[ ] Step 5 — Variant Scanner: Pattern Propagation
[ ] Step 5.5 — Chain Strategist: Exhaustive Chain Graph
[ ] Step 6 — Final Boss: Validation + Matured Triage (G10) + Verdict
[ ] Researcher Review: FINDINGS.md Part 2
```

---

## DIRECTORY STRUCTURE

```
CLAUDE.md                         ← This file
methodology/
├── 00-coordinator.md
├── 01-mapper.md
├── 01.5-analyst.md               ← Comprehension engine (G9 gate)
├── 02-hunter.md
├── 03-tracer.md
├── 04-exploiter.md
├── 05-variant-scanner.md
├── 05.5-chain-strategist.md      ← Exhaustive chain graph
└── 06-final-boss.md
comprehension/                    ← Analyst output. Consumed by Hunter/Tracer/Exploiter/Strategist/Final Boss.
├── coverage.md                   ← which subsystems are ✅ Understood (G9 gate)
├── domain-model.md
├── request-lifecycle.md
├── framework-semantics.md
├── trust-boundaries.md
├── invariants.md                 ← RANKED LEAD LIST (bidirectional: Analyst seeds, Hunter enriches)
├── security-model.md             ← intended privilege model (feeds G10 triage)
├── evolution.md
├── teach-back.md                 ← G9 proof-of-comprehension
└── subsystem/
    └── [name].md                 ← one per security-load-bearing subsystem
projectname_master/
├── 00-master-index.md            ← SINGLE SOURCE OF TRUTH
├── 01-mapper.md
├── 01.5-analyst.md
├── 02-hunter.md
├── 03-tracer.md
├── 04-exploiter.md
├── 05-variant-scanner.md
├── 05.5-chain-strategist.md
├── 06-final-boss.md
└── FINDINGS.md
projectname-local/
├── setup.sh                      ← local INSTANCE bring-up (bash/docker)
├── docker-compose.yml
└── README.md
projectname-poc/
└── [VULN-ID]-[type]/
    ├── notes.md
    ├── setup.py                  ← POC PRECONDITION script (python: register accounts, seed state)
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
## Comprehension Coverage
## Finding Lifecycle Tracker
## Attack Surface Map
## Auth & Access Control Summary
## Taint Path Summary
## Automated Scan Cross-Reference
## POC Status Board
## Variant Scan Queue
## Chain Graph
## Triage / Boundary Verdicts
## Feedback Queue
## Researcher Actions Required
## Key File References
```

---

## RULES THAT NEVER BEND

1. **No work without reading the methodology file first.** Not summarizing it. Reading it.
2. **No hunting a subsystem you have not proven you understand.** Comprehension (Step 1.5) gates Hunter/Tracer/Exploiter/Variant/Strategist. The teach-back artifact is the proof — a claim is not. (G9)
3. **No finding closed without Variant Scan queued.** Not optional.
4. **No POC accepted without a real oracle.** Not a 200 OK.
5. **No taint path older than one session used for exploitation.** Always re-read.
6. **No vuln class closed based on a single protected instance.** Never.
7. **No finding downgraded to "informational" without the escalation ladder attempted.** Try to escalate before you reject. (G10)
8. **Subagents write only their own files; the stage agent is the sole index writer.** Never parallel-write the index.
9. **Source code informs WHAT. HTTP traffic informs HOW.** Always.
10. **Write to master index after every significant action.** Not at end of session.
11. **If unsure whether a guard applies — it applies.** Default to caution.


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
- Print one line per subsystem comprehended: "[ANALYST] auth comprehended — 7 invariants, 2 unenforced"
- Print one line per chain resolved: "[CHAIN-001] unauth→admin→RCE confirmed (critical)"
- Print one line per triage downgrade with tripwire: "[TRIAGE] VULN-003 → informational (admin-by-design); revives if any unauth→admin primitive found"
- Everything else goes to files


## DECISIONS ALREADY MADE

- Local instance: generate docker-compose.yml + setup.sh, output to projectname-local/, tell researcher to run setup.sh and confirm Burp traffic. Do not ask.
- Scanner not installed: skip it, note it, move on. Do not ask.
- Stable Docker tag not obvious: use most recent non-dev tag. Do not ask.
- Ambiguous route auth: mark as "⚠️ Needs verification", continue. Do not ask.
- Comprehension scope ambiguous (is a subsystem security-load-bearing?): bias to INCLUSION — comprehend it. A blind spot is a silent failure; over-reading is bounded. Do not ask.
- Subsystem un-comprehendable (minified/obfuscated/vendored): mark `⚠️ Comprehension Blocked`, route to Researcher Actions, do NOT hunt it blind. Do not ask.
- Chain link missing (no primitive supplies the needed privilege): record a tripwire condition, do NOT invent or assume a primitive. Do not ask.
- Subagent model: assign per § MODEL ASSIGNMENT (breadth→Sonnet, judgment→Opus, fetch→Haiku). Do not default-inherit Opus for breadth. Do not ask.
