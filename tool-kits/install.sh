#!/usr/bin/env bash
#
# install.sh — single-file installer for my pentest toolkit (2026 edition).
# Supports: macOS (Homebrew) and Kali / Debian / Ubuntu (apt).
#
# Usage:
#   ./install.sh              install everything (idempotent, safe to re-run)
#   ./install.sh --check      report installed / missing for every tool, no install
#   ./install.sh --help       show this help
#
# 2026 currency notes:
#   - crackmapexec  -> netexec (nxc)         maintained fork, original is archived
#   - certipy       -> certipy-ad            ly4k's actively maintained fork
#   - bloodhound    -> bloodhound-ce         SpecterOps Community Edition ingestor
#   - nuclei                                 native package (Go binary, not pip)
#   - whatweb                                native package (Ruby tool, not pip)
#   - ProjectDiscovery suite                 subfinder, httpx, dnsx, katana, naabu

set -u

###########################################
# Install root
# Everything we control (uv tools, gems, git clones) lives under BASE_DIR.
# Brew tools stay under /usr/local or /opt/homebrew — Homebrew owns that prefix.
###########################################
BASE_DIR="${BASE_DIR:-$HOME/Tools}"
TOOLS_DIR="$BASE_DIR/custom-tools"
export UV_TOOL_DIR="$BASE_DIR/uv/tools"
export UV_TOOL_BIN_DIR="$BASE_DIR/bin"
export GEM_HOME="$BASE_DIR/gems"
export GEM_PATH="$GEM_HOME"
export PATH="$UV_TOOL_BIN_DIR:$GEM_HOME/bin:$PATH"
mkdir -p "$TOOLS_DIR" "$UV_TOOL_DIR" "$UV_TOOL_BIN_DIR" "$GEM_HOME"

###########################################
# OS detection
###########################################
PKG_MGR=""
detect_os() {
    case "$(uname -s)" in
        Darwin) PKG_MGR=brew ;;
        Linux)
            if [ -r /etc/os-release ] && grep -Eqi 'kali|debian|ubuntu' /etc/os-release; then
                PKG_MGR=apt
            else
                printf 'unsupported Linux distro (only Kali/Debian/Ubuntu)\n'; exit 1
            fi ;;
        *) printf 'unsupported OS: %s\n' "$(uname -s)"; exit 1 ;;
    esac
}
detect_os

###########################################
# Tool lists — native packages
# Two parallel lists so we can use the right name per package manager.
###########################################
BREW_FORMULAE=(
    nmap masscan rustscan tcpdump netcat
    sqlmap nikto ffuf feroxbuster gobuster
    nuclei subfinder httpx dnsx katana naabu
    bettercap hydra metasploit proxychains-ng
    hashcat john crunch
    amass theharvester
    binwalk
    android-platform-tools
)

BREW_CASKS=(
    wireshark
    burp-suite
    zap
    maltego
)

APT_PACKAGES=(
    nmap masscan rustscan tcpdump netcat-openbsd
    sqlmap nikto ffuf feroxbuster gobuster wpscan whatweb
    nuclei subfinder httpx-toolkit dnsx katana naabu
    bettercap hydra metasploit-framework proxychains4
    hashcat john crunch
    amass theharvester
    binwalk
    adb
    # GUI apps live in apt too on Linux:
    wireshark burpsuite zaproxy maltego
)

###########################################
# Tool lists — cross-platform
###########################################
GEMS=( wpscan )

# PyPI-hosted Python CLI tools
UV_TOOLS=(
    sqlmap
    droopescan
    impacket
    certipy-ad
    bloodhound-ce
    wesng
    volatility3
    oletools
    pwntools
)

# Tools not on PyPI — install via uv with a git URL.
# Format: displayed_name|uv_install_spec
UV_TOOLS_GIT=(
    "netexec|git+https://github.com/Pennyw0rth/NetExec"
    "xsser|git+https://github.com/epsylon/xsser"
)

GIT_REPOS=(
    "https://github.com/PowerShellMafia/PowerSploit.git|PowerSploit"
    "https://github.com/samratashok/nishang.git|nishang"
    "https://github.com/trustedsec/unicorn.git|unicorn"
    "https://github.com/BC-SECURITY/Empire.git|Empire"
    "https://github.com/danielmiessler/SecLists.git|SecLists"
    "https://github.com/fuzzdb-project/fuzzdb.git|fuzzdb"
    "https://github.com/swisskyrepo/PayloadsAllTheThings.git|PayloadsAllTheThings"
    "https://github.com/s0md3v/XSStrike.git|XSStrike"
    "https://github.com/urbanadventurer/WhatWeb.git|WhatWeb"
)

