# JavaScript / TypeScript Source Code Review - Bug Hunting Reference

## Technology Stack Identification

```bash
package.json          - Node.js dependencies & scripts
*.js, *.mjs, *.cjs   - JavaScript
*.ts, *.tsx, *.mts   - TypeScript / React
*.vue                 - Vue SFC
*.svelte              - Svelte
next.config.*         - Next.js
svelte.config.js      - SvelteKit
```

## Critical Vulnerability Patterns

### 1. SQL Injection

**Vulnerable:**
```js
// BAD: string concat
db.query("SELECT * FROM users WHERE id=" + userId)
db.query(`SELECT * FROM users WHERE id=${userId}`)

// BAD: Sequelize raw
sequelize.query(`SELECT * FROM users WHERE id=${userId}`, { type: QueryTypes.SELECT })

// BAD: Knex raw
knex.raw(`SELECT * FROM users WHERE id=${userId}`)

// BAD: Prisma $queryRaw
prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id=${userId}`)
```

**Safe:**
```js
// GOOD: parameterized
db.query("SELECT * FROM users WHERE id=?", [userId])
sequelize.query("SELECT * FROM users WHERE id=?", { replacements: [userId] })
knex("users").where("id", userId)
prisma.user.findUnique({ where: { id: userId } })
prisma.$queryRaw`SELECT * FROM users WHERE id=${userId}`  // Prisma tagged template (safe)
```

**Grep:**
```bash
grep -rn "\.query(\|\.raw(\|\.execute(" --include="*.js" --include="*.ts" | grep "\+\|\${" | grep -v node_modules
grep -rn "\$queryRawUnsafe\|sequelize\.query.*\${" --include="*.ts" --include="*.js" | grep -v node_modules
```

### 2. NoSQL Injection (MongoDB)

**Vulnerable:**
```js
// BAD: pass user input directly to find
db.collection("users").find({ username: req.body.username }).toArray()
// Attacker sends: {"username": {"$gt": ""}} or {"username": {"$regex": ".*"}}

// BAD: Mongoose populate with user-controlled match
Model.find().populate({ path: 'author', match: req.body.match })  // $where injection!
```

**Safe:**
```js
// GOOD: type-check input
if (typeof username !== "string") throw new Error("Invalid input")
db.collection("users").find({ username }).toArray()

// GOOD: Mongoose sanitize
const match = sanitizeFilter(req.body.match)
Model.find().populate({ path: 'author', match })
```

**Grep:**
```bash
grep -rn "\.find(\|\.findOne(\|\.findById(" --include="*.js" | grep "req\.\|body\.\|params\." | grep -v "sanitize\|mongoSanitize\|typeof\|parseInt"
```

### 3. Command Injection / RCE

**Vulnerable:**
```js
// BAD
exec("ls " + userInput)
execSync(`ping ${userInput}`)
spawn("cmd", [userInput])
execFile(userInput)

// BAD: eval
eval(userInput)
new Function(userInput)

// BAD: deserialization
const unserialized = require('node-serialize').unserialize(userInput)  // IIFE RCE!
serialize-javascript(userInput)  // not a sink, but check usage
```

**Safe:**
```js
// GOOD: use execFile with fixed command
execFile("ping", [userInput])
// GOOD: use spawn with no shell
spawn("cmd", ["/c", userInput], { shell: false })
```

**Grep:**
```bash
grep -rn "exec(\|execSync\|spawn(\|execFile\|eval(\|new Function" --include="*.js" --include="*.ts" | grep -v node_modules | grep -v test
grep -rn "node-serialize\|vm\.run\|vm\.compile" --include="*.js" | grep -v node_modules
```

### 4. SSRF

**Vulnerable:**
```js
axios.get(userUrl)
fetch(userUrl)
http.get(userUrl)
request(userUrl)
superagent.get(userUrl)
got(userUrl)
```

**Grep:**
```bash
grep -rn "axios\.\(get\|post\|put\|delete\)\|fetch(\|http\.get\|request(\|superagent\|got(" --include="*.js" --include="*.ts" | grep "req\.\|params\.\|query\.\|body\." | grep -v node_modules
```

### 5. XSS

**Vulnerable:**
```js
// BAD: DOM sinks
element.innerHTML = userInput
element.outerHTML = userInput
document.write(userInput)
$('div').html(userInput)

// BAD: React
<div dangerouslySetInnerHTML={{__html: userInput}} />

// BAD: Vue
<div v-html="userInput"></div>

