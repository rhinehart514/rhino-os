#!/usr/bin/env bash
set -euo pipefail

# morning-sweep.sh — Run the morning-sweep agent via Claude Code
# Designed to be called by launchd or manually
#
# Usage: ./morning-sweep.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/sweep-$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') — Starting morning sweep" >> "$LOG_FILE"

# Check if claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') — ERROR: claude CLI not found" >> "$LOG_FILE"
    exit 1
fi

# Run the sweep agent interactively (needs human for RED items)
# Note: morning-sweep is designed to be interactive, not headless
# For automated runs, it will produce the report but skip RED dispatch
claude --agent morning-sweep \
    "Run the morning sweep. Produce the morning brief. Classify all items. Do NOT auto-dispatch RED items — list them for human review." \
    2>> "$LOG_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') — Morning sweep complete" >> "$LOG_FILE"
