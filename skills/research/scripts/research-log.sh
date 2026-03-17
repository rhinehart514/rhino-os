#!/usr/bin/env bash
# Show research history from research-memory.json
# Usage: bash scripts/research-log.sh [topic]
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEMORY="$PROJECT_DIR/.claude/cache/research-memory.json"
echo "── research history ──"
if [[ ! -f "$MEMORY" ]]; then
    echo "  no research history"
    exit 0
fi
if command -v jq &>/dev/null; then
    SESSIONS=$(jq -r '.sessions | length // 0' "$MEMORY" 2>/dev/null)
    echo "  sessions: $SESSIONS"
    echo ""
    echo "  recent:"
    jq -r '.sessions[-5:][] | "  \(.date // "?") · \(.topic // "?") → \(.key_finding // "none")"' "$MEMORY" 2>/dev/null || true
    TOPIC="${1:-}"
    if [[ -n "$TOPIC" ]]; then
        echo ""
        echo "  matching \"$TOPIC\":"
        jq -r --arg t "$TOPIC" '.sessions[] | select(.topic | ascii_downcase | contains($t | ascii_downcase)) | "  \(.date) · \(.key_finding // "none")"' "$MEMORY" 2>/dev/null || echo "  no matches"
    fi
fi
