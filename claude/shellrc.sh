# >>> vuln research functions >>>
ACTIVE_ENGAGEMENT=""
_research_launch() {
    local session=$1 dir=$2 prompt=$3
    command -v tmux >/dev/null || {
        echo "[-] tmux not installed: apt install tmux"
        return 1
    }
    if tmux has-session -t "$session" 2>/dev/null; then
        echo "[!] tmux session '$session' already exists"
        echo "    attach: tmux attach -t $session"
        return 1
    fi
    tmux new-session -d -s "$session" -c "$dir"
    tmux send-keys -t "$session" \
        "IS_SANDBOX=1 claude --remote-control --model claude-opus-4-8 --dangerously-skip-permissions $(printf '%q' "$prompt")" Enter
    echo "[+] launched: $session"
    echo "    attach: tmux attach -t $session"
}
vuln() {
    local repo=$1
    [[ -z "$repo" ]] && echo "usage: vuln <repo-url> [prompt]" && return 1
    local name=$(basename "$repo" .git)
    local ts=$(date +%Y%m%d)
    local d=~/research/${ts}-${name}
    local template=~/research/.claude
    [[ ! -f "$template/CLAUDE.md" ]] && echo "[-] missing CLAUDE.md" && return 1
    [[ ! -d "$template/methodology" ]] && echo "[-] missing methodology/" && return 1
    mkdir -p "$d"
    cp "$template/CLAUDE.md" "$d/"
    cp -r "$template/methodology" "$d/"
    cp -r "$template/skills" "$d/" 
    cd "$d" || return 1
    git init -q .
    git clone "$repo" target >/dev/null 2>&1
    ACTIVE_ENGAGEMENT="$d"
    echo "$d" > ~/research/.active
    local prompt="${2:-"Read CLAUDE.md and begin from Step 1. \
Priority targets: pre-auth RCE, ATO, auth bypass, PII exposure, privilege escalation — medium to critical only. \
Especially hunt for chains landing in RCE: LFI to RCE, SSTI, deserialization, unrestricted file upload, code injection via eval/preg_replace, NoSQL \$where JS injection. Cross-reference skills/reference/<category>/ for variant techniques before closing any of these classes (G2/G7). \
Spawn subagents aggressively — run independent hunting tracks and pipeline stages in parallel, not sequentially. Fan out as wide as the target warrants. \
Run opengrep with rules at ~/tools/semgreprules/ alongside manual hunting — do not rely on opengrep alone. \
Check all findings against latest upstream — skip anything already patched. \
Do chain analysis on every confirmed finding. \
Complete all pipeline steps before stopping. \
No menus, no questions, no narration."}"
    _research_launch "${ts}-${name}" "$d" "$prompt"
}
engage() {
    local d
    d=$(ls -dt ~/research/[0-9]*/ 2>/dev/null | fzf --prompt="engagement: ")
    [[ -z "$d" ]] && return 1
    ACTIVE_ENGAGEMENT="$d"
    echo "$d" > ~/research/.active
    cd "$d" || return 1
    echo "[+] active: $d"
}
resume() {
    local d
    d=$(cat ~/research/.active 2>/dev/null)
    [[ -z "$d" ]] && echo "[-] no active engagement" && return 1
    cd "$d" || return 1
    local prompt="${1:-"Read CLAUDE.md and resume from current progress in 00-master-index.md. \
Priority targets: pre-auth RCE, ATO, auth bypass, PII exposure, privilege escalation — medium to critical only. \
Especially hunt for chains landing in RCE: LFI to RCE, SSTI, deserialization, unrestricted file upload, code injection via eval/preg_replace, NoSQL \$where JS injection. Cross-reference skills/reference/<category>/ for variant techniques before closing any of these classes (G2/G7). \
Spawn subagents aggressively — run independent hunting tracks and pipeline stages in parallel, not sequentially. Fan out as wide as the remaining work warrants. \
Run opengrep with rules at ~/tools/semgreprules/ alongside manual hunting — do not rely on opengrep alone. \
Check all findings against latest upstream — skip anything already patched. \
Do chain analysis on every confirmed finding. \
Continue until all pipeline steps are complete. \
No menus, no questions, no narration."}"
    echo "[+] resuming: $d"
    _research_launch "$(basename "$d")" "$d" "$prompt"
}
report() {
    local vuln_id=$1
    [[ -z "$vuln_id" ]] && echo "usage: report VULN-001" && return 1
    local d
    d=$(cat ~/research/.active 2>/dev/null)
    [[ -z "$d" ]] && echo "[-] no active engagement" && return 1
    cd "$d" || return 1
    _research_launch "$(basename "$d")-report" "$d" "report $vuln_id"
}
pusheng() {
    local d
    d=$(cat ~/research/.active 2>/dev/null)
    [[ -z "$d" ]] && echo "[-] no active engagement" && return 1
    [[ ! -d "$d" ]] && echo "[-] invalid path" && return 1

    local umbrella=~/research/.private-research
    local name=$(basename "$d")

    # ensure umbrella repo exists locally
    if [[ ! -d "$umbrella/.git" ]]; then
        mkdir -p "$umbrella"
        cd "$umbrella" || return 1
        git init -q .
        echo "target/" > .gitignore
        echo "*/target/" >> .gitignore
        git add .gitignore
        git commit -q -m "init"
        if ! git remote get-url origin >/dev/null 2>&1; then
            command -v gh >/dev/null || { echo "[-] gh CLI not installed"; return 1; }
            echo "[*] creating private repo: private-research"
            gh repo create private-research --private --source=. --remote=origin
        fi
        git push -u origin HEAD
    fi

    # sync this engagement's files (excluding target/) into umbrella/<name>/
    mkdir -p "$umbrella/$name"
    rsync -a --delete --exclude='target/' --exclude='.git/' "$d/" "$umbrella/$name/"

    cd "$umbrella" || return 1
    local msg="${*:-checkpoint $(date '+%Y-%m-%d %H:%M:%S %Z') — $name}"
    git add .
    git commit -m "$msg" || {
        echo "[*] nothing to commit"
        return 0
    }
    git push
}
# <<< vuln research functions <
