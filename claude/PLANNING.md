# PLANNING.md — Pipeline Reconstruction

> Blueprint for rebuilding the vuln-research pipeline so all parts (CLAUDE.md, methodology
> stages, skills, state) work together with nothing stepping on anything else. Structured so
> implementation can be fanned out across multiple subagents (incl. Sonnet) without drift or
> missed work. **Read this whole file before implementing. Implement in the wave order below.**

---

## 0. NORTH STAR — what "done and great" means

1. A researcher runs `vuln <repo>` and walks away. The pipeline deeply understands the code,
   hunts from that understanding, proves findings with real oracles, chains them, and
   delivers a matured triage verdict on each — **without missing low-hanging fruit** and
   **without corrupting its own state** under parallel subagents.
2. Every stage is gated and self-checking; an agent cannot fake progress past a gate.
3. The whole thing is internally consistent: no contradictory guards, no orphan artifacts,
   no dangling references, no unbounded loops.
4. Findings are judged for *significance*, not just reproducibility — admin→RCE in an
   admin-runs-code-by-design product is correctly downgraded, with the condition that would
   revive it recorded.

---

## 0.1 BASELINE — what we are building ON TOP OF (read before any WP)

**Canonical baseline = current GitHub `main` (`lukmanazri/utilities/claude`), EXCLUDING
`claudy/`.** Not any prior local/handed-off edits.

This matters because several pieces discussed in earlier iterations exist only in local
hand-offs and are **NOT in the repo**. Against the GitHub baseline, the following must be
*created*, not assumed-present:

- The Analyst stage (`02-analyst.md`) — **does not exist on main**; WP-7 creates it.
- Guard **G9** (comprehension gate) — **not in CLAUDE.md on main**; WP-4 creates it.
- The trust-preseed helper + comprehension mandate in `shellrc.sh` launch prompts —
  **not on main**; WP-5 (re)adds both. Do not write "keep already added."
- Master-index **§ Comprehension Coverage** — **not on main**; WP-3 creates it (alongside
  the new § Chain Graph / § Triage / § Feedback Queue).
- Hunter's hypothesis-driven rewrite, Mapper's Analyst handoff, Exploiter's comprehension
  grounding — **not on main**; WP-6/8/10 create them.

> If you instead choose a prior local hand-off as baseline, flip these WPs from "create" to
> "verify/extend." Pick ONE baseline and state it at the top of every WP hand-off. Mixed
> baselines are the #1 way this reconstruction silently drifts.

---

## 0.2 MODEL ASSIGNMENT — which model runs which agent (serves the Sonnet-subagent workflow)

The launch hardcodes `--model claude-opus-4-8`; patt-fetcher already hints `model="haiku"`.
There was no global policy. Here is the policy — assign per role by what the role needs:

| Role / agent | Model | Why |
|--------------|-------|-----|
| Coordinator (top-level orchestrator) | **Opus** | holds the whole plan, makes routing/gate decisions |
| Analyst subsystem fan-out (subagents) | **Sonnet** | parallel breadth reading; many cheap bounded readers |
| Analyst synthesis (invariants, security-model, teach-back) | **Opus** | cross-cutting judgment, the gate proof |
| Mapper | **Sonnet** | breadth enumeration |
| Hunter tracks + secondary free-hunt | **Sonnet** | parallel breadth; recall sweep |
| Tracer | **Sonnet**, escalate to **Opus** for hard taint paths | mostly mechanical slicing |
| Exploiter | **Opus** | payload reasoning, oracle design |
| Variant Scanner | **Sonnet** | mechanical sink enumeration + mini-traces |
| Chain Strategist (strategy/graph) | **Opus** | global graph reasoning |
| Chain Strategist link-hunts (subagents) | **Sonnet** | narrow bounded single-objective hunts |
| Final Boss validation | **Sonnet** | run POCs, capture oracles |
| Final Boss triager (escalation ladder, G10) | **Opus** | matured significance judgment |
| patt-fetcher | **Haiku** | mechanical fetch/extract |
| script-generator | **Sonnet** | generate + syntax-validate |

