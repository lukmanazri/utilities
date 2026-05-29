vuln() {
    local repo=$1
    local name=$(basename $repo .git)
    local ts=$(date +%Y%m%d)
    local d=~/research/${ts}-${name}
    
    mkdir -p $d
    cp ~/research/claude/v2/CLAUDE.md $d/
    cp -r ~/research/claude/v2/methodology $d/
    cd $d
    git clone $repo
    claude --model claude-opus-4-7 --dangerously-skip-permissions
}