###########################################
# Output helpers
###########################################
c_blue=$'\033[1;34m'; c_yel=$'\033[1;33m'; c_grn=$'\033[1;32m'
c_red=$'\033[1;31m';  c_dim=$'\033[2m';    c_off=$'\033[0m'

section() { printf '\n%s==> %s%s\n' "$c_blue" "$*" "$c_off"; }
warn()    { printf '%s !! %s%s\n'   "$c_yel" "$*" "$c_off"; }
ok()      { printf '%s  ✓%s %s\n'   "$c_grn" "$c_off" "$*"; }
miss()    { printf '%s  ✗%s %s\n'   "$c_red" "$c_off" "$*"; }

INSTALLED=0
MISSING=0
mark_ok()   { INSTALLED=$((INSTALLED+1)); ok   "$1"; }
mark_miss() { MISSING=$((MISSING+1));     miss "$1"; }

###########################################
# Detection predicates (dispatch on PKG_MGR)
###########################################
# `brew list <name>` resolves both formula and cask, and follows aliases
# (so `metasploit` / `android-platform-tools` are detected even when they're
# casks or alias names rather than top-level formulae).
has_brew_pkg()     { brew list "$1" >/dev/null 2>&1; }
has_apt_pkg()      { dpkg -s "$1" >/dev/null 2>&1; }
has_gem()          { gem list -i "$1" >/dev/null 2>&1; }
has_uv_tool()      { uv tool list 2>/dev/null | awk '{print $1}' | grep -qx "$1"; }
has_git_clone()    { [ -d "$TOOLS_DIR/$1/.git" ]; }

###########################################
# Native install dispatch
###########################################
install_brew_formula() { brew install "$1"; }
install_brew_cask()    { brew install --cask "$1"; }
install_apt_pkg()      { sudo apt-get install -y "$1"; }

# GEM_HOME is set to $BASE_DIR/gems above, so plain `gem install` writes there
# without needing sudo or --user-install.
gem_install() { gem install "$1"; }

###########################################
# Pre-flight
###########################################
preflight() {
    command -v git >/dev/null 2>&1 || {
        if [ "$PKG_MGR" = brew ]; then warn "git missing — run: xcode-select --install"
        else warn "git missing — run: sudo apt-get install -y git"
        fi; exit 1;
    }

    if [ "$PKG_MGR" = brew ]; then
        command -v brew >/dev/null 2>&1 || { warn "brew not found — install from https://brew.sh"; exit 1; }
    else
        command -v apt-get >/dev/null 2>&1 || { warn "apt-get not found"; exit 1; }
    fi

    if ! command -v uv >/dev/null 2>&1; then
        section "Installing uv"
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi

    command -v gem >/dev/null 2>&1 || warn "gem not found — Ruby section will be skipped"
}

###########################################
# CHECK mode
###########################################
run_check() {
    if [ "$PKG_MGR" = brew ]; then
        section "Brew formulae"
        for f in "${BREW_FORMULAE[@]}"; do
            has_brew_pkg "$f" && mark_ok "$f" || mark_miss "$f"
        done
        section "Brew casks"
        for c in "${BREW_CASKS[@]}"; do
            has_brew_pkg "$c" && mark_ok "$c" || mark_miss "$c"
        done
    else
        section "apt packages"
        for p in "${APT_PACKAGES[@]}"; do
            has_apt_pkg "$p" && mark_ok "$p" || mark_miss "$p"
        done
    fi

    section "Ruby gems"
    if command -v gem >/dev/null 2>&1; then
        for g in "${GEMS[@]}"; do
            has_gem "$g" && mark_ok "$g" || mark_miss "$g"
        done
    else
        warn "gem missing, skipping"
    fi

    section "uv tools"
    if command -v uv >/dev/null 2>&1; then
        for t in "${UV_TOOLS[@]}"; do
            has_uv_tool "$t" && mark_ok "$t" || mark_miss "$t"
        done
        for entry in "${UV_TOOLS_GIT[@]}"; do
            name="${entry%%|*}"
            has_uv_tool "$name" && mark_ok "$name (git)" || mark_miss "$name (git)"
        done
    else
        warn "uv missing, skipping"
    fi

    section "Custom git clones ($TOOLS_DIR)"
    for entry in "${GIT_REPOS[@]}"; do
        name="${entry##*|}"
        has_git_clone "$name" && mark_ok "$name" || mark_miss "$name"
    done

    total=$((INSTALLED + MISSING))
    printf '\n%s==> Summary:%s %s%d installed%s, %s%d missing%s, %d total\n' \
        "$c_blue" "$c_off" "$c_grn" "$INSTALLED" "$c_off" "$c_red" "$MISSING" "$c_off" "$total"
    [ "$MISSING" -eq 0 ]
}

