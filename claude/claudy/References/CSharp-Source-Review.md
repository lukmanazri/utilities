# C# / .NET Source Code Review - Bug Hunting Reference

## Technology Stack Identification

### Project File Indicators
```
*.csproj    - .NET / .NET Core / .NET Framework project
*.sln       - Visual Studio solution
web.config  - ASP.NET Framework configuration
appsettings.json - ASP.NET Core configuration
*.cshtml    - Razor views (.NET Core / MVC)
*.aspx      - Webforms pages (classic .NET Framework)
*.aspx.cs   - Webforms code-behind
*.ascx      - Webforms user controls
*.master    - Webforms master pages
*.svc       - WCF services
*.asmx      - Legacy SOAP services
*.razor     - Blazor components
*.xaml      - WPF/XAML UI
global.json - .NET SDK version pin
```

### Framework Version Detection
```bash
# From .csproj
grep -rn "TargetFramework" --include="*.csproj"
# net4.8 = .NET Framework 4.8 (classic)
# netcoreapp3.1 = .NET Core 3.1
# net5.0, net6.0, net7.0, net8.0 = modern .NET

# From global.json
grep -rn "version" global.json

# From web.config (classic)
grep -rn "targetFramework" web.config
```

### NuGet Package Audit
```bash
# List all packages
grep -rn "PackageReference" --include="*.csproj" -A1

# Check for known vulnerable packages
grep -rn "Microsoft.AspNetCore.Mvc\" --include="*.csproj"  # pre-2.2 vulnerable to CVE-XXXX
grep -rn "Newtonsoft.Json\" --include="*.csproj"           # pre-13.0.1 deserialization issues
grep -rn "System.Text.Encodings.Web\" --include="*.csproj"  # XSS encoder

# Scan with dotnet list package --vulnerable
dotnet list package --vulnerable 2>/dev/null
```

## Critical Vulnerability Patterns

### 1. SQL Injection

**Vulnerable - String concatenation:**
```csharp
// BAD: string concat in SqlCommand
string query = "SELECT * FROM Users WHERE Id = " + userId;
using var cmd = new SqlCommand(query, connection);
var reader = cmd.ExecuteReader();

// BAD: string interpolation in FromSqlRaw
var users = dbContext.Users.FromSqlRaw($"SELECT * FROM Users WHERE Id = {userId}");
dbContext.Database.ExecuteSqlRaw($"DELETE FROM Users WHERE Id = {userId}");
```

**Safe - Parameterized:**
```csharp
// GOOD: parameterized SqlCommand
using var cmd = new SqlCommand("SELECT * FROM Users WHERE Id = @Id", connection);
cmd.Parameters.AddWithValue("@Id", userId);

// GOOD: LINQ (always safe)
var user = dbContext.Users.FirstOrDefault(u => u.Id == userId);

// GOOD: FromSqlInterpolated (safe string interpolation in EF Core)
var users = dbContext.Users.FromSqlInterpolated($"SELECT * FROM Users WHERE Id = {userId}");

// GOOD: ExecuteSql with parameters
dbContext.Database.ExecuteSqlRaw("DELETE FROM Users WHERE Id = {0}", userId);
```

**Grep for SQLi patterns:**
```bash
grep -rn "ExecuteSqlRaw\|FromSqlRaw\|ExecuteSqlCommand" --include="*.cs" -A1 | grep -v "ExecuteSqlInterpolated\|FromSqlInterpolated"
grep -rn "new SqlCommand(.*\+" --include="*.cs"
grep -rn "\"SELECT.*\"\s*\+\s*" --include="*.cs"
grep -rn "SqlQuery<.*>(\".*\+" --include="*.cs"
```

### 2. Deserialization (Critical - Pays Highest)

**Vulnerable deserialization sinks:**
```csharp
// CRITICAL - BinaryFormatter
var formatter = new BinaryFormatter();
var obj = formatter.Deserialize(stream);  // RCE!

// CRITICAL - LosFormatter (ViewState)
var formatter = new LosFormatter();
var obj = formatter.Deserialize(stream);  // RCE via ViewState!

// CRITICAL - NetDataContractSerializer
var serializer = new NetDataContractSerializer();
var obj = serializer.Deserialize(stream); // RCE!

// HIGH - ObjectStateFormatter
var formatter = new ObjectStateFormatter();
var obj = formatter.Deserialize(stream);

// HIGH - SoapFormatter
var formatter = new SoapFormatter();
var obj = formatter.Deserialize(stream);

// MEDIUM - JavaScriptSerializer with TypeResolver
var serializer = new JavaScriptSerializer(new SimpleTypeResolver());
var obj = serializer.Deserialize<T>(json);  // RCE if SimpleTypeResolver used
```

