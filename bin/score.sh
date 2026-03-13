#!/usr/bin/env bash
set -uo pipefail
# NOTE: set -e intentionally omitted. Scoring uses [[ ]] && pattern
# where false conditions return 1 — that's normal, not an error.

# score.sh — Structural lint. Training loss. Fast, every commit.
#
# Measures what grep CAN measure honestly:
#   1. Build health  — does it compile? (gate: pass/fail)
#   2. Structure     — dead ends, empty states, navigation (0-100)
#   3. Hygiene       — any types, console.logs, todos, hardcoded values (0-100)
#
# What this does NOT measure (taste's job):
#   - Does the UX feel good? → rhino taste
#   - Are the product flows complete? → rhino taste
#   - Would a user come back? → rhino taste
#
# This is training loss. rhino taste is eval loss.
# Track both. They measure different things.
#
# Usage:
#   score.sh [project-dir]              # visual output (default)
#   score.sh [project-dir] --json       # machine-readable
#   score.sh [project-dir] --quiet      # single number for scripts
#   score.sh [project-dir] --force      # bypass 5min cache

PROJECT_DIR="."
OUTPUT_MODE="score"
FORCE=false
INTEGRITY_WARNINGS=""

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --quiet|-q) OUTPUT_MODE="quiet" ;;
        --force) FORCE=true ;;
        --help|-h)
            echo "Usage: score.sh [project-dir] [--json] [--quiet] [--force]"
            exit 0
            ;;
        -*) ;;
        *) PROJECT_DIR="$arg" ;;
    esac
done

# Resolve script dir before cd (so relative $0 still works)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$PROJECT_DIR"

# --- Config ---
source "$SCRIPT_DIR/lib/config.sh"

# --- Lens extensions ---
RHINO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LENS_SCORE="$RHINO_ROOT/lens/product/scoring/score-product.sh"
[[ -f "$LENS_SCORE" ]] && source "$LENS_SCORE"

