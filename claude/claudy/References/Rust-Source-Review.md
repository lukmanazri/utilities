# Rust Source Code Review - Bug Hunting Reference

## Technology Stack Identification

```bash
Cargo.toml, Cargo.lock  - Rust project
*.rs                    - Source
src/main.rs             - Binary entry
src/lib.rs              - Library root
```

## Unique Rust Concerns

Rust's type system prevents many traditional bugs (buffer overflows, use-after-free, null deref). Focus on logic bugs, error handling gaps, and unsafe operations.

## Critical Vulnerability Patterns

### 1. Unsafe Blocks on Network Input

**Vulnerable:**
```rust
// BAD: unsafe on raw bytes from network
let buf: &[u8] = &read_from_socket();
let ptr = buf.as_ptr();
unsafe {
    let value = ptr::read(ptr as *const u64);  // unvalidated!
    // use value
}

// BAD: unsafe transmute from network data
let bytes = tcp_stream.read(&mut buf)?;
let config: &Config = unsafe { std::mem::transmute(&bytes) };  // UB possible!
```

**Grep:**
```bash
grep -rn "unsafe {" --include="*.rs" -B5 | grep -v "test\|mod test\|#\[cfg(test)\]"
grep -rn "as \*const\|as \*mut\|transmute\|ptr::read\|ptr::write" --include="*.rs" | grep -v test
```

### 2. SQL Injection

**Vulnerable:**
```rust
// BAD: string formatting in query (diesel/sqlx)
sqlx::query(&format!("SELECT * FROM users WHERE id={}", user_id))
diesel::sql_query(format!("SELECT * FROM users WHERE id={}", user_id))

// BAD: raw query building
let query = format!("SELECT * FROM {} WHERE id={}", table, id);
conn.execute(&query, ...)?;
```

**Safe:**
```rust
// GOOD: parameterized
sqlx::query("SELECT * FROM users WHERE id=$1").bind(user_id)
diesel::users.filter(id.eq(user_id))
```

**Grep:**
```bash
grep -rn "format!.*SELECT\|format!.*INSERT\|format!.*UPDATE\|format!.*DELETE" --include="*.rs"
grep -rn "sql_query\|query(&format!" --include="*.rs"
```

### 3. Panics from Network Input (DoS)

**Vulnerable:**
```rust
// BAD: unwrap on network input
let id: u64 = input.parse().unwrap();    // DoS if input is "abc"
let value = map[key].unwrap();           // panics if missing key
let x = value.expect("should exist");    // panics

// BAD: array indexing without bounds check
let byte = buf[index];                   // panic if index >= len

// BAD: integer overflow in release (debug panics, release wraps)
let total: u32 = qty * price;            // can overflow silently
```

**Safe:**
```rust
// GOOD: handle errors
let id: u64 = input.parse().unwrap_or(0);
let id: u64 = input.parse().map_err(|e| ...)?;
let value = map.get(key).ok_or(MyError::NotFound)?;
let total = qty.checked_mul(price).ok_or(MyError::Overflow)?;
```

**Grep:**
```bash
grep -rn "\.unwrap()\|\.expect(" --include="*.rs" | grep -v test | grep -v "encode\|to_bytes\|serialize\|encode_default\|const\|static"
grep -rn "let.*=.*\[.*\]\|buf\[" --include="*.rs" | grep -v test
```

### 4. Error Swallowing (Silent Auth/Crypto Bypass)

**Vulnerable:**
```rust
// BAD: auth verification without checking
let result = verify_signature(message, sig, pubkey);
if let Ok(_) = result { ... }  // ignores error details
let _ = verify_token(token);   // result completely ignored!

// BAD: pattern matching that ignores failures
match verify_auth(token) {
    Ok(claims) => { /* authorized */ }
    _ => { /* also authorized! badly placed logic */ }
}
```

**Safe:**
```rust
// GOOD: only proceed on success
let claims = verify_auth(token)?;
// or
match verify_auth(token) {
    Ok(claims) => { /* authorized */ }
    Err(_) => return Err(Unauthorized),
}
```

**Grep:**
```bash
grep -rn "if let Ok\|let _ =\|if let Err" --include="*.rs" | grep -i "verify\|sign\|auth\|cert\|check\|validate\|permission\|role"
grep -rn "let _ =.*verify\|let _ =.*check\|let _ =.*validate\|let _ =.*auth" --include="*.rs"
```

### 5. Auth Logic in Comments (TODOs)

**Vulnerable:**
```rust
// TODO: verify signature
// FIXME: not signed for now
// HACK: skip auth in staging
// Votes are not signed for now
// Placeholder auth until we figure out keys
```

