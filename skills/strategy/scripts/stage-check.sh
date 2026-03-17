#!/usr/bin/env bash
# Check stage-appropriateness of current work
# Usage: bash scripts/stage-check.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RHINO_YML="$PROJECT_DIR/config/rhino.yml"
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
echo "── stage check ──"
STAGE=$(grep -m1 'stage:' "$RHINO_YML" 2>/dev/null | sed 's/.*stage: *//' | sed 's/#.*//' | tr -d ' ' || echo "unknown")
echo "  stage: $STAGE"
# Count features in building range (30-49)
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    BUILDING=$(jq -r 'to_entries[] | select(.value.score >= 30 and .value.score < 50) | .key' "$EVAL_CACHE" 2>/dev/null | wc -l | tr -d ' ')
    WORKING=$(jq -r 'to_entries[] | select(.value.score >= 50 and .value.score < 70) | .key' "$EVAL_CACHE" 2>/dev/null | wc -l | tr -d ' ')
    echo "  building: $BUILDING features"
    echo "  working: $WORKING features"
    if [[ "$STAGE" == "mvp" || "$STAGE" == "early" ]] && [[ "$BUILDING" -gt 3 ]]; then
        echo "  ⚠ feature sprawl: $BUILDING features building at stage $STAGE"
    else
        echo "  ✓ stage-appropriate"
    fi
fi
