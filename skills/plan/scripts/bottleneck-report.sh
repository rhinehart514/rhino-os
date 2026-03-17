#!/usr/bin/env bash
# bottleneck-report.sh — Formatted bottleneck report for /plan.
# Shows bottleneck feature, sub-score breakdown, completion, and delta trends.
# Usage: bash scripts/bottleneck-report.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== BOTTLENECK REPORT ==="
echo ""

# --- Primary bottleneck ---
RESULT=$("$RHINO_DIR/bin/compute-bottleneck.sh" 2>/dev/null || echo "")
if [[ -z "$RESULT" ]]; then
    echo "  no eval data — run rhino eval . first"
    echo "=== REPORT COMPLETE ==="
    exit 0
fi

# First line is the bottleneck
BOTTLENECK=$(echo "$RESULT" | head -1)
NAME=$(echo "$BOTTLENECK" | cut -f1)
SCORE=$(echo "$BOTTLENECK" | cut -f2)
WEIGHT=$(echo "$BOTTLENECK" | cut -f3)
DIM=$(echo "$BOTTLENECK" | cut -f5)

echo "▸ bottleneck: $NAME"
echo "  score: $SCORE/100  weight: $WEIGHT  weakest: $DIM"
echo ""

# --- Sub-score detail for bottleneck ---
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    D=$(jq -r ".[\"$NAME\"].delivery_score // \"?\"" "$EVAL_CACHE" 2>/dev/null)
    C=$(jq -r ".[\"$NAME\"].craft_score // \"?\"" "$EVAL_CACHE" 2>/dev/null)
    V=$(jq -r ".[\"$NAME\"].viability_score // \"?\"" "$EVAL_CACHE" 2>/dev/null)
    DELTA=$(jq -r ".[\"$NAME\"].delta // \"none\"" "$EVAL_CACHE" 2>/dev/null)
    echo "  sub-scores: delivery=$D  craft=$C  viability=$V  delta=$DELTA"

    # Diagnosis: which dimension is dragging?
    if [[ "$D" != "?" && "$C" != "?" && "$V" != "?" ]]; then
        if [[ "$D" -lt "$C" && "$D" -lt "$V" ]] 2>/dev/null; then
            echo "  diagnosis: delivery dragging — feature exists but doesn't deliver real value"
            echo "  action: complete the implementation, not polish"
        elif [[ "$C" -lt "$D" && "$C" -lt "$V" ]] 2>/dev/null; then
            echo "  diagnosis: craft dragging — delivers value but is fragile or rough"
            echo "  action: error handling, edge cases, polish"
        elif [[ "$V" -lt "$D" && "$V" -lt "$C" ]] 2>/dev/null; then
            echo "  diagnosis: viability dragging — works but lacks differentiation"
            echo "  action: competitive positioning, novelty, market fit"
        fi
    fi
    echo ""
fi

# --- All features ranked ---
echo "▸ all features (worst first)"
echo "$RESULT" | while IFS=$'\t' read -r fname fscore fweight fweighted fdim; do
    echo "  $fname: $fscore (w:$fweight, weakest:$fdim)"
done
echo ""

# --- Completion ---
COMPLETION=$("$RHINO_DIR/bin/compute-completion.sh" 2>/dev/null || echo "")
if [[ -n "$COMPLETION" ]]; then
    echo "▸ completion"
    echo "$COMPLETION" | sed 's/^/  /'
    echo ""

    # Version >80% check
    VERSION_PCT=$(echo "$COMPLETION" | grep 'version_completion:' | sed 's/.*: //')
    if [[ -n "$VERSION_PCT" ]] && [[ "$VERSION_PCT" -gt 80 ]] 2>/dev/null; then
        echo "  *** VERSION COMPLETION >80% — consider /roadmap bump ***"
        echo ""
    fi
fi

# --- Delta trends ---
DELTAS="$PROJECT_DIR/.claude/cache/eval-deltas.json"
if [[ -f "$DELTAS" ]] && command -v jq &>/dev/null; then
    echo "▸ delta trends"
    jq -r 'to_entries[] | select(.value != null) | "\(.key): \(.value)"' "$DELTAS" 2>/dev/null | sed 's/^/  /' | head -10
    echo ""

    # Features trending worse get priority flag
    WORSE=$(jq -r 'to_entries[] | select(.value == "worse") | .key' "$DELTAS" 2>/dev/null || echo "")
    if [[ -n "$WORSE" ]]; then
        echo "  *** REGRESSION: $(echo $WORSE | tr '\n' ', ') trending worse ***"
        echo ""
    fi
fi

echo "=== REPORT COMPLETE ==="