**Rule of thumb:** parallel breadth + mechanical = Sonnet; single-instance judgment = Opus;
pure fetch/transform = Haiku. The launch prompt sets the Coordinator model; each spawned
subagent must be spawned with its model per this table. State the intended model in every
agent's methodology header so the spawner doesn't default-inherit Opus for breadth work.

---

## 1. THE CORE MENTAL MODEL (everything below depends on this)

Three kinds of thing. Most past confusion came from blurring them. Keep them distinct:

- **STAGES** — sequential, gated, each owns one phase of the linear flow. Run top-to-bottom.
- **SERVICES** — bounded, re-entrant helpers callable *from inside* a stage; NOT in the linear
  flow. (targeted comprehension, single-primitive fast-track confirmation, reference lookup,
  patt-fetcher, script-generator.)
- **STATE** — the shared substrate every stage reads/writes (master index, `comprehension/`,
  chain-graph, `poc/`).

**Golden rules that fall out of this model:**
- A stage never does a service's job inline, and a service never tries to be a stage.
- **Single-writer rule:** subagents write only their OWN files; the active stage agent is the
  SOLE writer to the shared master index and merges children's outputs after they finish.
  Because stages are sequential at the top level, the index has exactly one writer at any
  instant → no locking needed, no clobber.
- **Parallelize within a node, never across a dependency edge.**

---

## 2. TARGET END-STATE

### 2.1 Canonical stage numbering (DECISION: KEEP DECIMALS — do NOT renumber)

**Implementation decision (locked):** keep decimal insertion points rather than renumbering to
00–08. Renumbering churns internal cross-refs in every stage file and invites unsafe
step-number find/replace (e.g. Mapper's own "Step 2" ≠ Hunter). Decimals keep every existing
filename and cross-reference valid; we only ADD two files. Lower mistake surface, and PLANNING
already treated the renumber as optional. Canonical scheme:

| Num | Stage | State |
|-----|-------|-------|
| 00 | coordinator | exists |
| 01 | mapper | exists |
| 01.5 | analyst | NEW (WP-7) |
| 02 | hunter | exists |
| 03 | tracer | exists |
| 04 | exploiter | exists |
| 05 | variant-scanner | exists |
| 05.5 | chain-strategist | NEW (WP-12) |
| 06 | final-boss | exists |

> Consequence: no mass rename. Existing guard refs (G1→04-exploiter, G2→05-variant,
> G7→02-hunter) stay valid. Only the two phantom refs get fixed (G8→03-tracer, chain→master
> index) and the two new files get referenced in core.

### 2.1b Implementation note — serial build merges per-file WP portions

PLANNING split CLAUDE.md across WP-2/4 (Wave 0) and WP-5 (Wave 1) for PARALLEL-subagent
safety. When implementing SERIALLY (single agent), finish each shared file in ONE coherent
pass instead — a half-edited core file handed between waves is internally inconsistent. So the
Wave-0 serial pass on CLAUDE.md also folds in WP-5's CLAUDE.md portions (architecture diagram,
progress tracker, directory structure). WP-5's `shellrc.sh` portion stays in its own slice.

### 2.2 Flow (strictly sequential top level + two bounded feedback edges)

```
01 Mapper → 02 Analyst → 03 Hunter → 04 Tracer → 05 Exploiter
          → 06 Variant Scanner → 07 Chain Strategist → 08 Final Boss [TERMINAL]

Feedback edge A (bounded, on-demand): any stage → Analyst-SERVICE (targeted comprehension)
Feedback edge B (bounded, 1 iteration): Final Boss triager ⇄ Chain Strategist
```

### 2.3 Services (re-entrant, bounded, callable from stages)