**Grep:**
```bash
grep -rn "TODO\|FIXME\|HACK\|for now\|placeholder\|not signed\|not verified\|skip auth\|bypass" --include="*.rs" | grep -i "sign\|verify\|cert\|auth\|permission\|role\|admin"
```

### 6. Memory Safety via Casting

**Vulnerable:**
```rust
// BAD: integer cast without checking
let len: usize = data.len();
let idx: u32 = user_input.parse()?;
let byte = data[idx as usize];   // idx can be 4 billion, truncate to 0!

// BAD: signed/unsigned confusion
let amount: i64 = user_input;
let result: u64 = amount as u64;  // negative becomes huge positive!
```

**Safe:**
```rust
// GOOD: try_into with error handling
let idx: usize = user_input.try_into().map_err(|_| MyError)?;
```

**Grep:**
```bash
grep -rn "as u8\|as u16\|as u32\|as u64\|as usize\|as i8\|as i16\|as i32\|as i64\|as isize" --include="*.rs" | grep -v "test\|checked\|saturating\|wrapping\|try_into"
```

### 7. Command Injection

**Vulnerable:**
```rust
// BAD: shell with user input
Command::new("sh").arg("-c").arg(user_input).output()
std::process::Command::new("bash").arg("-c").arg(format!("echo {}", input))
```

**Grep:**
```bash
grep -rn "Command::new.*sh\|Command::new.*bash\|Command::new.*cmd" --include="*.rs" | grep -v test
grep -rn "\.arg(\"-c\")\|\.arg(\"/c\")" --include="*.rs"
```

### 8. SSRF

**Vulnerable:**
```rust
// BAD: reqwest with user URL
reqwest::get(user_url).await
let client = reqwest::Client::new();
client.get(user_url).send().await
```

**Grep:**
```bash
grep -rn "reqwest::get\|client\.get\|client\.post" --include="*.rs" | grep -v test
```

### 9. Path Traversal

**Vulnerable:**
```rust
std::fs::read(user_path)
std::fs::read_to_string(user_path)
std::fs::OpenOptions::new().open(user_path)
tokio::fs::read(user_path)
```

**Grep:**
```bash
grep -rn "fs::read\|fs::read_to_string\|fs::write\|fs::open\|OpenOptions::new" --include="*.rs" | grep -v test
```

### 10. Hardcoded Secrets

```bash
grep -rn "\"[a-zA-Z0-9+/]{30,}=\"\|secret.*=.*\"[^\"]{8,}\"" --include="*.rs" | grep -v test
grep -rn "api_key\|secret_key\|private_key\|password\s*=\s*\"" --include="*.rs" | grep -v "env\|Env\|config\|test"
grep -rn "env::var" --include="*.rs" | grep -v test  # check env var usage
```

### 11. Race Conditions (Tokio/Async)

**Vulnerable:**
```rust
// BAD: check-then-act without atomic
if balance >= amount {
    // gap here - another task can modify balance
    balance -= amount;
}

// BAD: non-atomic increment
counter += 1;  // in async context with shared state

// BAD: Mutex used in async without lock holder drop
let mut guard = data.lock().unwrap();
// yield point (await) while holding lock
tokio::time::sleep(...).await;
*guard = new_value;  // deadlock or corruption
```

**Grep:**
```bash
grep -rn "if.*balance\|if.*supply\|if.*stock\|if.*quantity" --include="*.rs" -A5 | grep "=\|-=|\+="
grep -rn "\.lock()\|Mutex\|RwLock" --include="*.rs" -A3 | grep "\.await"
```

### 12. Insecure Random

```bash
grep -rn "rand::random\|rand::thread_rng" --include="*.rs" | grep "token\|password\|reset\|nonce\|secret"
grep -rn "fastrand::\|StdRng" --include="*.rs"  # potentially predictable
```

### 13. Web Framework Specific (Actix/Axum/Rocket)

```bash
# Missing auth extractors
grep -rn "pub async fn" --include="*.rs" | grep -v "auth\|Auth\|session\|Session\|Identity\|Bearer\|Authorized\|Guard\|user\|User"

# CORS misconfig
grep -rn "Cors::permissive\|allow_any_origin\|allow_any_header" --include="*.rs"
```

## Severity Assessment

| Finding | Severity |
|---------|----------|
| `unsafe` on raw network bytes without validation | **Critical** |
| `.unwrap()` on user-controlled parse | **Medium (DoS)** |
| Error swallowed on auth verification | **Critical** |
| "not signed for now" comment + no auth check | **Critical** |
| SQL format! injection | **Critical** |
| Command::new("sh").arg("-c") with user input | **Critical** |
| Race condition on financial balance | **High** |
| Hardcoded API key / crypto secret | **Critical** |
