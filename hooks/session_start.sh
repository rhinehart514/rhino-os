#!/usr/bin/env bash
# session_start.sh — SessionStart hook (v6)
set -euo pipefail

PROJECT_DIR=$(pwd)
INPUT=$(cat)
SESSION_TYPE=$(echo "$INPUT" | jq -r '.type // "startup"' 2>/dev/null || echo "startup")

# --- Project name ---
PROJECT_NAME=""
if [[ -f "$PROJECT_DIR/config/rhino.yml" ]]; then
    PROJECT_NAME=$(grep -m1 '^name:' "$PROJECT_DIR/config/rhino.yml" 2>/dev/null | sed 's/^name: *//' || true)
fi
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME=$(basename "$PROJECT_DIR")

# --- Last score ---
SCORE_DISPLAY=""
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]]; then
    TOTAL=$(jq -r '.total // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    BUILD=$(jq -r '.build // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    STRUCT=$(jq -r '.structure // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    HYGIENE=$(jq -r '.hygiene // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    SCORE_DISPLAY="Score: ${TOTAL}/100 (Build:${BUILD} Struct:${STRUCT} Hygiene:${HYGIENE})"
fi

# --- Active plan ---
PLAN_FILE=""
for p in "$PROJECT_DIR/.claude/plans/active-plan.md" "$HOME/.claude/plans/active-plan.md"; do
    if [[ -f "$p" ]]; then PLAN_FILE="$p"; break; fi
done

TASKS_REMAINING=0
NEXT_TASK=""
if [[ -n "$PLAN_FILE" ]]; then
    TOTAL_TASKS=$(grep -c '^\- \[' "$PLAN_FILE" 2>/dev/null || echo 0)
    DONE_TASKS=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
    TASKS_REMAINING=$((TOTAL_TASKS - DONE_TASKS))
    NEXT_TASK=$(grep -m1 '^\- \[ \]' "$PLAN_FILE" 2>/dev/null | sed 's/^- \[ \] //' || true)
fi

# === Output ===
echo ""
echo "rhino-os booted"
echo ""

LINE1="Project: ${PROJECT_NAME}"
[[ -n "$SCORE_DISPLAY" ]] && LINE1="$LINE1 | $SCORE_DISPLAY"
echo "$LINE1"

if [[ -n "$PLAN_FILE" && "$TASKS_REMAINING" -gt 0 ]]; then
    echo "Active plan: $TASKS_REMAINING tasks remaining"
    [[ -n "$NEXT_TASK" ]] && echo "-> NEXT: $NEXT_TASK"
elif [[ -z "$SCORE_DISPLAY" ]]; then
    echo "No score yet — run: rhino score ."
fi

# --- Compaction recovery ---
if [[ "$SESSION_TYPE" == "compact" ]]; then
    echo ""
    echo "Context compacted. Re-read:"
    echo "  1. mind/thinking.md"
    echo "  2. ~/.claude/knowledge/experiment-learnings.md"
    echo "  3. .claude/plans/active-plan.md"
fi