**Safe patterns:**
```csharp
// GOOD: BinaryFormatter with Binder
var formatter = new BinaryFormatter { Binder = new SafeSerializationBinder() };

// GOOD: JavaScriptSerializer without TypeResolver
var serializer = new JavaScriptSerializer();  // no resolver = safe

// GOOD: System.Text.Json (modern)
var obj = System.Text.Json.JsonSerializer.Deserialize<T>(json);  // safe by default
```

**Grep for deserialization sinks:**
```bash
grep -rn "BinaryFormatter\|LosFormatter\|ObjectStateFormatter\|NetDataContractSerializer\|SoapFormatter\|JavaScriptSerializer.*TypeResolver" --include="*.cs"
grep -rn "\.Deserialize(" --include="*.cs" | grep -v "JsonSerializer\.Deserialize\|JsonConvert\|System\.Text\.Json"
grep -rn "SerializationBinder" --include="*.cs"  # check if implemented correctly
grep -rn "ISafeSerializationData\|IObjectReference" --include="*.cs"  # safe surrogate
```

### 3. Cross-Site Scripting (XSS)

**Vulnerable:**
```csharp
// BAD: Html.Raw() in Razor views
@Html.Raw(Model.UserComment)

// BAD: MvcHtmlString.Create
return MvcHtmlString.Create(userInput);

// BAD: Response.Write
Response.Write("<div>" + userName + "</div>");

// BAD: InnerHtml in code-behind
div.InnerHtml = userComment;

// BAD: JavaScript string injection
var js = $"var name = '{userName}';";  // userName: '; alert(1);//
```

**Safe:**
```csharp
// GOOD: Razor automatically encodes (default)
<div>@Model.UserComment</div>

// GOOD: Html.Encode
Response.Write(Html.Encode(userName));

// GOOD: System.Text.Encodings.Web
var encoded = HtmlEncoder.Default.Encode(userInput);

// GOOD: Newtonsoft.Json serialization for JS contexts
var safeJs = JsonConvert.SerializeObject(userName);  // properly escapes quotes
```

**Grep for XSS sinks:**
```bash
grep -rn "Html\.Raw\|MvcHtmlString\|Response\.Write\|InnerHtml\s*=" --include="*.cs" --include="*.cshtml"
grep -rn "IHtmlString\|HtmlString" --include="*.cs"
```

### 4. Server-Side Request Forgery (SSRF)

**Vulnerable:**
```csharp
// BAD: user-controlled URL in HttpClient
var client = new HttpClient();
var response = await client.GetAsync(userProvidedUrl);

// BAD: WebClient with user URL
using var wc = new WebClient();
var data = wc.DownloadString(userProvidedUrl);

// BAD: HttpWebRequest with user URL
var request = (HttpWebRequest)WebRequest.Create(userProvidedUrl);

// BAD: RestSharp
var client = new RestClient(userProvidedUrl);
var response = client.Execute(request);
```

**Safe:**
```csharp
// GOOD: URL allowlist
var allowedHosts = new[] { "api.internal.com", "cdn.trusted.com" };
var uri = new Uri(userProvidedUrl);
if (!allowedHosts.Contains(uri.Host))
    throw new SecurityException("Untrusted host");

// GOOD: Block private IPs
if (IsPrivateIp(uri.Host))
    throw new SecurityException("Private IP blocked");

// GOOD: Only allow HTTPS
if (uri.Scheme != "https")
    throw new SecurityException("HTTP not allowed");
```

**Grep for SSRF sinks:**
```bash
grep -rn "HttpClient\.Get\|HttpClient\.Post\|HttpClient\.Send" --include="*.cs" | grep "Query\|Body\|Form\|Route"
grep -rn "WebClient\.Download\|WebClient\.Upload" --include="*.cs"
grep -rn "WebRequest\.Create\|HttpWebRequest\.Create" --include="*.cs"
grep -rn "RestClient\(" --include="*.cs"
```

### 5. XML External Entity (XXE)

**Vulnerable:**
```csharp
// BAD: XmlDocument without XmlResolver=null
var doc = new XmlDocument();
doc.Load(userXml);  // XXE!

// BAD: XmlReader without DtdProcessing.Prohibit
using var reader = XmlReader.Create(xmlStream);

// BAD: XDocument without settings
var doc = XDocument.Load(xmlStream);
```

**Safe:**
```csharp
// GOOD: XmlDocument with resolver nulled
var doc = new XmlDocument();
doc.XmlResolver = null;
doc.Load(xmlStream);

// GOOD: XmlReader with DtdProcessing.Prohibit
var settings = new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit };
using var reader = XmlReader.Create(xmlStream, settings);

// GOOD: XDocument with safe settings
using var reader = XmlReader.Create(xmlStream, new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit });
var doc = XDocument.Load(reader);
```

