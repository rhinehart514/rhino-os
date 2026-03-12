#!/usr/bin/env bash
# post_build.sh — Runs after /build. Scores, evals, logs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"

echo ""
echo "--- post-build -------------------------------------"

# Run score.sh
SCORE_SCRIPT="$SCRIPT_DIR/../bin/score.sh"
if [ -f "$SCORE_SCRIPT" ]; then
  echo "Scoring..."
  bash "$SCORE_SCRIPT" "$PROJECT_ROOT" 2>/dev/null | tail -5
fi

# Run eval.sh
EVAL_SCRIPT="$SCRIPT_DIR/../bin/eval.sh"
if [ -f "$EVAL_SCRIPT" ]; then
  BELIEFS_FILE="$PROJECT_ROOT/.claude/evals/beliefs.yml"
  if [ -f "$BELIEFS_FILE" ]; then
    echo ""
    echo "Running belief evals..."
    bash "$EVAL_SCRIPT" "$PROJECT_ROOT" 2>/dev/null
  fi
fi

# Log timestamp
echo ""
echo "-------------------------------------------------"
echo "Build logged: $(date '+%Y-%m-%d %H:%M')"
