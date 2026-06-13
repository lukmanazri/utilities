# Agent: Mapper
> Responsibility: Know what the application IS before any hunting begins.
> Output: projectname_master/01-mapper.md

---

## MAPPER JOB

You have exactly two jobs:
1. Map the attack surface completely
2. Get a running local instance with Burp proxied through it

Nothing else. Do not start hunting. Do not start analyzing auth. That is Hunter's job.
Your output is the foundation every other agent builds on — completeness here saves everyone.

---

## STEP 1 — INITIALIZE CODEBASE

```bash
# Start from repo root
find . -maxdepth 2 -name "*.md" | head -20    # README, INSTALL, CONTRIBUTING
find . -maxdepth 1 -type f                     # root-level config files
find . -name "package.json" -not -path "*/node_modules/*" | head -10
find . -name "requirements*.txt" -o -name "Pipfile" -o -name "pyproject.toml" | head -10
find . -name "go.mod" -o -name "Gemfile" -o -name "pom.xml" -o -name "build.gradle" | head -10
find . -name "Dockerfile" -o -name "docker-compose*.yml" | head -10
find . -name ".env*" -o -name "config*.yml" -o -name "config*.json" -o -name "settings*.py" | head -20
```

Read every file found above. Build a mental model of the entire application before writing anything.

---

## STEP 2 — TECH STACK IDENTIFICATION

For each detected language/framework, record:
- Language + version (from config files, not guesses)
- Framework + version
- ORM + version (critical for taint analysis later)
- Template engine + version + auto-escape behavior
- Authentication library
- Third-party libraries with security surface (crypto, serialization, file handling, HTTP clients)

**Auto-escape matters:** Document explicitly whether the template engine escapes by default. If it does not, XSS surface is dramatically larger.

---

## STEP 3 — ENTRY POINT MAPPING

Map ALL of these:

**HTTP:**
```bash
# Routes / endpoint definitions
grep -rn "app\.get\|app\.post\|app\.put\|app\.delete\|app\.patch\|app\.all\|@app\.route\|@router\." . \
  --include="*.js" --include="*.ts" --include="*.py" --include="*.rb" --include="*.go" --include="*.php" | grep -v node_modules

# Framework-specific
grep -rn "@GetMapping\|@PostMapping\|@RequestMapping\|@RestController" . --include="*.java"
grep -rn "Route::get\|Route::post\|Route::any" . --include="*.php"
grep -rn "func.*http\.Handler\|func.*http\.HandlerFunc\|r\.GET\|r\.POST" . --include="*.go"
```

**CLI / IPC / File inputs:**
```bash
grep -rn "argv\|argparse\|click\|cobra\|clap\|os\.Args\|process\.argv" . | grep -v node_modules | head -30
grep -rn "ipcMain\|ipcRenderer\|socket\.on\|ws\.on" . | grep -v node_modules | head -20
grep -rn "open(\|readFile\|fs\.read\|ioutil\.Read\|os\.Open" . | grep -v node_modules | head -30
```

**Webhooks / Message consumers:**
```bash
grep -rn "webhook\|consumer\|subscribe\|queue\|rabbit\|kafka\|celery\|sidekiq\|resque" . \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.rb" | grep -v node_modules | head -20
```

For each entry point, record:
- URL pattern / CLI invocation
- HTTP method(s) accepted
- Auth required? (check middleware chain)
- Parameters accepted (body, query, path, header)
- File: line

**This list becomes the Attack Surface Map in master index. Fill it in before moving on.**

---

## STEP 4 — CONFIGURATION & SECRETS

```bash
# Hardcoded secrets
grep -rn "password\|secret\|api_key\|apikey\|token\|private_key" . \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.yml" --include="*.json" \
  --include="*.env" --include="*.conf" --include="*.cfg" | grep -v "node_modules\|\.git\|test\|spec\|mock" | grep -v "#"

# .env files committed to repo
find . -name ".env" -not -path "*/.git/*"
find . -name ".env.*" -not -path "*/.git/*"

# Config files with real values (not templates)
find . -name "*.conf" -o -name "*.cfg" -o -name "local_settings*" | grep -v node_modules
```

Record every hardcoded credential found. These are instant findings (severity varies by what they protect).

---

## STEP 5 — MODULE MAP

```bash
# Directory structure (2 levels)
find . -type d -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" \
  -not -path "*/.venv/*" | head -60

# Import graph clues (what calls what)
grep -rn "from \.\|require(\.\|import \"\.\|include \"\." . \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.php" \
  | grep -v "node_modules\|\.git" | head -50
```

Build a service/module relationship map. Which modules handle: auth, data access, file ops, external calls, rendering?

---

