# Ruby Source Code Review - Bug Hunting Reference

## Technology Stack Identification

```bash
Gemfile, Gemfile.lock    - Ruby gems
*.rb                     - Source
*.erb                    - ERB templates
config/routes.rb         - Rails routes
Rakefile                 - Rake tasks
```

## Critical Vulnerability Patterns

### 1. SQL Injection (Rails/ActiveRecord)

**Vulnerable:**
```ruby
# BAD: string interpolation
User.where("email = '#{params[:email]}'")
User.where("id = " + params[:id])
User.find_by_sql("SELECT * FROM users WHERE id=#{params[:id]}")
User.connection.execute("SELECT * FROM users WHERE id=#{params[:id]}")

# BAD: order injection (can't parameterize column names)
User.order(params[:sort])
User.order("#{params[:col]} #{params[:dir]}")
User.reorder(params[:order])

# BAD: select with user column
User.select(params[:columns])

# BAD: Arel raw
User.where(User.arel_table[:id].eq(Arel.sql(params[:id])))
```

**Safe:**
```ruby
# GOOD: hash conditions
User.where(email: params[:email])
User.where("email = ?", params[:email])

# GOOD: order allowlist
allowed = %w[name email created_at]
raise "Invalid sort" unless allowed.include?(params[:sort])
User.order(params[:sort])
```

**Grep:**
```bash
grep -rn "\.where(\".*#{\|\.find_by_sql\|\.execute(\".*#{\|\.order(params\|\.reorder(params" --include="*.rb" | grep -v test
grep -rn "Arel\.sql\|\.select(params" --include="*.rb"
```

### 2. Command Injection

