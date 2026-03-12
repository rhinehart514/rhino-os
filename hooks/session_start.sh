#!/usr/bin/env bash
# session_start.sh — SessionStart hook (v5)
# Full context boot screen. Reads project state and surfaces what matters.
set -euo pipefail

PROJECT_DIR=$(pwd)
INPUT=$(cat)
SESSION_TYPE=$(echo "$INPUT" | jq -r '.type // "startup"' 2>/dev/null || echo "startup")

# --- Project name ---
PROJECT_NAME=""
# Try config/rhino.yml
if [[ -f "$PROJECT_DIR/config/rhino.yml" ]]; then
    PROJECT_NAME=$(grep -m1 '^name:' "$PROJECT_DIR/config/rhino.yml" 2>/dev/null | sed 's/^name: *//' || true)
fi
# Try .claude/state/workspace.json
if [[ -z "$PROJECT_NAME" && -f "$PROJECT_DIR/.claude/state/workspace.json" ]]; then
    PROJECT_NAME=$(jq -r '.name // ""' "$PROJECT_DIR/.claude/state/workspace.json" 2>/dev/null || true)
fi
# Fallback to directory name
if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME=$(basename "$PROJECT_DIR")
fi

# --- Stage ---
STAGE=""
if [[ -f "$PROJECT_DIR/.claude/state/workspace.json" ]]; then
    STAGE=$(jq -r '.stage // ""' "$PROJECT_DIR/.claude/state/workspace.json" 2>/dev/null || true)
fi

# --- Last score ---
SCORE_DISPLAY=""
SCORE_FILE="$PROJECT_DIR/.claude/scores/history.tsv"
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]]; then
    TOTAL=$(jq -r '.total // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    BUILD=$(jq -r '.build // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    STRUCT=$(jq -r '.structure // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    HYGIENE=$(jq -r '.hygiene // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    SCORE_DISPLAY="Score: ${TOTAL}/100 (Build:${BUILD} Struct:${STRUCT} Hygiene:${HYGIENE})"
elif [[ -f "$SCORE_FILE" ]]; then
    LAST_LINE=$(tail -1 "$SCORE_FILE" 2>/dev/null || true)
    if [[ -n "$LAST_LINE" ]]; then
        TOTAL=$(echo "$LAST_LINE" | awk '{print $2}' 2>/dev/null || echo "?")
        BUILD=$(echo "$LAST_LINE" | awk '{print $3}' 2>/dev/null || echo "?")
        STRUCT=$(echo "$LAST_LINE" | awk '{print $4}' 2>/dev/null || echo "?")
        HYGIENE=$(echo "$LAST_LINE" | awk '{print $5}' 2>/dev/null || echo "?")
        SCORE_DISPLAY="Score: ${TOTAL}/100 (Build:${BUILD} Struct:${STRUCT} Hygiene:${HYGIENE})"
    fi
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

# --- Last session summary ---
LAST_SESSION=""
LAST_SESSION_DATE=""
BRAINS_DAILY="$PROJECT_DIR/.claude/brains/daily.md"
if [[ -f "$BRAINS_DAILY" ]]; then
    LAST_HEADER=$(grep -n '^## ' "$BRAINS_DAILY" 2>/dev/null | tail -1 || true)
    if [[ -n "$LAST_HEADER" ]]; then
        LAST_SESSION_DATE=$(echo "$LAST_HEADER" | sed 's/^[0-9]*:## //' || true)
        LINE_NUM=$(echo "$LAST_HEADER" | cut -d: -f1)
        NEXT_LINE=$((LINE_NUM + 1))
        LAST_SESSION=$(sed -n "${NEXT_LINE}p" "$BRAINS_DAILY" 2>/dev/null || true)
    fi
fi

# --- Beliefs check ---
BELIEFS_EXIST=false
BELIEF_COUNT=0
BELIEFS_FILE="$PROJECT_DIR/.claude/evals/beliefs.yml"
if [[ -f "$BELIEFS_FILE" ]]; then
    BELIEF_COUNT=$(grep -c '^\s*- id:' "$BELIEFS_FILE" 2>/dev/null || echo 0)
    if [[ "$BELIEF_COUNT" -gt 0 ]]; then
        BELIEFS_EXIST=true
    fi
fi

# --- Corpus freshness ---
CORPUS_STATUS=""
CORPUS_DIR="$PROJECT_DIR/corpus"
if [[ -d "$CORPUS_DIR" ]]; then
    CORPUS_COUNT=$(find "$CORPUS_DIR" -type f -not -name 'README.md' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$CORPUS_COUNT" -gt 0 ]]; then
        CORPUS_STATUS="Corpus: ${CORPUS_COUNT} examples"
    fi
fi

# === Output the boot card ===
echo ""
echo "rhino-os booted"
echo ""

# Line 1: Project info
LINE1="Project: ${PROJECT_NAME}"
[[ -n "$STAGE" ]] && LINE1="$LINE1 | Stage: $STAGE"
[[ -n "$SCORE_DISPLAY" ]] && LINE1="$LINE1 | $SCORE_DISPLAY"
echo "$LINE1"

# Line 2: Last session
if [[ -n "$LAST_SESSION_DATE" ]]; then
    echo "Last session: ${LAST_SESSION:-no notes} — $LAST_SESSION_DATE"
else
    echo "Last session: first session"
fi

echo ""

# Active plan
if [[ -n "$PLAN_FILE" && "$TASKS_REMAINING" -gt 0 ]]; then
    echo "Active plan: $TASKS_REMAINING tasks remaining"
    if [[ -n "$NEXT_TASK" ]]; then
        echo "-> NEXT: $NEXT_TASK"
    fi
elif [[ -n "$PLAN_FILE" && "$TASKS_REMAINING" -eq 0 ]]; then
    echo "Active plan: all tasks complete! Run /plan for a new sprint."
else
    echo "No active plan. Run /plan to create one."
fi

# Beliefs
if [[ "$BELIEFS_EXIST" == "true" ]]; then
    echo ""
    echo "Beliefs: $BELIEF_COUNT defined (run /eval to check)"
fi

# Corpus
if [[ -n "$CORPUS_STATUS" ]]; then
    echo "$CORPUS_STATUS"
fi

# Score missing
if [[ -z "$SCORE_DISPLAY" ]]; then
    echo ""
    echo "No score yet — run: rhino score ."
fi

echo ""
echo "/build to start | /next for task | /status for full briefing | /eval to check beliefs"

# --- Compaction recovery ---
if [[ "$SESSION_TYPE" == "compact" ]]; then
    echo ""
    echo "Context compacted. Re-read:"
    echo "  1. docs/thinking.md"
    echo "  2. ~/.claude/knowledge/experiment-learnings.md"
    echo "  3. .claude/plans/active-plan.md"
    echo "  4. .claude/brains/longterm.md"
    echo "  5. .claude/rules/ (identity, product-brief, hypotheses)"
fi
