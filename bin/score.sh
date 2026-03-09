#!/usr/bin/env bash
set -uo pipefail
# NOTE: set -e intentionally omitted. Scoring uses [[ ]] && pattern
# where false conditions return 1 — that's normal, not an error.

# score.sh — Structural lint. Training loss. Fast, every commit.
#
# Measures what grep CAN measure honestly:
#   1. Build health  — does it compile? (gate: pass/fail)
#   2. Structure     — dead ends, empty states, navigation (0-100)
#   3. Hygiene       — any types, console.logs, TODOs, hardcoded values (0-100)
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

cd "$PROJECT_DIR"

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
CACHE_MAX_AGE=300

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

if [[ -d "apps/web/src" ]]; then SRC_DIR="apps/web/src"
elif [[ -d "src" ]]; then SRC_DIR="src"
elif [[ -d "app" ]]; then SRC_DIR="app"
fi

COMP_EXT="tsx"
[[ "$PROJECT_TYPE" == "vue" ]] && COMP_EXT="vue"
[[ "$PROJECT_TYPE" == "svelte" ]] && COMP_EXT="svelte"

# ============================================================
# 1. BUILD HEALTH (gate: pass/fail)
# ============================================================
score_build_health() {
    local score=100

    if [[ -f "tsconfig.json" ]] || [[ -f "apps/web/tsconfig.json" ]]; then
        if [[ "$FORCE" == true ]]; then
            local ts_errors
            ts_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
            if [[ "$ts_errors" -gt 0 ]]; then
                score=$((score - 30))
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
                score=$((score - 30))
            elif [[ "$build_age" -gt 86400 ]]; then
                score=$((score - 10))
            fi
        fi
    fi

    if grep -q '"build"' package.json 2>/dev/null; then
        if [[ "$FORCE" == true ]]; then
            if ! npm run build > /dev/null 2>&1; then
                score=$((score - 50))
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

    # Pages with no outbound navigation = dead ends
    local total_pages
    total_pages=$(find "$SRC_DIR" -name "page.$COMP_EXT" -o -name "index.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$total_pages" -eq 0 ]] && total_pages=1

    local dead_ends=0
    dead_ends=$(find "$SRC_DIR" -name "page.$COMP_EXT" 2>/dev/null | while read -r f; do
        if ! grep -ql "Link\|href\|router\|navigate\|onClick" "$f" 2>/dev/null; then
            echo "$f"
        fi
    done | wc -l | tr -d ' ')

    if [[ "$dead_ends" -gt 0 ]]; then
        local dead_pct=$((dead_ends * 100 / total_pages))
        score=$((score - dead_pct / 2))
    fi

    # Empty states without guidance
    local empty_states
    empty_states=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local empty_with_cta
    empty_with_cta=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | xargs grep -l "Link\|button\|onClick\|href" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$empty_states" -gt 0 ]]; then
        local cta_pct=$((empty_with_cta * 100 / empty_states))
        local missing_pct=$((100 - cta_pct))
        score=$((score - missing_pct / 3))
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

    # `any` types — real type safety gap
    local any_count
    any_count=$(grep -rn ": any\b" --include="*.ts" --include="*.tsx" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|\.d\.ts" | wc -l | tr -d ' ')
    if [[ "$any_count" -gt 50 ]]; then score=$((score - 30))
    elif [[ "$any_count" -gt 20 ]]; then score=$((score - 20))
    elif [[ "$any_count" -gt 5 ]]; then score=$((score - 10))
    fi

    # console.log in production code
    local console_count
    console_count=$(grep -rn "console\.\(log\|warn\|error\)" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|test\|spec\|__test__\|logger" | wc -l | tr -d ' ')
    if [[ "$console_count" -gt 30 ]]; then score=$((score - 25))
    elif [[ "$console_count" -gt 15 ]]; then score=$((score - 15))
    elif [[ "$console_count" -gt 5 ]]; then score=$((score - 5))
    fi

    # TODO/FIXME/HACK — unfinished work
    local todo_count
    todo_count=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
    if [[ "$todo_count" -gt 30 ]]; then score=$((score - 20))
    elif [[ "$todo_count" -gt 15 ]]; then score=$((score - 10))
    elif [[ "$todo_count" -gt 5 ]]; then score=$((score - 5))
    fi

    # Unused imports (rough signal — files with 10+ imports are suspicious)
    local large_import_files
    large_import_files=$(grep -rn "^import " --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | \
        awk -F: '{print $1}' | sort | uniq -c | sort -rn | awk '$1 > 15 {count++} END {print count+0}')
    if [[ "$large_import_files" -gt 10 ]]; then score=$((score - 15))
    elif [[ "$large_import_files" -gt 5 ]]; then score=$((score - 10))
    fi

    # Disabled lint rules — eslint-disable, @ts-ignore, @ts-expect-error
    local lint_overrides
    lint_overrides=$(grep -rn "eslint-disable\|@ts-ignore\|@ts-expect-error\|@ts-nocheck" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
    if [[ "$lint_overrides" -gt 20 ]]; then score=$((score - 15))
    elif [[ "$lint_overrides" -gt 10 ]]; then score=$((score - 10))
    elif [[ "$lint_overrides" -gt 3 ]]; then score=$((score - 5))
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
if [[ "$BUILD" -lt 70 ]]; then
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

printf "%s\t%s\t%s\t%s\t%s\n" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$BUILD" "$STRUCTURE" "$HYGIENE" \
    "$PROJECT_TYPE" >> "$HISTORY_FILE"

# --- Cache ---
mkdir -p "$CACHE_DIR"
cat > "$CACHE_FILE" <<CEOF
{"score":$local_min,"build":$BUILD,"build_gate":"$BUILD_GATE","structure":$STRUCTURE,"hygiene":$HYGIENE,"taste":${TASTE_SCORE:-null},"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR","cached_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
CEOF

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
{"score":$local_min,"build":$BUILD,"build_gate":"$BUILD_GATE","structure":$STRUCTURE,"hygiene":$HYGIENE,"taste":${TASTE_SCORE:-null},"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR"}
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
        echo -e "  Hygiene    ${color}${bar}\033[0m  ${v}/100  ${trend}  \033[2many, console.log, TODOs, @ts-ignore${marker}\033[0m"

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

        # Overall
        overall_color=$(dim_color "$local_min")
        echo -e "  \033[1mScore: ${overall_color}${local_min}/100\033[0m"
        echo ""
        echo -e "  \033[2m$PROJECT_TYPE ($SRC_DIR) · $(( $(wc -l < "$HISTORY_FILE" | tr -d ' ') - 1 )) runs\033[0m"
        ;;
esac
