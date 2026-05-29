# Python Source Code Review - Bug Hunting Reference

## Technology Stack Identification

```bash
# Project files
*.py           - Python source
requirements.txt / pyproject.toml / setup.py / setup.cfg / Pipfile / poetry.lock
*.cfg          - Config (tox.ini, setup.cfg)
*.ini          - Config (pytest.ini, alembic.ini)
```

## Critical Vulnerability Patterns

### 1. SQL Injection

**Vulnerable:**
```python
# BAD: string formatting
cursor.execute("SELECT * FROM users WHERE id=%s" % user_id)
cursor.execute(f"SELECT * FROM users WHERE id={user_id}")
cursor.execute("SELECT * FROM users WHERE id=" + user_id)
db.execute(text(f"SELECT * FROM {table_name}"))  # SQLAlchemy raw

# BAD: Django raw
User.objects.raw(f"SELECT * FROM users WHERE id={user_id}")
User.objects.extra(where=[f"id={user_id}"])

# BAD: Django values() with user JSONField keys (CVE-2024-42005)
Item.objects.values(f"data__{user_json_key}")
```

**Safe:**
```python
# GOOD: parameterized
cursor.execute("SELECT * FROM users WHERE id=%s", (user_id,))
db.execute(text("SELECT * FROM users WHERE id=:id"), {"id": user_id})

# GOOD: ORM
User.objects.filter(id=user_id)
session.query(User).filter(User.id == user_id)
```

**Grep:**
```bash
grep -rn "cursor\.execute\|\.raw(\|\.extra(\|text(f\"\|text(\"" --include="*.py" | grep -v "test_\|def test"
grep -rn "\.execute.*%\|\.execute.*\.format\|\.execute.*\+" --include="*.py"
```

### 2. Command Injection / RCE

**Vulnerable:**
```python
# BAD
os.system(f"ping {user_input}")
os.popen(user_input)
subprocess.call(user_input, shell=True)
subprocess.Popen(f"cmd {user_input}", shell=True)

# BAD: eval/exec
eval(user_input)
exec(user_input)
__import__(user_input)

# BAD: pickle deserialization
pickle.loads(user_data)      # RCE!
yaml.load(user_data)          # RCE! (vs safe yaml.safe_load)
marshal.loads(user_data)      # Code exec possible
dill.loads(user_data)         # RCE!
```

**Safe:**
```python
# GOOD: no shell
subprocess.call(["ping", user_input])  # shell=False
yaml.safe_load(user_data)              # use safe_load
json.loads(user_data)                  # safe
```

**Grep:**
```bash
grep -rn "os\.system\|os\.popen\|subprocess.*shell=True\|eval(\|exec(" --include="*.py" | grep -v test
grep -rn "pickle\.loads\|yaml\.load[^_]\|marshal\.loads\|dill\." --include="*.py" | grep -v test
```

### 3. SSRF

**Vulnerable:**
```python
requests.get(user_url)
requests.post(user_url)
urllib.request.urlopen(user_url)
httpx.get(user_url)
aiohttp.ClientSession().get(user_url)
```

**Grep:**
```bash
grep -rn "requests\.\(get\|post\|put\|delete\|head\|patch\)\|urllib\|httpx\|aiohttp" --include="*.py" | grep -v "test\|mock\|assert\|=\s*\""
```

### 4. SSTI (Server-Side Template Injection)

**Vulnerable:**
```python
# BAD: Jinja2
render_template_string(user_input)           # SSTI!
jinja2.Template(user_input).render()
Environment().from_string(user_input)

# BAD: Mako
Template(user_input).render()

# BAD: Django (rare, needs mark_safe/autoescape off)
render(request, 'template.html', {'user': mark_safe(user_input)})
```

**Grep:**
```bash
grep -rn "render_template_string\|\.from_string\|Template(" --include="*.py" | grep -v test
grep -rn "mark_safe\|autoescape.*off\|is_safe" --include="*.py"
```

### 5. XXE

**Vulnerable:**
```python
# BAD: lxml < 5.0 default
lxml.etree.parse(user_xml)
lxml.etree.fromstring(user_xml)

# BAD: standard library (varies by Python version)
xml.etree.ElementTree.parse(user_xml)     # pre-3.7.1 vulnerable
xml.dom.pulldom.parse(user_xml)            # may expand entities
```

**Grep:**
```bash
grep -rn "etree\.parse\|etree\.fromstring\|ElementTree\.parse\|lxml\|defusedxml" --include="*.py"
```

