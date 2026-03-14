#!/usr/bin/env bash
# init.sh — Bootstrap rhino-os into any repo
# One command, zero prompts. Detects project type, generates config + assertions.

set -euo pipefail

# --- Resolve RHINO_DIR ---
_INIT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_INIT_SOURCE" ]]; do _INIT_SOURCE="$(readlink "$_INIT_SOURCE")"; done
RHINO_DIR="$(cd "$(dirname "$_INIT_SOURCE")/.." && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Args ---
FORCE=false
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        --help|-h)
            echo "Usage: rhino init [--force]"
            echo "  Bootstrap rhino-os into any repo."
            echo "  --force    Regenerate even if already initialized"
            exit 0
            ;;
    esac
done

echo ""
echo -e "  ${CYAN}◆${NC} ${BOLD}rhino init${NC}"
echo ""

# ============================================================
# Phase 0: Guards & Detection
# ============================================================

# Idempotency guard
if [[ -f "config/rhino.yml" && "$FORCE" != true ]]; then
    echo -e "  ${DIM}already initialized (config/rhino.yml exists)${NC}"
    echo -e "  ${DIM}use --force to regenerate${NC}"
    echo ""
    exit 0
fi

# --- Detect project type ---
PROJECT_TYPE="unknown"

if [[ -f "package.json" ]]; then
    if grep -q '"next"' package.json 2>/dev/null; then PROJECT_TYPE="nextjs"
    elif grep -q '"react"' package.json 2>/dev/null; then PROJECT_TYPE="react"
    elif grep -q '"vue"' package.json 2>/dev/null; then PROJECT_TYPE="vue"
    elif grep -q '"svelte"' package.json 2>/dev/null; then PROJECT_TYPE="svelte"
    else PROJECT_TYPE="node"
    fi
elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
    PROJECT_TYPE="python"
elif [[ -f "go.mod" ]]; then
    PROJECT_TYPE="go"
fi

# CLI fallback
if [[ "$PROJECT_TYPE" == "unknown" ]]; then
    if [[ -d "bin" ]] && find bin -maxdepth 1 \( -name "*.sh" -o -name "*.mjs" \) -print -quit 2>/dev/null | grep -q .; then
        PROJECT_TYPE="cli"
    fi
fi

# --- Detect SRC_DIR ---
SRC_DIR=""
if [[ -d "apps/web/src" ]]; then SRC_DIR="apps/web/src"
elif [[ -d "src" ]]; then SRC_DIR="src"
elif [[ -d "app" ]]; then SRC_DIR="app"
elif [[ -d "bin" ]]; then SRC_DIR="bin"
fi

# --- Detect project name ---
PROJECT_NAME=""
if [[ -f "package.json" ]] && command -v jq &>/dev/null; then
    PROJECT_NAME=$(jq -r '.name // empty' package.json 2>/dev/null)
fi
if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME=$(basename "$(pwd)")
fi

echo -e "  ${GREEN}✓${NC} detected: ${BOLD}$PROJECT_TYPE${NC} ($SRC_DIR/)"

# --- Auto-detect features ---
FEATURES=()
FEATURE_PATHS=()

