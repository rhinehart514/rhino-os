#!/usr/bin/env bash
# capture_knowledge.sh — Post-session knowledge extraction hook
# Fires on Stop event. Summarizes session decisions and appends to knowledge.
# Budget: max $0.25 per capture. Skips trivial sessions (<5 tool uses).

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Only run on Stop events (tool_name will be empty for stop hooks)
# This hook is registered as a Stop hook in settings.json

CLAUDE_DIR="$HOME/.claude"
LOG_DIR="$CLAUDE_DIR/logs"
KNOWLEDGE_DIR="$CLAUDE_DIR/knowledge"
USAGE_FILE="$LOG_DIR/usage.jsonl"
CAPTURE_LOCK="$LOG_DIR/.capture-lock"

# Prevent concurrent captures
if [[ -f "$CAPTURE_LOCK" ]]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$CAPTURE_LOCK" 2>/dev/null || stat -c %Y "$CAPTURE_LOCK" 2>/dev/null || echo "0") ))
    # If lock is older than 5 minutes, it's stale
    if (( lock_age < 300 )); then
        exit 0
    fi
fi

# Count tool uses in the last session (approximate: last 30 minutes)
if [[ -f "$USAGE_FILE" ]]; then
    thirty_min_ago=$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
    if [[ -n "$thirty_min_ago" ]]; then
        tool_count=$(awk -v cutoff="$thirty_min_ago" '
            {
                match($0, /"ts":"([^"]+)"/, arr)
                if (arr[1] >= cutoff) count++
            }
            END { print count+0 }
        ' "$USAGE_FILE")
    else
        tool_count=0
    fi
else
    tool_count=0
fi

# Skip trivial sessions
if (( tool_count < 5 )); then
    exit 0
fi

# Detect current project directory
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Create capture lock
echo "$$" > "$CAPTURE_LOCK"
trap 'rm -f "$CAPTURE_LOCK"' EXIT

# Determine output file
SESSION_KNOWLEDGE="$KNOWLEDGE_DIR/sessions"
mkdir -p "$SESSION_KNOWLEDGE"
SESSION_FILE="$SESSION_KNOWLEDGE/${PROJECT_NAME}.md"

# Run a lightweight summarization (separate claude invocation)
SUMMARY=$(claude -p --max-budget-usd 0.25 --output-format json \
    "You are a knowledge capture assistant. Based on the current working directory ($PROJECT_DIR), summarize any key decisions, patterns learned, or things to remember from this session. Output as a concise markdown section with a date header. Keep it under 10 lines. If you can't determine meaningful session context, output exactly 'NO_CAPTURE'." 2>/dev/null || echo "NO_CAPTURE")

# Check if capture was meaningful
if [[ "$SUMMARY" == *"NO_CAPTURE"* ]] || [[ -z "$SUMMARY" ]]; then
    exit 0
fi

# Extract text from JSON output if needed
if echo "$SUMMARY" | jq -e '.result' &>/dev/null; then
    SUMMARY=$(echo "$SUMMARY" | jq -r '.result')
fi

# Append to session knowledge
{
    echo ""
    echo "## $(date '+%Y-%m-%d %H:%M') — $PROJECT_NAME"
    echo "$SUMMARY"
    echo ""
} >> "$SESSION_FILE"

# Prune entries older than 60 days
if [[ -f "$SESSION_FILE" ]]; then
    sixty_days_ago=$(date -v-60d +%Y-%m-%d 2>/dev/null || date -d '60 days ago' +%Y-%m-%d 2>/dev/null || echo "")
    if [[ -n "$sixty_days_ago" ]]; then
        # Keep only entries with dates >= 60 days ago
        tmpfile=$(mktemp)
        awk -v cutoff="$sixty_days_ago" '
            /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
                match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/, arr)
                if (arr[0] >= cutoff) { printing=1 } else { printing=0 }
            }
            printing || !/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ && !started { print }
            /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { started=1 }
        ' "$SESSION_FILE" > "$tmpfile"
        mv "$tmpfile" "$SESSION_FILE"
    fi
fi

exit 0
