# VALIDATION.md — WP-15 capstone (Slice 5)

Final consistency validation of the reconstructed pipeline. Run against the build dir only
(no GitHub). Baseline per PLANNING §0.1. Numbering: decimals (01.5, 05.5).

---

## A. §5 CONSISTENCY CHECKLIST — RESULT: ALL PASS

| # | Check | Result |
|---|-------|--------|
| 1 | Every referenced methodology file exists ⇄ vice versa | ✅ |
| 2 | Every referenced guard G1–G10 is defined in CLAUDE.md; all 10 referenced | ✅ |
| 3 | Every artifact has a producer + consumer (§B table) | ✅ |
| 4 | Step order present/consistent in all 5 locations (incl. 1.5 + 5.5) | ✅ |
| 5 | Every stage file has ENTRY + EXIT/DONE-WHEN + HANDOFF + ANTI-PATTERNS | ✅ (8/8) |
| 6 | Every handoff "→ next" matches the actual next stage | ✅ (after fix, §C) |
| 7 | Finding-schema fields (P, C, invariant, chain, verdict) consistent across the 4 schema files | ✅ |
| 8 | Single-writer documented per stateful/spawning stage | ✅ (after fix, §C) |
| 9 | Every feedback edge states a budget + terminator | ✅ |
| 10 | A reachable definition-of-done exists (Final Boss terminal) | ✅ |
| 11 | Zero phantom refs / zero absolute skills paths / zero stale "Vulnerability Chains" | ✅ |
| 12 | Guard non-contradiction (G1↔G9, G4 stage-aware, G6 vs Strategist, G9 gate+service) | ✅ |
| 13 | One baseline declared (PLANNING §0.1) | ✅ |
| 14 | Every stage carries a model header (§0.2) | ✅ (8/8) |
| 15 | POC folder uses setup.py; local-instance uses setup.sh (never conflated) | ✅ |
| — | All code fences balanced (CLAUDE + 9 methodology + INDEX) | ✅ |
| — | Cross-file section refs resolve (G9→Analyst §SERVICE MODE; G10→FinalBoss §ESCALATION LADDER) | ✅ |

Mechanical batch: **16/16 pass**. Relational batch: **all pass** after the two fixes in §C.

---

## B. ARTIFACT PRODUCER → CONSUMER (no orphans)

| Artifact | Produced by | Consumed by | OK |
|----------|-------------|-------------|----|
| master index (single-writer per stage) | all stages | all stages | ✅ |
| comprehension/subsystem/*.md | Analyst subagents | Analyst synthesis | ✅ |
| comprehension/invariants.md (bidirectional) | Analyst seeds → Hunter enriches | Hunter, Tracer, Exploiter, Strategist | ✅ |
| comprehension/security-model.md | Analyst | Final Boss triager (G10) | ✅ |
| comprehension/coverage.md | Analyst + service | Hunter, Tracer, Variant, Strategist (G9 gate) | ✅ |
| comprehension/teach-back.md | Analyst | G9 gate proof | ✅ |
| § Comprehension Coverage | Analyst | downstream gate reads | ✅ |
| § Chain Graph | Exploiter (obvious) + Strategist (exhaustive) | Final Boss | ✅ |
| § Triage / Boundary Verdicts | Final Boss (G10) | FINDINGS, researcher | ✅ |
| § Feedback Queue | Final Boss ⇄ Tracer/Strategist/Analyst | the routed stages | ✅ |
| poc/VULN-*/ | Exploiter | Final Boss validation | ✅ |
| P / C fields | Hunter (provisional) → Exploiter (precise) | Strategist (edges), triager (marginal test) | ✅ |

Every artifact is both produced and consumed. No orphan producers or consumers.

---

## C. ISSUES CAUGHT BY VALIDATION (and fixed)

1. **Variant Scanner handed off to the wrong stage.** Its handoff note said
   `Variant Scanner → Final Boss` — a leftover from the OLD pipeline where Variant was the last
   stage before Final Boss. With the Chain Strategist now at Step 5.5 between them, the flow is
   Variant (5) → Strategist (5.5) → Final Boss (6). **Fixed:** handoff now `→ Chain Strategist`,
   and it flags new siblings as new confirmed chain nodes (with P/C) for the Strategist. The
   inverse refs already agreed (Strategist entry cites Variant Step 5; Final Boss entry cites
   Strategist Step 5.5), so the chain is now fully consistent.

2. **Single-writer not restated in Hunter.** Hunter runs independent tracks as parallel
   subagents (per coordinator), but its file didn't restate the single-writer rule. **Fixed:**
   added a state-discipline line — track subagents write their own notes; the Hunter stage agent
   is the sole writer that merges to the index/invariants after they finish.

No other inconsistencies found.

---

## D. END-TO-END DRY-RUN (fictional target: "Acme CMS", Node/Express + Mongo)

Walking the whole flow to prove the gates fire, state flows, and loops terminate.

**`vuln https://github.com/acme/cms`** → `_trust_dir` pre-seeds trust → tmux launches Claude
Code (Coordinator, Opus) with the thin preprompt. Boot: reads CLAUDE.md → coordinator → no master
index yet → creates it, derives projectname "acme-cms" from `target/.git`. Begins Step 1.

- **[1] Mapper (Sonnet)** maps HTTP routes + a webhook consumer + a `bullmq` job + a stored
  "profile.bio" rendered later (second-order, per the recall-hole gate). Spins the Docker
  instance, confirms Burp. EXIT GATE satisfied → handoff → Analyst. *(Writes: Attack Surface Map,
  Local Instance, Tech Stack.)*

