#!/usr/bin/env bash
set -euo pipefail

# uninstall.sh — Cleanly remove everything install.sh set up.
# Idempotent — safe to re-run. Only removes symlinks that point to rhino-os.
#
# Usage:
#   ./uninstall.sh           # uninstall everything
#   ./uninstall.sh --check   # dry-run

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$SCRIPT_DIR"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) DRY_RUN=true ;;
    esac
done

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

action() {
    if $DRY_RUN; then
        echo -e "    ${DIM}[dry-run]${NC} $1"
    else
        echo -e "    ${GREEN}✓${NC} $1"
    fi
}

skip() {
    echo -e "    ${DIM}· $1${NC}"
}

preserve() {
    echo -e "    ${YELLOW}✓${NC} $1 ${DIM}(preserved — your data)${NC}"
}

# Remove a symlink only if it points into RHINO_DIR
remove_if_ours() {
    local target="$1"
    local label="$2"
    if [[ -L "$target" ]]; then
        local link_dest
        link_dest="$(readlink "$target")"
        if [[ "$link_dest" == "$RHINO_DIR"* ]]; then
            $DRY_RUN || rm -f "$target"
            action "removed $label"
        else
            skip "$label (points elsewhere)"
        fi
    else
        skip "$label (not a symlink)"
    fi
}

echo ""
echo -e "  ${CYAN}◆${NC} ${BOLD}rhino-os uninstall${NC}"
echo ""

# --- 1. Remove mind/ symlinks from rules ---
echo -e "  ${BOLD}Mind${NC}"
for mind_file in identity.md thinking.md standards.md; do
    remove_if_ours "$CLAUDE_DIR/rules/$mind_file" "rules/$mind_file"
done

# --- 2. Remove hook symlinks ---
echo ""
echo -e "  ${BOLD}Hooks${NC}"
if [[ -d "$CLAUDE_DIR/hooks" ]]; then
    for hook_file in "$CLAUDE_DIR/hooks"/*.sh; do
        [[ ! -e "$hook_file" ]] && continue
        name="$(basename "$hook_file")"
        remove_if_ours "$hook_file" "hooks/$name"
    done
else
    skip "hooks/ directory (does not exist)"
fi

# --- 3. Remove CLI symlinks ---
echo ""
echo -e "  ${BOLD}CLI${NC}"
LOCAL_BIN="$HOME/bin"
for tool in rhino score.sh taste.mjs; do
    remove_if_ours "$LOCAL_BIN/$tool" "~/bin/$tool"
done

# --- 4. Remove RHINO_DIR from shell profile ---
echo ""
echo -e "  ${BOLD}Environment${NC}"
PROFILE=""
if [[ -f "$HOME/.zshrc" ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    PROFILE="$HOME/.bashrc"
fi

if [[ -n "$PROFILE" ]]; then
    if grep -q 'export RHINO_DIR=' "$PROFILE" 2>/dev/null; then
        $DRY_RUN || sed -i '' '/^export RHINO_DIR=/d' "$PROFILE"
        action "removed RHINO_DIR from $PROFILE"
    else
        skip "RHINO_DIR not in $PROFILE"
    fi
else
    skip "no shell profile found"
fi

# --- 5. Preserve user data ---
echo ""
echo -e "  ${BOLD}Your data${NC}"
if [[ -d "$CLAUDE_DIR/knowledge" ]]; then
    preserve "~/.claude/knowledge/"
else
    skip "~/.claude/knowledge/ (does not exist)"
fi
if [[ -d "$CLAUDE_DIR/plans" ]]; then
    preserve "~/.claude/plans/"
else
    skip "~/.claude/plans/ (does not exist)"
fi

# --- Done ---
echo ""
if $DRY_RUN; then
    echo -e "  ${BOLD}Dry run complete.${NC} Run without --check to apply."
else
    echo -e "  ${GREEN}✓${NC} ${BOLD}Done.${NC} rhino-os uninstalled."
    [[ -n "$PROFILE" ]] && echo -e "    ${DIM}Reload your shell: source $PROFILE${NC}"
fi
echo ""