### 6. Path Traversal

**Vulnerable:**
```csharp
// BAD: File.ReadAllText with user path
var content = File.ReadAllText(userPath);

// BAD: Path.Combine insufficient (..\ still works)
var fullPath = Path.Combine(basePath, userPath);
File.OpenRead(fullPath);

// BAD: Server.MapPath (classic ASP.NET)
var path = Server.MapPath("~/uploads/" + userFileName);
```

**Safe:**
```csharp
// GOOD: GetFullPath + validate within base
var fullPath = Path.GetFullPath(Path.Combine(basePath, fileName));
if (!fullPath.StartsWith(Path.GetFullPath(basePath)))
    throw new SecurityException();

// GOOD: Use only safe filename (not path)
var safeName = Path.GetFileName(userFileName);
var path = Path.Combine(basePath, safeName);
```

### 7. Command Injection

**Vulnerable:**
```csharp
// BAD: Process.Start with user input in filename
Process.Start("cmd.exe", "/c " + userCommand);

// BAD: Process.Start with user-controller arguments
var psi = new ProcessStartInfo("convert.exe", userProvidedArgs);
Process.Start(psi);

// BAD: Assembly.Load with user-provided path
Assembly.LoadFrom(userPath);
```

**Safe:**
```csharp
// GOOD: Avoid shell execution altogether
Process.Start("convert.exe", safeArg);  // use Process directly for fixed exe

// GOOD: Whitelist commands
if (!allowedCommands.Contains(userCommand))
    throw new SecurityException();
```

### 8. Mass Assignment / Over-Posting

**Vulnerable:**
```csharp
// BAD: TryUpdateModel without Bind attribute
[HttpPost]
public IActionResult Update(int id)
{
    var user = dbContext.Users.Find(id);
    TryUpdateModel(user);  // binds all form fields including IsAdmin!
    dbContext.SaveChanges();
}

// BAD: [FromBody] with no DTO
[HttpPost]
public IActionResult Create(User user)  // User has IsAdmin, CanDelete, etc.
{
    dbContext.Users.Add(user);
    dbContext.SaveChanges();
}
```

**Safe:**
```csharp
// GOOD: Use DTO/view model
public class CreateUserDto
{
    public string Name { get; set; }
    public string Email { get; set; }
    // No IsAdmin, Role, etc.
}

[HttpPost]
public IActionResult Create(CreateUserDto dto) { ... }

// GOOD: Bind attribute
[HttpPost]
public IActionResult Update([Bind("Name,Email")] User user) { ... }

// GOOD: Whitelist properties
TryUpdateModel(user, "", new[] { "Name", "Email" });
```

### 9. Authentication / Authorization

**Vulnerable patterns:**
```csharp
// BAD: Missing [Authorize] on sensitive controller
[Route("api/admin")]
public class AdminController : ControllerBase  // no [Authorize]!

// BAD: [AllowAnonymous] on sensitive action
[Authorize]
public class AccountController : Controller
{
    [AllowAnonymous]
    public IActionResult DeleteAll() { ... }  // overrides class-level auth!
}

// BAD: Auth check that can be bypassed
if (HttpContext.User.IsInRole("Admin") || debugMode)  // debugMode always true in prod?
```

**Safe patterns:**
```csharp
// GOOD: Global auth + explicit opt-out
app.UseAuthorization();  // applies globally
// Only [AllowAnonymous] on login/register

// GOOD: Policy-based auth
[Authorize(Policy = "RequireAdminRole")]
public IActionResult SensitiveAction() { ... }

// GOOD: Resource-based auth
if (!await authService.AuthorizeAsync(User, document, "EditPolicy"))
    return Forbid();
```

**Grep for auth patterns:**
```bash
grep -rn "\[Authorize\]" --include="*.cs" | wc -l  # count of authorized endpoints
grep -rn "\[AllowAnonymous\]" --include="*.cs" -A3  # check context
grep -rn "\[Route" --include="*.cs" -A3 | grep -v "\[Authorize\]"  # routes without auth
```

### 10. Configuration Hardcoding

**Vulnerable:**
```csharp
// BAD: Hardcoded secrets
private const string ApiKey = "sk-live-abc123...";
private static readonly string ConnectionString = "Server=prod;Password=Secret123;";
var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("hardcoded-key-123"));

// BAD: machineKey in web.config committed to git
<machineKey validationKey="ABC123...,IsolateApps" decryptionKey="XYZ789...,IsolateApps" />
```