## STEP 6 — LOCAL INSTANCE SETUP (2.LOCAL)
> Do this NOW, in parallel with familiarization. Do not wait for Step 8.
> A running instance is an investigative tool. Use it to observe real behavior while mapping.

### 6.1 — Find the image

Search in order:
1. `docker-compose.yml` / `docker-compose.yaml`
2. `Dockerfile`
3. `README.md`, `INSTALL.md`, `docs/` — look for "docker" or "getting started"
4. GitHub Releases / GitHub Packages (`ghcr.io/org/repo`)
5. Docker Hub (`hub.docker.com/r/org/repo`)

**Version selection:**
- Always use the latest **stable** tagged release
- Never use: `latest`, `main`, `master`, `dev`, `nightly`, `edge`, mobile-specific tags
- Pin to exact semantic version: `v2.3.1` not `v2`
- If no stable tag exists → flag in Researcher Actions Required, use most recent non-dev tag

### 6.2 — Generate projectname-local/

**docker-compose.yml** — adapt to the app, this is a template:
```yaml
version: '3.8'
services:
  app:
    image: [org/repo:PINNED_VERSION]
    ports:
      - "127.0.0.1:3000:3000"    # bind to localhost only
    environment:
      - NODE_ENV=development       # adapt
      - DEBUG=true
    labels:
      - "project=projectname-local"
  # Add db, cache, etc as required by this app
```

**setup.sh:**
```bash
#!/bin/bash
# [projectname] - Local Research Instance
# Version: PINNED_VERSION
set -e

echo "[*] Tearing down existing instance..."
docker compose down --volumes --remove-orphans 2>/dev/null || true

echo "[*] Pulling images..."
docker compose pull

echo "[*] Starting..."
docker compose up -d

echo "[*] Waiting for health..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:PORT/HEALTH_ENDPOINT > /dev/null 2>&1; then
    echo "[+] Instance healthy at http://localhost:PORT"
    exit 0
  fi
  sleep 2
done
echo "[!] Health check failed after 60s"
exit 1
```

### 6.3 — Configure Burp Proxy

```bash
# Verify the instance is up
curl -v http://localhost:PORT/

# Verify traffic routes through Burp (127.0.0.1:8080 by default)
# In exploit.py later: requests.get(url, proxies={"http": "http://127.0.0.1:8080"})
# Confirm you can see the request in Burp Proxy > HTTP history
```

**Document in master index `## Local Instance`:**
- Version deployed
- Instance URL + port
- Default credentials (from README or first-run output)
- Health check endpoint
- Burp proxy confirmed: Yes/No

### 6.4 — Observe real behavior

While the instance is running, use it:
- Browse through main flows and capture traffic in Burp
- Note real parameter names (they may differ from source variable names)
- Note real response structures (error formats, auth token format)
- Note any redirects, CSP headers, security headers
- These observations feed directly into POC construction later

---

## MAPPER OUTPUT FILE STRUCTURE

```markdown
# Mapper Output — [projectname]

## Progress
- [ ] Tech stack identified
- [ ] Entry points mapped (source + runtime)
- [ ] Config & secrets documented
- [ ] Module relationships mapped
- [ ] Local instance running
- [ ] Burp proxy configured
- [ ] Real traffic observed
- [ ] Master index Attack Surface Map populated
- [ ] Master index Local Instance section populated

## Tech Stack
| Component | Technology | Version | Notes |
|-----------|-----------|---------|-------|

## Entry Points
| ID | URL Pattern | Method(s) | Auth? | Parameters | File:Line |
|----|-------------|-----------|-------|------------|-----------|

## Configuration & Secrets Found
| Type | Value (partial) | File:Line | Risk |
|------|----------------|-----------|------|

## Module Map
<!-- Which modules handle what -->

## External Integrations
| Service | Type | File:Line | User-controlled input? |
|---------|------|-----------|----------------------|

## Local Instance
- **Version deployed:**
- **Instance URL:**
- **Ports:**
- **Default credentials:**
- **Health endpoint:**
- **Burp configured:** Yes / No
- **Setup notes:**

## Observations from Real Traffic
<!-- What Burp showed that source code alone didn't reveal -->

## Handoff Note — Mapper → Hunter
**Completed:**
**Unresolved:**
**Hunter must know:**
**Guards fired:**
**Master index updated:** [timestamp]
```

---

## MAPPER ANTI-PATTERNS (do not do these)

- Do NOT read every source file — map structure, then read selectively
- Do NOT start analyzing authentication logic — write the entry point, mark it, move on
- Do NOT assess whether a sanitizer is adequate — record the sanitizer exists, move on
- Do NOT run automated scanners — that is Hunter's job
- Do NOT write "potentially vulnerable" about anything — your job is mapping, not assessment
- Do NOT spin up the instance "later" — do it at Step 6, use it as a research tool throughout
