#!/usr/bin/env bash
# stop.sh — Session logging + staleness nudge.
# Hook: Stop event. Target: <100ms.
# Writes session summary to .claude/sessions/ for trail.sh to read.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CACHE_FILE=".claude/cache/score-cache.json"
STALE_MINUTES=10
SESSIONS_DIR=".claude/sessions"
PRED_FILE=".claude/knowledge/predictions.tsv"
[[ ! -f "$PRED_FILE" ]] && PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"

# --- Session logging ---
log_session() {
    mkdir -p "$SESSIONS_DIR"

    local session_file="$SESSIONS_DIR/$(date +%Y-%m-%d-%H%M%S).yml"

    # Score: read from cache if available
    local score_after=""
    if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
        score_after=$(jq -r '.score // empty' "$CACHE_FILE" 2>/dev/null || true)
    fi

    # Score before: check git for the previous cache state
    local score_before=""
    local prev_cache
    prev_cache=$(git show HEAD:"$CACHE_FILE" 2>/dev/null || true)
    if [[ -n "$prev_cache" ]] && command -v jq &>/dev/null; then
        score_before=$(echo "$prev_cache" | jq -r '.score // empty' 2>/dev/null || true)
    fi

    # Predictions: count from today
    local today
    today=$(date +%Y-%m-%d)
    local predictions_count=0
    local graded_count=0
    if [[ -f "$PRED_FILE" ]]; then
        predictions_count=$(grep -c "^${today}" "$PRED_FILE" 2>/dev/null) || predictions_count=0
        graded_count=$(tail -n +2 "$PRED_FILE" | awk -F'\t' -v d="$today" '$1 == d && $6 != "" { c++ } END { print c+0 }')
    fi

    # Moves: count commits since session start (approximate: commits today)
    local moves=0
    moves=$(git log --oneline --since="$today" 2>/dev/null | wc -l | tr -d ' ') || moves=0

    # Learnings: collect model_updates from today's predictions
    local learnings=""
    if [[ -f "$PRED_FILE" ]]; then
        while IFS=$'\t' read -r _d _a _p _e _r _c mu; do
            [[ "$_d" != "$today" ]] && continue
            [[ -z "$mu" ]] && continue
            learnings="${learnings}\n  - \"${mu}\""
        done < <(tail -n +2 "$PRED_FILE")
    fi

    # Write session YAML
    {
        echo "date: $today"
        echo "time: $(date +%H:%M:%S)"
        [[ -n "$score_before" ]] && echo "score_before: $score_before"
        [[ -n "$score_after" ]] && echo "score_after: $score_after"
        echo "predictions_count: $predictions_count"
        echo "graded_count: $graded_count"
        echo "moves: $moves"
        echo "kept: $moves"
        echo "reverted: 0"
        if [[ -n "$learnings" ]]; then
            echo "learnings:"
            printf "%b\n" "$learnings"
        fi
    } > "$session_file"
}

log_session

# --- Score cache staleness check ---
if [[ -f "$CACHE_FILE" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
    else
        cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    fi
    stale_seconds=$((STALE_MINUTES * 60))

    # Check for uncommitted changes
    changed_files=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    staged_files=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    total_uncommitted=$((changed_files + staged_files))

    if [[ $cache_age -gt $stale_seconds && $total_uncommitted -gt 0 ]]; then
        echo -e "${YELLOW}⚠${NC} score cache ${BOLD}$((cache_age / 60))m${NC} stale with $total_uncommitted uncommitted changes — run ${DIM}rhino score .${NC}"
    fi

    if [[ $total_uncommitted -gt 5 ]]; then
        echo -e "${YELLOW}⚠${NC} $total_uncommitted uncommitted files — consider atomic commits"
    fi
fi
