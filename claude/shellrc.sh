# >>> vuln research functions >>>
ACTIVE_ENGAGEMENT=""
vuln() {
    local repo=$1
    [[ -z "$repo" ]] && echo "usage: vuln <repo-url> [prompt]" && return 1
    local name=$(basename $repo .git)
    local ts=$(date +%Y%m%d)
    local d=~/research/${ts}-${name}
    local template=~/research/.claude
    [[ ! -f "$template/CLAUDE.md" ]] && echo "[-] CLAUDE.md not found at $template" && return 1
    [[ ! -d "$template/methodology" ]] && echo "[-] methodology/ not found at $template" && return 1
    mkdir -p $d
    cp "$template/CLAUDE.md" $d/
    cp -r "$template/methodology" $d/
    cd $d
    git init -q .
    git clone $repo
    ACTIVE_ENGAGEMENT=$d
    echo $d > ~/research/.active
    local prompt="${2:-"Read CLAUDE.md and begin from Step 1. \
Priority targets: pre-auth RCE, ATO, auth bypass, PII exposure, privilege escalation — medium to critical only. \
Spawn subagents aggressively — run independent hunting tracks and pipeline stages in parallel, not sequentially. Fan out as wide as the target warrants. \
Run opengrep with rules at ~/tools/semgreprules/ alongside manual hunting — do not rely on opengrep alone. \
Check all findings against latest upstream — skip anything already patched. \
Do chain analysis on every confirmed finding. \
Complete all pipeline steps before stopping. \
No menus, no questions, no narration."}"
    IS_SANDBOX=1 claude --model claude-opus-4-8 --dangerously-skip-permissions "$prompt"
}
engage() {
    local d=$(ls -dt ~/research/[0-9]*/ | fzf --prompt="engagement: ")
    [[ -z "$d" ]] && return 1
    ACTIVE_ENGAGEMENT=$d
    echo $d > ~/research/.active
    cd $d
    echo "[+] active: $d"
}
resume() {
    local d=$(cat ~/research/.active 2>/dev/null)
    [[ -z "$d" ]] && echo "[-] no active engagement — run engage first" && return 1
    cd $d
    git init -q .
    local prompt="${1:-"Read CLAUDE.md and resume from current progress in 00-master-index.md. \
Priority targets: pre-auth RCE, ATO, auth bypass, PII exposure, privilege escalation — medium to critical only. \
Spawn subagents aggressively — run independent hunting tracks and pipeline stages in parallel, not sequentially. Fan out as wide as the remaining work warrants. \
Run opengrep with rules at ~/tools/semgreprules/ alongside manual hunting — do not rely on opengrep alone. \
Check all findings against latest upstream — skip anything already patched. \
Do chain analysis on every confirmed finding. \
Continue until all pipeline steps are complete. \
No menus, no questions, no narration."}"
    echo "[+] resuming: $d"
    IS_SANDBOX=1 claude --model claude-opus-4-8 --dangerously-skip-permissions "$prompt"
}
report() {
    local vuln_id=$1
    [[ -z "$vuln_id" ]] && echo "usage: report VULN-001" && return 1
    local d=$(cat ~/research/.active 2>/dev/null)
    [[ -z "$d" ]] && echo "[-] no active engagement — run engage first" && return 1
    echo "[*] reporting $vuln_id in $d"
    cd $d
    git init -q .
    IS_SANDBOX=1 claude --model claude-opus-4-8 --dangerously-skip-permissions "report $vuln_id"
}
# <<< vuln research functions <