- **[1.5] Analyst (fan-out Sonnet, synthesis Opus)** scope-selects (inclusion-biased) →
  subsystems auth, session, access-control, data-access, file, rendering, jobs. Fans out one
  subagent per subsystem (each writes only its own `subsystem/<name>.md`). Synthesis (sole writer)
  builds domain-model, request-lifecycle (3 endpoint traces), **security-model.md** (tiers:
  anon/user/editor/admin; admin "installs plugins → code-exec by design"; claimed boundary
  "tenants isolated"), **invariants.md** (INV-001 "order belongs to session.user" — unenforced;
  INV-014 "bio is escaped before render" — partial), and **teach-back** (no unknowns → passes).
  coverage.md: all `✅ Understood` except `jobs` = `⚠️ Comprehension Blocked` (minified worker) →
  Researcher Action. **G9 now armed.** Handoff → Hunter.

- **[2] Hunter (Sonnet)** reads coverage + invariants. Hypothesis pass from INV-001 → confirms an
  **IDOR** (P=user, C=cross-tenant-read) citing INV-001. Recall sweep (H6) finds an **auth bypass**
  in the webhook route that the invariants hadn't named → **adds INV-022 back** (bidirectional,
  source=Hunter), files it (P=unauth, C=privesc→admin). SAST flags a `child_process.exec` →
  **command-injection** candidate (P=admin, C=rce). `jobs` left untouched (G9). All findings carry
  provisional P/C. Handoff → Tracer.

- **[3] Tracer (Sonnet)** confirms taint paths for the three (full backward slices). Marks IDOR +
  auth-bypass + cmd-injection as confirmed paths. *(G9: all in understood subsystems.)* Handoff →
  Exploiter.

- **[4] Exploiter (Opus)** builds POCs through Burp with real oracles (G5). Sets **precise P/C**
  from the working POCs: VULN-001 IDOR {user→cross-tenant-read}, VULN-022 auth-bypass
  {unauth→admin}, VULN-031 cmd-injection {admin→rce}. Records the obvious standalone entries in
  § Chain Graph (G6 scope: leaves the exhaustive graph to Strategist). Handoff → Variant Scanner.

- **[5] Variant Scanner (Sonnet)** enumerates ALL `exec(`/`.find(` instances. Finds a sibling
  cmd-injection on an **editor**-reachable route → VULN-031b {editor→rce} (stronger P than seed).
  Closes the classes (G2: all instances triaged). Handoff → **Chain Strategist** (corrected).

- **[5.5] Chain Strategist (strategy Opus, link-hunts Sonnet)** builds the graph from confirmed
  nodes. Edge found: VULN-022 {C=admin} satisfies VULN-031 {P=admin} ⟹ **CHAIN-001:
  unauth → admin → rce = CRITICAL.** No missing link (no link-hunt needed). Records CHAIN-001
  ✅ Confirmed, queues the chain POC to Exploiter (bounded). Sole-writer merge to § Chain Graph.
  Handoff → Final Boss.

- **[6] Final Boss (validation Sonnet, triager Opus)** clean-reset → re-runs every POC (oracles
  fire). **Phase 2.7 escalation ladder (G10):** VULN-031 alone {admin→rce} → marginal capability
  ~0 vs security-model.md (admin runs code by design). Ladder: rung 1 (Tracer service: sink needs
  admin role check, not reachable lower) ✗; **rung 2 reads § Chain Graph → CHAIN-001 already
  supplies admin from unauth** ✓ → VULN-031 is NOT downgraded; it's a critical chain component.
  Contrast: a hypothetical "admin can edit theme files" finding with no chain → ladder all-fail →
  **Boundary Verdict = informational + TRIPWIRE** ("revives if any unauth/user→admin appears").
  Note the tripwire is *already* tripped by VULN-022 in this run, so even that flips critical —
  demonstrating the tripwire mechanism. Definition-of-done: all findings verdicted, CHAIN-001
  resolved, feedback budgets closed, `jobs` still in Researcher Actions, Part 2 NOT auto-populated.
  Terminal handoff → Researcher.

**Loop termination check:** the only loops are (a) Analyst SERVICE MODE — one subsystem per call,
logged; (b) reproducibility send-backs — 1 pass each; (c) edge-B Strategist⇄triager — 1 iteration.
All bounded, all logged in § Feedback Queue. No cycle can spin. ✅

**Recall check (low-hanging fruit):** the auth bypass came from the H6 recall sweep, NOT the
invariant list — and the bidirectional rule pulled it back into invariants.md. The second-order
"bio" sink was enumerated by Mapper's completeness gate. Depth-gating did not suppress either. ✅

**Result:** the pipeline holds end-to-end. Comprehension gates hunting, hunting is hypothesis-
driven with a recall net, P/C flow from Hunter→Exploiter→Strategist→triager, chains compose,
the matured triager escalates-before-downgrading with a revivable tripwire, and the whole thing
terminates at a clean definition-of-done.

---

## E. RECONSTRUCTION COMPLETE

All work packages delivered across Slices 1–5. The pipeline is internally consistent and the
new capabilities (comprehension gate, recall safeguards, chain strategist, matured triage,
single-writer state discipline, per-role models) are wired together with no orphan artifacts,
no contradictory guards, no dangling references, and no unbounded loops.

Remaining (your action, not blocking): run `fix-reference-links.sh --apply` against your
reference tree (WP-14b), and decide vendor-vs-prune for `system/`/`web-app-logic/` if you want
OS-level chaining.