### 6. Path Traversal

**Vulnerable:**
```python
open(user_path)
with open(user_path) as f:
send_file(user_path)                    # Flask
send_from_directory(base, user_path)    # Flask
FileResponse(user_path)                 # FastAPI
os.path.join(base, user_path)           # insufficient alone
```

**Grep:**
```bash
grep -rn "send_file\|send_from_directory\|FileResponse\|open(\|os\.path\.join" --include="*.py" | grep -v test
```

### 7. XSS

**Vulnerable:**
```python
# Flask
return Markup(user_input)
render_template_string("{{ %s|safe }}" % user_input)

# Django
return HttpResponse(user_input)     # unescaped
mark_safe(user_input)

# FastAPI
return HTMLResponse(user_input)
```

**Grep:**
```bash
grep -rn "Markup(\|mark_safe\|HTMLResponse\|\|safe" --include="*.py"
```

### 8. Mass Assignment / ORM

**Vulnerable:**
```python
# BAD: update all fields from request
User.objects.filter(id=id).update(**request.POST)
User(**request.json).save()
Model.set(**request.data)

# BAD: WTForms without field restriction
form = UserForm(request.form)     # includes is_admin field?
```

**Grep:**
```bash
grep -rn "\.update(\*\*\|\.save(\|\.set(\*\*\|\.create(\*\*" --include="*.py" | grep -v test
```

### 9. Auth Bypass

**Vulnerable:**
```python
# BAD: decorator missing
@app.route('/admin/delete')
def admin_delete():              # no @login_required!

# BAD: role check bypassable
def is_admin(user):
    return user.get('role') == 'admin' or DEBUG_MODE  # DEBUG_MODE = True in prod?

# BAD: JWT without algorithm check
jwt.decode(token, options={"verify_signature": False})
jwt.decode(token, algorithms=['none'])  # accepts alg=none
```

**Grep:**
```bash
grep -rn "@app\.route\|@router\.\(get\|post\)" --include="*.py" -A2 | grep -v "@login_required\|@jwt_required\|@auth_required\|@permission"
grep -rn "verify_signature.*False\|algorithms.*none\|options.*verify" --include="*.py"
```

### 10. Hardcoded Secrets

```bash
grep -rn "SECRET_KEY\s*=\s*\"\|password\s*=\s*\"\|api_key\s*=\s*\"\|token\s*=\s*\"" --include="*.py" | grep -v "test\|mock\|example\|os\.environ\|os\.getenv"
grep -rn "AWS_ACCESS\|DB_PASSWORD\|REDIS_PASSWORD\|JWT_SECRET" --include="*.py" --include="*.env" --include="*.cfg"
```

### 11. Race Conditions

```bash
# Check-then-act: read balance then deduct
grep -rn "balance\|Balance\|stock\|Stock" --include="*.py" -A3 | grep "\.save\|\.update\|\.commit"
grep -rn "select_for_update\|transaction\.atomic\|with transaction" --include="*.py"  # safe patterns

# Missing transactions on write
grep -rn "\.save()\|db\.commit()\|\.update(" --include="*.py" -B5 | grep -v "transaction\|atomic\|select_for_update"
```

### 12. Django Specific

```bash
# DEBUG mode
grep -rn "DEBUG\s*=\s*True" --include="*.py"

# CSRF exempt
grep -rn "csrf_exempt" --include="*.py"

# ALLOWED_HOSTS
grep -rn "ALLOWED_HOSTS" --include="*.py"
```

### 13. Flask Specific

```bash
# Debug mode in production
grep -rn "app\.run.*debug=True\|app\.debug\s*=\s*True" --include="*.py"

# Secret key strength
grep -rn "app\.secret_key\s*=" --include="*.py"
```

## Severity Assessment

| Finding | Severity |
|---------|----------|
| `pickle.loads(user_input)` | **Critical** |
| `os.system(user_input)` | **Critical** |
| `cursor.execute("SELECT " + user_input)` | **Critical** |
| `render_template_string(user_input)` | **Critical** |
| `requests.get(user_input)` without allowlist | **High** |
| `lxml.etree.parse(user_input)` | **High** |
| `send_file(user_input)` without path validation | **High** |
| `User(**request.json).save()` without whitelist | **Medium** |
| `DEBUG = True` in production | **Medium** |
| Missing `@login_required` on sensitive endpoint | **High** |
