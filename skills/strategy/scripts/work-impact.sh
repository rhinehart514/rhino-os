#!/usr/bin/env bash
# Compute work-to-impact ratio: commits vs score delta
# Usage: bash scripts/work-impact.sh [days]
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DAYS="${1:-7}"
HISTORY="$PROJECT_DIR/.claude/scores/history.tsv"
echo "── work-impact ratio (last ${DAYS}d) ──"
SINCE=$(date -v-${DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${DAYS} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
COMMITS=$(git -C "$PROJECT_DIR" log --oneline --since="$SINCE" 2>/dev/null | wc -l | tr -d ' ')
echo "  commits: $COMMITS"
if [[ -f "$HISTORY" ]] && [[ -n "$SINCE" ]]; then
    FIRST_SCORE=$(awk -F'\t' -v d="$SINCE" '$1 >= d {print $5; exit}' "$HISTORY" 2>/dev/null || echo "")
    LAST_SCORE=$(tail -1 "$HISTORY" | cut -f5 2>/dev/null || echo "")
    if [[ -n "$FIRST_SCORE" && -n "$LAST_SCORE" && "$FIRST_SCORE" =~ ^[0-9]+$ && "$LAST_SCORE" =~ ^[0-9]+$ ]]; then
        DELTA=$((LAST_SCORE - FIRST_SCORE))
        echo "  score: $FIRST_SCORE → $LAST_SCORE (delta: $DELTA)"
        if [[ "$COMMITS" -gt 0 ]]; then
            PTS_PER_COMMIT=$(python3 -c "print(f'{$DELTA/$COMMITS:.1f}')" 2>/dev/null || echo "?")
            echo "  pts/commit: $PTS_PER_COMMIT"
        fi
        if [[ "$COMMITS" -gt 10 && "$DELTA" -lt 3 ]]; then
            echo "  ⚠ high effort, low impact — rethink approach"
        fi
    fi
fi