**Vulnerable:**
```ruby
# BAD
system("ping #{params[:ip]}")
`ping #{params[:ip]}`
exec("ls #{params[:dir]}")
IO.popen(params[:cmd])
Open3.capture2(params[:cmd])
Kernel.exec(params[:cmd])
%x(rm #{params[:file]})
```

**Safe:**
```ruby
# GOOD: array form
system("ping", "-c", "3", params[:ip])
```

**Grep:**
```bash
grep -rn "system(\|`.*#{\|exec(\|IO\.popen\|Open3\.\|Kernel\.exec\|%x(" --include="*.rb" | grep -v test
```

### 3. Deserialization (YAML + Marshal)

**Vulnerable:**
```ruby
# BAD: Marshal (RCE with gadget chain)
Marshal.load(params[:data])

# BAD: YAML (RCE if Psych supports tags)
YAML.load(params[:yaml])           # unsafe_load in older versions!
YAML.load_file(params[:file])

# BAD: Oj gem
Oj.load(params[:json], mode: :object)  # RCE when :object mode
```

**Safe:**
```ruby
# GOOD: safe YAML
YAML.safe_load(params[:yaml])
YAML.safe_load_file(params[:file])

# GOOD: JSON
JSON.parse(params[:json])
```

**Grep:**
```bash
grep -rn "Marshal\.load\|YAML\.load[^_]\|YAML\.load_file\|Oj\.load.*object" --include="*.rb" | grep -v test
```

### 4. SSTI (ERB / Slim / Haml)

**Vulnerable:**
```ruby
# BAD: ERB
ERB.new(params[:template]).result
ERB.new(user_input).result(binding)

# BAD: Haml with user input
Haml::Engine.new(params[:template]).render

# BAD: Slim
Slim::Template.new { params[:template] }.render
```

**Grep:**
```bash
grep -rn "ERB\.new\|Haml::Engine\.new\|Slim::Template\.new" --include="*.rb" | grep -v test
```

### 5. XSS

**Vulnerable:**
```ruby
# BAD: raw output
<%= raw user_input %>
<%= user_input.html_safe %>
<%= content_tag :div, user_input, class: 'raw' %>

# BAD: in controller
render html: user_input
render inline: "<%= #{user_input} %>"
```

**Safe:**
```ruby
# GOOD: auto-escaped in ERB by default
<%= user_input %>
<%= sanitize user_input %>
```

**Grep:**
```bash
grep -rn "\.html_safe\|raw(\|render.*inline\|render.*html:" --include="*.rb" --include="*.erb" | grep -v test
```

### 6. Mass Assignment

**Vulnerable:**
```ruby
# BAD: no strong params
User.new(params[:user])
User.create(params[:user])
user.update(params)                 # Rails 3 no whitelist
user.update_attributes(params[:user])
user.assign_attributes(params[:user])

# BAD: permit! bypass
params[:user].permit!                # sledgehammer - allows everything
```

**Safe:**
```ruby
# GOOD: strong params
params.require(:user).permit(:name, :email)
```

**Grep:**
```bash
grep -rn "\.new(params\|\.create(params\|\.update(params\|\.update_attributes\|\.assign_attributes\|\.permit!" --include="*.rb" | grep -v test
```

### 7. Path Traversal

**Vulnerable:**
```ruby
File.read(params[:file])
File.open(params[:path])
send_file(params[:file])                          # Rails
send_data(File.read(params[:file]), ...)           # Rails
render file: params[:template]                     # Rails
```

**Grep:**
```bash
grep -rn "File\.read\|File\.open\|send_file\|render file:" --include="*.rb" | grep -v test
```

### 8. SSRF

**Vulnerable:**
```ruby
Net::HTTP.get(URI(params[:url]))
Net::HTTP.get_response(URI(params[:url]))
HTTParty.get(params[:url])
Faraday.get(params[:url])
RestClient.get(params[:url])
open(params[:url])                    # Kernel.open does HTTP too!
URI.open(params[:url])
```

**Grep:**
```bash
grep -rn "Net::HTTP\|HTTParty\|Faraday\|RestClient\|open(\|URI\.open" --include="*.rb" | grep -v test | grep "params\|request\.\|@"
```

### 9. Authorization

**Vulnerable:**
```ruby
# BAD: missing authorization
before_action :authenticate_user!, except: [:delete_all]  # whitelist!

# BAD: CanCanCan without check
def destroy
  User.find(params[:id]).destroy   # no authorize! or load_and_authorize_resource
end

# BAD: Pundit without verify
class UsersController
  def update
    @user.update(user_params)      # no authorize @user
  end
end
```

**Grep:**
```bash
grep -rn "before_action.*except\|skip_before_action\|skip_authorization\|skip_authorize_resource" --include="*.rb"
grep -rn "def \(create\|update\|destroy\)" --include="*.rb" -A5 | grep -v "authorize\|authenticate\|current_user\|require"
```

### 10. Hardcoded Secrets

```bash
grep -rn "secret_key_base\|SECRET_KEY_BASE\|Figaro\.env" --include="*.rb" --include="*.yml" | grep -v "ENV\["
grep -rn "password.*=.*\"\|api_key.*=.*\"" --include="*.rb" | grep -v test
grep -rn "Rails\.application\.credentials" --include="*.rb"  # should use this instead
```

### 11. Insecure Configuration

```bash
# Force SSL disabled
grep -rn "config\.force_ssl\s*=\s*false" --include="*.rb"

# Debug mode
grep -rn "config\.consider_all_requests_local\s*=\s*true" --include="*.rb" --include="*.yml"

# CSRF disabled
grep -rn "protect_from_forgery.*except\|skip_forgery_protection" --include="*.rb"
```

## Severity Assessment

| Finding | Severity |
|---------|----------|
| `Marshal.load(params[:x])` | **Critical** |
| `YAML.load(params[:x])` | **Critical** |
| `system("ping #{params[:ip]}")` | **Critical** |
| `User.where("id=#{params[:id]}")` | **Critical** |
| `User.new(params[:user])` no strong params | **High** |
| `render inline: params[:template]` | **Critical** |
| `Net::HTTP.get(URI(params[:url]))` | **High** |
| Missing `authorize` in controller | **High** |
