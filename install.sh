#!/usr/bin/env bash
set -euo pipefail

# install.sh — One-command setup for rhino-os v7.
# Idempotent — safe to re-run.
#
# Usage:
#   ./install.sh           # install everything
#   ./install.sh --check   # dry-run

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$SCRIPT_DIR"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) DRY_RUN=true ;;
    esac
done

GREEN='\033[0;32m'
CYAN='\033[0;36m'
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
    echo -e "    ${DIM}· $1 (exists)${NC}"
}

echo ""
echo -e "  ${CYAN}◆${NC} ${BOLD}rhino-os install${NC}"
echo ""

# --- 1. Create directories ---
for dir in \
    "$CLAUDE_DIR/knowledge"; do
    if [[ ! -d "$dir" ]]; then
        $DRY_RUN || mkdir -p "$dir"
        action "mkdir $dir"
    fi
done

# --- 2. Symlink CLI ---
echo ""
echo -e "  ${BOLD}CLI${NC}"
echo ""
LOCAL_BIN="$HOME/bin"
$DRY_RUN || mkdir -p "$LOCAL_BIN"

for tool in score.sh; do
    src="$RHINO_DIR/bin/$tool"
    [[ ! -f "$src" ]] && continue
    dest="$LOCAL_BIN/$tool"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        skip "~/bin/$tool"
    else
        $DRY_RUN || ln -sf "$src" "$dest"
        action "~/bin/$tool"
    fi
done

# taste.mjs lives in lens now
taste_src="$RHINO_DIR/lens/product/eval/taste.mjs"
if [[ -f "$taste_src" ]]; then
    taste_dest="$LOCAL_BIN/taste.mjs"
    if [[ -L "$taste_dest" && "$(readlink "$taste_dest")" == "$taste_src" ]]; then
        skip "~/bin/taste.mjs (lens)"
    else
        $DRY_RUN || ln -sf "$taste_src" "$taste_dest"
        action "~/bin/taste.mjs (lens)"
    fi
fi

rhino_dest="$LOCAL_BIN/rhino"
if [[ -L "$rhino_dest" && "$(readlink "$rhino_dest")" == "$RHINO_DIR/bin/rhino" ]]; then
    skip "~/bin/rhino"
else
    $DRY_RUN || ln -sf "$RHINO_DIR/bin/rhino" "$rhino_dest"
    action "~/bin/rhino"
fi

# --- 3. Set RHINO_DIR in shell profile ---
echo ""
echo -e "  ${BOLD}Environment${NC}"
PROFILE=""
if [[ -f "$HOME/.zshrc" ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    PROFILE="$HOME/.bashrc"
fi

if [[ -n "$PROFILE" ]]; then
    if grep -q "RHINO_DIR" "$PROFILE" 2>/dev/null; then
        skip "RHINO_DIR in $PROFILE"
    else
        $DRY_RUN || echo "export RHINO_DIR=\"$RHINO_DIR\"" >> "$PROFILE"
        action "RHINO_DIR=$RHINO_DIR added to $PROFILE"
    fi
fi

# --- Done ---
echo ""
if $DRY_RUN; then
    echo -e "  ${DIM}Dry run complete. Run without --check to apply.${NC}"
else
    echo -e "  ${GREEN}✓${NC} ${BOLD}Done.${NC} Reload your shell: ${DIM}source $PROFILE${NC}"
    echo ""
    echo -e "  ${DIM}Run${NC} ${BOLD}rhino init${NC} ${DIM}in each project to set up hooks and commands.${NC}"
fi
echo ""
