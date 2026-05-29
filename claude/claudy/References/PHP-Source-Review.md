# PHP Source Code Review - Bug Hunting Reference

## Technology Stack Identification

```bash
*.php           - PHP source
composer.json   - Dependencies
.htaccess       - Apache config
wp-content/*    - WordPress
```

## Critical Vulnerability Patterns

### 1. SQL Injection

**Vulnerable:**
```php
// BAD: mysql_ (removed in PHP 7, still in legacy code)
mysql_query("SELECT * FROM users WHERE id=" . $_GET['id']);

// BAD: mysqli with string concat
$mysqli->query("SELECT * FROM users WHERE id=" . $_GET['id']);
mysqli_query($conn, "SELECT * FROM users WHERE id={$_GET['id']}");

// BAD: PDO without prepare (emulated prepares = still vulnerable!)
$pdo->query("SELECT * FROM users WHERE id=" . $_GET['id']);
$pdo->exec("DELETE FROM users WHERE id=" . $_GET['id']);

// BAD: Laravel DB::raw
DB::select(DB::raw("SELECT * FROM users WHERE id=" . $_GET['id']));
DB::table('users')->whereRaw("id = {$_GET['id']}");
```

**Safe:**
```php
// GOOD: PDO prepared statements
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$_GET['id']]);

// GOOD: Laravel parameterized
DB::table('users')->where('id', $_GET['id'])->get();
```

**Grep:**
```bash
grep -rn "mysql_query\|mysqli_query\|->query(\|->exec(\|DB::raw\|DB::select" --include="*.php" | grep -v "test\|Test"
grep -rn "\$_GET\|\$_POST\|\$_REQUEST" --include="*.php" | grep "SELECT\|INSERT\|UPDATE\|DELETE"
```

### 2. Command Injection / RCE

**Vulnerable:**
```php
// BAD
system($_GET['cmd']);
exec($_GET['cmd']);
shell_exec($_GET['cmd']);
passthru($_GET['cmd']);
popen($_GET['cmd'], 'r');
proc_open($_GET['cmd'], ...);
`{$_GET['cmd']}`;  // backtick operator

// BAD: eval
eval($_GET['code']);
assert($_GET['code']);  // evaluates string in PHP < 8
create_function($_GET['args'], $_GET['code']);  // deprecated, still in old code
preg_replace('/.*/e', $_GET['code'], '');       // e modifier deprecated
```

**Grep:**
```bash
grep -rn "system(\|exec(\|shell_exec(\|passthru(\|popen(\|proc_open\|eval(\|assert(\|create_function" --include="*.php" | grep -v test
grep -rn "preg_replace.*\/e" --include="*.php"
```

### 3. File Inclusion (LFI / RFI / Path Traversal)

**Vulnerable:**
```php
// BAD: LFI
include($_GET['page']);
require($_GET['file']);
include_once($_GET['template']);
require_once("pages/" . $_GET['page'] . ".php");

// BAD: file read
file_get_contents($_GET['path']);
readfile($_GET['path']);
fopen($_GET['path'], 'r');
```

**Grep:**
```bash
grep -rn "include(\|require(\|include_once(\|require_once(" --include="*.php" | grep "\$_GET\|\$_POST\|\$_REQUEST"
grep -rn "file_get_contents\|readfile\|fopen" --include="*.php" | grep "\$\|_GET\|_POST\|_REQUEST"
```

### 4. Deserialization (Phar + Unserialize)

**Vulnerable:**
```php
// BAD: unserialize
$obj = unserialize($_GET['data']);

// BAD: phar wrapper (deserialization via file operations!)
file_get_contents('phar://' . $_GET['file'] . '.phar');
include('phar://' . $_GET['file']);
fopen('phar://' . $_GET['file'], 'r');
```

**Grep:**
```bash
grep -rn "unserialize\|phar://" --include="*.php" | grep -v test
```

### 5. Type Juggling

**Vulnerable:**
```php
// BAD: loose comparison
if ($_POST['password'] == $stored_hash) { ... }     // 0 == "string" = true!
if ($_POST['token'] == $expected) { ... }            // type juggling!
if (md5($_GET['pwd']) == '0e123456789') { ... }     // magic hash

// BAD: in_array without strict
if (in_array($role, ['admin', 'user'])) { ... }      // 1 == true -> matches any!
```

