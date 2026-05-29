# Vulnerability Research Template
> Security source code review template. Claude reads this on startup and follows the methodology below.

---

## Instructions for Claude
You are performing a security vulnerability research engagement on this codebase via thorough source code review. Follow every step below in order. Do not skip steps.

---

## Context & Memory Management ⚠️ IMPORTANT
You must maintain and update your progress state continuously throughout this engagement. Follow these rules strictly:

- **Before starting any step** — read `00-master-index.md` AND all existing `.md` files inside `projectname_master/` to understand what has already been completed. Never redo work that is already documented.
- **After completing any step or sub-task** — immediately write your findings into the corresponding step `.md` file AND update `00-master-index.md` before moving on. Do not batch updates.
- **After every significant discovery** — update the relevant step `.md` file AND the Master Index right away, even if the full step is not yet complete.
- **If context is lost or conversation is resumed** — your first action must always be to re-read `CLAUDE.md` then `00-master-index.md` first, then remaining step files. The Master Index is your single source of truth for where everything stands.
- **Never assume** what has been done — always verify against `00-master-index.md` before proceeding.
- **Treat `00-master-index.md` as your brain** — it connects everything. If a finding, taint path, or evidence is not cross-referenced there, it does not exist in the engagement.

---

## Directory Structure
Upon starting, derive `projectname` from the repository root folder name. Create and maintain the following structure:

```
projectname_master/
├── 00-master-index.md           ← CENTRAL NERVOUS SYSTEM — always update this
├── 02-codebase-familiarization.md
├── 03-auth-flow.md
├── 04-logic-flow.md
├── 05-vuln-skills.md
├── 05-opengrep.md
├── 05-snyk-cli.md
├── 06-taint-analysis.md
├── 07-poc-development.md
├── 08-local-setup.md
├── 09-poc-validation.md
└── FINDINGS.md
projectname-local/          ← created during Step 2, used throughout all steps
├── setup.sh
├── docker-compose.yml
└── README.md
projectname-poc/
└── [VULN-ID]-[vuln-class]/
    ├── notes.md
    └── [poc artifact]
```

---

## Global Progress Tracker
> Maintained by Claude. Updated after each step completes. This lives in CLAUDE.md and is the first thing Claude checks on resume.

- [ ] Step 1: Initialize Codebase
- [ ] Step 2: Codebase Familiarization
- [ ] Step 3: Authentication & Authorization Flow
- [ ] Step 4: Logic Flow Analysis
- [ ] Step 5: Vulnerability Research Skills + Automated Scanning
- [ ] Step 6: Taint Analysis
- [ ] Post Step 6: FINDINGS.md Part 1 Generated
- [ ] Step 7: POC Development
- [ ] Step 8: Local Instance Verification (confirm instance still clean for validation)
- [ ] Step 9: POC Validation
- [ ] Researcher Review: FINDINGS.md Part 2 Populated

---

## Step 1: Initialize Codebase
Run `/init` to initialize and understand the codebase. Once complete, write the full output into the `## code-init` subsection below, without modifying anything else in this file. Then mark Step 1 complete in the Global Progress Tracker above.

**Feed Forward → after Step 1:**
- Create `projectname_master/00-master-index.md` using the structure defined below
- Populate `## Application Summary` in the Master Index from `/init` output
- Mark Step 1 complete in Master Index Progress Tracker

### code-init
<!-- /init output will be written here by Claude -->

---

## 00-master-index.md — Structure
> THIS IS THE MOST IMPORTANT FILE IN THE ENGAGEMENT.
> Claude creates this after Step 1 and updates it continuously after every step and every finding.
> On any resume or context loss, this is the FIRST file Claude reads after CLAUDE.md.

```markdown
# Master Index — [projectname]
> Central nervous system for this vulnerability research engagement.
> Every finding, taint path, evidence reference, and step output is cross-referenced here.
> Last updated: <!-- timestamp -->

---

## Application Summary
<!-- Populated from /init output — stack, architecture, entry points overview -->

---

## Engagement Progress
| Step | Name | Status | Output File | Last Updated |
|------|------|--------|-------------|--------------|
| 1 | Initialize Codebase | ⏳ | CLAUDE.md#code-init | |
| 2 | Codebase Familiarization | ⏳ | 02-codebase-familiarization.md | |
| 3 | Authentication & Authorization Flow | ⏳ | 03-auth-flow.md | |
| 4 | Logic Flow Analysis | ⏳ | 04-logic-flow.md | |
| 5 | Vuln Skills + Automated Scanning | ⏳ | 05-vuln-skills.md / 05-opengrep.md / 05-snyk-cli.md | |
| 6 | Taint Analysis | ⏳ | 06-taint-analysis.md | |
| 7 | POC Development | ⏳ | 07-poc-development.md | |
| 8 | Local Instance Setup | ⏳ | 08-local-setup.md | |
| 9 | POC Validation | ⏳ | 09-poc-validation.md | |
<!-- Status: ⏳ Pending | 🔄 In Progress | ✅ Complete -->

---

## Finding Lifecycle Tracker
> Every suspected or confirmed finding lives here with its full thread across all steps.
> This table is the single source of truth for all finding statuses.

| Vuln ID | Title | Type | Severity | Discovered In | Evidence File:Line | Taint Path Ref | POC Path | Validation Status | FINDINGS.md |
|---------|-------|------|----------|---------------|--------------------|----------------|----------|-------------------|-------------|
<!-- Discovered In: step file where first identified e.g. 03-auth-flow.md -->
<!-- Taint Path Ref: row # in 06-taint-analysis.md Taint Paths table, or N/A -->
<!-- Type: sqli | rce | ssrf | idor | auth-bypass | path-traversal | xss | ssti | deserialize | logic | bac | 0day-candidate | other -->
<!-- Validation Status: ⏳ Pending | 🔄 POC In Progress | ✅ Confirmed | ❌ Not Reproduced | ⚠️ Partial | 🔬 Needs Manual Research -->
<!-- FINDINGS.md: Part 1 | Part 2 | Not yet added -->

---

## Attack Surface Map
> Populated from Step 2. All entry points that could be used as taint sources or attack vectors.
> Cross-referenced against taint analysis sources in Step 6.

| Entry Point | Type | File:Line | Auth Required | Taint Source? | Step 6 Ref |
|-------------|------|-----------|---------------|---------------|------------|
<!-- Taint Source?: Yes | No | Partial -->
<!-- Step 6 Ref: row # in 06-taint-analysis.md Sources table, or Pending -->

---

## Auth & Access Control Summary
> Populated from Step 3 and Step 4 BAC analysis.
> Cross-referenced against findings that involve auth/authz weaknesses.

| Component | Weakness Type | Severity | File:Line | Step Ref | Finding ID |
|-----------|--------------|----------|-----------|----------|------------|

---

## Taint Path Summary
> Populated from Step 6. Every traced taint path and whether it leads to a finding.
> Cross-referenced against the Finding Lifecycle Tracker above.

| Path # | Source | Sink | Sanitized? | Bypassable? | Finding ID | Step 6 Row |
|--------|--------|------|------------|-------------|------------|------------|

---

## Automated Scan Cross-Reference
> Populated from Step 5. Maps opengrep/snyk findings to manual analysis and final findings.

| Tool | Rule/Check | File:Line | Triaged As | Finding ID | Manual Confirmed? |
|------|-----------|-----------|------------|------------|-------------------|
<!-- Triaged As: ✅ True Positive | ❌ False Positive | ⚠️ Needs Review -->

---

## POC Status Board
> Populated from Steps 7–9. Live board of all POC development and validation status.

| Vuln ID | POC Path | Development Status | Validation Status | Evidence | Researcher Action |
|---------|----------|--------------------|-------------------|----------|-------------------|
<!-- Development Status: 🔄 In Progress | ✅ Ready | ❌ Failed -->
<!-- Validation Status: ⏳ Pending | ✅ Confirmed | ❌ Not Reproduced | ⚠️ Partial -->

---

## Researcher Actions Required
> Items that need YOUR input before Claude can proceed. Claude updates this list in real time.

| # | Action | Context | Blocking Step | Added On |
|---|--------|---------|---------------|----------|

---

## Key File References
| File | Purpose | Last Updated |
|------|---------|--------------|
| CLAUDE.md | Research template & global progress | |
| 00-master-index.md | This file — central cross-reference | |
| 02-codebase-familiarization.md | Entry points, stack, modules | |
| 03-auth-flow.md | Authn/authz lifecycle & weaknesses | |
| 04-logic-flow.md | Business logic, BAC coverage map | |
| 05-vuln-skills.md | Manual skill findings | |
| 05-opengrep.md | Opengrep scan results & triage | |
| 05-snyk-cli.md | Snyk scan results & triage | |
| 06-taint-analysis.md | Full taint paths, sources & sinks | |
| 07-poc-development.md | POC development status | |
| 08-local-setup.md | Docker setup & instance details | |
| 09-poc-validation.md | POC execution results | |
| FINDINGS.md | Part 1 (unvalidated) + Part 2 (validated) | |
```

