#!/usr/bin/env bash
# fix-reference-links.sh — WP-14b: prune dangling cross-links in the skills reference library.
#
# WHY: a handful of reference files link to sibling skill trees that are NOT vendored here —
#   ../../../../web-app-logic/reference/scenarios/...   (app-logic tree, not present)
#   ../../../../system/reference/scenarios/...          (OS-privesc/pivot tree, not present)
# Per the WP-14 decision (skills/INDEX.md), this library is APPLICATION-LAYER and those trees
# are not vendored. An autonomous agent following one of these links (e.g. during a G2/G7
# cross-check) hits a dead end. This script removes the broken link while KEEPING the
# human-readable reference text, appending a short scope note.
#
# Transformation:
#   [cache/poisoning-body-args.md](../../../../web-app-logic/reference/scenarios/cache/poisoning-body-args.md)
#       becomes
#   cache/poisoning-body-args.md *(out of app-layer scope — see skills/INDEX.md)*
#
# Properties: idempotent (safe to re-run), makes .bak backups by default, dry-run unless --apply.
#
# Usage:
#   ./fix-reference-links.sh [TARGET_DIR]            # dry-run: show what would change
#   ./fix-reference-links.sh [TARGET_DIR] --apply    # apply the fix (writes .bak backups)
#   ./fix-reference-links.sh [TARGET_DIR] --apply --no-backup
#
# TARGET_DIR defaults to ~/research/.claude/skills/reference (the engagement template).
# If you keep a working copy of the repo, point it at <repo>/claude/skills/reference instead.

set -euo pipefail

TARGET="${1:-$HOME/research/.claude/skills/reference}"
APPLY=0
BACKUP=1
for arg in "${@:2}"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --no-backup) BACKUP=0 ;;
    *) echo "[-] unknown arg: $arg"; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "[-] target dir not found: $TARGET"; exit 1; }

# Perl regex: a markdown link [label](URL) whose URL is one-or-more ../ then web-app-logic/ or system/.
# Replacement keeps the label and appends the scope note. After replacement there is no
# [..](..) link left, so re-running matches nothing → idempotent.
PATTERN='\[([^\]]+)\]\((?:\.\./)+(?:web-app-logic|system)/[^)]+\)'
REPLACE='$1 *(out of app-layer scope — see skills/INDEX.md)*'

# Find affected files
mapfile -t HITS < <(grep -rlE '\]\((\.\./)+(web-app-logic|system)/' "$TARGET" --include='*.md' 2>/dev/null || true)

if [[ ${#HITS[@]} -eq 0 ]]; then
  echo "[+] No dangling system/ or web-app-logic/ cross-links found under: $TARGET"
  echo "    (already clean, or none present.)"
  exit 0
fi

echo "[*] Target: $TARGET"
echo "[*] Files with dangling cross-links: ${#HITS[@]}"
TOTAL=0
for f in "${HITS[@]}"; do
  n=$(grep -coE '\]\((\.\./)+(web-app-logic|system)/' "$f")
  TOTAL=$((TOTAL + n))
  echo "    - ${f#$TARGET/}  ($n link(s))"
done
echo "[*] Total dangling links: $TOTAL"

if [[ $APPLY -eq 0 ]]; then
  echo
  echo "[dry-run] No files changed. Re-run with --apply to fix."
  echo "[dry-run] Preview of the replacement on the first file:"
  perl -pe "s#${PATTERN}#${REPLACE}#g" "${HITS[0]}" | grep -nE 'out of app-layer scope' | head -5 || true
  exit 0
fi

echo
echo "[*] Applying fix..."
for f in "${HITS[@]}"; do
  if [[ $BACKUP -eq 1 ]]; then
    perl -i.bak -pe "s#${PATTERN}#${REPLACE}#g" "$f"
  else
    perl -i -pe "s#${PATTERN}#${REPLACE}#g" "$f"
  fi
  echo "    fixed: ${f#$TARGET/}"
done

# Verify
REMAIN=$(grep -rlE '\]\((\.\./)+(web-app-logic|system)/' "$TARGET" --include='*.md' 2>/dev/null | wc -l | tr -d ' ')
echo
if [[ "$REMAIN" == "0" ]]; then
  echo "[+] Done. 0 dangling cross-links remain."
  [[ $BACKUP -eq 1 ]] && echo "    Backups written as *.bak (delete once you've verified)."
else
  echo "[!] $REMAIN file(s) still contain a matching pattern — inspect manually."
  exit 1
fi
