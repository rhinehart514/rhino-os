#!/usr/bin/env bash
# Check if score has plateaued
# Usage: bash scripts/plateau-check.sh [threshold]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
THRESHOLD="${1:-3}"
HISTORY="$PROJECT_DIR/.claude/scores/history.tsv"

if [[ ! -f "$HISTORY" ]]; then
    echo "no history — no plateau"
    exit 0
fi

# Get last N+1 scores to compute N deltas
SCORES=$(tail -n "$((THRESHOLD + 1))" "$HISTORY" | awk -F'\t' '{print $5}' | grep -E '^[0-9]+$')
COUNT=$(echo "$SCORES" | wc -l | tr -d ' ')

if [[ "$COUNT" -lt "$((THRESHOLD + 1))" ]]; then
    echo "not enough history ($COUNT scores, need $((THRESHOLD + 1)))"
    exit 0
fi

# Check if all deltas are <2
PREV=""
FLAT_COUNT=0
while IFS= read -r score; do
    if [[ -n "$PREV" ]]; then
        DELTA=$((score - PREV))
        ABS_DELTA=${DELTA#-}
        if [[ "$ABS_DELTA" -lt 2 ]]; then
            FLAT_COUNT=$((FLAT_COUNT + 1))
        fi
    fi
    PREV="$score"
done <<< "$SCORES"

if [[ "$FLAT_COUNT" -ge "$THRESHOLD" ]]; then
    echo "PLATEAU: $FLAT_COUNT consecutive flat moves (delta <2)"
    exit 1
else
    echo "no plateau ($FLAT_COUNT flat moves, threshold $THRESHOLD)"
    exit 0
fi
