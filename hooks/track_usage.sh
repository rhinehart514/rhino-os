#!/usr/bin/env bash
# track_usage.sh — PostToolUse hook
# Logs tool invocations to usage.jsonl with project context.
# Extracts CODE STYLE patterns (not taste) to code-style.jsonl.
# Taste is macro judgment — what to build, kill, prioritize.
# Code style is formatting — camelCase, semicolons, indentation.
# Must be fast (<50ms). Never block tool execution.

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

[[ -z "$TOOL_NAME" ]] && exit 0

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Extract file path from tool input
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

# Detect project from file path
PROJECT=""
if [[ -n "$FILE_PATH" ]]; then
    PROJECT="$(echo "$FILE_PATH" | sed "s|^$HOME/||" | cut -d'/' -f1)"
fi

# Log usage (always)
echo "{\"ts\":\"$TS\",\"tool\":\"$TOOL_NAME\",\"project\":\"$PROJECT\",\"file\":\"$FILE_PATH\"}" >> "$LOG_DIR/usage.jsonl"

# --- Code Style Extraction (Edit calls only) ---
# These are FORMATTING preferences, not taste.
# Taste comes from decisions (accept/reject/kill/build) captured by agents.
if [[ "$TOOL_NAME" == "Edit" && -n "$FILE_PATH" ]]; then
    NEW_STRING="$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)"

    if [[ -n "$NEW_STRING" ]]; then
        STYLE_FILE="$LOG_DIR/code-style.jsonl"

        # Prune: keep only last 7 days (check once per 100 entries)
        if [[ -f "$STYLE_FILE" ]]; then
            LINE_COUNT=$(wc -l < "$STYLE_FILE" | tr -d ' ')
            if (( LINE_COUNT > 500 )); then
                WEEK_AGO="$(date -u -v-7d +%Y-%m-%dT 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT 2>/dev/null || echo "")"
                if [[ -n "$WEEK_AGO" ]]; then
                    grep "\"ts\":\"$WEEK_AGO" "$STYLE_FILE" > "$STYLE_FILE.tmp" 2>/dev/null || true
                    # Keep lines from this week
                    awk -v cutoff="$WEEK_AGO" '/"ts":"/ { if (index($0, cutoff) > 0 || $0 > cutoff) print }' "$STYLE_FILE" > "$STYLE_FILE.tmp" 2>/dev/null
                    mv "$STYLE_FILE.tmp" "$STYLE_FILE" 2>/dev/null || true
                fi
            fi
        fi

        # Lightweight detection — max 5 checks, no grep on full string
        PATTERNS=""
        SAMPLE="${NEW_STRING:0:2000}"  # Only check first 2000 chars

        # Naming (one check)
        if [[ "$SAMPLE" =~ [a-z][A-Z][a-z] ]]; then
            PATTERNS="${PATTERNS:+$PATTERNS,}\"camel\""
        elif [[ "$SAMPLE" =~ [a-z]_[a-z] ]]; then
            PATTERNS="${PATTERNS:+$PATTERNS,}\"snake\""
        fi

        # Semicolons
        if [[ "$SAMPLE" =~ \;$ ]]; then
            PATTERNS="${PATTERNS:+$PATTERNS,}\"semi\""
        fi

        # Arrow vs function
        if [[ "$SAMPLE" =~ =\> ]]; then
            PATTERNS="${PATTERNS:+$PATTERNS,}\"arrow\""
        fi

        # ESM vs CJS
        if [[ "$SAMPLE" =~ ^import\  ]]; then
            PATTERNS="${PATTERNS:+$PATTERNS,}\"esm\""
        fi

        if [[ -n "$PATTERNS" ]]; then
            EXT="${FILE_PATH##*.}"
            echo "{\"ts\":\"$TS\",\"project\":\"$PROJECT\",\"ext\":\"$EXT\",\"s\":[$PATTERNS]}" >> "$STYLE_FILE"
        fi
    fi
fi

exit 0
