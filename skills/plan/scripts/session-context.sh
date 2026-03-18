#!/usr/bin/env bash
# session-context.sh — Scans ALL project state for /plan session context.
# Outputs structured summary. Zero context cost — only output enters the conversation.
# Usage: bash scripts/session-context.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== SESSION CONTEXT ==="
echo "date: $(date +%Y-%m-%d)"
echo ""

# --- Score ---
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]] && command -v jq &>/dev/null; then
    echo "▸ score"
    SCORE=$(jq -r '.score // "?"' "$SCORE_CACHE" 2>/dev/null)
    HEALTH=$(jq -r '.health // "?"' "$SCORE_CACHE" 2>/dev/null)
    PASS=$(jq -r '.assertion_pass_count // 0' "$SCORE_CACHE" 2>/dev/null)
    TOTAL=$(jq -r '.assertion_count // 0' "$SCORE_CACHE" 2>/dev/null)
    echo "  score: $SCORE  health: $HEALTH  assertions: $PASS/$TOTAL"
    echo ""
else
    echo "▸ score"
    echo "  (no score cache — run: rhino score .)"
    echo ""
fi

# --- Eval cache (per-feature sub-scores) ---
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    echo "▸ eval (per-feature)"
    jq -r 'to_entries[] | select(.value.score != null) | "  \(.key): \(.value.score) (d:\(.value.delivery_score // "?") c:\(.value.craft_score // "?") v:\(.value.viability_score // "?")) delta:\(.value.delta // "none")"' "$EVAL_CACHE" 2>/dev/null || echo "  (parse error)"
    echo ""
else
    echo "▸ eval (per-feature)"
    echo "  (no eval cache — run: /eval)"
    echo ""
fi

# --- Completion ---
if [[ -f "$RHINO_DIR/bin/compute-completion.sh" ]]; then
    echo "▸ completion"
    "$RHINO_DIR/bin/compute-completion.sh" 2>/dev/null | sed 's/^/  /' || echo "  (error)"
    echo ""
fi

# --- Bottleneck ---
if [[ -f "$RHINO_DIR/bin/compute-bottleneck.sh" ]]; then
    echo "▸ bottleneck"
    RESULT=$("$RHINO_DIR/bin/compute-bottleneck.sh" 2>/dev/null | head -1 || echo "")
    if [[ -n "$RESULT" ]]; then
        NAME=$(echo "$RESULT" | cut -f1)
        SCORE=$(echo "$RESULT" | cut -f2)
        WEIGHT=$(echo "$RESULT" | cut -f3)
        DIM=$(echo "$RESULT" | cut -f5)
        echo "  feature: $NAME  score: $SCORE  weight: $WEIGHT  weakest: $DIM"
    else
        echo "  no eval data"
    fi
    echo ""
fi

# --- Predictions (last 10 + accuracy) ---
PRED_FILE="$PROJECT_DIR/.claude/knowledge/predictions.tsv"
[[ ! -f "$PRED_FILE" ]] && PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    echo "▸ predictions"
    TOTAL=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
    GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$5 != ""' | wc -l | tr -d ' ')
    CORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$5 == "yes"' | wc -l | tr -d ' ')
    PARTIAL=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$5 == "partial"' | wc -l | tr -d ' ')
    WRONG=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$5 == "no"' | wc -l | tr -d ' ')
    UNGRADED=$((TOTAL - GRADED))
    if [[ "$GRADED" -gt 0 ]]; then
        # partial counts as 0.5
        ACC=$(python3 -c "print(round(($CORRECT + $PARTIAL * 0.5) / $GRADED * 100))" 2>/dev/null || echo "?")
        echo "  total: $TOTAL  graded: $GRADED  accuracy: ${ACC}%"
    else
        echo "  total: $TOTAL  graded: 0  accuracy: n/a"
    fi
    echo "  ungraded: $UNGRADED  correct: $CORRECT  partial: $PARTIAL  wrong: $WRONG"

    # Last 7 days count
    WEEK_AGO=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null || echo "0000-00-00")
    RECENT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' -v d="$WEEK_AGO" '$1 >= d' | wc -l | tr -d ' ')
    echo "  last_7_days: $RECENT"

    # Recent wrong predictions (highest signal)
    WRONG_RECENT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$5 == "no" || $5 == "partial"' | tail -3)
    if [[ -n "$WRONG_RECENT" ]]; then
        echo "  recent wrong:"
        echo "$WRONG_RECENT" | while IFS=$'\t' read -r date pred evidence result correct update; do
            echo "    $date: $pred"
            [[ -n "$update" ]] && echo "      update: $update"
        done
    fi
    echo ""
else
    echo "▸ predictions"
    echo "  (no predictions — /go will start logging them)"
    echo ""
