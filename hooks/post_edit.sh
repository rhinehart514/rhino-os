#!/usr/bin/env bash
# post_edit.sh — PostToolUse hook for Edit/Write
# Catches errors at write-time instead of commit-time.
# Inspired by ECC's per-edit enforcement philosophy:
# "LLMs forget instructions ~20% of the time, so PostToolUse hooks enforce at the tool level."
# Must be fast (<200ms). Never block — warnings only.

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Determine file extension
EXT="${FILE_PATH##*.}"
WARNINGS=""

# --- TypeScript / JavaScript checks ---
if [[ "$EXT" =~ ^(ts|tsx|js|jsx)$ ]]; then

    # console.log in non-test files
    if [[ "$FILE_PATH" != *test* && "$FILE_PATH" != *spec* && "$FILE_PATH" != *__test__* ]]; then
        console_count=$(grep -c 'console\.log' "$FILE_PATH" 2>/dev/null || echo "0")
        if (( console_count > 0 )); then
            WARNINGS+="${YELLOW}⚠${NC} ${console_count} console.log(s) in $(basename "$FILE_PATH") — remove before commit\n"
        fi
    fi

    # `: any` type annotations
    any_count=$(grep -c ': any' "$FILE_PATH" 2>/dev/null || echo "0")
    if (( any_count > 3 )); then
        WARNINGS+="${YELLOW}⚠${NC} ${any_count} \`: any\` types in $(basename "$FILE_PATH") — type these properly\n"
    fi

    # Inline typecheck (fast — only if tsconfig exists nearby)
    PROJECT_DIR="$(pwd)"
    if [[ -f "$PROJECT_DIR/tsconfig.json" ]] && command -v npx &>/dev/null; then
        # Only run on .ts/.tsx files, skip .js
        if [[ "$EXT" =~ ^(ts|tsx)$ ]]; then
            ts_errors=$(cd "$PROJECT_DIR" && perl -e 'alarm 10; exec @ARGV' npx --yes tsc --noEmit --pretty false 2>&1 | grep -c "^${FILE_PATH}" 2>/dev/null || echo "0")
            if (( ts_errors > 0 )); then
                WARNINGS+="${YELLOW}⚠${NC} ${ts_errors} TypeScript error(s) in $(basename "$FILE_PATH") — fix before continuing\n"
            fi
        fi
    fi
fi

# --- Python checks ---
if [[ "$EXT" == "py" ]]; then
    # print() in non-test files
    if [[ "$FILE_PATH" != *test* ]]; then
        print_count=$(grep -cE '^\s*print\(' "$FILE_PATH" 2>/dev/null || echo "0")
        if (( print_count > 2 )); then
            WARNINGS+="${YELLOW}⚠${NC} ${print_count} print() calls in $(basename "$FILE_PATH") — use logging instead\n"
        fi
    fi

    # Syntax check (fast)
    if command -v python3 &>/dev/null; then
        if ! PYFILE="$FILE_PATH" python3 -c "import ast, os; ast.parse(open(os.environ['PYFILE']).read())" 2>/dev/null; then
            WARNINGS+="${RED}●${NC} Python syntax error in $(basename "$FILE_PATH") — fix immediately\n"
        fi
    fi
fi

# --- Shell script checks ---
if [[ "$EXT" == "sh" || "$EXT" == "bash" ]]; then
    if ! bash -n "$FILE_PATH" 2>/dev/null; then
        WARNINGS+="${RED}●${NC} Shell syntax error in $(basename "$FILE_PATH") — fix immediately\n"
    fi
fi

# --- Universal checks ---
# Hardcoded secrets (basic patterns)
if grep -qE '(sk-[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36})' "$FILE_PATH" 2>/dev/null; then
    WARNINGS+="${RED}●${NC} Possible hardcoded secret in $(basename "$FILE_PATH") — remove immediately\n"
fi

# Output warnings (if any)
if [[ -n "$WARNINGS" ]]; then
    echo -e "$WARNINGS"
fi

exit 0
