#!/usr/bin/env bash
set -euo pipefail

# install.sh — One-command setup for rhino-os v9.
# Idempotent — safe to re-run.
#
# Usage:
#   ./install.sh           # install everything
#   ./install.sh --check   # dry-run

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$SCRIPT_DIR"
CLAUDE_DIR="$HOME/.claude"
CONFIG_DIR="$HOME/.config/rhino-os"
DRY_RUN=false

# Plugin mode detection
PLUGIN_MODE=false
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]] || [[ -f "$RHINO_DIR/.claude-plugin/plugin.json" ]]; then
    PLUGIN_MODE=true
fi

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) DRY_RUN=true ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

warn() {
    echo -e "    ${YELLOW}⚠${NC} $1"
}

echo ""
echo -e "  ${CYAN}◆${NC} ${BOLD}rhino-os install${NC}"
echo ""

# --- 0. Check dependencies BEFORE starting ---
echo -e "  ${BOLD}Dependencies${NC}"
echo ""

# jq is required for scoring, eval, init, and session boot
if command -v jq &>/dev/null; then
    action "jq available ($(jq --version 2>&1 || echo 'unknown'))"
else
    warn "jq not found — needed by scoring, eval, init, and session boot"
    echo -e "      ${DIM}Install: brew install jq  (macOS) or apt install jq  (Linux)${NC}"
    echo -e "      ${DIM}https://jqlang.github.io/jq/download/${NC}"
    echo ""
    echo -e "      ${DIM}Continuing install — jq can be added later.${NC}"
fi

# Claude Code is required
if command -v claude &>/dev/null; then
    action "Claude Code available"
else
    warn "claude CLI not found — rhino-os is a Claude Code plugin"
    echo -e "      ${DIM}Install: https://docs.anthropic.com/en/docs/claude-code${NC}"
fi

echo ""

# --- 1. Create directories ---
for dir in \
    "$CLAUDE_DIR/knowledge" \
    "$CLAUDE_DIR/rules" \
    "$CLAUDE_DIR/agents" \
    "$CONFIG_DIR"; do
    if [[ ! -d "$dir" ]]; then
        $DRY_RUN || mkdir -p "$dir"
        action "mkdir $dir"
    fi
done

# --- 1b. Store install path so other tools can find us ---
if ! $DRY_RUN; then
    echo "$RHINO_DIR" > "$CONFIG_DIR/install-path"
fi
action "install path → $CONFIG_DIR/install-path"

