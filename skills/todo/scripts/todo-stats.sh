#!/usr/bin/env bash
# Todo statistics
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TODOS="$PROJECT_DIR/.claude/plans/todos.yml"
echo "── todo stats ──"
if [[ ! -f "$TODOS" ]]; then
    echo "  no todos.yml"
    exit 0
fi
TOTAL=$(grep -c '^\s*- title:' "$TODOS" 2>/dev/null || echo "0")
OPEN=$(grep -c 'status: open\|status: active\|status: backlog' "$TODOS" 2>/dev/null || echo "0")
DONE=$(grep -c 'status: done' "$TODOS" 2>/dev/null || echo "0")
echo "  total: $TOTAL · open: $OPEN · done: $DONE"
if [[ "$TOTAL" -gt 0 ]]; then
    echo "  completion: $((DONE * 100 / TOTAL))%"
fi
echo ""
echo "  by source:"
grep 'source:' "$TODOS" 2>/dev/null | sed 's/.*source: *//' | sort | uniq -c | sort -rn | head -5 | sed 's/^/    /' || echo "    (no source data)"