# Next.js route groups: app/(group)/
if [[ -d "app" ]]; then
    for d in app/\(*/; do
        [[ ! -d "$d" ]] && continue
        name=$(basename "$d" | tr -d '()')
        FEATURES+=("$name")
        FEATURE_PATHS+=("$d")
    done
fi

# Top-level src directories (skip common utility dirs)
if [[ -d "src" ]]; then
    for d in src/*/; do
        [[ ! -d "$d" ]] && continue
        name=$(basename "$d")
        [[ "$name" == "components" || "$name" == "lib" || "$name" == "utils" || "$name" == "styles" || "$name" == "types" || "$name" == "hooks" || "$name" == "assets" || "$name" == "config" ]] && continue
        FEATURES+=("$name")
        FEATURE_PATHS+=("$d")
    done
fi

# Package workspaces
if [[ -f "package.json" ]] && grep -q '"workspaces"' package.json 2>/dev/null; then
    for ws in packages/*/; do
        [[ ! -d "$ws" ]] && continue
        name=$(basename "$ws")
        FEATURES+=("$name")
        FEATURE_PATHS+=("$ws")
    done
fi

# CLI scripts
if [[ -d "bin" ]]; then
    for f in bin/*.sh bin/*.mjs; do
        [[ ! -f "$f" ]] && continue
        name=$(basename "$f" | sed 's/\.[^.]*$//')
        FEATURES+=("$name")
        FEATURE_PATHS+=("$f")
    done
fi

if [[ ${#FEATURES[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}✓${NC} features: ${BOLD}${FEATURES[*]}${NC} (${#FEATURES[@]} detected)"
else
    echo -e "  ${DIM}·${NC} no features auto-detected"
fi

# ============================================================
# Phase 1: Build project profile via Claude
# ============================================================

CLAUDE_ANALYZED=false
DESCRIPTION=""
USER=""
HYPOTHESIS=""
# Associative arrays for per-feature Claude data
declare -A FEAT_DELIVERS
declare -A FEAT_FOR

# --- Gather context ---
CONTEXT=""

# README
if [[ -f "README.md" ]]; then
    CONTEXT+="=== README.md (first 200 lines) ===
$(head -200 README.md)

"
fi

# Package description
if [[ -f "package.json" ]] && command -v jq &>/dev/null; then
    PKG_DESC=$(jq -r '.description // empty' package.json 2>/dev/null)
    if [[ -n "$PKG_DESC" ]]; then
        CONTEXT+="=== package.json description ===
${PKG_DESC}

"
    fi
elif [[ -f "pyproject.toml" ]]; then
    PYPROJ_DESC=$(grep -m1 'description' pyproject.toml 2>/dev/null | sed 's/.*= *"//' | sed 's/".*//' || true)
    if [[ -n "$PYPROJ_DESC" ]]; then
        CONTEXT+="=== pyproject.toml description ===
${PYPROJ_DESC}

"
    fi
fi

# Directory listing
if [[ -n "$SRC_DIR" && -d "$SRC_DIR" ]]; then
    CONTEXT+="=== ${SRC_DIR}/ listing (first 30) ===
$(ls "$SRC_DIR" 2>/dev/null | head -30)

"
fi

# Key source files (first 5 that exist, first 100 lines each)
KEY_FILES_FOUND=0
for candidate in app/page.tsx src/App.tsx src/index.ts app/layout.tsx index.ts main.py main.go; do
    if [[ -f "$candidate" && "$KEY_FILES_FOUND" -lt 5 ]]; then
        CONTEXT+="=== ${candidate} (first 100 lines) ===
$(head -100 "$candidate")

"
        KEY_FILES_FOUND=$((KEY_FILES_FOUND + 1))
    fi
done

# --- Build feature names list ---
FEATURE_NAMES=""
if [[ ${#FEATURES[@]} -gt 0 ]]; then
    FEATURE_NAMES=$(printf '%s, ' "${FEATURES[@]}")
    FEATURE_NAMES="${FEATURE_NAMES%, }"
fi

# --- Call Claude if available ---
if command -v claude &>/dev/null; then
    PROMPT="Analyze this codebase and return ONLY a JSON object:
{\"description\":\"one-line project description\",\"user\":\"who specifically uses this\",\"hypothesis\":\"value hypothesis in format: Users can X faster/better than Y\",\"features\":{}}

For the features object, use these detected feature names as keys: [${FEATURE_NAMES}]
For each, add: {\"delivers\":\"specific value this delivers\",\"for\":\"who uses it\"}

Be specific. Not \"handles auth\" but \"user signup and login with OAuth\".
Not \"users\" but \"sales teams who share decks with prospects\".

Context:
${CONTEXT}"

    echo -e "  ${DIM}·${NC} analyzing project with Claude..."
    CLAUDE_RESULT=$(claude -p "$PROMPT" --model haiku 2>/dev/null) || CLAUDE_RESULT=""

    if [[ -n "$CLAUDE_RESULT" ]]; then
        # Strip markdown fences if present
        CLEANED=$(echo "$CLAUDE_RESULT" | sed '/^```/d')

        if echo "$CLEANED" | jq -c . &>/dev/null 2>&1; then
            DESCRIPTION=$(echo "$CLEANED" | jq -r '.description // empty' 2>/dev/null)
            USER=$(echo "$CLEANED" | jq -r '.user // empty' 2>/dev/null)
            HYPOTHESIS=$(echo "$CLEANED" | jq -r '.hypothesis // empty' 2>/dev/null)

            # Extract per-feature data
            for feat in "${FEATURES[@]}"; do
                feat_delivers=$(echo "$CLEANED" | jq -r --arg f "$feat" '.features[$f].delivers // empty' 2>/dev/null)
                feat_for=$(echo "$CLEANED" | jq -r --arg f "$feat" '.features[$f].for // empty' 2>/dev/null)
                [[ -n "$feat_delivers" ]] && FEAT_DELIVERS["$feat"]="$feat_delivers"
                [[ -n "$feat_for" ]] && FEAT_FOR["$feat"]="$feat_for"
            done

            CLAUDE_ANALYZED=true
            echo -e "  ${GREEN}✓${NC} project profile built"
        fi
    fi
fi

if [[ "$CLAUDE_ANALYZED" != true ]]; then
    if ! command -v claude &>/dev/null && [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
        echo -e "  ${DIM}·${NC} Install Claude CLI for full project analysis"
    fi
fi

# ============================================================
# Phase 2: Generate config/rhino.yml
# ============================================================
mkdir -p config

if [[ "$CLAUDE_ANALYZED" == true ]]; then
    # Use Claude's analysis — no placeholders
    :
else
    # Fallback placeholders by project type
    case "$PROJECT_TYPE" in
        nextjs|react|vue|svelte)
            HYPOTHESIS="Users can [do X] faster than alternatives" ;;
        node|cli)
            HYPOTHESIS="Developers can [do X] with this tool" ;;
        python)
            HYPOTHESIS="Users can [do X] with this library" ;;
        go)
            HYPOTHESIS="Users can [do X] with this tool" ;;
        *)
            HYPOTHESIS="Users get [specific value] from this project" ;;
    esac
    USER="[Who specifically uses this?]"
    DESCRIPTION=""
fi

# Build features section for rhino.yml
FEATURES_YAML=""
FEATURE_COUNT=0

if [[ ${#FEATURES[@]} -gt 0 ]]; then
    FEATURES_YAML="
# ── Features ─────────────────────────────────────────
# Each feature declares what it delivers and for whom.
# rhino eval reads these and has Claude judge the gap.
features:"

    for i in "${!FEATURES[@]}"; do
        feat="${FEATURES[$i]}"
        feat_path="${FEATURE_PATHS[$i]}"

        if [[ "$CLAUDE_ANALYZED" == true ]]; then
            delivers_text="${FEAT_DELIVERS[$feat]:-[what ${feat} delivers — edit this]}"
            for_text="${FEAT_FOR[$feat]:-[who uses ${feat}]}"
        else
            # Fallback: infer from file/directory type
            delivers_text="[what ${feat} delivers — edit this]"
            for_text="[who uses ${feat}]"

            if [[ "$feat_path" == app/\(* ]]; then
                delivers_text="[what the ${feat} section of the app delivers]"
                for_text="end users"
            elif [[ -f "$feat_path" ]]; then
                # Script — read first comment line for description
                desc=$(grep '^#' "$feat_path" 2>/dev/null | grep -v '^#!' | head -1 | sed 's/^# *//')
                [[ -n "$desc" ]] && delivers_text="$desc"
                for_text="developers using the CLI"
            elif [[ -d "$feat_path" ]]; then
                delivers_text="[what ${feat} delivers]"
                for_text="[who uses ${feat}]"
            fi
        fi

        FEATURES_YAML+="
  ${feat}:
    delivers: \"${delivers_text}\"
    for: \"${for_text}\"
    code: [\"${feat_path}\"]"
        FEATURE_COUNT=$((FEATURE_COUNT + 1))
    done
fi

cat > config/rhino.yml <<RHINO_YML
project:
  stage: mvp
  mode: build

value:
  hypothesis: "$HYPOTHESIS"
  user: "$USER"
  signals:
    - name: core_value
      description: "[What the product delivers]"
      target: "[How to measure it]"
      measurable: false
${FEATURES_YAML}

scoring:
  cache_ttl: 300
  health_gate_threshold: 20
  health_warn_threshold: 40
  onboarding_cap: 50

evals:
  generative: true
  beliefs_fallback: true
RHINO_YML

echo -e "  ${GREEN}✓${NC} config/rhino.yml (${FEATURE_COUNT} features)"

# ============================================================
# Phase 3: Create .claude/ structure
# ============================================================
mkdir -p .claude/cache .claude/scores config/evals

echo -e "  ${GREEN}✓${NC} .claude/ directories"

# ============================================================
# Phase 3b: Scaffold .claude/ for project-local Claude Code config
# ============================================================

# 3b-i. Symlink mind files into .claude/rules/
mkdir -p .claude/rules
for mind_file in identity.md thinking.md standards.md self.md; do
    src="$RHINO_DIR/mind/$mind_file"
    target=".claude/rules/$mind_file"
    if [[ -f "$src" ]]; then
        ln -sf "$src" "$target"
    fi
done
# Lens mind files
for lens_dir in "$RHINO_DIR"/lens/*/mind; do
    [[ ! -d "$lens_dir" ]] && continue
    for lens_mind in "$lens_dir"/*.md; do
        [[ ! -f "$lens_mind" ]] && continue
        name="$(basename "$lens_mind")"
        ln -sf "$lens_mind" ".claude/rules/$name"
    done
done

# 3b-ii. Symlink commands into .claude/commands/
mkdir -p .claude/commands
# Lens commands first (lower priority)
for lens_cmd_dir in "$RHINO_DIR"/lens/*/commands; do
    [[ ! -d "$lens_cmd_dir" ]] && continue
    for cmd_file in "$lens_cmd_dir"/*.md; do
        [[ ! -f "$cmd_file" ]] && continue
        name="$(basename "$cmd_file")"
        # Skip if core command with same name exists
        [[ -f "$RHINO_DIR/.claude/commands/$name" ]] && continue
        ln -sf "$cmd_file" ".claude/commands/$name"
    done
done
# Core commands (higher priority — overwrite lens if same name)
for cmd_file in "$RHINO_DIR"/.claude/commands/*.md; do
    [[ ! -f "$cmd_file" ]] && continue
    [[ -L "$cmd_file" ]] && continue
    name="$(basename "$cmd_file")"
    ln -sf "$cmd_file" ".claude/commands/$name"
done

# 3b-iii. Generate .claude/settings.json
SETTINGS_TARGET=".claude/settings.json"
RHINO_SETTINGS='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "'"$RHINO_DIR"'/hooks/session_start.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "'"$RHINO_DIR"'/hooks/post_edit.sh"
          },
          {
            "type": "command",
            "command": "'"$RHINO_DIR"'/hooks/post_skill.sh"
          }
        ]
      }
    ]
  }
}'

if [[ -f "$SETTINGS_TARGET" ]]; then
    if command -v jq &>/dev/null; then
        # Merge: preserve existing settings, overlay hooks
        tmp="$(mktemp)"
        echo "$RHINO_SETTINGS" | jq -s '.[0] * {hooks: .[1].hooks}' "$SETTINGS_TARGET" - > "$tmp" && mv "$tmp" "$SETTINGS_TARGET"
    else
        echo -e "  ${YELLOW}⚠${NC} jq not found — .claude/settings.json not updated (has existing content)"
    fi
else
    echo "$RHINO_SETTINGS" > "$SETTINGS_TARGET"
fi

# 3b-iv. Append to .gitignore
GITIGNORE_ENTRIES=(".claude/rules/" ".claude/commands/" ".claude/settings.json")
if [[ ! -f .gitignore ]]; then
    printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > .gitignore
else
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if ! grep -qF "$entry" .gitignore 2>/dev/null; then
            echo "$entry" >> .gitignore
        fi
    done
fi

echo -e "  ${GREEN}✓${NC} .claude/ scaffolding (rules, commands, hooks)"

# ============================================================
# Phase 4: Validate & Output
# ============================================================

# --- Score bar helper ---
print_score_bar() {
    local score=${1:-0}
    local filled=$(( (score + 2) / 5 ))
    [[ $filled -gt 20 ]] && filled=20
    local empty=$((20 - filled))
    local color="$RED"
    [[ $score -ge 50 ]] && color="$YELLOW"
    [[ $score -ge 80 ]] && color="$GREEN"
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    local trail=""
    for ((i=0; i<empty; i++)); do trail="${trail}░"; done
    printf "${color}${bar}${DIM}${trail}${NC}"
}

# --- Run first eval ---
SCORE=""
if [[ -f "$RHINO_DIR/bin/score.sh" ]]; then
    SCORE=$(bash "$RHINO_DIR/bin/score.sh" . --quiet --force 2>/dev/null) || SCORE=""
fi

# --- Display ---
echo ""
SEP="  ${DIM}⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯${NC}"

DESC_DISPLAY="${DESCRIPTION:-initialized}"
USER_DISPLAY="${USER:-edit config/rhino.yml}"
# Strip bracket placeholders for display
[[ "$USER_DISPLAY" == \[* ]] && USER_DISPLAY="edit config/rhino.yml"

echo -e "${SEP}"
echo -e "  ${BOLD}${PROJECT_NAME}${NC} ${DIM}—${NC} ${DESC_DISPLAY}"
echo -e "  ${DIM}for:${NC} ${USER_DISPLAY}"
echo -e "  ${DIM}hypothesis:${NC} \"${HYPOTHESIS}\""
echo ""
echo -e "  ${GREEN}✓${NC} config/rhino.yml (${FEATURE_COUNT} features)"
echo -e "  ${GREEN}✓${NC} first eval complete"
echo ""

if [[ -n "$SCORE" ]]; then
    SCORE_NUM="${SCORE%%[^0-9]*}"
    [[ -z "$SCORE_NUM" ]] && SCORE_NUM=0
    SCORE_BAR=$(print_score_bar "$SCORE_NUM")
    echo -e "  ${DIM}score${NC}  ${BOLD}${SCORE}/100${NC}  ${SCORE_BAR}"
else
    echo -e "  ${DIM}score${NC}  ${DIM}—${NC}"
fi
echo -e "         ${DIM}${FEATURE_COUNT} features${NC}"

echo -e "${SEP}"
echo ""
echo -e "  ${DIM}next: /plan${NC}"
echo ""