---

## Step 2: Codebase Familiarization
**Output file:** `projectname_master/02-codebase-familiarization.md`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT CODEBASE FAMILIARIZATION SKILLS HERE -->

- Map out all entry points (HTTP endpoints, CLI args, IPC, file inputs, etc.)
- Identify the full technology stack, frameworks, and third-party libraries
- Identify all configuration files, environment variable usage, and secrets handling
- Enumerate all modules, services, and their relationships
- Identify all external integrations (APIs, databases, message queues, storage, etc.)

**2.LOCAL — Spin Up Local Instance (run in parallel with familiarization)**
> Do not wait until Step 8. A running instance is an investigative tool, not just a validation target.
> Use it NOW to observe real application behavior while mapping entry points.

- Refer to the full Local Instance Setup instructions defined in `Step 8` — execute them here at Step 2
- The output artifacts (`projectname-local/setup.sh`, `docker-compose.yml`, `README.md`) are created now
- Once the instance is healthy:
  - Use it to observe actual HTTP traffic, real response structures, real error messages
  - Use it to confirm entry points and parameter names while mapping the Attack Surface
  - Use it to validate that the stack identified from source matches runtime behavior
  - Use browser devtools or a proxy (Burp/ZAP) to capture real requests during normal app usage
- Document instance URL, exposed ports, and default credentials in `02-codebase-familiarization.md ## Local Instance`
- Update `## POC Status Board` in Master Index with the instance URL so all later steps can reference it
- **The instance should remain running throughout Steps 3–7 as an investigative aid**

**Feed Forward → after Step 2:**
- Populate `## Attack Surface Map` in `00-master-index.md` with all discovered entry points
- Mark each entry point `Taint Source?: Pending` — Step 6 will resolve this
- Update `## Engagement Progress` row for Step 2 in Master Index
- Update `## POC Status Board` in Master Index with local instance URL and port

**File structure:**
```markdown
# Codebase Familiarization

## Progress
- [ ] Skills applied
- [ ] Local instance spun up and healthy (2.LOCAL)
- [ ] Proxy configured against local instance
- [ ] Entry points mapped (source + runtime observation)
- [ ] Tech stack identified
- [ ] Config & secrets documented
- [ ] Module relationships mapped
- [ ] External integrations listed
- [ ] Master Index Attack Surface Map updated
- [ ] Master Index POC Status Board updated with instance URL

## Entry Points

## Tech Stack

## Configuration & Secrets

## Module Map

## External Integrations

## Local Instance
- **Version deployed:**
- **Instance URL:**
- **Exposed ports:**
- **Default credentials:**
- **Setup notes:**
- **Proxy configured:** Yes / No
```

---

## Step 3: Authentication & Authorization Flow
**Output file:** `projectname_master/03-auth-flow.md`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT AUTHENTICATION & AUTHORIZATION SKILLS HERE -->

- Map the full authn/authz lifecycle:
  - Session creation, token issuance, validation, refresh, and revocation
- Identify missing, bypassable, or incorrectly ordered access control checks
- Review privilege escalation paths, IDOR, and horizontal/vertical privilege boundaries
- Assess cryptographic choices for tokens/passwords (algorithms, key management, entropy)
- Map all roles, permissions, and their enforcement points

**Feed Forward → after Step 3:**
- For every weakness identified: add a provisional entry to `## Finding Lifecycle Tracker` in Master Index with status `⏳ Pending` and `Discovered In: 03-auth-flow.md`
- Populate `## Auth & Access Control Summary` in Master Index
- Update `## Engagement Progress` row for Step 3 in Master Index

**File structure:**
```markdown
# Authentication & Authorization Flow

## Progress
- [ ] Skills applied
- [ ] Authn lifecycle mapped
- [ ] Authz checks reviewed
- [ ] Privilege boundaries assessed
- [ ] Cryptographic choices reviewed
- [ ] Roles & permissions mapped
- [ ] Master Index updated with provisional findings

## Authentication Lifecycle

## Authorization Checks

## Privilege Boundaries

## Cryptographic Assessment

## Roles & Permissions Map

## Weaknesses Identified
```

---

## Step 4: Logic Flow Analysis
**Output file:** `projectname_master/04-logic-flow.md`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT LOGIC FLOW SKILLS HERE -->

- Reconstruct business logic for all critical features (auth, payments, roles, state transitions, etc.)
- Identify logic flaws, race conditions, TOCTOU issues, and incorrect assumption chains
- Look for inconsistencies between intended behavior (docs/comments) and actual implementation
- Map all state machines and transitions
- Identify any trust boundary violations between components

### 4.ZERO — Zero-Day Mindset: Function & Library Research ⚠️
> No CVE does not mean no vulnerability.
> Your job here is to understand what every significant function and library
> in this codebase is SUPPOSED to do, then determine if it actually does it safely
> under the conditions this application creates.

For every significant public function, method, or third-party library encountered during logic flow mapping:

**Step A — Do not assume safety based on absence of CVEs:**
- A function with zero known CVEs may still be:
  - Misused in a way the author never intended
  - Safe in isolation but unsafe in this specific calling context
  - Safe for the documented input range but unsafe for edge cases this app allows
  - Newly introduced and simply not yet researched by the community
  - An internal/obscure library with no CVE tracking at all

**Step B — Read the actual documentation:**
- Find the official docs for every non-trivial function/library in use
- Read what the function guarantees — and more importantly, what it does NOT guarantee
- Read the "security considerations" or "caveats" sections if they exist
- Read the changelog/release notes for the version in use — were any security fixes made in newer versions that this app hasn't adopted?
- Read any open issues or PRs on the project's repository that relate to security

**Step C — Identify assumption gaps:**
- What does the DEVELOPER assume this function does?
  (infer from how they call it, what they pass to it, what they do with its output)
- What does the function ACTUALLY guarantee per its documentation?
- Is there a gap between those two? That gap is a potential 0day surface
- Examples of common assumption gaps:
  - Dev assumes `sanitize()` handles all Unicode — docs say ASCII only
  - Dev assumes ORM auto-escapes all query types — docs say raw() is excluded
  - Dev assumes library validates input — library says caller is responsible
  - Dev assumes default config is secure — docs say security features are opt-in
  - Dev assumes function is atomic — docs say concurrent calls are not safe

**Step D — Version-specific research:**
- Identify the exact version of every library in use (from package.json, requirements.txt, go.mod, pom.xml, Gemfile.lock, etc.)
- For that exact version: is it the latest? If not, what changed in newer versions?
- Are there security-relevant behavioral differences between the version in use and the current version?
- Document any version-specific weakness in `04-logic-flow.md ## Library Research`

