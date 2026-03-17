#!/usr/bin/env bash
# Check if proposed score has dangerous variance from rubric
# Usage: bash scripts/variance-check.sh <feature> <proposed_score>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FEATURE="${1:?usage: variance-check.sh <feature> <proposed_score>}"
PROPOSED="${2:?usage: variance-check.sh <feature> <proposed_score>}"
RUBRIC="$PROJECT_DIR/.claude/cache/rubrics/$FEATURE.json"

if [[ ! -f "$RUBRIC" ]]; then
    echo "no rubric for $FEATURE — first score, no variance check needed"
    exit 0
fi

if command -v jq &>/dev/null; then
    LAST_SCORE=$(jq -r '.last_score // 0' "$RUBRIC" 2>/dev/null)
    DELTA=$((PROPOSED - LAST_SCORE))
    ABS_DELTA=${DELTA#-}

    if [[ "$ABS_DELTA" -gt 15 ]]; then
        echo "⚠ VARIANCE: proposed $PROPOSED vs rubric $LAST_SCORE (delta: $DELTA)"
        echo "  investigate before publishing — same code should get same score"
        exit 1
    else
        echo "✓ variance ok: proposed $PROPOSED vs rubric $LAST_SCORE (delta: $DELTA)"
    fi
fi
