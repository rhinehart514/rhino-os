#!/usr/bin/env bash
set -euo pipefail

# install.sh — Install rhino-os into ~/.claude/
#
# What this does:
# 1. Backs up existing files before overwriting
# 2. Symlinks individual files (not directories) from repo into ~/.claude/
# 3. Merges settings.json (preserves your existing MCP servers and hooks)
# 4. Seeds knowledge directories from templates
# 5. Installs LaunchAgents on macOS (optional)
#
# Safe to re-run (idempotent).
#
# Usage: ./install.sh [--no-launchd] [--no-backup]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.backup-$(date +%Y%m%d-%H%M%S)"
INSTALL_LAUNCHD=true
CREATE_BACKUP=true

# Parse args
for arg in "$@"; do
    case $arg in
        --no-launchd) INSTALL_LAUNCHD=false ;;
        --no-backup) CREATE_BACKUP=false ;;
        --help|-h)
            echo "Usage: ./install.sh [--no-launchd] [--no-backup]"
            echo ""
            echo "Options:"
            echo "  --no-launchd  Skip installing macOS LaunchAgents"
            echo "  --no-backup   Skip backing up existing files"
            exit 0
            ;;
    esac
done

echo "=== rhino-os installer ==="
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# Ensure target directories exist
mkdir -p "$CLAUDE_DIR"/{agents/refs,skills,rules,hooks,evals/rubrics,evals/reports,knowledge,logs,state,plans}

# --- Helper functions ---

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" && "$CREATE_BACKUP" == "true" ]]; then
        mkdir -p "$BACKUP_DIR"
        local rel_path="${target#$CLAUDE_DIR/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$target" "$backup_path"
        echo "  backed up: $rel_path"
    fi
}

symlink_file() {
    local source="$1"
    local target="$2"

    # Skip if already correctly linked
    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        echo "  already linked: $(basename "$target")"
        return
    fi

    backup_if_exists "$target"
    ln -sf "$source" "$target"
    echo "  linked: $(basename "$target")"
}

