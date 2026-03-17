#!/usr/bin/env bash
# Quick system health pulse
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "── system pulse ──"
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]] && command -v jq &>/dev/null; then
    SCORE=$(jq -r '.score // "?"' "$SCORE_CACHE" 2>/dev/null)
    echo "  score: $SCORE/100"
fi
BN=$("$RHINO_DIR/bin/compute-bottleneck.sh" 2>/dev/null | head -1)
if [[ -n "$BN" ]]; then
    echo "  bottleneck: $(echo "$BN" | cut -f1) ($(echo "$BN" | cut -f2))"
fi
PRED="$PROJECT_DIR/.claude/knowledge/predictions.tsv"
[[ ! -f "$PRED" ]] && PRED="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED" ]]; then
    UNGRADED=$(tail -n +2 "$PRED" | awk -F'\t' '$6 == "" { c++ } END { print c+0 }')
    echo "  ungraded predictions: $UNGRADED"
fi
PLAN="$PROJECT_DIR/.claude/plans/plan.yml"
if [[ -f "$PLAN" ]]; then
    TODO=$(grep -c 'status: todo' "$PLAN" 2>/dev/null || echo "0")
    echo "  plan tasks: $TODO remaining"
fi