# --- Spinner ---
SPINNER_PID=""
spin() {
    local msg="$1"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    printf '\033[2m' >&2
    while true; do
        for (( i=0; i<${#chars}; i++ )); do
            printf "\r  %s %s" "${chars:$i:1}" "$msg" >&2
            sleep 0.1
        done
    done
}

start_spinner() {
    [[ "$OUTPUT_MODE" == "quiet" || "$OUTPUT_MODE" == "json" ]] && return
    spin "$1" &
    SPINNER_PID=$!
    disown $SPINNER_PID 2>/dev/null
}

stop_spinner() {
    local result="${1:-done}"
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
    fi
    if [[ "$OUTPUT_MODE" != "quiet" && "$OUTPUT_MODE" != "json" ]]; then printf "\r  ✓ %s\033[0m\n" "$result" >&2; fi
}

cleanup_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        printf "\033[0m\n" >&2
    fi
}
trap cleanup_spinner EXIT

# --- Cache ---
CACHE_DIR=".claude/cache"
CACHE_FILE="$CACHE_DIR/score-cache.json"
CACHE_MAX_AGE=$(cfg scoring.cache_ttl 300)

if [[ "$FORCE" != true && -f "$CACHE_FILE" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [[ "$cache_age" -lt "$CACHE_MAX_AGE" ]]; then
        case "$OUTPUT_MODE" in
            quiet)
                cached_score=$(jq -r '.score // empty' "$CACHE_FILE" 2>/dev/null)
                if [[ -n "$cached_score" && "$cached_score" != "null" ]]; then
                    echo "$cached_score"
                    exit 0
                fi
                ;;
            json) cat "$CACHE_FILE" 2>/dev/null && exit 0 ;;
            score)
                printf '\033[2m  (cached %ds ago, use --force to refresh)\033[0m\n' "$cache_age" >&2
                ;;
        esac
    fi
fi

# --- Detect project ---
PROJECT_TYPE="unknown"
SRC_DIR=""

if [[ -f "package.json" ]]; then
    if grep -q '"next"' package.json 2>/dev/null; then PROJECT_TYPE="nextjs"
    elif grep -q '"react"' package.json 2>/dev/null; then PROJECT_TYPE="react"
    elif grep -q '"vue"' package.json 2>/dev/null; then PROJECT_TYPE="vue"
    elif grep -q '"svelte"' package.json 2>/dev/null; then PROJECT_TYPE="svelte"
    else PROJECT_TYPE="node"
    fi
fi

# Detect CLI/shell projects (like rhino-os itself)
if [[ "$PROJECT_TYPE" == "unknown" ]]; then
    if [[ -d "bin" ]] && find bin -maxdepth 1 \( -name "*.sh" -o -name "*.mjs" \) -print -quit 2>/dev/null | grep -q .; then
        PROJECT_TYPE="cli"
    fi
fi

if [[ -d "apps/web/src" ]]; then SRC_DIR="apps/web/src"
elif [[ -d "src" ]]; then SRC_DIR="src"
elif [[ -d "app" ]]; then SRC_DIR="app"
elif [[ "$PROJECT_TYPE" == "cli" ]]; then SRC_DIR="bin"
fi

COMP_EXT="tsx"
[[ "$PROJECT_TYPE" == "vue" ]] && COMP_EXT="vue"
[[ "$PROJECT_TYPE" == "svelte" ]] && COMP_EXT="svelte"

# ============================================================
# 1. BUILD HEALTH (gate: pass/fail)
# ============================================================
score_build_health() {
    local score=100
    local ts_penalty=$(cfg scoring.build.ts_error_penalty -30)
    local stale_penalty=$(cfg scoring.build.stale_build_penalty -10)
    local fail_penalty=$(cfg scoring.build.build_fail_penalty -50)

    if [[ -f "tsconfig.json" ]] || [[ -f "apps/web/tsconfig.json" ]]; then
        if [[ "$FORCE" == true ]]; then
            local ts_errors
            ts_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
            if [[ "$ts_errors" -gt 0 ]]; then
                score=$((score + ts_penalty))
            fi
        else
            local has_build=false
            local build_age=999999
            if [[ -d ".next" ]]; then
                has_build=true
                build_age=$(( $(date +%s) - $(stat -f %m ".next" 2>/dev/null || stat -c %Y ".next" 2>/dev/null || echo 0) ))
            elif [[ -d "dist" ]]; then
                has_build=true
                build_age=$(( $(date +%s) - $(stat -f %m "dist" 2>/dev/null || stat -c %Y "dist" 2>/dev/null || echo 0) ))
            elif [[ -d "apps/web/.next" ]]; then
                has_build=true
                build_age=$(( $(date +%s) - $(stat -f %m "apps/web/.next" 2>/dev/null || stat -c %Y "apps/web/.next" 2>/dev/null || echo 0) ))
            fi
            if ! $has_build; then
                score=$((score + ts_penalty))
            elif [[ "$build_age" -gt 86400 ]]; then
                score=$((score + stale_penalty))
            fi
        fi
    fi

    if grep -q '"build"' package.json 2>/dev/null; then
        if [[ "$FORCE" == true ]]; then
            if ! npm run build > /dev/null 2>&1; then
                score=$((score + fail_penalty))
            fi
        fi
    fi

    echo "$score"
}

# ============================================================
# 2. STRUCTURE (0-100, subtractive)
#    Dead ends, empty states without CTAs, navigation gaps.
#    Things grep can measure: "does this page link anywhere?"
# ============================================================
score_structure() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # --- Universal structure checks (all project types) ---

    # Large files: >500 lines suggests missing decomposition
    local large_files=0
    while IFS= read -r f; do
        [[ ! -f "$f" ]] && continue
        local lines
        lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
        [[ "$lines" -gt 500 ]] && large_files=$((large_files + 1))
    done < <(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.mjs" -o -name "*.sh" -o -name "*.py" \) ! -path "*/node_modules/*" ! -path "*/.next/*" ! -name "*.d.ts" ! -name "*.min.*" 2>/dev/null)
    if [[ "$large_files" -gt 10 ]]; then score=$((score - 15))
    elif [[ "$large_files" -gt 5 ]]; then score=$((score - 10))
    elif [[ "$large_files" -gt 2 ]]; then score=$((score - 5))
    fi

    # Deep nesting: files nested >5 levels deep suggest poor organization
    local deep_files=0
    deep_files=$(find "$SRC_DIR" -mindepth 6 -type f ! -path "*/node_modules/*" ! -path "*/.next/*" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$deep_files" -gt 20 ]]; then score=$((score - 10))
    elif [[ "$deep_files" -gt 5 ]]; then score=$((score - 5))
    fi

    # Test presence: no tests at all is a structural gap
    local has_tests=0
    if find . -maxdepth 4 -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" \) ! -path "*/node_modules/*" 2>/dev/null | head -1 | grep -q .; then
        has_tests=1
    elif [[ -d "tests" ]] || [[ -d "test" ]] || [[ -d "__tests__" ]]; then
        # Has test directory — check if it has actual test files
        if find tests test __tests__ -type f 2>/dev/null | head -1 | grep -q .; then
            has_tests=1
        fi
    fi
    if [[ "$has_tests" -eq 0 ]]; then
        score=$((score - 10))
    fi

    # CLI projects: score structure differently than web projects
    if [[ "$PROJECT_TYPE" == "cli" ]]; then
        # Broken references: agent/program files referencing non-existent paths
        local broken_refs=0
        for f in agents/*.md programs/*.md; do
            [[ ! -f "$f" ]] && continue
            # Check for file path references that don't exist
            while IFS= read -r ref; do
                ref=$(echo "$ref" | sed 's/`//g' | xargs 2>/dev/null)
                [[ -z "$ref" ]] && continue
                # Skip glob patterns (*, ?) — these are templates, not literal paths
                [[ "$ref" == *'*'* || "$ref" == *'?'* ]] && continue
                # Skip refs containing newlines or spaces (multi-line false positives)
                [[ "$ref" == *$'\n'* || "$ref" == *" "* ]] && continue
                # Skip refs that are clearly not file paths (contain brackets, etc.)
                [[ "$ref" == *'['* || "$ref" == *'('* || "$ref" == *'{'* ]] && continue
                # Only check refs that look like file paths (contain / or end with known extensions)
                if [[ "$ref" == */* || "$ref" == *.sh || "$ref" == *.md || "$ref" == *.yml || "$ref" == *.json || "$ref" == *.mjs ]]; then
                    # Expand ~ to $HOME
                    local expanded="${ref/#\~/$HOME}"
                    if [[ ! -e "$expanded" && ! -e "$ref" ]]; then
                        broken_refs=$((broken_refs + 1))
                    fi
                fi
            done < <(grep -oE '`[~./][^`]+`' "$f" 2>/dev/null | sed 's/`//g')
        done
        if [[ "$broken_refs" -gt 10 ]]; then score=$((score - 30))
        elif [[ "$broken_refs" -gt 5 ]]; then score=$((score - 20))
        elif [[ "$broken_refs" -gt 0 ]]; then score=$((score - 10))
        fi

        # Dead commands: functions/commands defined in bin/rhino but unreachable
        local total_commands=0 documented_commands=0
        if [[ -f "bin/rhino" ]]; then
            total_commands=$(grep -cE '^\s+[a-z_-]+\)' bin/rhino 2>/dev/null || echo 0)
            # Check if help text documents them
            documented_commands=$(grep -cE '^\s+[a-z_-]+\s' bin/rhino 2>/dev/null | head -1 || echo 0)
        fi

        # Config coherence: does rhino.yml reference things that exist in code?
        if [[ -f "config/rhino.yml" ]]; then
            # Check if dimensions listed in config (base or lens) match what taste.mjs scores
            local config_dims
            config_dims=$(grep -A20 'dimensions:' config/rhino.yml lens/product/config/rhino-product.yml 2>/dev/null | grep '^ *-' | wc -l | tr -d ' ')
            if [[ "$config_dims" -eq 0 ]]; then
                score=$((score - 10))
            fi
        fi

        [[ "$score" -lt 0 ]] && score=0
        echo "$score"
        return
    fi

    # Product lens: web-specific structure checks (dead ends, empty states, IA audit)
    if type -t score_structure_product &>/dev/null; then
        score=$(score_structure_product "$score" "$SRC_DIR" "$PROJECT_TYPE" "$COMP_EXT")
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# ============================================================
# 3. HYGIENE (0-100, subtractive)
#    Code debt that grep can count. Not opinions about UX.
#    Starts at 100, deducts for measurable problems.
# ============================================================
score_hygiene() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # Measure codebase size for density-based scoring
    # Small projects (<500 lines) get stricter thresholds via a multiplier
    local total_src_lines=0
    total_src_lines=$(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.mjs" -o -name "*.sh" -o -name "*.py" \) ! -path "*/node_modules/*" ! -path "*/.next/*" 2>/dev/null -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    [[ "$total_src_lines" -eq 0 ]] && total_src_lines=1

    # Density multiplier: penalties are more severe for smaller codebases
    # CLI projects opt out — console output and TODOs in scripts are structurally different
    # <200 lines → 3x penalty, <1000 → 2x, <5000 → 1.5x, ≥5000 → 1x
    local density_mult=100  # stored as percentage to avoid floats
    if [[ "$PROJECT_TYPE" != "cli" ]]; then
        if [[ "$total_src_lines" -lt 200 ]]; then density_mult=300
        elif [[ "$total_src_lines" -lt 1000 ]]; then density_mult=200
        elif [[ "$total_src_lines" -lt 5000 ]]; then density_mult=150
        fi
    fi

    # Helper: tiered penalty from config. Usage: tiered_penalty count "50:-30 20:-20 5:-10"
    # Thresholds checked from highest to lowest. Penalty scaled by density_mult.
    tiered_penalty() {
        local count=$1 defaults="$2"
        local pair threshold penalty
        for pair in $defaults; do
            threshold="${pair%%:*}"
            penalty="${pair#*:}"
            if [[ "$count" -gt "$threshold" ]]; then
                # Scale penalty by density multiplier (negative * positive / 100 stays negative)
                local scaled=$(( penalty * density_mult / 100 ))
                # Cap: never deduct more than 3x the base penalty
                local cap=$(( penalty * 3 ))
                [[ "$scaled" -lt "$cap" ]] && scaled="$cap"
                score=$((score + scaled))
                return
            fi
        done
    }

    if [[ "$PROJECT_TYPE" == "cli" ]]; then
        # CLI hygiene: check shell scripts and JS files in bin/

        # Check for unfinished work markers in shell scripts and JS
        local todo_count
        todo_count=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.sh" --include="*.mjs" "$SRC_DIR" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
        tiered_penalty "$todo_count" "20:-20 10:-10 3:-5"

        # console.log/console.error in JS files (CLI tools should use structured output)
        local console_count
        console_count=$(grep -rn "console\.\(log\|warn\|error\)" --include="*.mjs" --include="*.js" "$SRC_DIR" 2>/dev/null | grep -v "// ok\|logger\|debug\|node_modules" | wc -l | tr -d ' ')
        # CLI tools legitimately use console — higher thresholds than web
        tiered_penalty "$console_count" "50:-20 30:-10 15:-5"

        # Syntax errors in shell scripts
        local syntax_errors=0
        for f in "$SRC_DIR"/*.sh lib/*.sh; do
            [[ ! -f "$f" ]] && continue
            if ! bash -n "$f" 2>/dev/null; then
                syntax_errors=$((syntax_errors + 1))
            fi
        done
        tiered_penalty "$syntax_errors" "3:-30 1:-15"

        # Syntax errors in JS/MJS files
        for f in "$SRC_DIR"/*.mjs; do
            [[ ! -f "$f" ]] && continue
            if ! node --check "$f" 2>/dev/null; then
                syntax_errors=$((syntax_errors + 1))
            fi
        done
        tiered_penalty "$syntax_errors" "3:-30 1:-15"

        # Hardcoded paths (should use config or variables)
        local hardcoded_paths
        hardcoded_paths=$(grep -rn "/Users/\|/home/" --include="*.sh" --include="*.mjs" "$SRC_DIR" 2>/dev/null | grep -v "# ok\|example\|template\|node_modules" | wc -l | tr -d ' ')
        tiered_penalty "$hardcoded_paths" "10:-20 5:-10 1:-5"

        # Unreachable code after return/exit (only count if next non-blank line is actual code, not control flow)
        local dead_code
        dead_code=$(grep -rn -A1 "^\s*return\b\|^\s*exit\b" --include="*.sh" "$SRC_DIR" 2>/dev/null | grep -v "return\|exit\|}\|esac\|fi\|done\|else\|elif\|#\|^\s*$\|node_modules\|local\|;;\|^--" | wc -l | tr -d ' ')
        tiered_penalty "$dead_code" "10:-15 5:-10 2:-5"

        [[ "$score" -lt 0 ]] && score=0
        echo "$score"
        return
    fi

    # Product lens: web-specific hygiene checks (any types, console.log, lint overrides)
    if type -t score_hygiene_product &>/dev/null; then
        score=$(score_hygiene_product "$score" "$SRC_DIR" "$PROJECT_TYPE" "$COMP_EXT" "$density_mult")
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# ============================================================
# Run all checks
# ============================================================
[[ "$OUTPUT_MODE" != "quiet" && "$OUTPUT_MODE" != "json" ]] && echo -e "\033[1m=== rhino score ===\033[0m" >&2

start_spinner "checking build..."
BUILD=$(score_build_health)
stop_spinner "build: $BUILD/100"

start_spinner "analyzing structure..."
STRUCTURE=$(score_structure)
stop_spinner "structure: $STRUCTURE/100"

start_spinner "checking hygiene..."
HYGIENE=$(score_hygiene)
stop_spinner "hygiene: $HYGIENE/100"

# Build gate
BUILD_GATE_THRESHOLD=$(cfg scoring.build.gate_threshold 70)
if [[ "$BUILD" -lt "$BUILD_GATE_THRESHOLD" ]]; then
    BUILD_GATE="FAIL"
else
    BUILD_GATE="PASS"
fi

# Weakest link (structure and hygiene only — build is a gate)
local_min=$STRUCTURE
[[ "$HYGIENE" -lt "$local_min" ]] && local_min=$HYGIENE
if [[ "$BUILD_GATE" == "FAIL" ]]; then
    local_min=0
fi

# --- History ---
HISTORY_DIR=".claude/scores"
HISTORY_FILE="$HISTORY_DIR/history.tsv"
mkdir -p "$HISTORY_DIR"

if [[ ! -f "$HISTORY_FILE" ]]; then
    printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$HISTORY_FILE"
fi

# --- Integrity checks (run BEFORE writing current entry to history) ---
# Compare the last two EXISTING history entries against each other.
# This is more reliable than current-vs-previous because both entries were
# computed by score.sh (no mismatch between fresh computation and seeded/stale data).
HIST_LINES=$(wc -l < "$HISTORY_FILE" | tr -d ' ')

# COSMETIC-ONLY + INFLATION: compare last two history entries
if [[ "$HIST_LINES" -ge 3 ]]; then
    hist_last_structure=$(tail -1 "$HISTORY_FILE" | cut -f3)
    hist_last_hygiene=$(tail -1 "$HISTORY_FILE" | cut -f4)
    hist_prev_structure=$(tail -2 "$HISTORY_FILE" | head -1 | cut -f3)
    hist_prev_hygiene=$(tail -2 "$HISTORY_FILE" | head -1 | cut -f4)
    if [[ -n "$hist_prev_structure" && "$hist_prev_structure" =~ ^[0-9]+$ && -n "$hist_prev_hygiene" && "$hist_prev_hygiene" =~ ^[0-9]+$ \
       && -n "$hist_last_structure" && "$hist_last_structure" =~ ^[0-9]+$ && -n "$hist_last_hygiene" && "$hist_last_hygiene" =~ ^[0-9]+$ ]]; then
        h_struct_delta=$((hist_last_structure - hist_prev_structure))
        h_hygiene_delta=$((hist_last_hygiene - hist_prev_hygiene))
        # Cosmetic-only: hygiene improved but structure didn't
        if [[ "$h_hygiene_delta" -gt 5 && "$h_struct_delta" -le 0 ]]; then
            INTEGRITY_WARNINGS="${INTEGRITY_WARNINGS}COSMETIC-ONLY: hygiene +${h_hygiene_delta} but structure ${h_struct_delta}. Cleanup without structural improvement.\n"
        fi
        # Inflation: single commit jumped too much
        max_delta=$(cfg integrity.max_single_commit_delta 15)
        h_total_delta=$(( h_struct_delta + h_hygiene_delta ))
        if [[ "$h_total_delta" -gt "$max_delta" ]]; then
            INTEGRITY_WARNINGS="${INTEGRITY_WARNINGS}INFLATION: score jumped +${h_total_delta} in one run (max: ${max_delta}). Verify changes are real.\n"
        fi
    fi
fi

# PLATEAU: score unchanged across N runs (checked before writing current entry)
plateau_runs=$(cfg integrity.plateau_experiments 5)
if [[ "$HIST_LINES" -gt "$plateau_runs" ]]; then
    unique_scores=$(tail -"$plateau_runs" "$HISTORY_FILE" | cut -f3 | sort -u | wc -l | tr -d ' ')
    if [[ "$unique_scores" -eq 1 ]]; then
        INTEGRITY_WARNINGS="${INTEGRITY_WARNINGS}PLATEAU: structure score unchanged across last ${plateau_runs} runs. Might be stuck.\n"
    fi
fi

# --- Write current entry to history (after integrity checks) ---
printf "%s\t%s\t%s\t%s\t%s\n" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$BUILD" "$STRUCTURE" "$HYGIENE" \
    "$PROJECT_TYPE" >> "$HISTORY_FILE"

# STAGE CEILING: flag scores exceeding ceiling for current stage
if [[ -f ".claude/plans/active-plan.md" ]] || [[ -f "config/rhino.yml" ]]; then
    # Detect stage from rhino.yml or default to mvp
    local_stage=$(cfg project.stage "mvp")
    ceiling_max=""
    case "$local_stage" in
        mvp)    ceiling_max=65 ;;
        early)  ceiling_max=80 ;;
        growth) ceiling_max=90 ;;
        mature) ceiling_max=95 ;;
    esac
    if [[ -n "$ceiling_max" && "$local_min" -gt "$ceiling_max" ]]; then
        INTEGRITY_WARNINGS="${INTEGRITY_WARNINGS}CEILING: score ${local_min} exceeds ${local_stage} stage ceiling (${ceiling_max}). Verify this isn't inflated.\n"
    fi
fi

# EXPERIMENT DISCIPLINE: check experiment health from TSVs
# These read the 4 config values that were previously defined but never enforced.
exp_discard_floor=$(cfg experiments.discard_rate_floor 0.25)
exp_min_delta=$(cfg experiments.min_keep_delta 0.02)
exp_moonshot_n=$(cfg experiments.moonshot_every_n 5)

if [[ -d ".claude/experiments" ]]; then
    # Aggregate across all experiment TSVs
    total_kept=0
    total_discarded=0
    total_experiments=0
    recent_discards=0
    last_n_experiments=""

    for tsv in .claude/experiments/*.tsv; do
        [[ -f "$tsv" ]] || continue
        kept=$(grep -c 'keep' "$tsv" 2>/dev/null || echo 0)
        discarded=$(grep -c 'discard' "$tsv" 2>/dev/null || echo 0)
        total_kept=$((total_kept + kept))
        total_discarded=$((total_discarded + discarded))
        total_experiments=$((total_experiments + kept + discarded))
        # Collect last N experiment statuses for moonshot check
        tail -n "$exp_moonshot_n" "$tsv" | grep -v '^commit\|^---\|^$' >> "$CACHE_DIR/.exp_recent" 2>/dev/null || true
    done

    if [[ "$total_experiments" -ge 5 ]]; then
        # KEEP_RATE_HIGH: discard rate below floor = not exploring enough
        discard_rate=0
        if [[ "$total_experiments" -gt 0 ]]; then
            discard_rate=$((total_discarded * 100 / total_experiments))
        fi
        discard_floor_pct=$(echo "$exp_discard_floor" | awk '{printf "%d", $1 * 100}')
        if [[ "$discard_rate" -lt "$discard_floor_pct" ]]; then
            INTEGRITY_WARNINGS="${INTEGRITY_WARNINGS}KEEP_RATE_HIGH: ${total_kept}/${total_experiments} kept (discard rate ${discard_rate}% < ${discard_floor_pct}% floor). Not exploring enough — try riskier hypotheses.\n"
        fi

        # NO_MOONSHOTS: last N experiments all kept = no risk-taking
        if [[ -f "$CACHE_DIR/.exp_recent" ]]; then
            recent_total=$(wc -l < "$CACHE_DIR/.exp_recent" | tr -d ' ')
            recent_discards=$(grep -c 'discard' "$CACHE_DIR/.exp_recent" 2>/dev/null || echo 0)
            if [[ "$recent_total" -ge "$exp_moonshot_n" && "$recent_discards" -eq 0 ]]; then
                INTEGRITY_WARNINGS="${INTEGRITY_WARNINGS}NO_MOONSHOTS: last ${recent_total} experiments all kept. Every ${exp_moonshot_n}th experiment should be high-risk. Try something that might fail.\n"
            fi
            rm -f "$CACHE_DIR/.exp_recent"
        fi
    fi
fi

# --- Taste eval (product quality from last visual eval) ---
TASTE_SCORE=""
TASTE_FILE=""
TASTE_AGE_DAYS=""
if [[ -d ".claude/evals/reports" ]]; then
    TASTE_FILE=$(ls -t .claude/evals/reports/taste-*.json 2>/dev/null | head -1)
    if [[ -n "$TASTE_FILE" ]] && command -v jq &> /dev/null; then
        TASTE_SCORE=$(jq -r '.score_100 // empty' "$TASTE_FILE" 2>/dev/null)
        taste_mtime=$(stat -f %m "$TASTE_FILE" 2>/dev/null || stat -c %Y "$TASTE_FILE" 2>/dev/null || echo 0)
        TASTE_AGE_DAYS=$(( ($(date +%s) - taste_mtime) / 86400 ))
    fi
fi

# Taste counts toward weakest link when available
if [[ -n "$TASTE_SCORE" && "$TASTE_SCORE" =~ ^[0-9]+$ ]]; then
    [[ "$TASTE_SCORE" -lt "$local_min" ]] && local_min=$TASTE_SCORE
fi

# --- Build integrity JSON array ---
INTEGRITY_JSON="[]"
if [[ -n "$INTEGRITY_WARNINGS" ]]; then
    INTEGRITY_JSON="["
    first=true
    while IFS= read -r warn; do
        [[ -z "$warn" ]] && continue
        $first || INTEGRITY_JSON+=","
        INTEGRITY_JSON+="\"$warn\""
        first=false
    done < <(printf '%b' "$INTEGRITY_WARNINGS")
    INTEGRITY_JSON+="]"
fi

# --- Cache (AFTER taste read so taste score is included) ---
mkdir -p "$CACHE_DIR"
cat > "$CACHE_FILE" <<CEOF
{"score":$local_min,"build":$BUILD,"build_gate":"$BUILD_GATE","structure":$STRUCTURE,"hygiene":$HYGIENE,"taste":${TASTE_SCORE:-null},"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR","integrity_warnings":$INTEGRITY_JSON,"cached_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
CEOF

# --- Trends ---
trend_for() {
    local dim="$1" current="$2" col="$3"
    if [[ $(wc -l < "$HISTORY_FILE" | tr -d ' ') -ge 3 ]]; then
        local prev
        prev=$(tail -2 "$HISTORY_FILE" | head -1 | cut -f"$col")
        if [[ -n "$prev" && "$prev" =~ ^[0-9]+$ ]]; then
            local delta=$((current - prev))
            if [[ "$delta" -gt 0 ]]; then echo "↑$delta"
            elif [[ "$delta" -lt 0 ]]; then echo "↓$((delta * -1))"
            else echo "—"
            fi
            return
        fi
    fi
    echo "·"
}

# --- Output ---
make_bar() {
    local val=$1 width=20
    local filled=$((val * width / 100))
    local empty=$((width - filled))
    local bar=""
    for ((b=0; b<filled; b++)); do bar+="█"; done
    for ((b=0; b<empty; b++)); do bar+="░"; done
    echo "$bar"
}

dim_color() {
    local val=$1
    if [[ "$val" -ge 70 ]]; then echo "\033[0;32m"
    elif [[ "$val" -ge 40 ]]; then echo "\033[1;33m"
    else echo "\033[0;31m"
    fi
}

case "$OUTPUT_MODE" in
    quiet)
        echo "$local_min"
        ;;
    json)
        cat <<EOF
{"score":$local_min,"build":$BUILD,"build_gate":"$BUILD_GATE","structure":$STRUCTURE,"hygiene":$HYGIENE,"taste":${TASTE_SCORE:-null},"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR","integrity_warnings":$INTEGRITY_JSON}
EOF
        ;;
    score)
        echo ""

        # Build gate
        if [[ "$BUILD_GATE" == "FAIL" ]]; then
            echo -e "  \033[0;31m✗ BUILD GATE: FAIL ($BUILD/100)\033[0m"
        else
            echo -e "  \033[0;32m✓\033[0m build ($BUILD/100)"
        fi
        echo ""

        # Structure
        v="$STRUCTURE"
        bar=$(make_bar "$v")
        trend=$(trend_for "structure" "$v" 3)
        color=$(dim_color "$v")
        marker=""
        [[ "$v" -eq "$local_min" ]] && marker=" ◀ weakest"
        echo -e "  Structure  ${color}${bar}\033[0m  ${v}/100  ${trend}  \033[2mdead ends, empty states${marker}\033[0m"

        # Hygiene
        v="$HYGIENE"
        bar=$(make_bar "$v")
        trend=$(trend_for "hygiene" "$v" 4)
        color=$(dim_color "$v")
        marker=""
        [[ "$v" -eq "$local_min" ]] && marker=" ◀ weakest"
        echo -e "  Hygiene    ${color}${bar}\033[0m  ${v}/100  ${trend}  \033[2many, console.log, todos, @ts-ignore${marker}\033[0m"

        # Taste — the product quality layer
        if [[ -n "$TASTE_SCORE" && "$TASTE_SCORE" =~ ^[0-9]+$ ]]; then
            bar=$(make_bar "$TASTE_SCORE")
            color=$(dim_color "$TASTE_SCORE")
            marker=""
            [[ "$TASTE_SCORE" -eq "$local_min" ]] && marker=" ◀ weakest"
            stale_note=""
            if [[ -n "$TASTE_AGE_DAYS" && "$TASTE_AGE_DAYS" -gt 7 ]]; then
                stale_note=" \033[1;33m(${TASTE_AGE_DAYS}d old — rerun)\033[0m"
            fi
            echo -e "  Taste      ${color}${bar}\033[0m  ${TASTE_SCORE}/100  \033[2mUX, flows, delight (visual eval)${marker}\033[0m${stale_note}"
        else
            echo -e "  Taste      \033[2m░░░░░░░░░░░░░░░░░░░░\033[0m   —     \033[2mrun: rhino taste\033[0m"
        fi

        echo ""

        # Integrity warnings
        if [[ -n "$INTEGRITY_WARNINGS" ]]; then
            echo -e "  \033[1;33m⚠ Integrity Warnings:\033[0m"
            printf '%b' "$INTEGRITY_WARNINGS" | while IFS= read -r warn; do
                [[ -n "$warn" ]] && echo -e "    \033[1;33m· $warn\033[0m"
            done
            echo ""
        fi

        # Overall
        overall_color=$(dim_color "$local_min")
        echo -e "  \033[1mScore: ${overall_color}${local_min}/100\033[0m"
        echo ""
        echo -e "  \033[2m$PROJECT_TYPE ($SRC_DIR) · $(( $(wc -l < "$HISTORY_FILE" | tr -d ' ') - 1 )) runs\033[0m"
        ;;
esac
