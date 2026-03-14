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
# Phase 1: Generate config/rhino.yml
# ============================================================
mkdir -p config

# Value hypothesis placeholder by project type
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

        # Generate a reasonable delivers: based on what we can see
        local delivers_text="[what ${feat} delivers — edit this]"
        local for_text="[who uses ${feat}]"

        # Try to infer from file/directory type
        if [[ "$feat_path" == app/\(* ]]; then
            delivers_text="[what the ${feat} section of the app delivers]"
            for_text="end users"
        elif [[ -f "$feat_path" ]]; then
            # Script — read first comment line for description
            local desc
            desc=$(grep '^#' "$feat_path" 2>/dev/null | grep -v '^#!' | head -1 | sed 's/^# *//')
            [[ -n "$desc" ]] && delivers_text="$desc"
            for_text="developers using the CLI"
        elif [[ -d "$feat_path" ]]; then
            delivers_text="[what ${feat} delivers]"
            for_text="[who uses ${feat}]"
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
  user: "[Who specifically uses this?]"
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
# Phase 4: Validate & Output
# ============================================================
echo ""

SCORE=""
if [[ -f "$RHINO_DIR/bin/score.sh" ]]; then
    SCORE=$(bash "$RHINO_DIR/bin/score.sh" . --quiet --force 2>/dev/null) || SCORE=""
fi

if [[ -n "$SCORE" ]]; then
    # Determine display format
    if [[ -f ".claude/cache/score-cache.json" ]] && command -v jq &>/dev/null; then
        MODE=$(jq -r '.scoring_mode // "empty"' .claude/cache/score-cache.json 2>/dev/null)
        if [[ "$MODE" == "onboarding" ]]; then
            echo -e "  ${DIM}score:${NC} ${BOLD}${SCORE}/50${NC} ${DIM}(onboarding)${NC}"
        else
            echo -e "  ${DIM}score:${NC} ${BOLD}${SCORE}/100${NC}"
        fi
    else
        echo -e "  ${DIM}score:${NC} ${BOLD}${SCORE}${NC}"
    fi
fi

echo ""
echo -e "  ${DIM}next: edit config/rhino.yml → define your value hypothesis${NC}"
echo -e "  ${DIM}      then: /plan${NC}"
echo ""