// BAD: URL-based sinks
element.src = userInput       // javascript: URI possible
location.href = userInput
eval(userInput)
setTimeout(userInput, 100)    // string form = eval
```

**Grep:**
```bash
grep -rn "innerHTML\|outerHTML\|document\.write\|dangerouslySetInner\|v-html\|\.html(" --include="*.js" --include="*.tsx" --include="*.vue" | grep -v node_modules
grep -rn "setTimeout\|setInterval" --include="*.js" | grep -v node_modules | grep -v "() =>\|function"
```

### 6. Prototype Pollution

**Vulnerable:**
```js
// BAD: recursive merge without hasOwnProperty check
_.merge(target, userInput)
_.defaultsDeep(target, userInput)
Object.assign(target, userInput)

// BAD: JSON path operations
_.set(target, userPath, userValue)

// BAD: deep-extend, hoek
deepExtend(target, userInput)
```

**Grep:**
```bash
grep -rn "\.merge(\|\.extend(\|\.defaultsDeep\|\.set(\|\.assign(" --include="*.js" | grep -v node_modules | grep -v test
grep -rn "Object\.assign\|Object\.create" --include="*.js" | grep -v node_modules
grep -rn "__proto__\|constructor\[" --include="*.js" --include="*.ts" | grep -v node_modules
```

### 7. Path Traversal

**Vulnerable:**
```js
fs.readFile(userPath)
fs.createReadStream(userPath)
path.join(base, userPath)         // insufficient
express.static(userPath)
res.sendFile(userPath)
res.download(userPath)
```

**Grep:**
```bash
grep -rn "readFile\|createReadStream\|sendFile\|download\|static(" --include="*.js" --include="*.ts" | grep -v node_modules | grep "req\.\|params\.\|query\."
```

### 8. JWT / Authentication

**Vulnerable:**
```js
// BAD: no algorithm check
jwt.verify(token, secret)                   // accepts alg:none by default
jwt.decode(token)                           // no verification at all!
jwt.verify(token, secret, { algorithms: ['none', 'HS256'] })

// BAD: hardcoded secret
const token = jwt.sign(user, "hardcoded-secret-123")
```

**Safe:**
```js
// GOOD: explicit algorithm
jwt.verify(token, secret, { algorithms: ['HS256'] })
// GOOD: env-based secret
jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] })
```

**Grep:**
```bash
grep -rn "jwt\.decode\|jwt\.sign\|jwt\.verify" --include="*.js" --include="*.ts" | grep -v node_modules
grep -rn "algorithms.*\[.*none" --include="*.js" --include="*.ts" | grep -v node_modules
```

### 9. Mass Assignment

**Vulnerable:**
```js
// BAD: Sequelize
User.create(req.body)                        // attacker sets isAdmin=true
User.update(req.body, { where: ... })

// BAD: Mongoose
User.create(req.body)
User.findByIdAndUpdate(id, req.body)

// BAD: Prisma
prisma.user.create({ data: req.body })
```

**Safe:**
```js
// GOOD: pick allowed fields
const { name, email } = req.body
User.create({ name, email })
```

**Grep:**
```bash
grep -rn "\.create(req\.body\|\.update(req\.body\|\.findByIdAndUpdate(req\." --include="*.js" --include="*.ts" | grep -v node_modules
```

### 10. PostMessage Vulnerabilities

```bash
grep -rn "postMessage\|addEventListener.*message" --include="*.js" | grep -v node_modules
# Check if origin is validated in event listener
grep -rn "event\.origin\|e\.origin" --include="*.js" | grep -v node_modules
```

### 11. CI/CD (GitHub Actions) - Expression Injection

```bash
# Taint sources in workflows
grep -rn "github\.event\.\(issue\|pull_request\|comment\|review\)" .github/workflows/
grep -rn '\${{.*github\.event' .github/workflows/

# No permissions set
grep -rn "Permissions\|permissions:" .github/workflows/ | grep -v "{}"
```

## Severity Assessment

| Finding | Severity |
|---------|----------|
| `exec(userInput)` | **Critical** |
| `eval(userInput)` | **Critical** |
| SQL concat in query | **Critical** |
| NoSQL injection (`$gt`, `$where`) | **Critical** |
| Deserialization (`node-serialize`) | **Critical** |
| `innerHTML = userInput` (stored) | **High** |
| Prototype pollution (sink reachable) | **High** |
| `jwt.decode()` no verify | **High** |
| `fs.readFile(userInput)` no sanitize | **Medium** |
| `User.create(req.body)` no whitelist | **Medium** |
