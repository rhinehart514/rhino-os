#!/usr/bin/env bash
# Show current version thesis progress
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
echo "── version progress ──"
if [[ ! -f "$ROADMAP" ]]; then
    echo "  no roadmap.yml"
    exit 0
fi
CURRENT=$(grep -m1 'current:' "$ROADMAP" 2>/dev/null | sed 's/.*current: *//' || echo "?")
THESIS=$(grep -A3 "^  ${CURRENT}:" "$ROADMAP" 2>/dev/null | grep 'thesis:' | sed 's/.*thesis: *//' | sed 's/"//g' || echo "?")
echo "  version: $CURRENT"
echo "  thesis: \"$THESIS\""
COMPLETION=$("$RHINO_DIR/bin/compute-completion.sh" 2>/dev/null | grep "version_completion" | awk '{print $2}')
[[ -n "$COMPLETION" ]] && echo "  completion: ${COMPLETION}%"