###########################################
# INSTALL mode
###########################################
run_install() {
    if [ "$PKG_MGR" = brew ]; then
        section "Brew formulae"
        for f in "${BREW_FORMULAE[@]}"; do
            if has_brew_pkg "$f"; then ok "$f already installed"
            else install_brew_formula "$f" || warn "failed: $f"
            fi
        done
        section "Brew casks"
        for c in "${BREW_CASKS[@]}"; do
            if has_brew_pkg "$c"; then ok "$c already installed"
            else install_brew_cask "$c" || warn "failed: $c"
            fi
        done
    else
        section "apt update"
        sudo apt-get update -y || warn "apt-get update failed"
        section "apt packages"
        for p in "${APT_PACKAGES[@]}"; do
            if has_apt_pkg "$p"; then ok "$p already installed"
            else install_apt_pkg "$p" || warn "failed: $p"
            fi
        done
    fi

    if command -v gem >/dev/null 2>&1; then
        section "Ruby gems"
        for g in "${GEMS[@]}"; do
            if has_gem "$g"; then ok "$g already installed"
            else gem_install "$g" || warn "failed: $g"
            fi
        done
    fi

    section "uv tools"
    for t in "${UV_TOOLS[@]}"; do
        if has_uv_tool "$t"; then ok "$t already installed"
        else uv tool install "$t" || warn "failed: $t"
        fi
    done
    for entry in "${UV_TOOLS_GIT[@]}"; do
        name="${entry%%|*}"; spec="${entry##*|}"
        if has_uv_tool "$name"; then ok "$name already installed"
        else uv tool install "$spec" || warn "failed: $name ($spec)"
        fi
    done

    section "Custom git clones ($TOOLS_DIR)"
    mkdir -p "$TOOLS_DIR"
    for entry in "${GIT_REPOS[@]}"; do
        url="${entry%%|*}"; name="${entry##*|}"; dest="$TOOLS_DIR/$name"
        if [ -d "$dest/.git" ]; then
            ( cd "$dest" && git pull --ff-only ) >/dev/null 2>&1 \
                && ok "updated $name" || warn "git pull failed: $name"
        else
            git clone --depth 1 "$url" "$dest" >/dev/null 2>&1 \
                && ok "cloned $name" || warn "git clone failed: $name"
        fi
    done

    printf '\n%s==> Done.%s Run %s./install.sh --check%s to verify.\n' \
        "$c_blue" "$c_off" "$c_dim" "$c_off"

    printf '\n%s==> Layout under %s%s%s\n' "$c_blue" "$c_dim" "$BASE_DIR" "$c_off"
    printf '       %s/bin           uv tool executables (nxc, certipy, ...)\n' "$BASE_DIR"
    printf '       %s/uv/tools      uv tool environments\n' "$BASE_DIR"
    printf '       %s/gems          ruby gems (wpscan, ...)\n' "$BASE_DIR"
    printf '       %s/custom-tools  git clones (PowerSploit, SecLists, ...)\n' "$BASE_DIR"
    printf '       (brew tools live under brew --prefix, not relocatable)\n'

    printf '\n%s==> Add this to your ~/.zshrc so the tools stay on PATH:%s\n' "$c_blue" "$c_off"
    cat <<EOF
       export BASE_DIR="\$HOME/Tools"
       export UV_TOOL_DIR="\$BASE_DIR/uv/tools"
       export UV_TOOL_BIN_DIR="\$BASE_DIR/bin"
       export GEM_HOME="\$BASE_DIR/gems"
       export GEM_PATH="\$GEM_HOME"
       export PATH="\$UV_TOOL_BIN_DIR:\$GEM_HOME/bin:\$PATH"
EOF
}

###########################################
# Dispatch
###########################################
show_help() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-install}" in
    -c|--check)  preflight; run_check ;;
    -h|--help)   show_help ;;
    install|"")  preflight; run_install ;;
    *) printf 'unknown option: %s\n\n' "$1"; show_help; exit 1 ;;
esac