# --- 1. Programs (the core of rhino-os) ---
echo "Installing programs..."
mkdir -p "$CLAUDE_DIR/programs"
for program in "$SCRIPT_DIR"/programs/*.md; do
    name="$(basename "$program")"
    symlink_file "$program" "$CLAUDE_DIR/programs/$name"
done

# --- 2. Agents (legacy, still functional) ---
echo "Installing agents..."
for agent in "$SCRIPT_DIR"/agents/*.md; do
    name="$(basename "$agent")"
    symlink_file "$agent" "$CLAUDE_DIR/agents/$name"
done

# Agent refs (reference docs agents depend on)
if [[ -d "$SCRIPT_DIR/agents/refs" ]]; then
    mkdir -p "$CLAUDE_DIR/agents/refs"
    for ref in "$SCRIPT_DIR"/agents/refs/*.md; do
        name="$(basename "$ref")"
        symlink_file "$ref" "$CLAUDE_DIR/agents/refs/$name"
    done
fi

# --- 3. Skills ---
echo "Installing skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name="$(basename "$skill_dir")"
    mkdir -p "$CLAUDE_DIR/skills/$skill_name"
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        symlink_file "$skill_dir/SKILL.md" "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
    fi
done

# --- 3. Rules ---
echo "Installing rules..."
for rule in "$SCRIPT_DIR"/rules/*.md; do
    name="$(basename "$rule")"
    symlink_file "$rule" "$CLAUDE_DIR/rules/$name"
done

# --- 4. Hooks ---
echo "Installing hooks..."
for hook in "$SCRIPT_DIR"/hooks/*; do
    name="$(basename "$hook")"
    symlink_file "$hook" "$CLAUDE_DIR/hooks/$name"
    chmod +x "$CLAUDE_DIR/hooks/$name"
done

# --- 5. Eval rubrics ---
echo "Installing eval rubrics..."
for rubric in "$SCRIPT_DIR"/evals/rubrics/*.md; do
    name="$(basename "$rubric")"
    symlink_file "$rubric" "$CLAUDE_DIR/evals/rubrics/$name"
done

# --- 6. CLAUDE.md ---
echo "Installing CLAUDE.md..."
if [[ -e "$CLAUDE_DIR/CLAUDE.md" && ! -L "$CLAUDE_DIR/CLAUDE.md" ]]; then
    echo "  CLAUDE.md exists and is not a symlink."
    echo "  Your existing CLAUDE.md is preserved. Template available at:"
    echo "  $SCRIPT_DIR/config/CLAUDE.md"
else
    symlink_file "$SCRIPT_DIR/config/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
fi

# --- 7. Settings.json (merge hooks additively, don't overwrite) ---
echo "Merging settings.json..."
if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
    if command -v jq &> /dev/null; then
        backup_if_exists "$CLAUDE_DIR/settings.json"

        # Additive merge: add template hooks that don't exist in user config
        # For each hook in template, check if command already exists in user config
        jq -s '
          # Start with user config
          .[1] as $user | .[0] as $template |
          $user |
          # For each hook type (PreToolUse, PostToolUse, Stop), add missing hooks
          .hooks.PreToolUse |= (
            . as $existing |
            ($existing | map(.hooks // [] | map(.command // "")) | flatten) as $cmds |
            ($template.hooks.PreToolUse // [] | map(
              select(.hooks as $h | $cmds | any(. == ($h[0].command // "")) | not)
            )) as $new |
            $existing + $new
          ) |
          .hooks.PostToolUse |= (
            . as $existing |
            ($existing | map(.hooks // [] | map(.command // "")) | flatten) as $cmds |
            ($template.hooks.PostToolUse // [] | map(
              select(.hooks as $h | $cmds | any(. == ($h[0].command // "")) | not)
            )) as $new |
            $existing + $new
          ) |
          # Merge non-hooks keys from template (add missing, dont overwrite existing)
          ($template | del(.hooks)) as $tmpl_base |
          ($tmpl_base * (. | del(.hooks))) as $merged_base |
          $merged_base + {hooks: .hooks}
        ' "$SCRIPT_DIR/config/settings.json" \
          "$CLAUDE_DIR/settings.json" \
          > "$CLAUDE_DIR/settings.json.tmp"
        mv "$CLAUDE_DIR/settings.json.tmp" "$CLAUDE_DIR/settings.json"
        echo "  merged settings.json (hooks added additively, existing preserved)"
    else
        echo "  WARNING: jq not installed. Skipping settings merge."
        echo "  Install jq: brew install jq"
        echo "  Then re-run ./install.sh"
    fi
else
    cp "$SCRIPT_DIR/config/settings.json" "$CLAUDE_DIR/settings.json"
    echo "  created settings.json from template"
fi

# --- 8. config.json (merge MCP servers) ---
echo "Merging config.json..."
if [[ -f "$CLAUDE_DIR/config.json" ]]; then
    if command -v jq &> /dev/null; then
        backup_if_exists "$CLAUDE_DIR/config.json"
        # Additive merge: template MCP servers + user MCP servers (user wins on conflict)
        jq -s '.[0].mcpServers as $tmpl | .[1] | .mcpServers = ($tmpl + .mcpServers)' \
            "$SCRIPT_DIR/config/config.json" \
            "$CLAUDE_DIR/config.json" \
            > "$CLAUDE_DIR/config.json.tmp"
        # Expand $HOME in paths (MCP server args use $HOME)
        sed "s|\$HOME|$HOME|g" "$CLAUDE_DIR/config.json.tmp" > "$CLAUDE_DIR/config.json.tmp2"
        mv "$CLAUDE_DIR/config.json.tmp2" "$CLAUDE_DIR/config.json"
        rm -f "$CLAUDE_DIR/config.json.tmp"
        echo "  merged config.json (MCP servers added additively, yours preserved)"
    else
        echo "  WARNING: jq not installed. Skipping config merge."
    fi
else
    sed "s|\$HOME|$HOME|g" "$SCRIPT_DIR/config/config.json" > "$CLAUDE_DIR/config.json"
    echo "  created config.json from template"
fi

# --- 9. Seed knowledge directories ---
echo "Seeding knowledge directories..."

seed_knowledge_dir() {
    local agent_name="$1"
    local display_name="$2"
    mkdir -p "$CLAUDE_DIR/knowledge/$agent_name"

    # Seed from agent-specific knowledge if it exists
    if [[ -d "$SCRIPT_DIR/knowledge/$agent_name" ]]; then
        for seed_file in "$SCRIPT_DIR"/knowledge/"$agent_name"/*; do
            [[ ! -f "$seed_file" ]] && continue
            name="$(basename "$seed_file")"
            target="$CLAUDE_DIR/knowledge/$agent_name/$name"
            if [[ ! -f "$target" ]]; then
                cp "$seed_file" "$target"
                echo "  seeded: $agent_name/$name"
            else
                echo "  exists: $agent_name/$name (preserved)"
            fi
        done
    fi

    # Seed from template if agent-specific doesn't exist
    for template_file in "$SCRIPT_DIR"/knowledge/_template/*.md; do
        [[ ! -f "$template_file" ]] && continue
        name="$(basename "$template_file")"
        [[ "$name" == "README.md" ]] && continue
        target="$CLAUDE_DIR/knowledge/$agent_name/$name"
        if [[ ! -f "$target" ]]; then
            cp "$template_file" "$target"
            if command -v sed &> /dev/null; then
                sed -i '' "s/\[Agent Name\]/$display_name/g" "$target" 2>/dev/null || \
                sed -i "s/\[Agent Name\]/$display_name/g" "$target" 2>/dev/null || true
            fi
            echo "  seeded: $agent_name/$name"
        else
            echo "  exists: $agent_name/$name (preserved)"
        fi
    done
}

seed_knowledge_dir "scout" "Scout"
seed_knowledge_dir "design-engineer" "Design Engineer"

# Seed intelligence layer data (landscape.json, etc.)
echo "Seeding intelligence layer data..."
for seed_file in "$SCRIPT_DIR"/knowledge/*.json; do
    [[ ! -f "$seed_file" ]] && continue
    name="$(basename "$seed_file")"
    target="$CLAUDE_DIR/knowledge/$name"
    if [[ ! -f "$target" ]]; then
        cp "$seed_file" "$target"
        echo "  seeded: $name"
    else
        echo "  exists: $name (preserved)"
    fi
done

# Migrate old money-scout knowledge → scout
if [[ -d "$CLAUDE_DIR/knowledge/money-scout" && ! -d "$CLAUDE_DIR/knowledge/scout" ]]; then
    mv "$CLAUDE_DIR/knowledge/money-scout" "$CLAUDE_DIR/knowledge/scout"
    echo "  migrated: money-scout → scout"
fi

# --- 10. Make scripts executable + install rhino CLI ---
echo "Setting permissions..."
if ls "$SCRIPT_DIR"/automation/scripts/*.sh &>/dev/null; then
    chmod +x "$SCRIPT_DIR"/automation/scripts/*.sh
    echo "  automation scripts marked executable"
fi

# Install rhino CLI
chmod +x "$SCRIPT_DIR/bin/rhino"
RHINO_BIN_TARGET="$HOME/bin/rhino"
mkdir -p "$HOME/bin"
ln -sf "$SCRIPT_DIR/bin/rhino" "$RHINO_BIN_TARGET"
echo "  linked: rhino CLI → $RHINO_BIN_TARGET"
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo "  NOTE: Add ~/bin to your PATH if not already present"
fi

# --- 10b. Install MCP server dependencies ---
echo "Installing MCP server..."
if [[ -f "$SCRIPT_DIR/src/mcp-server/package.json" ]]; then
    (cd "$SCRIPT_DIR/src/mcp-server" && npm install --silent 2>/dev/null) && \
        echo "  rhino-state MCP server installed" || \
        echo "  WARNING: MCP server install failed (run manually: cd src/mcp-server && npm install)"
fi

# --- 10c. Install API server dependencies ---
echo "Installing API server..."
if [[ -f "$SCRIPT_DIR/src/api-server/package.json" ]]; then
    (cd "$SCRIPT_DIR/src/api-server" && npm install --silent 2>/dev/null) && \
        echo "  rhino API server installed" || \
        echo "  WARNING: API server install failed (run manually: cd src/api-server && npm install)"
fi

# --- 11. LaunchAgents (macOS only) ---
if [[ "$INSTALL_LAUNCHD" == "true" && "$(uname)" == "Darwin" ]]; then
    echo "Installing LaunchAgents..."
    LAUNCH_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_DIR"

    for plist in "$SCRIPT_DIR"/automation/launchd/*.plist; do
        name="$(basename "$plist")"

        # Unload if already loaded
        launchctl unload "$LAUNCH_DIR/$name" 2>/dev/null || true

        # Expand $HOME in plist and copy
        sed "s|\$HOME|$HOME|g" "$plist" > "$LAUNCH_DIR/$name"
        echo "  installed: $name"

        # Load the agent
        launchctl load "$LAUNCH_DIR/$name" 2>/dev/null || true
        echo "  loaded: $name"
    done
else
    echo "Skipping LaunchAgents (--no-launchd or non-macOS)"
fi

# --- Done ---
echo ""
echo "=== Installation complete ==="

if [[ -d "$BACKUP_DIR" ]]; then
    echo "Backups saved to: $BACKUP_DIR"
fi

echo ""
echo "What's installed:"
echo "  - 2 programs (strategy.md, build.md) — the brain (autoresearch pattern)"
echo "  - 5 agents (strategist, builder = thin wrappers; scout, sweep, design-engineer = standalone)"
echo "  - 6 skills (eval, experiment, product-eval, smart-commit, todofocus, product-2026)"
echo "  - 4 hooks (session_context, track_usage, capture_knowledge, enforce_ideation)"
echo "  - 1 CLI (rhino)"
echo ""
echo "How to use:"
echo "  \"run strategy\"    — decide what to build (reads programs/strategy.md)"
echo "  \"let's build\"     — build it, score it, keep/discard (reads programs/build.md)"
echo "  rhino visuals [dir]  — update GitHub badges"
echo "  rhino experiments    — see experiment results"