**Step E — Edge case analysis:**
- What happens when this function receives:
  - Empty input / null / None / undefined
  - Extremely long input (boundary conditions)
  - Unexpected type (string where int expected, array where scalar expected)
  - Special characters the developer may not have considered
  - Concurrent calls (race conditions)
  - Malformed but structurally valid input (e.g. valid JSON with unexpected keys)
- For each edge case: does the function handle it safely or does behavior become undefined/unsafe?

**Document everything found in:**
- `04-logic-flow.md ## Library Research` — per-library analysis
- `04-logic-flow.md ## Assumption Gaps` — developer assumption vs actual guarantee
- Flag any genuine assumption gap as a provisional finding in Master Index with type `0day-candidate`

### 4.BAC — Broken Access Control Analysis ⚠️
- Identify **all functions/methods/middleware** that enforce application-specific access control:
  - Look for patterns like permission checks, role guards, ownership validators, policy enforcement, decorators/annotations (e.g. `@require_role`, `canAccess()`, `authorize()`, `checkPermission()`, `isAdmin()`, etc.)
  - Check framework-specific access control mechanisms (middleware chains, guards, filters, interceptors)
- For every identified access control function, map **which endpoints/routes/actions it is applied to**
- Then audit **every endpoint/route/action** and verify:
  - Is an access control function applied?
  - Is it applied at the **correct layer** (route level, controller level, service level)?
  - Is it applied **consistently** — or only on some HTTP methods but not others (e.g. GET protected but POST is not)?
  - Is it applied **before** any business logic executes, or can it be bypassed by reaching the logic directly?
