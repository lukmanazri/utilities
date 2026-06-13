# Run me sourced:  source setup.sh   (NOT bash setup.sh)
# bash setup.sh runs in a child shell, so the final `source` can't reach your shell.

_setup_research() {
    local CLAUDE_DIR="$HOME/research/.claude"
    local MARKER="# >>> vuln research functions >>>"
    local SRC SCRIPT_DIR RC SH

    # resolve this script's dir, in bash or zsh
    if [ -n "${BASH_SOURCE:-}" ]; then
        SRC="${BASH_SOURCE[0]}"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        SRC="${(%):-%x}"
    else
        SRC="$0"
    fi
    SCRIPT_DIR="$(cd "$(dirname "$SRC")" && pwd)"

    # 1. detect the shell actually running
    if [ -n "${ZSH_VERSION:-}" ]; then
        RC="$HOME/.zshrc"; SH=zsh
    elif [ -n "${BASH_VERSION:-}" ]; then
        RC="$HOME/.bashrc"; SH=bash
    else
        echo "[-] unknown shell; run this sourced under bash or zsh"; return 1
    fi
    echo "[+] shell: $SH  ->  $RC"

    # 2. copy template files + dirs into ~/research/.claude
    [ -f "$SCRIPT_DIR/CLAUDE.md" ]    || { echo "[-] CLAUDE.md missing in $SCRIPT_DIR"; return 1; }
    [ -d "$SCRIPT_DIR/methodology" ]  || { echo "[-] methodology/ missing in $SCRIPT_DIR"; return 1; }
    [ -f "$SCRIPT_DIR/shellrc.sh" ]   || { echo "[-] shellrc.sh missing in $SCRIPT_DIR"; return 1; }

    mkdir -p "$CLAUDE_DIR"
    cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    cp -r "$SCRIPT_DIR/methodology" "$CLAUDE_DIR/"
    echo "[+] template installed -> $CLAUDE_DIR"

    # 3. append functions to rc (idempotent via marker)
    touch "$RC"
    if grep -qF "$MARKER" "$RC"; then
        echo "[*] functions already in $RC, skipping append"
    else
        printf '\n' >> "$RC"
        cat "$SCRIPT_DIR/shellrc.sh" >> "$RC"
        echo "[+] functions appended to $RC"
    fi

    # 4. source it into the current shell
    # shellcheck disable=SC1090
    source "$RC"
    echo "[+] sourced $RC  ->  vuln/engage/resume/report ready"
}

_setup_research
unset -f _setup_research 2>/dev/null
