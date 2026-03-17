#!/usr/bin/env bash
# Formatted bottleneck report for /plan
# Usage: bash scripts/bottleneck-report.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "── bottleneck report ──"

# Use shared bottleneck computation
RESULT=$("$RHINO_DIR/bin/compute-bottleneck.sh" 2>/dev/null || echo "")
if [[ -z "$RESULT" ]]; then
    echo "  no eval data — run rhino eval . first"
    exit 0
fi

# First line is the bottleneck
BOTTLENECK=$(echo "$RESULT" | head -1)
NAME=$(echo "$BOTTLENECK" | cut -f1)
SCORE=$(echo "$BOTTLENECK" | cut -f2)
WEIGHT=$(echo "$BOTTLENECK" | cut -f3)
DIM=$(echo "$BOTTLENECK" | cut -f5)

echo "  feature: $NAME"
echo "  score: $SCORE/100 (weight: $WEIGHT)"
echo "  weakest dimension: $DIM"
echo ""

# Completion
COMPLETION=$("$RHINO_DIR/bin/compute-completion.sh" 2>/dev/null || echo "")
if [[ -n "$COMPLETION" ]]; then
    echo "── completion ──"
    echo "$COMPLETION" | sed 's/^/  /'
fi