- Flag all endpoints that are **missing access control entirely**
- Flag all endpoints where access control is **present but insufficient**:
  - Wrong role/permission checked
  - Check applied after sensitive operation already executed
  - Check bypassable via parameter manipulation (e.g. IDOR — user can access other users' resources by changing an ID)
  - Horizontal vs vertical privilege confusion (user A can access user B's data)
- Document every gap as a BAC candidate finding

**Feed Forward → after Step 4:**
- For every BAC finding and logic flaw: add/update entry in `## Finding Lifecycle Tracker` in Master Index
- Update `## Auth & Access Control Summary` in Master Index with BAC coverage map results
- Cross-reference BAC findings against Step 3 auth weaknesses — if the same component is implicated, link the finding IDs
- Update `## Engagement Progress` row for Step 4 in Master Index

**File structure:**
```markdown
# Logic Flow Analysis

## Progress
- [ ] Skills applied
- [ ] Critical feature flows reconstructed
- [ ] State machines mapped
- [ ] Race conditions reviewed
- [ ] Trust boundaries assessed
- [ ] Implementation vs intent reviewed
- [ ] Library research completed (versions, docs, assumption gaps)
- [ ] 0day candidates identified and flagged in Master Index
- [ ] Access control functions identified
- [ ] BAC coverage map completed
- [ ] Missing/insufficient access control flagged
- [ ] Master Index updated with provisional findings

## Critical Feature Flows

## State Machines

## Race Conditions & TOCTOU

## Trust Boundary Analysis

## Access Control Functions
> All functions/middleware/decorators that enforce access control in this application.

| Function/Method | Location (file:line) | Type | Applied Via |
|----------------|----------------------|------|-------------|

## BAC Coverage Map
> Every endpoint/route mapped against its access control enforcement.

| Endpoint | Method | Access Control Applied | Function Used | Layer | Verdict |
|----------|--------|----------------------|---------------|-------|---------|
<!-- Verdict: ✅ Protected | ❌ Missing | ⚠️ Insufficient -->

## BAC Findings

### [BAC-001]
- **Endpoint:**
- **Method:**
- **Issue:** <!-- Missing | Insufficient | Wrong layer | IDOR | Horizontal priv | Vertical priv -->
- **Expected Control:**
- **Actual Control:**
- **File:Line:**
- **Impact:**
- **Master Index Finding ID:** <!-- assigned Vuln ID -->

## Library Research
> Per-library analysis — version, documentation gaps, assumption mismatches

| Library | Version in Use | Latest Version | Docs Reviewed | Assumption Gap Found? | Finding ID |
|---------|---------------|----------------|---------------|----------------------|------------|

## Assumption Gaps
> Developer assumption vs actual function guarantee — each gap is a 0day candidate surface

### [LIB-001] [library name]
- **Developer assumes:** 
- **Documentation actually guarantees:**
- **Gap:**
- **Edge cases that expose the gap:**
- **Provisional finding:** `0day-candidate` / None

## Zero-Day Candidates
<!-- Promoted to Master Index Finding Lifecycle Tracker with type: 0day-candidate -->

## Logic Flaws Identified
```

---

## Step 5: Vulnerability Research Skills
**Output file:** `projectname_master/05-vuln-skills.md`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT VULNERABILITY RESEARCH SKILLS HERE -->

---

### 5.ZERO — Zero-Day Research: Automated Tool Blind Spots
> Opengrep and Snyk find KNOWN patterns. This phase finds what they cannot.
> Tools match signatures. They do not read documentation. They do not understand intent.
> This phase is purely manual — it extends Step 4's library research into the scanning context.

Before running automated tools in 5.A and 5.B:

**For every library/framework flagged in Step 4 `## Library Research`:**
- Are there any known-but-unpatched issues? Check:
  - GitHub Issues tagged `security` or `vulnerability`
  - Project's security advisories page (GitHub → Security → Advisories)
  - OSV database (osv.dev) for the package and version
  - Vendor mailing lists or security contacts if applicable
- If the library has a public API or plugin system: can user-controlled input influence its internal behavior in undocumented ways?
- If the library wraps a lower-level system call: does it correctly sanitize before passing down?

**For every `0day-candidate` flagged in Step 4:**
- Construct a manual test case to verify the assumption gap is real
- Document the test case in `05-vuln-skills.md ## Zero-Day Candidates`
- This becomes a high-priority manual finding regardless of what automated tools report

**Mindset rule:**
> If a function has existed for years with no CVE, that is evidence the community
> has not looked closely — not evidence that it is safe.
> Your knowledge has a cutoff. The codebase may use patterns or versions
> that postdate your training. When in doubt: read the source of the library itself.
> Clone it if necessary. Read what it actually does, not what you think it does.

### 5.A — Automated Scanning: Opengrep (Semgrep Rules)
**Output file:** `projectname_master/05-opengrep.md`

Before running, check if opengrep is available:

```bash
which opengrep || which semgrep
```

**If NOT installed — present the researcher with a choice:**
> "Opengrep is not installed. Would you like me to install it, or skip and continue manually?"
> - **Option A: Install** → Claude runs the appropriate installer below, then proceeds
> - **Option B: Skip** → Claude marks opengrep as skipped in `05-opengrep.md` and continues to Step 5.B

**Installation (if researcher chooses Option A):**
```bash
# Option 1 — pip (recommended)
pip install opengrep

# Option 2 — via semgrep (fallback)
pip install semgrep

# Option 3 — homebrew (macOS)
brew install semgrep
```

**If installed or after installation — run the following rule sets** against the codebase root, chosen based on the detected tech stack from Step 2:

```bash
# Security audit rules (always run)
opengrep --config "p/security-audit" .

# OWASP Top 10
opengrep --config "p/owasp-top-ten" .

# Language/framework specific — apply based on detected stack:
opengrep --config "p/python" .            # if Python detected
opengrep --config "p/javascript" .        # if JS/Node detected
opengrep --config "p/typescript" .        # if TS detected
opengrep --config "p/java" .              # if Java detected
opengrep --config "p/go" .                # if Go detected
opengrep --config "p/ruby" .              # if Ruby detected
opengrep --config "p/php" .               # if PHP detected

# Web/API specific
opengrep --config "p/jwt" .               # JWT issues
opengrep --config "p/secrets" .           # hardcoded secrets
opengrep --config "p/sql-injection" .     # SQLi
opengrep --config "p/xss" .               # XSS
opengrep --config "p/command-injection" . # RCE

# Output results to file
opengrep --config "p/security-audit" --config "p/owasp-top-ten" . --json > projectname_master/opengrep-results.json
```

**Feed Forward → after 5.A:**
- For every ✅ True Positive: add entry to `## Finding Lifecycle Tracker` in Master Index with `Discovered In: 05-opengrep.md`
- Populate `## Automated Scan Cross-Reference` in Master Index with all opengrep findings and triage verdicts
- Update `## Engagement Progress` for Step 5 in Master Index

**`05-opengrep.md` file structure:**
```markdown
# Opengrep Scan Results

## Status
- [ ] Installed / Skipped (researcher choice)
- [ ] Scan completed
- [ ] Findings triaged
- [ ] True positives added to Master Index Finding Lifecycle Tracker

## Tool Version

## Rules Applied

## Scan Coverage
- **Target:**
- **Files Scanned:**
- **Rules Run:**

## Triaged Findings
| # | Rule ID | Severity | File:Line | Description | Verdict | Finding ID |
|---|---------|----------|-----------|-------------|---------|------------|
<!-- Verdict: ✅ True Positive | ❌ False Positive | ⚠️ Needs Review -->
<!-- Finding ID: assigned Vuln ID if True Positive, else N/A -->

## True Positives → Master Index
<!-- List all ✅ True Positive Vuln IDs added to Finding Lifecycle Tracker -->
```

---

### 5.B — Automated Scanning: Snyk CLI
**Output file:** `projectname_master/05-snyk-cli.md`

Before running, check if snyk is available:

```bash
which snyk
```

**If NOT installed — present the researcher with a choice:**
> "Snyk CLI is not installed. Would you like me to install it, or skip and continue manually?"
> - **Option A: Install** → Claude runs the installer below, then proceeds
> - **Option B: Skip** → Claude marks Snyk as skipped in `05-snyk-cli.md` and continues

**Installation (if researcher chooses Option A):**
```bash
# via npm (recommended)
npm install -g snyk

# Authenticate after install
snyk auth
```

**If installed or after installation — run the following scans:**

```bash
# Dependency vulnerability scan
snyk test --all-projects

# Source code SAST scan
snyk code test

# Infrastructure as Code scan (if IaC files detected)
snyk iac test

# Output results to file
snyk test --all-projects --json > projectname_master/snyk-deps-results.json
snyk code test --json > projectname_master/snyk-code-results.json
```

**Feed Forward → after 5.B:**
- For every ✅ True Positive: add entry to `## Finding Lifecycle Tracker` in Master Index with `Discovered In: 05-snyk-cli.md`
- Populate `## Automated Scan Cross-Reference` in Master Index with all snyk findings and triage verdicts
- Cross-reference snyk dependency CVEs against the tech stack in `02-codebase-familiarization.md` — if a vulnerable package is used in a sensitive flow, flag it with higher priority
- Update `## Engagement Progress` for Step 5 in Master Index

**`05-snyk-cli.md` file structure:**
```markdown
# Snyk CLI Scan Results

## Status
- [ ] Installed / Authenticated / Skipped (researcher choice)
- [ ] Dependency scan completed
- [ ] Code scan completed
- [ ] IaC scan completed (if applicable)
- [ ] Findings triaged
- [ ] True positives added to Master Index Finding Lifecycle Tracker

## Tool Version

## Scans Run
- [ ] `snyk test` — dependency vulnerabilities
- [ ] `snyk code test` — SAST
- [ ] `snyk iac test` — Infrastructure as Code

## Dependency Vulnerabilities
| # | Package | Severity | CVE | Introduced Via | Fix Available | Finding ID |
|---|---------|----------|-----|----------------|---------------|------------|

## Code Findings (SAST)
| # | Rule | Severity | File:Line | Description | Verdict | Finding ID |
|---|------|----------|-----------|-------------|---------|------------|

## IaC Findings
| # | Issue | Severity | File:Line | Description | Finding ID |
|---|-------|----------|-----------|-------------|------------|

## True Positives → Master Index
<!-- List all ✅ True Positive Vuln IDs added to Finding Lifecycle Tracker -->
```

---

### 5.C — Merge Automated Findings into Master Index
After both tools complete (or are skipped):
- Review all `✅ True Positive` entries from `05-opengrep.md` and `05-snyk-cli.md`
- Ensure every true positive has a unique Vuln ID assigned and is in `## Finding Lifecycle Tracker`
- Cross-reference automated findings against Step 3 and Step 4 provisional findings — if the same component is implicated, merge and link the finding IDs rather than duplicating
- Note any automated findings that need taint analysis confirmation → flag in `## Researcher Actions Required` in Master Index

**File structure:**
```markdown
# Vulnerability Research Skills

## Progress
- [ ] Opengrep: installed / skipped
- [ ] Opengrep: scan completed
- [ ] Opengrep: findings triaged → 05-opengrep.md
- [ ] Snyk: installed / skipped
- [ ] Snyk: scan completed
- [ ] Snyk: findings triaged → 05-snyk-cli.md
- [ ] Automated findings merged into Master Index
- [ ] Manual skills applied
- [ ] Master Index updated

## Zero-Day Candidates
> Manually researched — not from automated tools

### [0DAY-001] [library/function name]
- **Version in use:**
- **Assumption gap (from Step 4):**
- **Manual test case:**
- **Verdict:** Confirmed / Not Reproduced / Needs More Research
- **Master Index Finding ID:**

## Manual Skills Applied
- [ ] <!-- skill name -->

## Findings Per Skill

### <!-- skill name -->
```

---

## Step 6: Data Flow & Taint Analysis ⚠️ CRITICAL
**Output file:** `projectname_master/06-taint-analysis.md`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT TAINT ANALYSIS SKILLS HERE -->

> Step 6 does NOT repeat recon or scanning — that was Steps 2 and 5.
> Step 6 picks up where they left off and does one thing: **prove complete, exploitable paths from untrusted input to dangerous sink via call graph traversal.**

---

### Phase 1 — Load Prior Context (do not repeat work)
Before any analysis, read and load into working memory:
- `02-codebase-familiarization.md` → framework, tech stack, layer architecture, ORM, template engine, module map
- `00-master-index.md ## Attack Surface Map` → all entry points already enumerated — these ARE your taint sources list
- `05-opengrep.md` + `05-snyk-cli.md` → automated sink candidates already found — use these as your sink starting points
- `03-auth-flow.md ## Weaknesses Identified` + `04-logic-flow.md ## BAC Findings` → provisional findings already flagged — taint analysis should confirm or deny these first before looking for new paths

From `02-codebase-familiarization.md`, extract and note:
- Exact framework request ingestion patterns for THIS codebase (e.g. `request.args`, `req.body`, `$request->input()`)
- How data moves between layers (controller → service → repository) in THIS codebase
- ORM parameterization patterns in use
- Template engine and its auto-escape behavior

Do NOT re-enumerate entry points or re-run grep patterns already covered by Steps 2 and 5.

---

### Phase 2 — Second-Order Taint Identification ⚠️ NEW — not covered in prior steps
The only source enumeration Step 6 does that is genuinely new:

- Search for data that is **written** to a persistent store (DB, cache, file, session, queue) by one request and **read back** by another request — where the original write was user-supplied
- This is second-order taint — the source and sink live in different requests entirely and most scanners miss it entirely
- grep for storage writes that are near user input, then find where that stored key/field/column is read back:

```bash
# Find writes near user input (examples — adapt to detected stack)
grep -rn "\.save(\|\.create(\|\.insert(\|\.set(\|session\[" .
grep -rn "cache\.set\|redis\.set\|memcache\.set" .
grep -rn "open(.*'w'\|writeFile\|write(" .

# Then find reads of the same keys/fields/columns
grep -rn "\.find(\|\.get(\|\.select(\|session\.get\|cache\.get" .
```

- For each second-order path found: document the write location (source request) and read location (sink request) separately
- Add to Sources table with type `Second-Order`

---

### Phase 3 — Gap-Fill Sink Enumeration (complement Step 5, do not repeat)
Step 5 opengrep/snyk already scanned for sinks. Step 6 only fills gaps:

- Check `05-opengrep.md` and `05-snyk-cli.md` — are there sink classes NOT covered by the rules that ran?
- Check whether automated tools had false-negative blind spots for THIS codebase's specific patterns (e.g. custom query builders, wrapper functions around dangerous sinks)
- Run targeted grep ONLY for sink patterns NOT already covered:

```bash
# Custom wrapper functions around dangerous sinks — these are what scanners miss
# Find functions that wrap exec/query/eval internally but are called with user data
grep -rn "def .*query\|def .*execute\|def .*run_cmd\|function.*Query\|function.*Exec" .

# Dynamic method calls / reflection
grep -rn "__getattr__\|getattr(\|call_user_func\|invokeMethod\|\.send(" .

# Sinks inside ORM raw() escape hatches
grep -rn "\.raw(\|\.extra(\|\.RawSQL\|createNativeQuery\|nativeQuery" .
```

- Merge any new sinks found into the Sinks table alongside Step 5 results

---

### Phase 4 — Call Graph Traversal ⚠️ THE CORE — this is what Steps 2 and 5 cannot do
For every sink (from Step 5 + Phase 3 gap-fill) and every source (from Attack Surface Map + Phase 2 second-order), perform bidirectional traversal. This is the phase that actually connects them.

**Backwards slice — sink → source:**
```
Given a sink at file:line:
1. Identify the variable(s) consumed at the sink
2. Find where that variable was last assigned — read the assignment
3. Was it assigned from a function return?
   → read that function's full body
4. Was it assigned from a parameter?
   → find ALL callers of this function:
   grep -rn "function_name(" . --include="*.py" (or relevant extension)
5. For each caller: what argument is passed at that position?
   → repeat from step 1 with that argument in the caller's scope
6. Continue until you reach:
   a. An entry point from the Attack Surface Map → COMPLETE PATH ✅
   b. A hardcoded / static value → dead end ❌
   c. A sanitization function → assess in Phase 5 ⚠️
   d. A DB/cache read → check if that stored value was user-supplied (second-order) 🔄
```

**Forward slice — source → sink:**
```
Given a source (entry point) at file:line producing variable X:
1. Find every usage of X in the same scope
2. Is X passed to a function?
   → read that function — what does it do with X?
3. Is X stored (DB/session/cache/file)?
   → find where it is read back (second-order path)
4. Is X returned from the current function?
   → find all callers, trace X in their scope
5. Is X transformed (encoded, cast, formatted)?
   → does the transform sanitize, or just change form? (assess in Phase 5)
6. Continue until:
   a. X reaches a sink → COMPLETE PATH ✅
   b. X is fully sanitized before any sink → protected ✅
   c. X is discarded / never reaches a sink → dead end ❌
```

**Priority order for traversal:**
1. First — confirm or deny provisional findings from Steps 3/4/5 (these already have context)
2. Second — trace paths from HIGH-value entry points (unauthenticated endpoints, public APIs, file uploads)
3. Third — trace remaining entry points from Attack Surface Map
4. Fourth — backwards slice from any sinks NOT yet reached by forward slices

**Compound vulnerability detection:**
- If a complete path involves an endpoint flagged in Step 3 (auth weakness) or Step 4 (BAC gap) → this is a compound finding
- e.g. unauthenticated endpoint (Step 3/4) + SQL injection path (Step 6) = CRITICAL
- Link finding IDs and note the compound nature in both step files and Master Index

---

### Phase 4.5 — Sink & Sanitizer Zero-Day Assessment
> This phase sits between call graph traversal and sanitization assessment.
> After finding a path in Phase 4, before assessing the sanitizer in Phase 5:
> verify that every function in the chain actually does what you assume it does.

For every sink and every sanitizer encountered in a confirmed taint path:

**Re-read the actual implementation — not just the call site:**
- If it is a library function: find the library source, read the actual implementation
- Do not rely on the function name or your prior knowledge of what it "should" do
- The version in use may behave differently from what you know
- Look for: optional parameters that change behavior, config flags that affect safety, input-length limits that cause silent truncation

**Sink safety re-evaluation:**
- Does this sink have any "safe mode" that is NOT being used here?
  e.g. parameterized query API exists but raw string API is being called instead
- Does this sink have documented unsafe input patterns that are present in this path?
- Does this sink behave differently under concurrent access?
- Is this sink actually reached in all deployment configurations, or only some?

**Sanitizer re-evaluation:**
- Does this sanitizer's documentation explicitly claim to prevent this class of attack?
- If not explicitly documented as a security control — it is NOT a security control
- Read its source if available: does the implementation match the documentation?
- Has this sanitizer had any security-relevant changes in recent versions?
- Is the version in use older than a known-safe version?

**If you cannot verify a sink or sanitizer's behavior from documentation or source:**
- Do NOT assume it is safe
- Do NOT assume it is unsafe
- Flag it explicitly in `06-taint-analysis.md ## Unverified Behaviors` for researcher review
- Mark the path as `⚠️ Needs Manual Verification` in the Taint Paths table

### Phase 5 — Sanitization Assessment
For every sanitization function encountered during traversal — do not assume it works:

```
1. Read its full implementation
2. Is it context-appropriate?
   - HTML encode ≠ SQL escape ≠ shell escape ≠ path sanitize
   - HTML encode before a SQL sink = NOT protected
3. Is it applied BEFORE the sink or AFTER?
   - Applied after = useless
4. Is it applied on ALL code paths to the sink, or only some branches?
   - Sanitized on one branch, unsanitized on another = bypassable
5. Can it be bypassed?
   - Double encoding, null bytes, unicode normalization
   - Type confusion (array where scalar expected, integer overflow)
   - Length truncation (sanitize then truncate loses sanitization)
   - Second application (sanitized copy stored, unsanitized copy also stored)
```

Mark each path's sanitization as:
- ✅ **Effective** — correctly applied, context-appropriate, covers all branches, not bypassable
- ⚠️ **Weak** — applied but bypassable or context-inappropriate — document the bypass
- ❌ **Missing** — no sanitization between source and sink

---

**Feed Forward → after Step 6:**
- For every confirmed path: update `## Finding Lifecycle Tracker` in Master Index with `Taint Path Ref` filled
- Update `## Attack Surface Map` — mark each entry point's `Taint Source?` as Yes/No/Partial
- Update `## Taint Path Summary` in Master Index with every traced path
- For any taint path confirming a provisional finding from Steps 3/4/5: update that finding's `Taint Path Ref`
- For any NEW finding discovered only in taint analysis: add new entry to Finding Lifecycle Tracker
- Each confirmed path becomes direct input to Step 7 POC development — the traversal notes ARE the POC recipe
- Update `## Engagement Progress` row for Step 6 in Master Index

**File structure:**
```markdown
# Taint Analysis

## Progress
- [ ] Skills applied
- [ ] Phase 1: Prior context loaded from Steps 2, 3, 4, 5
- [ ] Phase 2: Second-order taint sources identified
- [ ] Phase 3: Sink gap-fill complete (complement to Step 5)
- [ ] Phase 4: Call graph traversal complete (backwards + forward slices)
- [ ] Phase 5: Sanitization assessed for all paths
- [ ] Provisional findings from Steps 3/4/5 confirmed or denied
- [ ] Compound findings identified and linked
- [ ] Master Index Taint Path Summary updated
- [ ] Master Index Finding Lifecycle Tracker updated

## Sources
> Primary sources: loaded from 00-master-index.md Attack Surface Map (do not re-enumerate)
> Second-order sources: identified in Phase 2 of this step

| # | Type | File:Line | Variable | Sanitization | Primary / Second-Order |
|---|------|-----------|----------|--------------|------------------------|

## Sinks
> Base list: loaded from 05-opengrep.md + 05-snyk-cli.md (do not re-run covered patterns)
> Gap-fill: custom wrappers and reflection patterns found in Phase 3

| # | Sink Class | File:Line | Variable Consumed | Source: Step5 / Gap-fill |
|---|-----------|-----------|-------------------|--------------------------|

## Call Graph Traversal
> One entry per traced path — document the full traversal chain

### Path [#] — [Source file:line] → [Sink file:line]
- **Slice Direction:** Backwards from sink / Forwards from source / Both
- **Traversal Chain:**
  ```
  sink @ file:line
  └── variable X ← assigned at file:line
      └── returned from function_name() @ file:line
          └── called by caller_function() @ file:line
              └── parameter receives value from request.args['param'] ← SOURCE
  ```
- **Provisional Finding Confirmed?** <!-- Yes → VULN-ID | No | New finding -->
- **Compound Finding?** <!-- Yes → link Step 3/4 finding ID | No -->
- **Verdict:** ✅ Complete path | ❌ Dead end | ⚠️ Sanitized — assess Phase 5

## Sanitization Assessment
| Path # | Sanitizer | Location | Context-Appropriate? | All Branches? | Bypassable? | Verdict |
|--------|-----------|----------|---------------------|---------------|-------------|---------|

## Second-Order Taint Cases
| # | Write Location | Read Location | Data Field | Path # |
|---|---------------|---------------|------------|--------|

## Implicit Trust Cases

## Unverified Behaviors
> Sinks or sanitizers whose actual behavior could not be confirmed from docs or source.
> Researcher must manually verify before marking path as confirmed or safe.

| # | Function | Location | Uncertainty | Action Required |
|---|----------|----------|-------------|-----------------|

## Confirmed Taint Paths → Step 7 Input
> Each row is a direct recipe for POC development in Step 7

| Path # | Finding ID | Source Request | Sink | Payload Type Needed | Sanitization Bypass Needed |
|--------|------------|---------------|------|--------------------|-----------------------------|
```


## Post Step 6: Generate FINDINGS.md
**Output file:** `projectname_master/FINDINGS.md`

Immediately after completing Step 6, consolidate all entries in the `## Finding Lifecycle Tracker` in `00-master-index.md` and populate `Part 1: Unvalidated Findings` in `FINDINGS.md`.

**Rules:**
- Use the Master Index Finding Lifecycle Tracker as the single source — do not re-derive findings from step files individually
- **Claude populates Part 1 automatically** — include every finding in the tracker regardless of confidence level. Annotate low-confidence findings with a note.
- **Claude only updates Part 2 when the researcher explicitly provides validation input** — never move a finding to Part 2 autonomously.
- When the researcher validates a finding, Claude must:
  1. Add the full entry to `Part 2: Validated Findings` with researcher notes included
  2. Mark the corresponding entry in `Part 1` with `✅ Validated — see Part 2`
  3. Update `## Finding Lifecycle Tracker` in Master Index with `FINDINGS.md: Part 2`
  4. Pre-create the POC folder and `notes.md` inside `projectname-poc/` for all Part 1 findings as POC candidates
- Never delete entries from Part 1 — even invalidated findings stay with a `❌ Invalidated` note

**FINDINGS.md structure:**
```markdown
# Findings

---

## Part 1: Unvalidated Findings
> Populated automatically by Claude after Step 6 using the Master Index Finding Lifecycle Tracker.
> Suspected vulnerabilities based on source code review — not yet confirmed.

| # | Vuln ID | Title | Severity (Est.) | CWE | File:Line | Discovered In | Taint Path Ref |
|---|---------|-------|-----------------|-----|-----------|---------------|----------------|

### [VULN-001] Title
- **Estimated Severity:**
- **CWE:**
- **Affected Component:**
- **File:Line:**
- **Description:**
- **Taint Path / Logic Flaw Summary:**
- **Discovered In:** <!-- step file where first identified -->
- **Taint Path Ref:** <!-- row # in 06-taint-analysis.md, or N/A -->
- **Automated Tool Ref:** <!-- opengrep rule / snyk check, or N/A -->
- **POC Candidate:** `projectname-poc/VULN-001-[type]/`
- **Validation Status:** `⏳ Pending`

---

## Part 2: Validated Findings
> Populated only when the researcher manually confirms a finding. Claude updates this section based on researcher input only.

| # | Vuln ID | Title | Severity | CWE | File:Line | Validated By | Validation Date |
|---|---------|-------|----------|-----|-----------|--------------|-----------------|

### [VULN-001] Title
- **Severity:**
- **CWE:**
- **Affected Component:**
- **File:Line:**
- **Description:**
- **Taint Path / Logic Flaw Summary:**
- **POC Path:**
- **Evidence:**
- **Researcher Notes:**
- **Remediation:**
- **Validated By:**
- **Validation Date:**
```

---

## Step 7: POC Development
**Output file:** `projectname_master/07-poc-development.md`
**POC artifacts:** `projectname-poc/`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT POC DEVELOPMENT SKILLS HERE -->

---

> ### ⚠️ RESEARCH PHILOSOPHY — READ THIS BEFORE WRITING A SINGLE LINE OF POC
>
> **DO NOT assume. DO NOT hallucinate. DO NOT chase easy wins.**
>
> A POC is only valid if it is derived entirely from source code evidence.
> Every parameter name, every endpoint, every payload transformation, every
> precondition — must be traced back to an actual line of code.
>
> **Easy wins are rarely the real bugs.** The most impactful vulnerabilities
> in real applications are chains — where one weakness enables another, where
> a bypassed check opens a path to a critical sink, where business logic
> assumptions collapse under unexpected input sequences.
>
> Always ask: **what does the code ACTUALLY do, not what should it do?**

---

### Pre-POC Protocol — Mandatory for every finding before writing any payload

For each finding from `## Confirmed Taint Paths → Step 7 Input` in `06-taint-analysis.md`:

#### P0 — Re-read the source code ⚠️ NON-NEGOTIABLE
Before constructing anything:
- Re-read the **full function body** of every hop in the traversal chain
- Re-read the **sink function** — not just the call site, the actual implementation
- Re-read the **source ingestion point** — exactly how does the input land?
- Re-read every **sanitizer or validator** in the path — does it actually do what its name implies?
- Re-read the **calling context** — what wraps this function? Is there middleware above it?
- **If anything in the chain looks different from what Step 6 documented → STOP. Update the taint path in `06-taint-analysis.md` first. Do not proceed with a stale path.**

#### P1 — Re-evaluate the taint path
After re-reading:
- Is the path still valid? All hops confirmed in current code?
- Are there any transformations that were missed in Step 6?
- Does input actually reach the sink in ALL execution branches, or only some?
- Is there a guard clause, early return, or exception handler that breaks the path?
- Document re-evaluation verdict in `07-poc-development.md` before continuing

#### P2 — Chain Analysis ⚠️ ALWAYS CHECK BEFORE SINGLE-STEP EXPLOIT
Do NOT immediately try to exploit the finding in isolation. First ask:
- Does this finding **enable** another finding? (e.g. auth bypass → then IDOR → then SQLi)
- Does this finding **depend on** another finding to be exploitable? (e.g. SQLi requires bypassing a role check first)
- Are there multiple findings that **compose** into a higher-severity chain?
- Check every other finding in `FINDINGS.md Part 1` — can any of them be chained with this one?
- Map the full chain before writing any POC:
  ```
  Step 1: [VULN-ID-A] bypass auth check at endpoint X
       ↓  (now attacker has session with role Y)
  Step 2: [VULN-ID-B] access admin endpoint Z (BAC gap from Step 4)
       ↓  (now attacker controls parameter W)
  Step 3: [VULN-ID-C] inject into SQL query via parameter W
       ↓
  Impact: full DB read as unauthenticated user
  ```
- **Chain priority is context-dependent — use judgment:**
  - If an individually critical finding (CVSS ≥ 9.0, direct RCE, auth bypass) is already confirmed → report it immediately as a standalone, do not hold it waiting for a chain
  - If findings are medium/high severity individually but compose into critical impact → chain first
  - If the engagement is time-boxed or near deadline → standalone critical findings take priority over chain completeness
  - If no time constraint and findings are incomplete individually → invest in chain
- Document chain in `07-poc-development.md` under `## Vulnerability Chains`
- Document chain priority decision and reasoning in the same section

#### P3 — Precondition Mapping
What must be TRUE in the application before the exploit fires?
- Does a specific user account need to exist? What role/permissions?
- Does a specific object (record, file, resource) need to exist in the DB?
- Does the app need to be in a specific state (feature flag, config value)?
- Does a prior request need to have been made (session established, token issued)?
- For each precondition: document HOW to satisfy it using the local instance
- If a precondition cannot be satisfied → flag to researcher in `## Researcher Actions Required` in Master Index

#### P4 — Oracle Definition
How will we know, with certainty, that the exploit worked?
Define this BEFORE running anything:

| Vuln Class | Oracle |
|------------|--------|
| SQLi (error-based) | Specific DB error string in response |
| SQLi (blind boolean) | Response differs between true/false condition |
| SQLi (time-based) | Response time delay ≥ N seconds |
| SQLi (UNION) | Controlled data appears in response body |
| RCE / Command injection | OOB DNS/HTTP callback received, OR file created in known path, OR command output in response |
| SSRF | OOB HTTP request received at attacker-controlled server |
| Path traversal | Known file content (e.g. `/etc/passwd` first line) appears in response |
| IDOR | Response body contains another user's PII/data |
| Auth bypass | Protected resource returned without valid credentials |
| SSTI | Math expression result appears in response (e.g. `{{7*7}}` → `49`) |
| XSS (reflected) | Payload echoed unescaped in response body |
| XSS (stored) | Payload persists and executes on subsequent page load |
| Deserialization | OOB callback, OR application error revealing gadget chain execution |
| Business logic | Measurable state change violating intended constraint (e.g. negative balance, skipped step) |

- For OOB oracles: set up a listener (`nc -lvnp PORT` or `interactsh-client`) BEFORE running the POC
- **Never accept a 200 OK or absence of error as proof of exploitation**
- **Never accept "the payload was sent" as proof — only the oracle counts**

#### P5 — Payload Construction (derived from code, not templates)
Build the payload by tracing the taint path in reverse:

```
1. Start at the sink — what exact input format does it consume?
   e.g. SQL query expects string → need to break out of string context first
   e.g. exec() expects shell string → need shell metacharacter injection
   e.g. template.render() expects template string → need template syntax

2. Work backwards through every transformation in the chain:
   - If step N applies htmlspecialchars() → does the sink care about HTML? 
     If sink is SQL, HTML encoding is irrelevant → payload passes through
   - If step N applies base64_decode() → payload must be base64 encoded
   - If step N casts to int → string payloads die here, need numeric injection
   - If step N applies regex filter → craft payload that satisfies regex but still exploits
   - Each transformation = one adjustment to the payload

3. Arrive at the source — this is the raw payload to inject at the entry point

4. Verify the payload makes sense for the input type:
   - HTTP param: URL encode special chars if needed
   - JSON body: valid JSON with payload embedded
   - HTTP header: header injection constraints apply
   - File upload: payload in filename, content, or MIME type?

5. Keep it MINIMAL — the smallest payload that proves the bug
   Do not use complex payloads when simple ones suffice
   Complex payloads introduce variables that make debugging harder
```

#### P6 — Exploit Construction
Build the exact runnable artifact. For HTTP-based vulns:

```bash
# Always derive from actual code — never guess endpoint or parameter names
# Template: adapt to actual finding

curl -v   -X [METHOD derived from route definition]   '[BASE_URL][ENDPOINT from route definition]'   -H 'Content-Type: [from endpoint handler]'   -H 'Authorization: [token obtained in precondition setup, if required]'   -d '[PAYLOAD derived from P5]'

# For chain exploits: sequence of requests, each building on the last
# Request 1: satisfy precondition / obtain token
# Request 2: use token to access intermediate resource
# Request 3: exploit final sink with controlled input
```

For non-HTTP vulns (CLI, IPC, file-based):
- Derive exact invocation from the source ingestion point identified in Phase 1
- Do NOT assume a CLI interface exists — verify from the codebase first

#### P7 — Evidence Capture Checklist
Every POC must produce captured evidence before it is considered complete:
- [ ] Full raw HTTP request (headers + body)
- [ ] Full raw HTTP response (status + headers + body)
- [ ] Oracle evidence captured:
  - OOB: screenshot of callback received
  - File: `cat` output of created/read file
  - DB: query result showing exfiltrated data
  - Timing: response time log
- [ ] Precondition setup steps documented and reproducible
- [ ] Chain steps documented in sequence if multi-step
- [ ] Clean-state reproduction: ran `setup.sh`, re-ran POC from scratch, reproduced ✅

---

### POC Folder Structure
For each finding, create `projectname-poc/[VULN-ID]-[type]/`:

```
projectname-poc/VULN-001-sqli/
├── notes.md          ← pre-flight analysis, chain map, oracle definition
├── setup.sh          ← precondition setup (create accounts, seed data, get tokens)
├── exploit.sh        ← the actual POC invocation
├── chain.md          ← if multi-step: full chain with inter-step dependencies
└── evidence/
    ├── request.txt   ← raw request
    ├── response.txt  ← raw response
    └── oracle.txt    ← oracle proof (OOB log, file content, DB output, etc.)
```

**`notes.md` template:**
```markdown
# [VULN-ID] — [Title]

## Source Code Re-read Verdict
- **Taint path still valid:** Yes / No (if No — updated in 06-taint-analysis.md)
- **New observations from re-read:**
- **Hops confirmed:**
  - [ ] Source @ file:line — confirmed
  - [ ] [function name] @ file:line — confirmed
  - [ ] [function name] @ file:line — confirmed
  - [ ] Sink @ file:line — confirmed

## Chain Analysis
- **Standalone exploitable:** Yes / No
- **Chains with:** <!-- VULN-IDs or None -->
- **Chain sequence:**
  ```
  Step 1: [VULN-ID] — [what it does] → [what it enables]
  Step 2: [VULN-ID] — [what it does] → [what it enables]
  Step N: [impact]
  ```
- **POC type:** Single-step / Chain

## Preconditions
| # | Precondition | How to Satisfy | Satisfied By |
|---|-------------|----------------|--------------|

## Oracle
- **Oracle type:**
- **Expected evidence:**
- **Listener required:** Yes (port/tool) / No

## Payload Derivation
- **Sink expects:**
- **Transformations in chain:**
  1. [transformation] → payload adjustment: [what changes]
  2. [transformation] → payload adjustment: [what changes]
- **Final raw payload:**
- **Injection point:** [parameter/header/field name from source code]

## Reproduction Steps
1. Run `setup.sh` — clean instance
2. Run `setup.sh` (preconditions) — [what it creates]
3. Run `exploit.sh`
4. Verify oracle: [exact check]
```

---

### Vulnerability Chains Registry
> Claude maintains this section in `07-poc-development.md` as chains are discovered.
> Chains always take priority over single-step POCs.

```markdown
## Vulnerability Chains

### Chain-001
- **Severity:** <!-- higher than any individual component -->
- **Steps:**
  | Step | Vuln ID | Action | Enables |
  |------|---------|--------|---------|
- **Combined Impact:**
- **POC:** `projectname-poc/chain-001/`
```

---

**Feed Forward → after Step 7:**
- Update `## POC Status Board` in Master Index with POC path and status per finding
- Update `## Finding Lifecycle Tracker` — set `POC Path` for each finding
- Flag any chains discovered to researcher via `## Researcher Actions Required` in Master Index
- Each completed POC folder is the direct input to Step 9 validation
- Update `## Engagement Progress` row for Step 7 in Master Index

**`07-poc-development.md` file structure:**
```markdown
# POC Development

## Progress
| # | Vuln ID | Type | Single/Chain | POC Path | Pre-flight Done | Status |
|---|---------|------|-------------|----------|-----------------|--------|

## Vulnerability Chains
<!-- Populated as chains are discovered — always higher priority than single-step -->

## Pre-flight Analysis Per Finding

### [VULN-001]
- **Source re-read:** ✅ Confirmed / ⚠️ Path updated / ❌ Path invalid
- **Chain analysis:** Standalone / Part of Chain-[N]
- **Preconditions mapped:** Yes / No
- **Oracle defined:** [oracle type]
- **POC Path:** `projectname-poc/VULN-001-[type]/`
- **Development Status:** 🔄 In Progress / ✅ Ready / ❌ Blocked — [reason]
```


## Step 8: Local Instance — Clean State Verification
**Output file:** `projectname_master/08-local-setup.md`

> ⚠️ The local instance was ALREADY set up during Step 2.
> Step 8 is NOT first-time setup — it is a clean-state reset before POC validation.
> The full setup instructions live here as the canonical reference, but execution started at Step 2.

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT LOCAL INSTANCE SETUP SKILLS HERE -->

### 8.CANONICAL — Local Instance Setup Reference
> This is the canonical definition of the local instance setup.
> Executed first at Step 2 (2.LOCAL). Re-executed here for clean-state validation.

#### Docker Image Discovery
Search the repository in this order:
1. `docker-compose.yml` / `docker-compose.yaml`
2. `Dockerfile`
3. `README.md`, `INSTALL.md`, `docs/`
4. GitHub Releases and GitHub Packages (`ghcr.io`)
5. Official Docker Hub listing

**Version selection rules:**
- Always use the latest **stable** tagged release
- Never use `latest`, `main`, `master`, `dev`, `nightly`, or any mobile-specific tag
- Always pin to an exact semantic version (e.g. `v2.3.1`)
- Document the chosen version and rationale in `projectname-local/README.md`

#### Setup Script
Inside `projectname-local/`, generate `setup.sh` (created at Step 2, referenced here):

```bash
#!/bin/bash
# [projectname] - Local Research Instance
# Version: <pinned version>
# Purpose: Clean, reproducible local environment for vulnerability research

set -e

# ── Cleanup ────────────────────────────────────────────────────────────────
echo "[*] Tearing down any existing instance..."
docker compose down --volumes --remove-orphans 2>/dev/null || true
docker system prune -f --filter "label=project=projectname-local" 2>/dev/null || true

# ── Pull Images ────────────────────────────────────────────────────────────
echo "[*] Pulling pinned images..."
docker compose pull

# ── Launch ─────────────────────────────────────────────────────────────────
echo "[*] Starting local instance..."
docker compose up -d

# ── Health Check ───────────────────────────────────────────────────────────
echo "[*] Waiting for services to be healthy..."
sleep 5
echo "[+] Instance ready."
echo "[+] Access: http://localhost:<port>"
```

### 8.VERIFY — Pre-Validation Clean State Check
Before Step 9 POC validation begins, verify the instance is in a known-clean state:
- Run `setup.sh` — this tears down any state accumulated during research and starts fresh
- Verify all services are healthy after restart
- Verify default credentials still work (not accidentally changed during research)
- Verify no test data or artifacts from earlier research remain in the instance
- Confirm the instance URL and ports match what is documented in Master Index `## POC Status Board`
- If any POC preconditions require specific seed data: document which POCs need it and run their `setup.sh` in Step 9

**Feed Forward → after Step 8:**
- Confirm clean instance is ready in `## POC Status Board` in Master Index
- Update `## Engagement Progress` row for Step 8 in Master Index

**File structure:**
```markdown
# Local Instance — Clean State Verification

## Progress
- [ ] setup.sh executed — clean state confirmed
- [ ] All services healthy
- [ ] Default credentials verified
- [ ] No residual research artifacts in instance
- [ ] Instance URL confirmed against Master Index POC Status Board
- [ ] Ready for Step 9 validation

## Instance Details (from Step 2)
- **Version deployed:**
- **Instance URL:**
- **Exposed ports:**
- **Default credentials:**

## Clean State Verification Notes

## Issues Found During Reset
```

---

## Step 9: POC Validation
**Output file:** `projectname_master/09-poc-validation.md`

Apply the following specialized vulnerability research skills during this step:
- [ ] <!-- INSERT POC VALIDATION SKILLS HERE -->

- Use `## POC Status Board` in Master Index to get the full list of POCs to validate and the local instance target URL
- Ensure `projectname-local/setup.sh` has been run and the instance is healthy before proceeding
- For each POC in `projectname-poc/`:
  - Execute the POC against the local instance
  - Record the **exact** result (response, behavior, error, side effect)
  - Assign validation status:
    - ✅ **Confirmed** — POC produces expected vulnerable behavior
    - ❌ **Not Reproduced** — POC did not trigger, document why
    - ⚠️ **Partial** — Some conditions met but not fully exploitable, document gap
  - Flag all `✅ Confirmed` findings to the researcher for manual review and promotion to `FINDINGS.md Part 2`
  - **Never write to `FINDINGS.md Part 2` autonomously** — only flag candidates to the researcher

**Feed Forward → after Step 9:**
- Update `## POC Status Board` in Master Index with validation status and evidence for every finding
- Update `## Finding Lifecycle Tracker` — set `Validation Status` column for every finding
- Update `## Researcher Actions Required` in Master Index — list every ✅ Confirmed finding and prompt researcher to confirm promotion to `FINDINGS.md Part 2`
- Update `## Engagement Progress` row for Step 9 in Master Index

**File structure:**
```markdown
# POC Validation

## Progress
| # | Vuln ID | POC Path | Validation Status | Evidence | Researcher Notified |
|---|---------|----------|-------------------|----------|---------------------|

## Validation Notes Per Finding

### [VULN-001]
- **Validation Status:**
- **Local Instance Target:**
- **Command / Request Used:**
- **Response / Behavior Observed:**
- **Evidence:**
- **Notes:**
- **Master Index Updated:** <!-- Yes/No -->
- **Researcher Action Required:** <!-- Confirm to promote to FINDINGS.md Part 2 -->
```

---

## FINDINGS.md — Researcher Workflow
When you are ready to validate a finding manually:
1. Tell Claude: `"Validate VULN-001 — confirmed, here are my notes: [your notes]"`
2. Claude will:
   - Move the finding into `FINDINGS.md Part 2` with your notes
   - Update `## Finding Lifecycle Tracker` in Master Index to `✅ Confirmed` and `FINDINGS.md: Part 2`
   - Update `## POC Status Board` in Master Index
   - Remove from `## Researcher Actions Required` in Master Index
3. If you want to invalidate: `"Invalidate VULN-001 — false positive"` and Claude will mark it `❌ Invalidated` in Part 1 and the Master Index without deleting it
