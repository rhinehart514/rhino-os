#!/usr/bin/env bash
# pre_compact.sh — PreCompact hook
# Saves current task state before context compaction so SessionStart can restore it.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
PROJECT_DIR=$(pwd)
OUT="$CLAUDE_DIR/state/.pre-compact-context.json"

task_index=0
task_name=""
sprint_progress=""
milestone_progress=""

# Find active plan and extract current task
PLAN_FILE=""
for p in "$PROJECT_DIR/.claude/plans/active-plan.md" "$CLAUDE_DIR/plans/active-plan.md"; do
    if [[ -f "$p" ]]; then PLAN_FILE="$p"; break; fi
done

if [[ -n "$PLAN_FILE" ]]; then
    total=$(grep -c '^\- \[' "$PLAN_FILE" 2>/dev/null || echo 0)
    done=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
    sprint_progress="$done/$total"
    # Find first unchecked task
    task_name=$(grep -m1 '^\- \[ \]' "$PLAN_FILE" 2>/dev/null | sed 's/^- \[ \] //' || echo "")
    task_index=$((done + 1))
fi

# Check milestone progress
MILESTONES="$PROJECT_DIR/.claude/plans/milestones.md"
if [[ -f "$MILESTONES" ]]; then
    dod_total=$(grep -c '^\- \[' "$MILESTONES" 2>/dev/null || echo 0)
    dod_done=$(grep -c '^\- \[x\]' "$MILESTONES" 2>/dev/null || echo 0)
    milestone_progress="$dod_done/$dod_total DoD"
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
{
  "task_index": $task_index,
  "task_name": "$(echo "$task_name" | sed 's/"/\\"/g')",
  "sprint_progress": "$sprint_progress",
  "milestone_progress": "$milestone_progress",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Write session summary to brains/daily.md
BRAINS_DIR="$PROJECT_DIR/.claude/brains"
DAILY_FILE="$BRAINS_DIR/daily.md"
TODAY=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

if [ -d "$BRAINS_DIR" ] && [ -f "$DAILY_FILE" ]; then
  # Get last score for the summary
  SCORE_FILE="$PROJECT_DIR/.claude/scores/history.tsv"
  LAST_SCORE=""
  if [ -f "$SCORE_FILE" ]; then
    LAST_LINE=$(tail -1 "$SCORE_FILE" 2>/dev/null)
    if [ -n "$LAST_LINE" ]; then
      LAST_SCORE=$(echo "$LAST_LINE" | awk '{print $4}')
    fi
  fi

  echo "" >> "$DAILY_FILE"
  echo "## $TODAY $TIME" >> "$DAILY_FILE"
  echo "Score: ${LAST_SCORE:-unknown}/100 (auto-logged before compact)" >> "$DAILY_FILE"
  echo "[Session notes: update this manually with what happened]" >> "$DAILY_FILE"
fi
