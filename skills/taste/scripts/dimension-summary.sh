#!/usr/bin/env bash
# Show taste evaluation history and dimension trends
# Usage: bash scripts/dimension-summary.sh [dimension]
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HISTORY="$PROJECT_DIR/.claude/evals/taste-history.tsv"
echo "── taste history ──"
if [[ ! -f "$HISTORY" ]]; then
    echo "  no taste evaluations yet"
    exit 0
fi
EVALS=$(tail -n +2 "$HISTORY" | wc -l | tr -d ' ')
echo "  evaluations: $EVALS"
if [[ "$EVALS" -gt 0 ]]; then
    echo "  latest:"
    tail -1 "$HISTORY" | awk -F'\t' '{print "    url: "$2; print "    overall: "$3; print "    date: "$1}'
fi
DIMENSION="${1:-}"
if [[ -n "$DIMENSION" ]]; then
    echo ""
    echo "  $DIMENSION trend:"
    tail -n +2 "$HISTORY" | awk -F'\t' -v d="$DIMENSION" '{for(i=1;i<=NF;i++) if($i==d && i<NF) print "    "$(i+1)}' | tail -5
fi