**Grep for secrets:**
```bash
grep -rn "Password\s*=\s*\"\|ApiKey\s*=\s*\"\|Secret\s*=\s*\"" --include="*.cs" --include="*.config"
grep -rn "validationKey\|decryptionKey\|machineKey" --include="*.config"
grep -rn "SymmetricSecurityKey\|IssuerSigningKey" --include="*.cs"
grep -rn "new.*Credentials\|ClientSecret\|Bearer\s*\"" --include="*.cs"
```

## ASP.NET Webforms Specific

### ViewState Security
```bash
# Check if ViewState is encrypted
grep -rn "ViewStateEncryptionMode\|EnableViewStateMac" --include="*.cs" --include="*.config"

# Check machineKey configuration
grep -rn "machineKey\|validationKey\|decryptionKey" --include="web.config"
# __VIEWSTATEENCRYPTED="" in HTML = signed only (not encrypted)

# Check for diagnostic handlers
grep -rn "trace enabled\|elmah" --include="web.config"
```

### IIS / Web.config Vulnerabilities
```bash
# Check for debug mode in production
grep -rn "compilation.*debug=\"true\"" --include="web.config"

# Check customErrors mode
grep -rn "customErrors mode=\"Off\"" --include="web.config"  # stack traces leaked!

# Check for directory browsing
grep -rn "directoryBrowse enabled=\"true\"" --include="web.config"

# Check for request filtering bypasses
grep -rn "requestFiltering\|requestLimits\|maxAllowedContentLength" --include="web.config"
```

## C# Source Code Review Flow

### 1. Map Controllers & Routes
```bash
# Find all controllers
grep -rn "class.*Controller" --include="*.cs"

# Find all minimal API endpoints (.NET 6+)
grep -rn "app\.MapGet\|app\.MapPost\|app\.MapPut\|app\.MapDelete" --include="*.cs"

# Find all MVC route attributes
grep -rn "\[Route\|\[HttpGet\|\[HttpPost\|\[HttpPut\|\[HttpDelete\|\[HttpPatch" --include="*.cs"
```

### 2. Identify Authentication Model
```bash
grep -rn "\[Authorize\]\|\[AllowAnonymous\]" --include="*.cs"
grep -rn "AddAuthentication\|AddJwtBearer\|AddOpenIdConnect\|AddIdentity" --include="*.cs"
grep -rn "SignInManager\|UserManager\|IAuthenticationService" --include="*.cs"
```

### 3. Map Database Access
```bash
grep -rn "DbContext\|DbSet\|OnModelCreating" --include="*.cs"
grep -rn "SqlConnection\|IDbConnection\|Dapper" --include="*.cs"
grep -rn "FromSqlRaw\|ExecuteSqlRaw\|SqlQuery" --include="*.cs"
```

### 4. Check for Input Validation Gaps
```bash
# Model validation bypasses
grep -rn "ModelState\.IsValid" --include="*.cs" -B3  # check ALL controllers use this

# Nullable reference types (possible null dereference issues)
grep -rn "\.FirstOrDefault()\|\.SingleOrDefault()" --include="*.cs" -A2 | grep -v "\.\?\."

# Missing validation attributes
grep -rn "class.*Dto\|class.*Request\|class.*Model" --include="*.cs" -A5 | grep -v "\[Required\|\[Range\|\[MaxLength\|\[RegularExpression"
```

### 5. Race Condition Primitives
```bash
# Check-then-act patterns
grep -rn "if.*Balance.*>=\|if.*Stock.*>=\|if.*Count.*>" --include="*.cs" -A3 | grep "SaveChanges\|\.Add\|\.Update"

# Missing transactions
grep -rn "SaveChanges\|SaveChangesAsync" --include="*.cs" -B5 | grep -v "TransactionScope\|BeginTransaction\|UseTransaction"
```

## Severity Assessment for C# Findings

| Finding | Severity | Reason |
|---------|----------|--------|
| `BinaryFormatter.Deserialize()` with user input | **Critical** | Direct RCE |
| `LosFormatter.Deserialize()` + leaked machineKey | **Critical** | ViewState RCE |
| SQLi via `ExecuteSqlRaw(userInput)` | **Critical** | Full DB compromise |
| `trace.axd` exposed anonymously | **Critical** | Credentials + session leak |
| `elmah.axd` exposed with DB creds in errors | **Critical** | DB credential leak |
| `HttpClient.GetAsync(userInput)` without allowlist | **High** | SSRF to internal services |
| `XmlDocument.Load(userInput)` without null resolver | **High** | XXE to SSRF/file read |
| `File.ReadAllText(userInput)` without path check | **High** | Arbitrary file read |
| `@Html.Raw(userInput)` without encoding | **Medium** | Stored XSS |
| `TryUpdateModel(user)` without Bind attribute | **Medium** | Mass assignment |
| Server error with stack trace | **Low** | Information disclosure |
| `requestValidationMode="2.0"` in web.config | **Low** | Weakened XSS protection |