# --- 2. Symlink mind files → ~/.claude/rules/ (skip in plugin mode — handled by skills) ---
if ! $PLUGIN_MODE; then
    echo -e "  ${BOLD}Mind${NC}"
    echo ""
    for mind_file in identity.md thinking.md standards.md; do
        src="$RHINO_DIR/mind/$mind_file"
        dest="$CLAUDE_DIR/rules/$mind_file"
        [[ ! -f "$src" ]] && continue
        if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
            skip "~/.claude/rules/$mind_file"
        else
            $DRY_RUN || ln -sf "$src" "$dest"
            action "~/.claude/rules/$mind_file"
        fi
    done
    # Lens mind files (e.g., product-eyes.md, product-self.md)
    for lens_dir in "$RHINO_DIR"/lens/*/mind; do
        [[ ! -d "$lens_dir" ]] && continue
        for lens_mind in "$lens_dir"/*.md; do
            [[ ! -f "$lens_mind" ]] && continue
            name="$(basename "$lens_mind")"
            dest="$CLAUDE_DIR/rules/$name"
            if [[ -L "$dest" && "$(readlink "$dest")" == "$lens_mind" ]]; then
                skip "~/.claude/rules/$name"
            else
                $DRY_RUN || ln -sf "$lens_mind" "$dest"
                action "~/.claude/rules/$name (lens)"
            fi
        done
    done
else
    echo -e "  ${BOLD}Mind${NC}"
    echo -e "    ${DIM}plugin mode — handled by skills/${NC}"
fi

# --- 3. Skills are the commands (plugin system handles routing) ---
echo ""
echo -e "  ${BOLD}Skills${NC}"
SKILL_COUNT=$(find "$RHINO_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
echo -e "    ${DIM}${SKILL_COUNT} skills available via plugin system${NC}"

# --- 4. Symlink agents → ~/.claude/agents/ (skip in plugin mode) ---
if ! $PLUGIN_MODE; then
    echo ""
    echo -e "  ${BOLD}Agents${NC}"
    echo ""
    AGENTS_DIR="$CLAUDE_DIR/agents"
    mkdir -p "$AGENTS_DIR"
    AGENT_COUNT=0
    for agent_file in "$RHINO_DIR"/agents/*.md; do
        [[ ! -f "$agent_file" ]] && continue
        name="$(basename "$agent_file")"
        dest="$AGENTS_DIR/$name"
        if [[ -L "$dest" && "$(readlink "$dest")" == "$agent_file" ]]; then
            skip "~/.claude/agents/$name"
        else
            $DRY_RUN || ln -sf "$agent_file" "$dest"
            action "~/.claude/agents/$name"
        fi
        AGENT_COUNT=$((AGENT_COUNT + 1))
    done
    echo -e "    ${DIM}${AGENT_COUNT} agents available${NC}"
else
    echo ""
    echo -e "  ${BOLD}Agents${NC}"
    echo -e "    ${DIM}plugin mode — handled by plugin system${NC}"
fi

# --- 5. Symlink CLI (skip in plugin mode — no global ~/bin) ---
if ! $PLUGIN_MODE; then
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
else
    echo ""
    echo -e "  ${BOLD}CLI${NC}"
    echo -e "    ${DIM}plugin mode — no global CLI install${NC}"
fi

# --- 6. Set RHINO_DIR + PATH in shell profile (skip in plugin mode) ---
if ! $PLUGIN_MODE; then
    echo ""
    echo -e "  ${BOLD}Environment${NC}"
    PROFILE=""
    if [[ -f "$HOME/.zshrc" ]]; then
        PROFILE="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        PROFILE="$HOME/.bashrc"
    elif [[ -f "$HOME/.bash_profile" ]]; then
        PROFILE="$HOME/.bash_profile"
    fi

    if [[ -n "$PROFILE" ]]; then
        if grep -q "RHINO_DIR" "$PROFILE" 2>/dev/null; then
            skip "RHINO_DIR in $PROFILE"
        else
            $DRY_RUN || echo "export RHINO_DIR=\"$RHINO_DIR\"" >> "$PROFILE"
            action "RHINO_DIR=$RHINO_DIR added to $PROFILE"
        fi
        # Ensure ~/bin is in PATH
        if grep -q 'PATH.*\$HOME/bin\|PATH.*~/bin' "$PROFILE" 2>/dev/null; then
            skip "~/bin in PATH"
        else
            $DRY_RUN || echo 'export PATH="$HOME/bin:$PATH"' >> "$PROFILE"
            action '~/bin added to PATH'
        fi
    else
        echo -e "    \033[1;33m⚠\033[0m No shell profile found (.zshrc, .bashrc, .bash_profile)"
        echo -e "    ${DIM}Add manually: export PATH=\"\$HOME/bin:\$PATH\" && export RHINO_DIR=\"$RHINO_DIR\"${NC}"
    fi
else
    echo ""
    echo -e "  ${BOLD}Environment${NC}"
    echo -e "    ${DIM}plugin mode — no shell profile changes${NC}"
fi

# --- 7. Plugin mode verification ---
if $PLUGIN_MODE && ! $DRY_RUN; then
    echo ""
    echo -e "  ${BOLD}Plugin Verification${NC}"
    echo ""

    # Check that skills are actually findable
    local_skill_count=$(find "$RHINO_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$local_skill_count" -ge 10 ]]; then
        action "$local_skill_count skills found in $RHINO_DIR/skills/"
    else
        warn "only $local_skill_count skills found (expected 10+) — plugin may not work correctly"
    fi

    # Check plugin.json exists and is valid
    plugin_json="$RHINO_DIR/.claude-plugin/plugin.json"
    if [[ -f "$plugin_json" ]]; then
        if command -v jq &>/dev/null && jq empty "$plugin_json" 2>/dev/null; then
            action "plugin.json valid"
        elif [[ -f "$plugin_json" ]]; then
            action "plugin.json exists"
        fi
    else
        warn "plugin.json not found at $plugin_json"
    fi

    # Check mind skill exists (delivers mind files in plugin mode)
    if [[ -f "$RHINO_DIR/skills/rhino-mind/SKILL.md" ]]; then
        action "rhino-mind skill available (delivers mind files)"
    else
        warn "rhino-mind skill missing — mind files won't load in plugin mode"
    fi
fi

# --- 8. Verify installation ---
echo ""
if $DRY_RUN; then
    echo -e "  ${DIM}Dry run complete. Run without --check to apply.${NC}"
else
    # Run doctor for verification (with error handling)
    if PATH="${LOCAL_BIN:-$HOME/bin}:$PATH" "$RHINO_DIR/bin/rhino" doctor 2>/dev/null; then
        : # doctor ran successfully
    else
        echo ""
        warn "rhino doctor exited with an error — this is ok for first install"
        echo -e "      ${DIM}Run 'rhino doctor' after sourcing your shell profile to verify.${NC}"
    fi

    # --- Post-install summary ---
    echo ""
    echo -e "  ${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✓${NC} ${BOLD}rhino-os installed${NC}"
    echo ""

    if $PLUGIN_MODE; then
        echo -e "  ${BOLD}What was set up:${NC}"
        echo -e "    · ${local_skill_count:-0} skills loaded via plugin system"
        echo -e "    · agents loaded via plugin system"
        echo -e "    · mind files delivered via rhino-mind skill"
        echo ""
        echo -e "  ${BOLD}Next steps:${NC}"
        echo -e "    ${BOLD}1.${NC} Open Claude Code in any project"
        echo -e "    ${BOLD}2.${NC} Type ${BOLD}/plan${NC} to find the bottleneck and start building"
        echo -e "    ${BOLD}3.${NC} Or type ${BOLD}/rhino help${NC} to see all commands"
    else
        # Count what was installed
        mind_count=0; agent_count_final=0
        for f in "$CLAUDE_DIR/rules"/*.md; do [[ -L "$f" ]] && mind_count=$((mind_count + 1)); done
        for f in "$CLAUDE_DIR/agents"/*.md; do [[ -L "$f" ]] && agent_count_final=$((agent_count_final + 1)); done

        echo -e "  ${BOLD}What was set up:${NC}"
        echo -e "    · ${mind_count} mind files in ~/.claude/rules/"
        echo -e "    · ${agent_count_final} agents in ~/.claude/agents/"
        echo -e "    · rhino CLI in ~/bin/"
        echo -e "    · RHINO_DIR in ${PROFILE:-your shell profile}"
        echo ""
        echo -e "  ${BOLD}Next steps:${NC}"
        echo -e "    ${BOLD}1.${NC} Source your shell:  ${BOLD}source ${PROFILE:-~/.zshrc}${NC}"
        echo -e "    ${BOLD}2.${NC} In any project:     ${BOLD}rhino init${NC}"
        echo -e "    ${BOLD}3.${NC} Then start building: ${BOLD}/plan${NC}  or  ${BOLD}/rhino help${NC}"
    fi

    echo ""
fi
echo ""
