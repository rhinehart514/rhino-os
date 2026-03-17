#!/usr/bin/env bash
# evidence-scan.sh — Scans all project state for ideation evidence.
# Outputs structured JSON. Zero context cost — only output enters the conversation.
set -euo pipefail

PROJECT_DIR="${1:-.}"

# --- Eval cache sub-scores ---
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    echo "=== EVAL SCORES ==="
    jq -r 'to_entries[] | select(.value.score != null) | "\(.key): \(.value.score) (d:\(.value.delivery_score) c:\(.value.craft_score) v:\(.value.viability_score)) delta:\(.value.delta // "none")"' "$EVAL_CACHE" 2>/dev/null || echo "(parse error)"
    echo ""
    # Weakest feature
    WEAKEST=$(jq -r 'to_entries | map(select(.value.score != null)) | sort_by(.value.score) | .[0] | "\(.key) at \(.value.score)"' "$EVAL_CACHE" 2>/dev/null || echo "unknown")
    echo "BOTTLENECK: $WEAKEST"
    echo ""
fi

# --- Wrong predictions (highest signal) ---
PRED_FILE="$PROJECT_DIR/.claude/knowledge/predictions.tsv"
[[ ! -f "$PRED_FILE" ]] && PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    echo "=== WRONG PREDICTIONS (last 10) ==="
    tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "no" || $6 == "partial"' | tail -10 | while IFS=$'\t' read -r date pred evidence result correct update; do
        echo "  $date: $pred"
        [[ -n "$update" ]] && echo "    model update: $update"
    done
    WRONG_CT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "no" || $6 == "partial"' | wc -l | tr -d ' ')
    echo "  ($WRONG_CT total wrong/partial predictions)"
    echo ""
fi

# --- Backlog clusters (3+ todos on same feature) ---
TODOS_FILE="$PROJECT_DIR/.claude/plans/todos.yml"
if [[ -f "$TODOS_FILE" ]]; then
    echo "=== BACKLOG CLUSTERS ==="
    grep -E 'feature:|tag:' "$TODOS_FILE" 2>/dev/null | sed 's/.*: *//' | sort | uniq -c | sort -rn | head -5 | while read -r count tag; do
        [[ "$count" -ge 3 ]] && echo "  $tag: $count todos (cluster)"
        [[ "$count" -lt 3 ]] && echo "  $tag: $count todos"
    done
    echo ""
fi

# --- Thesis gaps (unproven evidence) ---
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
if [[ -f "$ROADMAP" ]]; then
    echo "=== UNPROVEN THESIS EVIDENCE ==="
    # Find current version's evidence items
    awk '/^  v[0-9]/{ver=$0} /evidence:/{if(ver ~ /status: active/ || ver ~ /status: testing/) in_ev=1; next} in_ev && /^    -/{print "  " $0; next} in_ev && /^  [^ ]/{in_ev=0}' "$ROADMAP" 2>/dev/null || echo "(parse error)"
    echo ""
fi

# --- Dead ends that might be worth retrying ---
LEARNINGS="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
[[ ! -f "$LEARNINGS" ]] && LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]]; then
    echo "=== DEAD ENDS ==="
    awk '/^## Dead Ends/,/^## /{if(/^## / && !/Dead Ends/) exit; print}' "$LEARNINGS" 2>/dev/null | grep -E '^\s*-' | head -5
    echo ""
    echo "=== UNKNOWN TERRITORY ==="
    awk '/^## Unknown Territory/,/^## /{if(/^## / && !/Unknown/) exit; print}' "$LEARNINGS" 2>/dev/null | grep -E '^\s*-' | head -10
    echo ""
fi

# --- Stale features (no score movement in 14+ days) ---
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    echo "=== STALE FEATURES (same delta) ==="
    jq -r 'to_entries[] | select(.value.delta == "same") | "\(.key): score \(.value.score) — no movement"' "$EVAL_CACHE" 2>/dev/null
    echo ""
fi

# --- Customer intel summary ---
CUST_INTEL="$PROJECT_DIR/.claude/cache/customer-intel.json"
if [[ -f "$CUST_INTEL" ]] && command -v jq &>/dev/null; then
    echo "=== CUSTOMER SIGNALS ==="
    jq -r '.demand_signals[]? // empty' "$CUST_INTEL" 2>/dev/null | head -5
    echo ""
fi

# --- Git activity (what's been worked on) ---
echo "=== RECENT WORK (last 20 commits) ==="
git -C "$PROJECT_DIR" log --oneline -20 2>/dev/null || echo "(not a git repo)"
echo ""

echo "=== SCAN COMPLETE ==="
