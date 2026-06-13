#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/research/.claude"
MARKER="# >>> vuln research functions >>>"

# 1. detect interactive shell -> pick rc file
case "$(basename "${SHELL:-}")" in
    zsh)  RC="$HOME/.zshrc" ;;
    bash) RC="$HOME/.bashrc" ;;
    *)    echo "[-] unrecognized shell '${SHELL:-unknown}', defaulting to ~/.bashrc"
          RC="$HOME/.bashrc" ;;
esac
echo "[+] shell rc: $RC"

# 2. install template (CLAUDE.md + methodology/) into ~/research/.claude
[[ -f "$SCRIPT_DIR/CLAUDE.md" ]]    || { echo "[-] CLAUDE.md missing in $SCRIPT_DIR"; exit 1; }
[[ -d "$SCRIPT_DIR/methodology" ]] || { echo "[-] methodology/ missing in $SCRIPT_DIR"; exit 1; }

mkdir -p "$CLAUDE_DIR"
cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
cp -r "$SCRIPT_DIR/methodology" "$CLAUDE_DIR/"
echo "[+] template installed -> $CLAUDE_DIR"

# 3. append functions to rc (idempotent via marker)
[[ -f "$SCRIPT_DIR/shellrc.sh" ]] || { echo "[-] shellrc.sh missing in $SCRIPT_DIR"; exit 1; }

touch "$RC"
if grep -qF "$MARKER" "$RC"; then
    echo "[*] functions already in $RC, skipping append"
else
    printf '\n' >> "$RC"
    cat "$SCRIPT_DIR/shellrc.sh" >> "$RC"
    echo "[+] functions appended to $RC"
fi

echo "[+] done. run: source $RC"
