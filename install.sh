#!/usr/bin/env bash
set -euo pipefail

# install.sh — One-command setup for rhino-os v5.
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
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

action() {
    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${NC} $1"
    else
        echo -e "  ${GREEN}✓${NC} $1"
    fi
}

skip() {
    echo -e "  ${DIM}[skip]${NC} $1 (exists)"
}

echo -e "${BOLD}Setting up rhino-os v5...${NC}"
echo ""

# --- 1. Create directories ---
for dir in \
    "$CLAUDE_DIR/knowledge" \
    "$CLAUDE_DIR/logs" \
    "$CLAUDE_DIR/programs" \
    "$CLAUDE_DIR/commands" \
    "$CLAUDE_DIR/hooks" \
    "$CLAUDE_DIR/plans"; do
    if [[ ! -d "$dir" ]]; then
        $DRY_RUN || mkdir -p "$dir"
        action "mkdir $dir"
    fi
done

# --- 2. Symlink programs ---
echo ""
echo -e "${BOLD}Programs:${NC}"
for prog in "$RHINO_DIR"/programs/*.md; do
    [[ ! -f "$prog" ]] && continue
    name="$(basename "$prog")"
    target="$CLAUDE_DIR/programs/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$prog" ]]; then
        skip "programs/$name"
    else
        $DRY_RUN || ln -sf "$prog" "$target"
        action "programs/$name"
    fi
done

# --- 3. Symlink skills as commands ---
echo ""
echo -e "${BOLD}Skills:${NC}"

# Clean up old commands that no longer exist
for old_cmd in strategy sweep todofocus experiment design score taste eval product-eval scout research-taste init product-2026 council meta smart-commit docs review; do
    old_cmd_file="$CLAUDE_DIR/commands/$old_cmd/SKILL.md"
    if [[ -L "$old_cmd_file" || -f "$old_cmd_file" ]]; then
        $DRY_RUN || rm -f "$old_cmd_file"
        $DRY_RUN || rmdir "$CLAUDE_DIR/commands/$old_cmd" 2>/dev/null || true
        action "removed old command: $old_cmd"
    fi
done

for skill_dir in "$RHINO_DIR"/skills/*/; do
    [[ ! -d "$skill_dir" ]] && continue
    skill_name="$(basename "$skill_dir")"
    skill_file="$skill_dir/SKILL.md"
    [[ ! -f "$skill_file" ]] && continue

    cmd_dir="$CLAUDE_DIR/commands/$skill_name"
    cmd_file="$cmd_dir/SKILL.md"

    if [[ -L "$cmd_file" && "$(readlink "$cmd_file")" == "$skill_file" ]]; then
        skip "commands/$skill_name"
    else
        $DRY_RUN || mkdir -p "$cmd_dir"
        $DRY_RUN || ln -sf "$skill_file" "$cmd_file"
        action "commands/$skill_name"
    fi
done

# --- 4. Symlink hooks ---
echo ""
echo -e "${BOLD}Hooks:${NC}"

# Clean up old hooks that no longer exist
for old_hook in autonomy_gate.sh capture_knowledge.sh check_predictions.sh enforce_ideation_readonly.sh extract_patterns.sh session_context.sh thinking_nudge.sh track_cost.sh track_usage.sh; do
    old_hook_file="$CLAUDE_DIR/hooks/$old_hook"
    if [[ -L "$old_hook_file" ]]; then
        $DRY_RUN || rm -f "$old_hook_file"
        action "removed old hook: $old_hook"
    fi
done

for hook in "$RHINO_DIR"/hooks/*.sh; do
    [[ ! -f "$hook" ]] && continue
    name="$(basename "$hook")"
    target="$CLAUDE_DIR/hooks/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$hook" ]]; then
        skip "hooks/$name"
    else
        $DRY_RUN || ln -sf "$hook" "$target"
        $DRY_RUN || chmod +x "$hook"
        action "hooks/$name"
    fi
done

# --- 5. Symlink bin tools ---
echo ""
echo -e "${BOLD}CLI tools:${NC}"
LOCAL_BIN="$HOME/bin"
$DRY_RUN || mkdir -p "$LOCAL_BIN"

for tool in score.sh taste.mjs; do
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

rhino_dest="$LOCAL_BIN/rhino"
if [[ -L "$rhino_dest" && "$(readlink "$rhino_dest")" == "$RHINO_DIR/bin/rhino" ]]; then
    skip "~/bin/rhino"
else
    $DRY_RUN || ln -sf "$RHINO_DIR/bin/rhino" "$rhino_dest"
    action "~/bin/rhino"
fi

# --- 6. Merge settings.json ---
echo ""
echo -e "${BOLD}Settings:${NC}"
SETTINGS_SRC="$RHINO_DIR/config/settings.json"
SETTINGS_DEST="$CLAUDE_DIR/settings.json"

if [[ -f "$SETTINGS_DEST" ]]; then
    if command -v jq &>/dev/null; then
        # Replace hooks section entirely with source (clean slate for v5)
        $DRY_RUN || {
            tmp="$(mktemp)"
            jq -s '.[0] * {hooks: .[1].hooks}' "$SETTINGS_DEST" "$SETTINGS_SRC" > "$tmp" && mv "$tmp" "$SETTINGS_DEST"
        }
        action "settings.json (hooks updated to v5)"
    else
        echo -e "  ${YELLOW}[warn]${NC} jq not found — copy config/settings.json manually"
    fi
else
    $DRY_RUN || cp "$SETTINGS_SRC" "$SETTINGS_DEST"
    action "settings.json (copied)"
fi

# --- 7. Set RHINO_DIR in shell profile ---
echo ""
echo -e "${BOLD}Environment:${NC}"
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
    echo -e "${BOLD}Dry run complete.${NC} Run without --check to apply."
else
    echo -e "${BOLD}Done.${NC} Open any project and run ${BLUE}/setup${NC} to onboard it."
    echo -e "${DIM}Reload your shell: source $PROFILE${NC}"
fi
