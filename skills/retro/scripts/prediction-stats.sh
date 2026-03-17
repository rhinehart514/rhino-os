#!/usr/bin/env bash
# Prediction statistics for /retro
# Usage: bash scripts/prediction-stats.sh
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PRED_FILE="$PROJECT_DIR/.claude/knowledge/predictions.tsv"
[[ ! -f "$PRED_FILE" ]] && PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
echo "── prediction stats ──"
if [[ ! -f "$PRED_FILE" ]]; then
    echo "  no predictions.tsv"
    exit 0
fi
TOTAL=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
UNGRADED=$((TOTAL - GRADED))
CORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
PARTIAL=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
WRONG=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "no" { c++ } END { print c+0 }')
echo "  total: $TOTAL"
echo "  graded: $GRADED (ungraded: $UNGRADED)"
echo "  correct: $CORRECT · partial: $PARTIAL · wrong: $WRONG"
if [[ "$GRADED" -gt 0 ]]; then
    EFFECTIVE=$(python3 -c "print(f'{($CORRECT + $PARTIAL * 0.5) / $GRADED * 100:.0f}')" 2>/dev/null || echo "?")
    echo "  accuracy: ${EFFECTIVE}%"
    if [[ "$EFFECTIVE" != "?" ]]; then
        ACC=${EFFECTIVE%.*}
        if [[ "$ACC" -gt 70 ]]; then
            echo "  ⚠ too safe — predictions need to be bolder"
        elif [[ "$ACC" -lt 50 ]]; then
            echo "  ⚠ model may be broken — review prediction quality"
        else
            echo "  ✓ well-calibrated (50-70% range)"
        fi
    fi
fi
# Recent predictions
echo ""
echo "  last 3:"
tail -3 "$PRED_FILE" | awk -F'\t' '{print "    "$1" · "$3" → "$6}' 2>/dev/null || true
