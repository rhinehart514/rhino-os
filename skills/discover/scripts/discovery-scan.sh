#!/usr/bin/env bash
# discovery-scan.sh — Scans existing product-spec.yml + eval-cache + market data.
# Outputs structured state for /discover to consume.
# Usage: bash scripts/discovery-scan.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== PRODUCT SPEC STATUS ==="
SPEC="$PROJECT_DIR/config/product-spec.yml"
if [[ -f "$SPEC" ]]; then
    echo "EXISTS: $SPEC"
    echo ""
    # Count filled vs empty fields
    TOTAL=$(grep -c '""' "$SPEC" 2>/dev/null || echo "0")
    echo "EMPTY FIELDS: $TOTAL"
    echo ""
    # Show key fields
    echo "--- Key fields ---"
    for field in "person:" "situation:" "in_one_sentence:" "trigger:" "model:"; do
        LINE=$(grep "$field" "$SPEC" 2>/dev/null | head -1 || echo "")
        if [[ -n "$LINE" ]]; then
            # Check if value is empty
            if echo "$LINE" | grep -q '""'; then
                echo "  EMPTY: $field"
            else
                echo "  SET: $LINE"
            fi
        fi
    done
    echo ""
    # Last reviewed
    REVIEWED=$(grep "last_reviewed:" "$SPEC" 2>/dev/null | head -1 || echo "never")
    echo "LAST REVIEWED: $REVIEWED"
else
    echo "NO SPEC FOUND — will generate from scratch"
fi
echo ""

echo "=== EVAL CACHE ==="
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    FEATURE_COUNT=$(jq 'length' "$EVAL_CACHE" 2>/dev/null || echo "0")
    echo "FEATURES: $FEATURE_COUNT"
    jq -r 'to_entries[] | select(.value.score != null) | "  \(.key): \(.value.score) (d:\(.value.delivery_score // "?") c:\(.value.craft_score // "?") v:\(.value.viability_score // "?"))"' "$EVAL_CACHE" 2>/dev/null || echo "(no scored features)"
    echo ""
    # Average score
    AVG=$(jq '[.[] | select(.score != null) | .score] | if length > 0 then (add / length | floor) else 0 end' "$EVAL_CACHE" 2>/dev/null || echo "0")
    echo "AVG SCORE: $AVG"
else
    echo "NO EVAL DATA"
fi
echo ""

echo "=== MARKET DATA ==="
MARKET="$PROJECT_DIR/.claude/cache/market-context.json"
if [[ -f "$MARKET" ]]; then
    AGE_DAYS=$(( ($(date +%s) - $(stat -f %m "$MARKET" 2>/dev/null || stat -c %Y "$MARKET" 2>/dev/null || echo "0")) / 86400 ))
    echo "EXISTS: $MARKET (${AGE_DAYS}d old)"
    if [[ "$AGE_DAYS" -gt 7 ]]; then
        echo "STALE — recommend re-research"
    fi
else
    echo "NO MARKET DATA — agents should research"
fi
echo ""

echo "=== CUSTOMER INTEL ==="
CUSTOMER="$PROJECT_DIR/.claude/cache/customer-intel.json"
if [[ -f "$CUSTOMER" ]]; then
    AGE_DAYS=$(( ($(date +%s) - $(stat -f %m "$CUSTOMER" 2>/dev/null || stat -c %Y "$CUSTOMER" 2>/dev/null || echo "0")) / 86400 ))
    echo "EXISTS: $CUSTOMER (${AGE_DAYS}d old)"
else
    echo "NO CUSTOMER INTEL — agents should research"
fi
echo ""

echo "=== ROADMAP ==="
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
if [[ -f "$ROADMAP" ]]; then
    echo "EXISTS"
    grep -E "^  thesis:|^  version:" "$ROADMAP" 2>/dev/null | head -4
else
    echo "NO ROADMAP — will create after spec"
fi
echo ""

echo "=== STRATEGY ==="
STRATEGY="$PROJECT_DIR/.claude/plans/strategy.yml"
if [[ -f "$STRATEGY" ]]; then
    echo "EXISTS"
    grep -E "bottleneck:|stage:" "$STRATEGY" 2>/dev/null | head -2
else
    echo "NO STRATEGY — will populate from spec"
fi
echo ""

echo "=== ASSERTIONS ==="
BELIEFS="$PROJECT_DIR/config/beliefs.yml"
if [[ -f "$BELIEFS" ]]; then
    TOTAL=$(grep -c "^- " "$BELIEFS" 2>/dev/null || echo "0")
    PASSING=$(grep -c "status: pass" "$BELIEFS" 2>/dev/null || echo "0")
    FAILING=$(grep -c "status: fail" "$BELIEFS" 2>/dev/null || echo "0")
    echo "TOTAL: $TOTAL · PASSING: $PASSING · FAILING: $FAILING"
else
    echo "NO ASSERTIONS — will generate from spec"
fi
echo ""

echo "=== PREDICTIONS (last 7 days) ==="
PREDICTIONS="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PREDICTIONS" ]]; then
    WEEK_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "7 days ago" +%Y-%m-%d 2>/dev/null || echo "0000-00-00")
    RECENT=$(awk -F'\t' -v d="$WEEK_AGO" '$1 >= d' "$PREDICTIONS" 2>/dev/null | wc -l | tr -d ' ')
    echo "RECENT: $RECENT predictions in last 7 days"
    if [[ "$RECENT" -lt 3 ]]; then
        echo "WARNING: prediction starvation"
    fi
else
    echo "NO PREDICTIONS"
fi
echo ""

echo "=== RHINO CONFIG ==="
RHINO="$PROJECT_DIR/config/rhino.yml"
if [[ -f "$RHINO" ]]; then
    echo "EXISTS"
    grep -E "^  user:|^  name:" "$RHINO" 2>/dev/null | head -2
else
    echo "NO RHINO CONFIG"
fi
