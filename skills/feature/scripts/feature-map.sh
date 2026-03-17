#!/usr/bin/env bash
# Show feature map: name, weight, eval score, maturity, dependencies
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "── feature map ──"
RESULT=$("$RHINO_DIR/bin/compute-bottleneck.sh" 2>/dev/null || echo "")
if [[ -z "$RESULT" ]]; then
    echo "  no eval data"
    exit 0
fi
echo "  name            score  weight  dimension"
echo "  ────            ─────  ──────  ─────────"
echo "$RESULT" | while IFS=$'\t' read -r name score weight weighted dim; do
    # Maturity label from score
    if [[ "$score" -ge 90 ]]; then mat="proven"
    elif [[ "$score" -ge 70 ]]; then mat="polished"
    elif [[ "$score" -ge 50 ]]; then mat="working"
    elif [[ "$score" -ge 30 ]]; then mat="building"
    else mat="planned"; fi
    printf "  %-16s %3s    w:%-2s    %s (%s)\n" "$name" "$score" "$weight" "$dim" "$mat"
done
