# Taint Analysis Methodology for Source Code Bug Hunting

## Overview

**Taint analysis** is the systematic tracking of untrusted data from where it enters the application (source) to where it is consumed in dangerous operations (sink), without being sanitized. This is the #1 methodology for finding high-impact bugs in source code reviews.

## Core Concepts

### Source
Any entry point where attacker-controlled data enters the application:
- HTTP request parameters (query, body, headers, cookies, path)
- File uploads
- WebSocket messages
- Database rows populated by other users (second-order)
- External API responses

### Sink
Any operation where data is interpreted/executed rather than treated as data:
- Database queries (SQLi)
- Shell commands (RCE)
- File system operations (path traversal, LFI)
- XML parsers (XXE)
- HTML rendering contexts (XSS)
- Deserialization (RCE)
- Template rendering (SSTI)
- Network requests (SSRF)

### Sanitizer
Any function that neutralizes dangerous characters or enforces safe data semantics:
- Parameterized queries / prepared statements
- HTML encoding (HtmlEncode, htmlspecialchars)
- Input validation (regex, type checks, allowlists)
- ObjectSerializationBinder (C# deserialization safety)

## Taint Sources by Platform

### C# / ASP.NET Core Sources
```
Request.Query["key"]              HttpRequest.Query
Request.Form["key"]               HttpContext.Request.Form
Request.RouteValues["key"]        Route data
[FromQuery] string param          Model binding
[FromBody] object body            Request body
[FromHeader] string header        Header binding
[FromForm] IFormFile file         File upload
[FromRoute] int id                Route parameters
Request.Headers["X-Custom"]       Custom headers
Request.Cookies["session"]        Cookie values
```

### C# / ASP.NET Framework (Webforms) Sources
```
Request.QueryString["key"]        Query string
Request.Form["key"]               Form data
Request.Params["key"]             Combined
Request.Headers["key"]            Headers
Request.Cookies["key"]            Cookies
Request["key"]                    Index accessor
HttpContext.Current.Request       Same via static accessor
Page.Request.Form                 Page-level form access
```

## Taint Sinks by Bug Class

### SQL Injection Sinks

| Language | Unsafe Pattern | Safe Pattern |
|----------|---------------|--------------|
| C# | `new SqlCommand("SELECT * FROM " + input)` | `new SqlCommand("SELECT * FROM @table", conn)` with `cmd.Parameters.AddWithValue("@table", input)` |
| C# EF Core | `dbContext.Database.ExecuteSqlRaw($"SELECT * FROM {input}")` | `dbContext.Database.ExecuteSqlRaw("SELECT * FROM {0}", input)` or LINQ |
| C# EF Core | `dbContext.Blogs.FromSqlRaw($"SELECT * FROM {input}")` | `FromSqlInterpolated($"SELECT * FROM {input}")` |
| Python | `cursor.execute("SELECT * FROM " + input)` | `cursor.execute("SELECT * FROM %s", (input,))` |
| JS | `db.query("SELECT * FROM " + input)` | `db.query("SELECT * FROM $1", [input])` |
| PHP | `mysql_query("SELECT * FROM " . $input)` | `$stmt->bind_param("s", $input)` followed by `$stmt->execute()` |

### SSRF Sinks

| Language | Pattern | Notes |
|----------|---------|-------|
| C# | `new HttpClient().GetAsync(userUrl)` | Check if URL is from request |
| C# | `new WebClient().DownloadString(userUrl)` | Legacy, but still in codebases |
| C# | `HttpWebRequest.Create(userUrl)` | Very common pattern |
| Python | `requests.get(userUrl)` | Most popular Python SSRF sink |
| JS | `axios.get(req.query.url)` | Direct from query param |
| Go | `http.Get(userUrl)` | Simple but dangerous |

### XXE Sinks

| Language | Vulnerable Pattern | Safe Pattern |
|----------|-------------------|--------------|
| C# | `new XmlDocument().Load(input)` | `var doc = new XmlDocument(); doc.XmlResolver = null; doc.Load(input);` |
| C# | `XmlReader.Create(input)` | `XmlReader.Create(input, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit })` |
| Python | `lxml.etree.parse(input)` | Requires `resolve_entities=False` in lxml >= 5.0 |
| Python | `xml.etree.ElementTree.parse(input)` | Older versions vulnerable; Python 3.7.1+ safer but check |

### Deserialization Sinks (C# Critical)

| Sink Class | Gadget Chains | Impact |
|-----------|--------------|--------|
| `BinaryFormatter.Deserialize()` | TypeConfuseDelegate, WindowsIdentity | RCE |
| `LosFormatter.Deserialize()` | ActivitySurrogateSelector, TextFormattingRunProperties | RCE |
| `ObjectStateFormatter.Deserialize()` | TypeConfuseDelegate | RCE |
| `NetDataContractSerializer.Deserialize()` | PSObject | RCE |
| `JavaScriptSerializer.Deserialize()` | Limited (SimpleTypeResolver needed) | RCE if resolver enabled |
| `XmlSerializer.Deserialize()` | ObjectDataProvider, ResourceDictionary | RCE |
| `SoapFormatter.Deserialize()` | Full gadget chain support | RCE |
| `DataContractJsonSerializer.Deserialize()` | Limited | RCE if known types |

### Command Execution / RCE Sinks

| Language | Pattern |
|----------|---------|
| C# | `Process.Start(cmd, args)` |
| C# | `Process.Start(new ProcessStartInfo { FileName = input, Arguments = ... })` |
| C# | `Assembly.Load(bytes)` / `Assembly.LoadFrom(path)` |
| Python | `os.system(input)`, `subprocess.call(input, shell=True)` |
| Python | `eval(input)`, `exec(input)`, `pickle.loads(input)` |
| JS | `eval(input)`, `execSync(input)` |
| PHP | `system(input)`, `shell_exec(input)`, `eval(input)` |

### XSS Sinks

| Language | Pattern |
|----------|---------|
| C# | `@Html.Raw(userInput)` in .cshtml |
| C# | `Response.Write(userInput)` |
| C# | `MvcHtmlString.Create(userInput)` |
| C# Razor | Using `@Html.Raw(@Model.Description)` on user-stored data |
| JS | `element.innerHTML = userInput` |
| JS React | `dangerouslySetInnerHTML={{__html: userInput}}` |
| Ruby | `<%= raw(user_input) %>` or `user_input.html_safe` |

## Taint Propagation Through Code

### Direct Taint (1-hop)
```
Request.Query["id"] -> int.Parse() -> SqlCommand -> Execute()
                              ^ No sanitization on the value = SQLi
```

### Indirect Taint (Multi-hop)
```
Request.Body -> deserialize to Model -> store in DB
   later: DB query -> Model property -> Response.Write() -> XSS
```

### Transitive Taint (Through library/framework)
```
Controller.Action(string param) -> Service.Method(param) -> Repository.Query(param) -> DB
```

### Taint via Configuration
```
appsettings.json -> IOptions<T>.Value.ConnectionString -> SqlConnection
                                                        ^ Hardcoded creds in source
```

## Taint Analysis Hunting Protocol

### Step 1: Map All Sources
List every way user input enters the application:
1. Check every Controller / Route handler
2. Check every middleware that reads request body
3. Check every [FromBody], [FromQuery], [FromRoute], [FromHeader] parameter
4. Check WebSocket handlers, SignalR hubs
5. Check background job triggers

### Step 2: Map All Sinks
List every dangerous operation in the codebase:
```
grep -rn "Process.Start\|SqlCommand\|HttpClient.Get\|XmlDocument.Load\|BinaryFormatter" --include="*.cs"
grep -rn "exec(\|eval(\|execute(\|system(\|subprocess" --include="*.py"
grep -rn "execSync\|spawn(\|eval(\|child_process" --include="*.js"
```

### Step 3: Trace Source -> Sink
For each source, follow the data path:
1. Does it reach a function call? Check that function.
2. Does it reach a variable assignment? Check wherever that variable is used.
3. Does it reach a deserialize/parse/transform? Check the result.
4. Does it reach a sink? If yes, check for sanitizers.

### Step 4: Check for Sanitizers
Between source and sink, is there:
- Parameterized SQL? (SqlParameter, $1, %s)
- HTML encoding? (HtmlEncode, htmlspecialchars)
- Path validation? (Path.GetFullPath, allowlist check)
- URL validation? (Uri.IsWellFormedUriString, allowlist domains)
- Deserialization binder? (SerializationBinder restricting types)
- Input validation? (regex, range check, type enforcement)

### Step 5: Verify Reachability
- Is the code path actually reachable from an HTTP endpoint?
- Are there feature flags / environment checks that disable it?
- Is the endpoint behind auth that changes the attack surface?
- Is the input actually controllable (not overwritten by middleware)?

### Step 6: Verify Exploitability
- Craft a real PoC request
- Test against live/staging environment
- Confirm the impact (data leak, code execution, auth bypass)
- Document exact request/response for report

## Quick Taint Scan Queries

### C# Full Taint Scan
```bash
echo "=== SOURCES ==="
grep -rn "Request\.Query\|Request\.Form\|Request\.Body\|\[FromBody\]\|\[FromQuery\]\|\[FromRoute\]\|\[FromHeader\]" --include="*.cs" | grep -v "/obj/\|/bin/" > taint-sources.txt

echo "=== SINKS ==="
grep -rn "Process\.Start\|SqlCommand\|HttpClient\.Get\|WebClient\.Download\|XmlDocument\.Load\|BinaryFormatter\.Deserialize\|LosFormatter\.Deserialize\|ObjectStateFormatter\|File\.ReadAllText\|Server\.MapPath\|Response\.Write\|Html\.Raw\|MvcHtmlString" --include="*.cs" | grep -v "/obj/\|/bin/" > taint-sinks.txt

echo "=== SANITIZERS ==="
grep -rn "ModelState\.IsValid\|TryValidateModel\|SqlParameter\|HtmlEncode\|AntiXssEncoder\|SerializationBinder\|DtdProcessing\.Prohibit\|XmlResolver = null" --include="*.cs" | grep -v "/obj/\|/bin/" > taint-sanitizers.txt

echo "Files: taint-sources.txt, taint-sinks.txt, taint-sanitizers.txt"
echo "Cross-reference sources with sinks -- if a source reaches a sink without a sanitizer in between, investigate."
```

### Python Full Taint Scan
```bash
echo "=== SOURCES ==="
grep -rn "request\.args\|request\.form\|request\.json\|request\.GET\|request\.POST\|request\.data" --include="*.py" | grep -v test > taint-sources.txt

echo "=== SINKS ==="
grep -rn "pickle\.loads\|yaml\.load\|eval(\|exec(\|os\.system\|subprocess\|requests\.get\|urllib\|cursor\.execute\|render_template_string\|lxml" --include="*.py" | grep -v test > taint-sinks.txt
```

## Common Taint-Based Vulnerability Chains

```
Source: Request.Query["userId"]
  -> Sink: SqlCommand("SELECT * FROM Users WHERE Id=" + userId)  [SQLi]
     -> Extract admin password hash
        -> Crack / pass-the-hash
           -> Login as admin [Full ATO]

Source: Request.Query["url"]
  -> Sink: WebClient.DownloadString(url)  [SSRF]
     -> http://169.254.169.254/latest/meta-data/  [AWS metadata]
        -> IAM credentials
           -> aws s3 ls [Cloud takeover]

Source: Request.Form["__VIEWSTATE"]
  -> Sink: LosFormatter.Deserialize(viewStateBytes)  [Deserialization RCE]
     -> machineKey leaked in web.config
        -> ysoserial.net TypeConfuseDelegate gadget
           -> Process.Start("cmd.exe") [RCE as IIS APPPOOL]

Source: Request.Body -> JsonConvert.DeserializeObject<User>(body)
  -> No bind whitelist
     -> Sink: TryUpdateModel(user)  [Mass Assignment]
        -> Attacker sets IsAdmin=true
           -> Full privilege escalation
```