**Safe:**
```php
// GOOD: strict comparison
if ($_POST['password'] === $stored_hash) { ... }
if (in_array($role, ['admin', 'user'], true)) { ... }
```

**Grep:**
```bash
grep -rn "==.*password\|==.*token\|==.*hash\|==.*secret" --include="*.php"
grep -rn "in_array.*false\)" --include="*.php"  # missing strict param
```

### 6. XSS

**Vulnerable:**
```php
echo $_GET['name'];
print $_POST['comment'];
<?= $_GET['q'] ?>

// BAD: strip_tags insufficient (event handlers survive)
echo strip_tags($input);  // <img onerror=alert(1)> survives!
```

**Safe:**
```php
echo htmlspecialchars($_GET['name'], ENT_QUOTES, 'UTF-8');
```

**Grep:**
```bash
grep -rn "echo \$\|print \$\|<?=\$" --include="*.php" | grep "_GET\|_POST\|_REQUEST" | grep -v "htmlspecialchars\|htmlentities\|escape"
```

### 7. SSRF

**Vulnerable:**
```php
file_get_contents($_GET['url']);
curl_exec($ch) with CURLOPT_URL = $_GET['url'];
fopen($_GET['url'], 'r');
```

**Grep:**
```bash
grep -rn "curl_exec\|curl_setopt.*CURLOPT_URL\|file_get_contents" --include="*.php" | grep "\$\|_GET\|_POST"
```

### 8. Authentication / Session

**Vulnerable:**
```php
// BAD: cookie auth without crypto
if ($_COOKIE['user_id'] == 1) { $is_admin = true; }

// BAD: session fixation
session_start();  // no session_regenerate_id()

// BAD: hardcoded passwords
$admin_password = "admin123";
if ($_POST['password'] == $admin_password) { ... }

// BAD: PHP hash comparison
password_verify($_POST['pass'], $hash);  // this is actually GOOD - use this!
```

**Grep:**
```bash
grep -rn "\$_COOKIE.*admin\|\$_COOKIE.*role\|\$_COOKIE.*auth" --include="*.php"
grep -rn "password\s*=\s*[\"']" --include="*.php" | grep -v "password_verify\|password_hash"
grep -rn "session_start\|session_id\|session_regenerate" --include="*.php"
```

### 9. File Upload

**Vulnerable:**
```php
// BAD: no extension check
move_uploaded_file($_FILES['file']['tmp_name'], "/uploads/" . $_FILES['file']['name']);

// BAD: blacklist extension check
$ext = pathinfo($_FILES['file']['name'], PATHINFO_EXTENSION);
if ($ext != "php") { move_uploaded_file(...); }  // .php5, .phtml, .phar bypass
```

**Grep:**
```bash
grep -rn "move_uploaded_file\|is_uploaded_file" --include="*.php"
grep -rn "\$_FILES" --include="*.php" -A5 | grep "move_\|name"
```

### 10. Configuration Exposure

**Vulnerable:**
```bash
# .env files web-accessible
grep -rn "DB_HOST\|DB_PASSWORD\|APP_SECRET" --include=".env" --include="*.env"

# Debug mode
grep -rn "WP_DEBUG\|APP_DEBUG\|debug.*true" --include="*.php"

# phpinfo
grep -rn "phpinfo\|phpcredits" --include="*.php"

# .git exposed
```

## WordPress-Specific Checks

```bash
# Outdated plugins (version strings)
grep -rn "Version:" wp-content/plugins/*/readme.txt

# XMLRPC enabled
grep -rn "xmlrpc_enabled\|xmlrpc.php" --include="*.php"

# User enumeration
grep -rn "wp-json\|rest_route\|oembed" --include="*.php" | grep -v test
```

## Severity Assessment

| Finding | Severity |
|---------|----------|
| `unserialize($_GET['x'])` | **Critical** |
| `system($_GET['cmd'])` | **Critical** |
| MySQL string concat in query | **Critical** |
| `include($_GET['page'])` | **Critical** |
| `file_get_contents($_GET['url'])` | **High** |
| Loose comparison on auth tokens | **High** |
| `echo $_GET['x']` without escape | **Medium** |
| `==` comparison with `in_array` no strict | **Medium** |
