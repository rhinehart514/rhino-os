#!/usr/bin/env bash
# Show plan.yml progress
# Usage: bash scripts/plan-progress.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLAN_FILE="$PROJECT_DIR/.claude/plans/plan.yml"

echo "── plan progress ──"

if [[ ! -f "$PLAN_FILE" ]]; then
    echo "  no active plan"
    exit 0
fi

TOTAL=$(grep -c '- title:' "$PLAN_FILE" 2>/dev/null || echo "0")
DONE=$(grep -c 'status: done' "$PLAN_FILE" 2>/dev/null || echo "0")
TODO=$(grep -c 'status: todo' "$PLAN_FILE" 2>/dev/null || echo "0")
IN_PROGRESS=$(grep -c 'status: in_progress' "$PLAN_FILE" 2>/dev/null || echo "0")

PLAN_NAME=$(grep -m1 'name:' "$PLAN_FILE" 2>/dev/null | sed 's/.*name: *//' | sed 's/"//g' || echo "unknown")

echo "  plan: \"$PLAN_NAME\""
echo "  done: $DONE/$TOTAL"
echo "  in progress: $IN_PROGRESS"
echo "  remaining: $TODO"

if [[ "$TOTAL" -gt 0 ]]; then
    PCT=$((DONE * 100 / TOTAL))
    echo "  completion: ${PCT}%"
fi

# Next task
NEXT=$(grep -B1 'status: todo' "$PLAN_FILE" 2>/dev/null | grep 'title:' | head -1 | sed 's/.*title: *//' || true)
[[ -n "$NEXT" ]] && echo "  next: $NEXT"
