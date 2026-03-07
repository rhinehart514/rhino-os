#!/usr/bin/env bash
# track_usage.sh — PostToolUse hook that logs tool invocations AND extracts edit patterns
# Appended to ~/.claude/logs/usage.jsonl
# Edit patterns logged to ~/.claude/logs/edit-patterns.jsonl for taste extraction
# Must be fast (<100ms) and never block tool execution

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Only log if we got a tool name
if [[ -z "$TOOL_NAME" ]]; then
    exit 0
fi

LOG_DIR="$HOME/.claude/logs"
KNOWLEDGE_DIR="$HOME/.claude/knowledge"
mkdir -p "$LOG_DIR" "$KNOWLEDGE_DIR"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Extract file path from tool input (works for Edit, Write, Read)
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

# Detect project from file path
PROJECT=""
if [[ -n "$FILE_PATH" ]]; then
    # Extract project name: first directory component under ~/
    PROJECT="$(echo "$FILE_PATH" | sed "s|^$HOME/||" | cut -d'/' -f1)"
fi

# Enhanced usage log with file path and project
echo "{\"ts\":\"$TS\",\"tool\":\"$TOOL_NAME\",\"project\":\"$PROJECT\",\"file\":\"$FILE_PATH\"}" >> "$LOG_DIR/usage.jsonl"

# --- Edit Pattern Extraction ---
# For Edit calls, analyze old_string → new_string for style patterns
if [[ "$TOOL_NAME" == "Edit" ]]; then
    OLD_STRING="$(echo "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)"
    NEW_STRING="$(echo "$INPUT" | jq -r '.tool_input.new_string // empty' 2>/dev/null)"

    if [[ -n "$OLD_STRING" && -n "$NEW_STRING" ]]; then
        PATTERNS=()

        # --- Naming convention detection ---
        # Check new_string for dominant naming style in identifiers
        if echo "$NEW_STRING" | grep -qE '[a-z][A-Z][a-z]'; then
            PATTERNS+=("naming_camel")
        fi
        if echo "$NEW_STRING" | grep -qE '[a-z]_[a-z]'; then
            PATTERNS+=("naming_snake")
        fi

        # --- Quote style ---
        SINGLE_QUOTES=$(echo "$NEW_STRING" | grep -o "'" | wc -l | tr -d ' ')
        DOUBLE_QUOTES=$(echo "$NEW_STRING" | grep -o '"' | wc -l | tr -d ' ')
        BACKTICK_QUOTES=$(echo "$NEW_STRING" | grep -o '`' | wc -l | tr -d ' ')
        if (( SINGLE_QUOTES > DOUBLE_QUOTES && SINGLE_QUOTES > 0 )); then
            PATTERNS+=("quotes_single")
        elif (( DOUBLE_QUOTES > SINGLE_QUOTES && DOUBLE_QUOTES > 0 )); then
            PATTERNS+=("quotes_double")
        fi
        if (( BACKTICK_QUOTES > 0 )); then
            PATTERNS+=("quotes_template_literal")
        fi

        # --- Semicolons ---
        OLD_SEMIS=$(echo "$OLD_STRING" | grep -c ';$' || true)
        NEW_SEMIS=$(echo "$NEW_STRING" | grep -c ';$' || true)
        if (( NEW_SEMIS > OLD_SEMIS )); then
            PATTERNS+=("semicolons_added")
        elif (( OLD_SEMIS > NEW_SEMIS )); then
            PATTERNS+=("semicolons_removed")
        fi

        # --- Comment changes ---
        OLD_COMMENTS=$(echo "$OLD_STRING" | grep -cE '^\s*(//|#|/\*|\*)' || true)
        NEW_COMMENTS=$(echo "$NEW_STRING" | grep -cE '^\s*(//|#|/\*|\*)' || true)
        if (( NEW_COMMENTS > OLD_COMMENTS )); then
            PATTERNS+=("comments_added")
        elif (( OLD_COMMENTS > NEW_COMMENTS )); then
            PATTERNS+=("comments_removed")
        fi

        # --- Variable declaration style ---
        if echo "$NEW_STRING" | grep -qE '\bconst\b'; then
            PATTERNS+=("decl_const")
        fi
        if echo "$NEW_STRING" | grep -qE '\blet\b'; then
            PATTERNS+=("decl_let")
        fi
        if echo "$NEW_STRING" | grep -qE '\bvar\b'; then
            PATTERNS+=("decl_var")
        fi

        # --- Function style ---
        if echo "$NEW_STRING" | grep -qE '=>'; then
            PATTERNS+=("fn_arrow")
        fi
        if echo "$NEW_STRING" | grep -qE '\bfunction\b'; then
            PATTERNS+=("fn_keyword")
        fi

        # --- Error handling style ---
        if echo "$NEW_STRING" | grep -qE '\btry\s*\{'; then
            PATTERNS+=("error_try_catch")
        fi
        if echo "$NEW_STRING" | grep -qE '\bif\s*\(\s*!'; then
            PATTERNS+=("error_early_return")
        fi
        if echo "$NEW_STRING" | grep -qE '\.catch\('; then
            PATTERNS+=("error_promise_catch")
        fi

        # --- Import style ---
        if echo "$NEW_STRING" | grep -qE '^import\b'; then
            PATTERNS+=("import_esm")
        fi
        if echo "$NEW_STRING" | grep -qE '\brequire\('; then
            PATTERNS+=("import_cjs")
        fi

        # --- Deletion detection (old is longer than new = removing code) ---
        OLD_LINES=$(echo "$OLD_STRING" | wc -l | tr -d ' ')
        NEW_LINES=$(echo "$NEW_STRING" | wc -l | tr -d ' ')
        if (( OLD_LINES > NEW_LINES + 3 )); then
            PATTERNS+=("code_deletion")
        fi
        if (( NEW_LINES > OLD_LINES + 5 )); then
            PATTERNS+=("code_expansion")
        fi

        # --- Whitespace/formatting preferences ---
        if echo "$NEW_STRING" | grep -qE '^\t'; then
            PATTERNS+=("indent_tabs")
        fi
        if echo "$NEW_STRING" | grep -qE '^  [^ ]'; then
            PATTERNS+=("indent_2space")
        fi
        if echo "$NEW_STRING" | grep -qE '^    [^ ]'; then
            PATTERNS+=("indent_4space")
        fi

        # Log patterns if any detected
        if [[ ${#PATTERNS[@]} -gt 0 ]]; then
            PATTERN_JSON=$(printf '%s\n' "${PATTERNS[@]}" | jq -R . | jq -s .)
            # Get file extension for language context
            EXT="${FILE_PATH##*.}"
            echo "{\"ts\":\"$TS\",\"project\":\"$PROJECT\",\"file\":\"$FILE_PATH\",\"ext\":\"$EXT\",\"patterns\":$PATTERN_JSON}" >> "$LOG_DIR/edit-patterns.jsonl"
        fi
    fi
fi

# --- Write tool: track what gets created ---
if [[ "$TOOL_NAME" == "Write" && -n "$FILE_PATH" ]]; then
    EXT="${FILE_PATH##*.}"
    echo "{\"ts\":\"$TS\",\"project\":\"$PROJECT\",\"file\":\"$FILE_PATH\",\"ext\":\"$EXT\",\"patterns\":[\"file_created\"]}" >> "$LOG_DIR/edit-patterns.jsonl"
fi

exit 0