| Service | Provided by | Callers | Bound |
|---------|-------------|---------|-------|
| Targeted comprehension | Analyst (service mode) | Hunter, Tracer, Variant, Strategist | 1 subsystem/call, updates coverage.md |
| Single-primitive fast-track confirm | Tracer (service mode) | Strategist link-hunts, Final Boss rung-1 | 1 primitive, time-boxed |
| Reference lookup | skills/reference/* | Hunter, Tracer, Exploiter, Strategist | read-only |
| PATT fetch | skills/patt-fetcher | Exploiter, Strategist | live fetch, fail-soft |
| Script gen | skills/script-generator | Exploiter, Strategist | generate+validate, never execute |

### 2.4 Guard system (final, non-contradictory set)

| Guard | Purpose | Reconciliation note |
|-------|---------|---------------------|
| G1 | Insider-knowledge poison (blackbox POC) | POC-time only. Does NOT conflict with G9 (whitebox comprehension). State this in both. |
| G2 | Premature closure | unchanged |
| G3 | Pattern stagnation | unchanged |
| G4 | Context budget | **make STAGE-AWARE**: checkpoint unit = per-subsystem (Analyst), per-finding (Hunter/Tracer), per-chain (Strategist). The flat "5 files" rule breaks Analyst. |
| G5 | Single-oracle acceptance | unchanged |
| G6 | Chain blindness | **scope vs G7-strategist**: Exploiter/G6 handles standalone + obvious chains; Strategist does the exhaustive graph. No overlap. |
| G9 | Comprehension gate | **also a SERVICE**: a stage may request targeted comprehension instead of being blocked. Blocked-subsystem ≠ free hunt. |
| G10 | **NEW — Marginal-capability / boundary test** | Final Boss triager may not stamp "informational" until the escalation ladder (§2.7) has been attempted and documented. |

(G7, G8 unchanged.)

### 2.5 Finding schema (extended — defined ONCE, used everywhere)

Every finding record carries, from creation onward:

| Field | Set by | Notes |
|-------|--------|-------|
| Vuln ID, Title, Type, Severity | Hunter | existing |
| **Precondition-privilege (P)** | Hunter (provisional) → Exploiter (precise) | unauth / user / role-X / admin |
| **Capability-granted (C)** | Hunter (provisional) → Exploiter (precise) | rce / file-read / cross-tenant-read / privesc→X / … |
| **Invariant-ref** | Hunter | which INV-NNN it violates (or "+new" if it adds one back) |
| **Chain-membership** | Strategist | which CHAIN-NNN it is a node in |
| **Marginal-capability verdict** | Final Boss (G10) | valid / needs-chain / needs-lower-priv / informational(+tripwire) |

P and C are mandatory because the Strategist (graph edges) and the triager (marginal test)
both consume them. Introduce them at Hunter or those agents run on missing fields.

### 2.6 Artifact inventory (every producer + consumer — no orphans)

| Artifact | Produced by | Consumed by |
|----------|-------------|-------------|
| master index (single source of truth) | all (single-writer per stage) | all |
| comprehension/subsystem/*.md | Analyst subagents | Analyst (synthesis) |
| comprehension/domain-model.md | Analyst | Hunter, Strategist, Final Boss |
| comprehension/request-lifecycle.md | Analyst | Hunter, Tracer |
| comprehension/framework-semantics.md | Analyst | Hunter, Tracer, Exploiter |
| comprehension/trust-boundaries.md | Analyst | Hunter, Strategist |
| comprehension/invariants.md (BIDIRECTIONAL) | Analyst seeds, Hunter enriches | Hunter, Tracer, Exploiter, Strategist |
| comprehension/evolution.md | Analyst | Hunter, Variant Scanner |
| **comprehension/security-model.md (NEW)** | Analyst | **Final Boss triager (G10)** |
| comprehension/coverage.md | Analyst + service updates | Hunter, Tracer, Variant, Strategist (G9) |
| comprehension/teach-back.md | Analyst | gate proof only |
| chain-graph (master index § Chain Graph) | Strategist | Final Boss |
| triage/boundary verdicts (master index § Triage) | Final Boss | FINDINGS, researcher |
| feedback queue (master index § Feedback Queue) | Final Boss ⇄ Strategist | both |
| poc/VULN-*/ | Exploiter | Final Boss validation |

### 2.7 The matured Final Boss — escalation ladder (G10)

For EVERY finding, before any downgrade, attempt and document each rung; route each to its
**cheapest correct mechanism** (never a full pipeline re-run):

1. **Lower the entry.** Does the sink truly *require* the assumed P, or is that just where it
   was found? → targeted mini Hunter+Tracer (SERVICE) on reachability at lower privilege.
