#!/usr/bin/env bash
set -euo pipefail

# Read hook input from stdin
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name')"

# Check if ideation output style is active
# Claude Code saves the selected output style in settings.local.json
SETTINGS_FILES=(
  ".claude/settings.local.json"
  "$HOME/.claude/settings.local.json"
)

STYLE=""
for f in "${SETTINGS_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    STYLE="$(jq -r '.outputStyle // empty' "$f" 2>/dev/null || true)"
    if [[ -n "$STYLE" ]]; then
      break
    fi
  fi
done

# Block edits/writes/bash in ideation mode
if echo "$STYLE" | grep -qi "ideation"; then
  if [[ "$TOOL_NAME" =~ ^(Edit|Write|NotebookEdit|Bash)$ ]]; then
    echo '{"decision": "block", "reason": "IDEATE mode is read-only. Switch output style to Implementation to edit or run commands."}' >&2
    exit 2
  fi
fi

exit 0
