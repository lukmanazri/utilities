# Go Source Code Review - Bug Hunting Reference

## Technology Stack Identification

```bash
go.mod, go.sum      - Go modules
*.go                - Source
main.go             - Entry point
```

## Critical Vulnerability Patterns

### 1. SQL Injection

**Vulnerable:**
```go
// BAD: fmt.Sprintf in query
db.Query(fmt.Sprintf("SELECT * FROM users WHERE id=%s", userId))
db.Exec(fmt.Sprintf("INSERT INTO users (name) VALUES ('%s')", name))

// BAD: string concat
db.Query("SELECT * FROM users WHERE id=" + userId)

// BAD: GORM raw
db.Raw("SELECT * FROM users WHERE id=" + userId)
```

**Safe:**
```go
// GOOD: placeholders
db.Query("SELECT * FROM users WHERE id=$1", userId)
db.Exec("INSERT INTO users (name) VALUES ($1)", name)

// GOOD: GORM parameterized
db.Raw("SELECT * FROM users WHERE id=?", userId)
db.Where("id = ?", userId).First(&user)
```

**Grep:**
```bash
grep -rn "fmt\.Sprintf.*SELECT\|fmt\.Sprintf.*INSERT\|fmt\.Sprintf.*UPDATE\|fmt\.Sprintf.*DELETE" --include="*.go"
grep -rn "\.Query(\".*\+\|\.Exec(\".*\+" --include="*.go"
grep -rn "\.Raw(fmt\.\|\"SELECT.*\+" --include="*.go"
```

### 2. Command Injection

**Vulnerable:**
```go
// BAD: user input in command
exec.Command("sh", "-c", userInput).Run()
exec.Command("bash", "-c", "echo " + userInput).Output()
os.StartProcess(userInput, ...)
```

**Safe:**
```go
// GOOD: no shell, fixed command with args
exec.Command("ping", "-c", "3", userInput).Run()
```

**Grep:**
```bash
grep -rn "exec\.Command\|os\.StartProcess\|syscall\.Exec" --include="*.go" | grep -v test
grep -rn "sh.*-c\|bash.*-c\|cmd.*\/c" --include="*.go"
```

### 3. XSS (template.HTML)

**Vulnerable:**
```go
// BAD: raw HTML type
template.HTML(userInput)         // no escaping!
template.JS(userInput)
template.URL(userInput)
template.HTMLAttr(userInput)
template.CSS(userInput)
```

**Safe:**
```go
// GOOD: default template escaping
// {{.}} in html/template auto-escapes
template.HTMLEscapeString(userInput)
```

**Grep:**
```bash
grep -rn "template\.HTML\|template\.JS\|template\.URL\|template\.HTMLAttr\|template\.CSS" --include="*.go" | grep -v test
```

### 4. SSRF

**Vulnerable:**
```go
http.Get(userURL)
http.Post(userURL, ...)
http.NewRequest("GET", userURL, nil)
client.Do(request)  // with user-controlled Request.URL
```

**Grep:**
```bash
grep -rn "http\.Get\|http\.Post\|http\.NewRequest\|client\.Do" --include="*.go" | grep -v test
```

### 5. Path Traversal

**Vulnerable:**
```go
os.Open(userPath)
ioutil.ReadFile(userPath)
os.ReadFile(userPath)
http.ServeFile(w, r, userPath)
filepath.Join(base, userPath)  // insufficient alone
```

**Grep:**
```bash
grep -rn "os\.Open\|ioutil\.ReadFile\|os\.ReadFile\|http\.ServeFile" --include="*.go" | grep -v test
```

### 6. Race Conditions

**Vulnerable:**
```go
// BAD: map read/write without mutex (panic / data race)
var cache = make(map[string]string)
func handler(w http.ResponseWriter, r *http.Request) {
    cache[key] = value    // concurrent write without mutex!
}

// BAD: check-then-act
if user.Balance >= amount {
    user.Balance -= amount  // race window!
}
```

**Safe:**
```go
// GOOD: mutex protection
var mu sync.Mutex
mu.Lock()
cache[key] = value
mu.Unlock()

// GOOD: atomic operations
atomic.AddInt64(&counter, 1)
```

**Grep:**
```bash
grep -rn "go func\|sync\.Mutex\|sync\.RWMutex\|atomic\." --include="*.go"
grep -rn "map\[.*\]" --include="*.go" -A5 | grep -v "sync\.\|sync\.Mutex\|sync\.RWMutex\|atomic\."
```

### 7. Error Swallowing

**Vulnerable:**
```go
// BAD: error ignored
user, _ := repo.FindUser(id)
token, _ := jwt.Parse(tokenStr, ...)

// BAD: auth error swallowed
if err != nil {
    log.Println(err)
}
// continues execution anyway!
```

**Grep:**
```bash
grep -rn "_, err :=\|, _ :=" --include="*.go" | grep -v test
grep -rn "if err != nil" --include="*.go" -A2 | grep -v "return\|:=.*error\|\.Error\|fatal\|panic\|nil"
```

### 8. JWT / Authentication

```bash
grep -rn "jwt\.Parse\|jwt\.ParseWithClaims\|jwt\.SigningMethod" --include="*.go" | grep -v test
grep -rn "HS256\|HS384\|HS512" --include="*.go"  # HMAC in code = hardcoded secret?
grep -rn "\"alg\":\"none\"" --include="*.go"
```

### 9. Hardcoded Secrets

```bash
grep -rn "\"[a-zA-Z0-9+/]{30,}=\"\|secret.*=\s*\"[^\"]{8,}\"" --include="*.go" | grep -v test
grep -rn "password\|apiKey\|apiSecret\|privateKey\|accessKey" --include="*.go" | grep ":= \"\|= \""
```

### 10. Unsafe Reflection / Deserialization

```bash
grep -rn "reflect\.\|unsafe\.\|relect\.ValueOf" --include="*.go" | grep -v test
grep -rn "json\.Unmarshal\|xml\.Unmarshal\|gob\.Decode" --include="*.go" | grep -v test
```

### 11. Goroutine Leaks / DoS

```bash
grep -rn "go func" --include="*.go" | grep -v "context\.\|select\|\.Done()\|WaitGroup"
# Missing context cancellation in goroutines
```

## Severity Assessment

| Finding | Severity |
|---------|----------|
| `exec.Command("sh", "-c", userInput)` | **Critical** |
| `fmt.Sprintf("SELECT..."+userInput)` | **Critical** |
| `template.HTML(userInput)` in stored content | **High** |
| `http.Get(userInput)` without allowlist | **High** |
| `os.Open(userInput)` without path validation | **Medium** |
| Race condition on financial operation | **Medium-High** |
| Error swallowing on auth verification | **High** |
| Hardcoded JWT secret | **Critical** |