2. **Chain to supply P.** Is there a confirmed/plausible finding that grants P? → mostly
   *read* the Strategist's already-built chain graph; only fire edge-B (1 iteration) for a
   genuinely new hypothesis. If no partner exists → record a **tripwire** ("becomes critical
   if any unauth→admin primitive appears").
3. **Re-scope the boundary.** Does it grant a *different* capability that crosses a boundary
   the product claims to hold (tenant isolation, cross-org read, persistence past rotation)?
   → pure reasoning over `security-model.md`, no spawn.
4. **Aggregate.** Do several marginal findings together cross a boundary? → pure reasoning.

Only when all four fail → **Security Boundary Verdict = informational**, written as a reasoned
paragraph citing the product's security model + the tripwire condition that would revive it.
**Never delete. Never a bare "not applicable."**

---

## 3. PROBLEM THEMES → why each change exists (so implementers don't "fix" it back)

- **A — State integrity.** Single mutable index + parallel subagents = clobber. Fix: §1
  single-writer rule everywhere + index-lint at handoff + resumable per-stage sub-state.
- **B — Parallelism was wrong across stages.** Gates create cross-stage dependencies; running
  stages concurrently reads half-built state. Fix: parallelize within node only; G4
  stage-aware.
- **C — G9 reached too far and too narrow.** Variant/Strategist hunt code outside Analyst
  scope; Mapper misses cascade into invisible bugs. Fix: Analyst as SERVICE (targeted
  comprehension on demand) + Mapper exit-gate enumerates webhooks/queues/CLI/second-order +
  inclusion-biased scoping + NEW security-model.md (triager had no ground truth).
- **D — Depth bought at the cost of recall (LOW-HANGING-FRUIT RISK).** "Hunter must cite an
  invariant" suppresses bugs behind missed invariants. Fix: invariants.md BIDIRECTIONAL
  (Hunter enriches) + secondary free-hunt pass + SAST as recall net + no-match finding adds an
  invariant back. **This theme is first-class — see §3.1.**
- **E — Chain/triage loop could re-run everything.** Fix: route each ladder rung to cheapest
  mechanism; bound edge-B to 1 iteration; new primitives get one bounded delta pass, not
  re-entry; explicit definition-of-done terminates all loops.

### 3.1 RECALL SAFEGUARDS — do NOT let depth-gating hide low-hanging vulns

The new comprehension gates must never reduce what gets found. Mandatory safety nets:

1. **Hunter secondary free-hunt pass** — after hypothesis-driven hunting from invariants.md,
   run an unconstrained sink-sweep (the existing grep blocks + SAST) over all `✅ Understood`
   subsystems. Anything it surfaces that has no matching invariant → ADD the invariant back to
   invariants.md and file the finding. Depth-first does not mean breadth-skipped.
2. **SAST (opengrep/semgrep) always runs** as an independent recall channel; every TP is a
   finding regardless of whether comprehension predicted it.
3. **Inclusion-biased scoping** in Analyst — a blind spot is a silent failure (worst kind);
   over-reading is bounded and merely slower. When unsure, comprehend it.
4. **Mapper completeness gate** — webhooks, queue consumers, CLI/IPC, scheduled jobs, and
   second-order (write-here-read-there) sources explicitly enumerated, or they never reach
   comprehension → never hunted.
5. **Variant Scanner full enumeration** — already enumerates ALL sink instances; keep it, and
   let it request targeted comprehension for siblings outside Analyst's original scope.

---

## 4. WORK PACKAGES

Each WP owns a fixed file set. **In a given wave, no two WPs edit the same file.** Each WP is
independently executable by a subagent given this PLANNING.md.

### Wave 0 — FOUNDATION (sequential, single owner; touches the shared core files)

> CLAUDE.md and 00-coordinator.md are the shared core. Edit them in Wave 0 only, in sequence.
> After Wave 0 they are FROZEN (read-only) for Wave 1.

**WP-1 — Numbering + reference map**
- Owns: all filenames; produces the §6 reference map as ground truth.
- Do: rename files per §2.1; update the §6 map; nothing dangling.
- Accept: every step-number/guard/artifact reference resolves (run §5 check #1, #4).

**WP-2 — State discipline & resumability** (CLAUDE.md + 00-coordinator.md)
- Add the single-writer rule (§1) to CLAUDE.md Environment + 00 spawn protocol.
- Add **index-lint at every handoff**: every finding has a row; no orphan refs; no stale
  "never updated" timestamps; coverage/chain/triage tables internally consistent.
- Add **resumable per-stage sub-state**: each stateful stage records its own progress
  (subsystems comprehended, chain-graph status, feedback-loop position); boot sequence reads
  sub-state, not just the step table. Update BOOT SEQUENCE accordingly.
- Accept: §5 checks #8, and a described crash-mid-Analyst resumes without redo/skip.

**WP-3 — Finding schema** (00-coordinator.md master index + cross-ref the templates)
- Add P, C, invariant-ref, chain-membership, marginal-verdict columns to Finding Lifecycle
  Tracker. Add master index sections: **Chain Graph**, **Triage / Boundary Verdicts**,
  **Feedback Queue** (in addition to existing Comprehension Coverage).
- Accept: §5 check #7; schema fields named identically here and in WP-8/10/13 templates.

**WP-4 — Guard system** (CLAUDE.md guards + rules-that-never-bend + decisions)
- Reconcile per §2.4: G1↔G9 note, G4 stage-aware, G6 vs Strategist scope, G9 service+gate,
  add G10. Update "RULES THAT NEVER BEND" and "DECISIONS ALREADY MADE".
- **[G2-fix] Broken ref in guard G8:** CLAUDE.md G8 currently says "update
  `06-taint-analysis.md`" — that file does not exist. Point it at the Tracer file (`04-tracer.md`).
- **[G8-gap] Extend `## DECISIONS ALREADY MADE`** with new-stage decisions in the existing
  style, e.g. "Comprehension scope ambiguous → bias to inclusion, comprehend it, do not ask";
  "Subsystem un-comprehendable (minified) → mark Blocked + researcher, do not hunt blind";
  "Chain link missing → record tripwire, do not invent a primitive."
- **[G8-gap] Extend `## VERBOSITY RULES`** for the new stages: Analyst prints one line per
  subsystem done ("[ANALYST] auth comprehended — 7 invariants"); Strategist prints one line
  per chain ("[CHAIN-001] unauth→admin→RCE confirmed"); triager prints one line per downgrade
  with the tripwire.
- Accept: §5 checks #2, #12; G8 references a file that exists; new DECISIONS/VERBOSITY entries present.

### Wave 1 — STAGES + STRUCTURE (PARALLEL; each WP owns ONE file)

> Safe to fan out as concurrent subagents: each edits a distinct file; core files frozen.

**WP-5 — Flow & parallelism** (CLAUDE.md architecture/tracker/structure sections + shellrc.sh prompts)
- Update AGENT ARCHITECTURE diagram, GLOBAL PROGRESS TRACKER, and the explicit dependency DAG
  to the §2.2 flow incl. 07 Strategist + both feedback edges.
- **[explicit] Update CLAUDE.md `## DIRECTORY STRUCTURE`:** add the `comprehension/` tree,
  renumber `methodology/` (00–08) and `projectname_master/` to match §2.1, and **[G3-fix]
  change the POC folder's `setup.sh` → `setup.py`** (the POC precondition script is Python;
  `setup.sh` is only for the local-instance folder). Add `chain-graph`/triage artifacts where
  shown in §2.6.
- **[baseline] shellrc launch prompts:** per §0.1 these are NOT on main — (re)ADD the
  trust-preseed helper (`_trust_dir`, called in `vuln()` + `resume()`) AND the comprehension
  mandate. Then replace "run stages in parallel" with "fan out WITHIN a stage; never across a
  dependency edge." Do NOT assume either is already present.
- **[G5] Set the Coordinator launch model per §0.2** (keep Opus for the top-level launch); the
  prompt should instruct spawning subagents with their per-role models from §0.2.
- **[G10] `report()` prompt:** surface the new finding fields — boundary verdict + chain
  membership — so a per-finding report reflects triage outcome, not just the raw finding.
- Note: WP-5 is the only Wave-1 WP that touches CLAUDE.md (architecture/tracker/structure
  only, NOT the frozen guards/env sections). Coordinate so it doesn't reopen Wave-0 regions.
- Accept: §5 check #4 (step order identical in all 5 locations); POC tree shows setup.py;
  trust-preseed + comprehension mandate present in both prompts.

**WP-6 — Mapper (01)**
- Exit gate enumerates webhooks/queues/CLI/IPC/scheduled-jobs/second-order sources (recall
  safeguard #4). Handoff → Analyst. Breadth-only language retained.
- Accept: exit-gate checklist includes all five non-HTTP source classes.

**WP-7 — Analyst (02)**
- Add **security-model.md** artifact (privilege tiers, what each does by design, vendor-claimed
  boundaries — from docs/SECURITY.md). Add **service mode** (targeted single-subsystem
  comprehension on demand, updates coverage.md). Inclusion-biased scoping. Seed invariants.md
  as the *initial* (not final) lead list. Resumable per-subsystem sub-state.
- Accept: security-model.md in EXIT gate; service-mode entry path documented; §5 check #3.

**WP-8 — Hunter (03)**
- Add **secondary free-hunt pass** + SAST recall net (safeguard #1, #2); no-match finding ADDS
  an invariant back (bidirectional). Provisional P/C on every finding. G9 gate read. Each
  finding cites invariant-or-+new.
- Accept: free-hunt pass present; finding template has P, C, invariant-ref.

**WP-9 — Tracer (04)**
- Entry gate: finding cites an invariant (else bounce to Hunter). Add **service mode**
  (single-primitive fast-track confirmation) for Strategist/Final Boss callers. Resumable
  per-finding.
- Accept: service-mode contract documented; entry gate present.

**WP-10 — Exploiter (05)**
- Make P/C *precise* from the actual POC. G6 scoped to standalone + obvious chains (defer
  exhaustive graph to Strategist). Keep comprehension grounding + blackbox-first POC note.
- **[G1-fix] Broken ref:** the CHAIN REGISTRY section says "Maintained in `07-exploiter.md
  § Vulnerability Chains`" — that file does not exist. Point chain records at the master index
  **§ Chain Graph** (created in WP-3); Exploiter writes standalone/obvious chains there, the
  Strategist owns the exhaustive graph.
- Accept: P/C precision step present; G6 scope note present; no `07-exploiter.md` reference remains.

**WP-11 — Variant Scanner (06)**
- Keep full sink enumeration (safeguard #5). May call Analyst service for out-of-scope
  siblings. Per-seed resumable. Confirmed siblings carry full schema.
- Accept: targeted-comprehension call path documented.

**WP-12 — Chain Strategist (07, NEW FILE)**
- Owns chain graph + strategy (NOT the hunt). Spawns **narrow single-objective link-hunts**
  that: read comprehension only (no re-comprehend), target `✅ Understood` subsystems (G9),
  write to a chainer scratch file; **chainer is sole index-merge writer** (§1). Bounds: max
  depth ~4, max link-hunt spawns/hypothesis, consumes only confirmed findings. **App-layer
  scope** unless system/ + web-app-logic/ refs are vendored (see WP-14). Resolves-or-blocks
  ALL chains. Has its own definition-of-done.
- Accept: single-writer stated; bounds stated; G9 respected; scope decision recorded.

**WP-13 — Matured Final Boss (08)**
- Add **escalation-ladder triage (G10)** per §2.7 (4 rungs, each routed to cheapest
  mechanism). **Security Boundary Verdict** using security-model.md. Marginal-capability test.
  Never-delete + tripwire. Edge-B feedback (1 iteration). Bounded delta pass for new
  primitives. Terminal **definition-of-done** (all findings verdicted, all chains resolved,
  feedback budget spent, no pending comprehension requests).
- **[G6] MERGE, don't duplicate:** Final Boss already has a `## FEEDBACK LOOP ROUTING` table
  that sends back to Tracer/Exploiter. Rung-1 (targeted Tracer) overlaps it. Fold the existing
  routing table INTO the escalation ladder — one feedback mechanism, not two. Rungs map to:
  rung-1 → targeted Tracer/Hunter SERVICE, rung-2 → Strategist edge-B, rungs 3–4 → reasoning.
- **[G7] Verdict placement:** the marginal-capability / boundary verdict annotates **Part 1**
  entries (auto). It is NOT a Part 2 action — Part 2 stays researcher-gated and is never
  populated autonomously. The tripwire condition is recorded in the Part 1 entry.
- Accept: all 4 rungs present with routing; G10 referenced; single (merged) feedback table;
  verdict lives in Part 1; definition-of-done present; §5 #9,#10.

**WP-14 — Skills integration**
- Owns: skills/INDEX.md (+ patt-fetcher / script-generator framing as SERVICES).
- **[G4-fix] Standardize skills paths to engagement-relative.** Hunter currently points at the
  ABSOLUTE template path `~/research/.claude/skills/reference/<category>/`, but `vuln()` copies
  skills INTO the engagement dir, so at runtime the live copy is `skills/reference/...`
  (relative), which is what Exploiter correctly uses. The absolute path may be stale/empty
  during an engagement. Convert ALL skills references across every methodology file to
  engagement-relative `skills/...`. (This is a cross-file find/replace — list the touched files
  in the §6 map.)
- Reconcile dead cross-links: EITHER vendor `system/` + `web-app-logic/` reference trees OR
  prune the `../../../../` links and scope Strategist app-layer (must agree with WP-12).
- Reconcile opengrep `p/` packs vs `~/tools/semgreprules/` (vendor packs locally; point both
  Hunter and the recall net at the local path).
- Accept: §5 check #11; no dead cross-references remain; zero absolute `~/research/.claude/skills`
  references remain (all engagement-relative).

### Wave 2 — VALIDATION (sequential, last)

**WP-15 — Global consistency & dry-run**
- Run the entire §5 consistency checklist. Walk the boot sequence mentally end-to-end on a
  fictional target. Confirm every loop terminates and every artifact has a producer+consumer.
- Accept: all §5 checks pass; a written dry-run trace exists; zero open items in §7.

---

## 5. GLOBAL CONSISTENCY INVARIANTS (the "don't miss any shit" checklist)

Run after EVERY wave and in WP-15. All must hold:

1. Every stage file referenced in CLAUDE.md / 00-coordinator exists, and vice versa.
2. Every guard (G1–G10) referenced anywhere is defined in CLAUDE.md; every defined guard is
   referenced at the point(s) it fires.
3. Every artifact path mentioned (comprehension/*, master-index sections, poc/, chain-graph,
   feedback queue) has a producer AND a consumer in §2.6 — no orphans.
4. Step order is byte-identical in all 5 places: boot sequence, architecture diagram, progress
   tracker, coordinator engagement table, shellrc launch prompts.
5. Every stage file has all four: ENTRY GATE, EXIT/DONE-WHEN, HANDOFF NOTE, ANTI-PATTERNS.
6. Every handoff note's "→ Next Agent" names the actual next stage in §2.2.
7. Finding-schema fields (P, C, invariant-ref, chain-membership, marginal-verdict) appear
   consistently in coordinator master table + Hunter + Exploiter + Final Boss templates.
8. Single-writer rule documented per stateful stage; no two agents write the same state file
   concurrently anywhere in the design.
9. Every feedback edge states a budget and a terminator; no loop without an exit.
10. A reachable definition-of-done exists for the whole pipeline (Final Boss terminal).
11. Zero dead cross-references (esp. `../../../../system/` and `../../../../web-app-logic/`),
    AND zero phantom file references (`07-exploiter.md`, `06-taint-analysis.md`), AND zero
    absolute `~/research/.claude/skills` references (all skills paths engagement-relative).
12. Guard non-contradiction holds: G1↔G9 (POC vs comprehension), G4 stage-aware, G6 vs
    Strategist scope, G9 gate-and-service.
13. One baseline only (§0.1): every WP hand-off names the same baseline; no WP mixes
    "create" and "assume-present" for the same artifact.
14. Every spawned agent/subagent has a model assigned per §0.2 (stated in its methodology
    header); no breadth/mechanical role silently inherits Opus.
15. POC folder uses `setup.py` (precondition); local-instance folder uses `setup.sh`. The two
    are never conflated.

---

## 6. CROSS-REFERENCE MAP (update on any rename/addition — prevents dangling refs)

### Step-number references (where each step number appears — keep in sync on renumber)
- CLAUDE.md: BOOT SEQUENCE, AGENT ARCHITECTURE, GLOBAL PROGRESS TRACKER, DIRECTORY STRUCTURE.
- 00-coordinator.md: AGENT SPAWN, Engagement Progress table, Key File References.
- Each stage file: its own header + its HANDOFF "→ next".
- shellrc.sh: both launch prompts (vuln + resume).

### Guard references (where each guard fires — keep in sync on guard edits)
- G1 → Exploiter (05) blackbox rule. G2 → Variant Scanner (06). G4 → all stateful stages
  (now stage-specific units). G5 → Exploiter (05) oracle rules. G6 → Exploiter (05) chain;
  scope-paired with Strategist (07). G7 → Hunter (03) zero-day. G8 → Exploiter (05)/Final
  Boss (08) staleness. G9 → Hunter (03)/Tracer (04)/Variant (06)/Strategist (07) gate + Analyst
  (02) service. G10 → Final Boss (08) triage.

### Artifact references — see §2.6 producer/consumer table (authoritative).

### Master-index section references (sections all stages must keep current)
Application Summary · Engagement Progress · Comprehension Coverage · Finding Lifecycle Tracker
(+P/C/invariant/chain/verdict cols) · Attack Surface Map · Auth & AC Summary · Taint Path
Summary · Automated Scan Cross-Reference · POC Status Board · Variant Scan Queue · **Chain
Graph (new)** · **Triage / Boundary Verdicts (new)** · **Feedback Queue (new)** · Researcher
Actions Required · Key File References.

---

## 7. RISK REGISTER (known traps — do not regress these)

| # | Risk | Mitigation (where enforced) |
|---|------|------------------------------|
| R1 | Parallel subagents clobber the index | Single-writer rule (WP-2), build-time one-file-per-WP rule (§4) |
| R2 | Depth-gating hides low-hanging vulns | Recall safeguards §3.1 (WP-6/7/8/11) |
| R3 | Chain/triage loop re-runs the pipeline | Cheapest-mechanism routing + bounded edge-B + delta pass (WP-13) |
| R4 | Triager has no ground truth for "by design" | security-model.md (WP-7) feeds G10 (WP-13) |
| R5 | G9 blocks discovery in un-comprehended code | Analyst service mode (WP-7), inclusion-biased scoping |
| R6 | Mapper miss → invisible bug | Mapper completeness gate (WP-6) |
| R7 | Renumber leaves dangling refs | Reference map §6 + §5 checks #1,#4 |
| R8 | G4 breaks Analyst's deep read | Stage-aware G4 (WP-4) |
| R9 | Strategist reaches for missing refs | App-layer scope OR vendor refs (WP-12/14) |
| R10 | Crash loses mid-stage progress | Resumable sub-state + boot reads it (WP-2) |
| R11 | Mixed baseline silently drifts the rebuild | §0.1 single-baseline rule + §5 check #13 |
| R12 | Breadth subagents default to Opus (slow/expensive) | §0.2 model table + §5 check #14 |
| R13 | Phantom file refs (07-exploiter, 06-taint-analysis) survive | WP-4/WP-10 fixes + §5 check #11 |
| R14 | Stale absolute skills path empty at runtime | WP-14 path standardization + §5 check #11 |
| R15 | Two contradictory Final Boss feedback mechanisms | WP-13 merge (G6) |

---

## 8. OUT OF SCOPE (explicitly deferred — do not do now)

- Dropping privileges for internet-sourced PoCs / hardening the drondlet run profile (separate
  security pass; noted in earlier review).
- Adding offline XXE / prototype-pollution reference dirs (content work, not architecture).
- CTF-provenance cleanup in reference files (cosmetic).
- Any change to the reference-library *content* beyond the dead-link/opengrep reconciliation
  in WP-14.

---

## 9. BUILD ORDER SUMMARY (for the implementing coordinator)

```
Wave 0 (sequential, one owner):   WP-1 → WP-2 → WP-3 → WP-4     [shared core; then FREEZE]
Wave 1 (parallel subagents):      WP-5, WP-6, WP-7, WP-8, WP-9, WP-10, WP-11, WP-12, WP-13, WP-14
                                  (each owns exactly one file; core frozen)
Wave 2 (sequential, last):        WP-15  [run §5 checklist + dry-run]
```

Hand each Wave-1 WP to a subagent with: this PLANNING.md, its WP spec, and the §5 invariants.
A WP is only "done" when its own Accept criteria pass AND the §5 checklist still holds.