fi

# --- Strategy ---
STRATEGY="$PROJECT_DIR/.claude/plans/strategy.yml"
if [[ -f "$STRATEGY" ]]; then
    echo "▸ strategy"
    STAGE=$(grep -m1 'stage:' "$STRATEGY" 2>/dev/null | sed 's/.*stage: *//' || echo "?")
    BOTTLENECK=$(grep -m1 'bottleneck:' "$STRATEGY" 2>/dev/null | sed 's/.*bottleneck: *//' || echo "?")
    UPDATED=$(grep -m1 'last_updated:' "$STRATEGY" 2>/dev/null | sed 's/.*last_updated: *//' || echo "?")
    echo "  stage: $STAGE  bottleneck: $BOTTLENECK  updated: $UPDATED"
    echo ""
else
    echo "▸ strategy"
    echo "  (no strategy — run: /strategy honest)"
    echo ""
fi

# --- Roadmap (current thesis) ---
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
if [[ -f "$ROADMAP" ]]; then
    echo "▸ roadmap"
    # Current version + thesis
    grep -m1 'version:' "$ROADMAP" 2>/dev/null | sed 's/^/  /' || true
    grep -m1 'thesis:' "$ROADMAP" 2>/dev/null | sed 's/^/  /' || true
    # Evidence items
    echo "  evidence:"
    grep -A1 'evidence_needed:' "$ROADMAP" 2>/dev/null | grep -E '^\s+-' | sed 's/^/  /' | head -8 || true
    echo ""
else
    echo "▸ roadmap"
    echo "  (no roadmap — run: /roadmap new)"
    echo ""
fi

# --- Todos ---
TODOS="$PROJECT_DIR/.claude/plans/todos.yml"
if [[ -f "$TODOS" ]]; then
    echo "▸ todos"
    TOTAL_TODOS=$(grep -c '- title:' "$TODOS" 2>/dev/null || true)
    TOTAL_TODOS="${TOTAL_TODOS:-0}"; TOTAL_TODOS="${TOTAL_TODOS// /}"
    DONE_TODOS=$(grep -c 'status: done' "$TODOS" 2>/dev/null || true)
    DONE_TODOS="${DONE_TODOS:-0}"; DONE_TODOS="${DONE_TODOS// /}"
    ACTIVE_TODOS=$(grep -cE 'status: (todo|captured)' "$TODOS" 2>/dev/null || true)
    ACTIVE_TODOS="${ACTIVE_TODOS:-0}"; ACTIVE_TODOS="${ACTIVE_TODOS// /}"
    echo "  total: $TOTAL_TODOS  done: $DONE_TODOS  active: $ACTIVE_TODOS"
    echo ""
else
    echo "▸ todos"
    echo "  (no backlog — run: /todo add \"your first task\")"
    echo ""
fi

# --- Research (recent findings) ---
RESEARCH="$HOME/.claude/cache/last-research.yml"
if [[ -f "$RESEARCH" ]]; then
    echo "▸ research"
    TOPIC=$(grep -m1 'topic:' "$RESEARCH" 2>/dev/null | sed 's/.*topic: *//' || echo "?")
    RDATE=$(grep -m1 'date:' "$RESEARCH" 2>/dev/null | sed 's/.*date: *//' || echo "?")
    echo "  topic: $TOPIC  date: $RDATE"
    # Suggested tasks
    grep -A5 'suggested_tasks:' "$RESEARCH" 2>/dev/null | grep -E '^\s+-' | sed 's/^/  /' | head -3 || true
    echo ""
fi

# --- Git (recent work) ---
echo "▸ git (last 10)"
git -C "$PROJECT_DIR" log --oneline -10 2>/dev/null || echo "  (not a git repo)"
echo ""

# --- Knowledge model freshness ---
LEARNINGS="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
[[ ! -f "$LEARNINGS" ]] && LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]]; then
    echo "▸ knowledge model"
    if [[ -f "$RHINO_DIR/bin/detect-staleness.sh" ]]; then
        "$RHINO_DIR/bin/detect-staleness.sh" "$LEARNINGS" 2>/dev/null | sed 's/^/  /' || echo "  (error)"
    else
        if [[ "$(uname)" == "Darwin" ]]; then
            AGE=$(( ($(date +%s) - $(stat -f %m "$LEARNINGS")) / 86400 ))
        else
            AGE=$(( ($(date +%s) - $(stat -c %Y "$LEARNINGS")) / 86400 ))
        fi
        echo "  age: ${AGE} days"
    fi
    echo ""
else
    echo "▸ knowledge model"
    echo "  (no learnings file — /onboard or /go will create one)"
    echo ""
fi

echo "=== CONTEXT COMPLETE ==="
