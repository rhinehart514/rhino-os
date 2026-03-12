#!/usr/bin/env bash
# eval.sh — Tier 1 mechanical eval runner
# Runs belief checks against a project. No LLM calls.

set -euo pipefail

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

PROJECT_NAME=$(basename "$(pwd)")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

PASS=0
WARN=0
FAIL=0
SCORE_PENALTY=0

# --- Check functions ---

check_pass() {
    local name="$1"
    local desc="$2"
    echo "  [PASS] $name    $desc    PASS"
    PASS=$((PASS + 1))
}

check_warn() {
    local name="$1"
    local desc="$2"
    echo "  [WARN] $name    $desc    WARN"
    WARN=$((WARN + 1))
}

check_fail() {
    local name="$1"
    local desc="$2"
    local severity="${3:-warn}"
    local penalty="${4:-0}"
    if [[ "$severity" == "block" ]]; then
        echo "  [FAIL] $name    $desc    FAIL [block]"
    else
        echo "  [FAIL] $name    $desc    FAIL [warn]"
    fi
    FAIL=$((FAIL + 1))
    SCORE_PENALTY=$((SCORE_PENALTY + penalty))
}

echo "rhino eval — $PROJECT_NAME $TIMESTAMP"
echo ""

# === Default checks (always run) ===

# 1. Build check — project identity
if [[ -f "package.json" ]]; then
    check_pass "project-id" "package.json exists"
elif [[ -f "pyproject.toml" ]]; then
    check_pass "project-id" "pyproject.toml exists"
elif [[ -f "Cargo.toml" ]]; then
    check_pass "project-id" "Cargo.toml exists"
elif [[ -f "go.mod" ]]; then
    check_pass "project-id" "go.mod exists"
else
    check_warn "project-id" "no standard project file found"
fi

# 2. Hygiene — console.log count
if [[ -d "src" ]]; then
    CONSOLE_COUNT=$(grep -r 'console\.log' src/ 2>/dev/null | grep -v node_modules | grep -v '.test.' | grep -v '.spec.' | wc -l | tr -d ' ')
    if [[ "$CONSOLE_COUNT" -eq 0 ]]; then
        check_pass "no-console-log" "0 console.log in src/"
    elif [[ "$CONSOLE_COUNT" -le 5 ]]; then
        check_warn "console-log" "$CONSOLE_COUNT console.log found in src/"
    else
        check_fail "console-log" "$CONSOLE_COUNT console.log found in src/" "warn" 3
    fi

    # 3. Hygiene — TODO count
    TODO_COUNT=$(grep -r 'TODO\|FIXME\|HACK\|XXX' src/ 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
    if [[ "$TODO_COUNT" -eq 0 ]]; then
        check_pass "no-todos" "0 TODO/FIXME in src/"
    elif [[ "$TODO_COUNT" -le 5 ]]; then
        check_warn "todos" "$TODO_COUNT TODO/FIXME found in src/"
    else
        check_fail "todos" "$TODO_COUNT TODO/FIXME found in src/" "warn" 2
    fi

    # 4. Hygiene — any types (TypeScript)
    ANY_COUNT=$(grep -r ': any\b\|as any\b' src/ 2>/dev/null | grep -v node_modules | grep -v '.test.' | grep -v '.spec.' | grep -v '.d.ts' | wc -l | tr -d ' ')
    if [[ "$ANY_COUNT" -eq 0 ]]; then
        check_pass "no-any-types" "0 'any' types in src/"
    elif [[ "$ANY_COUNT" -le 3 ]]; then
        check_warn "any-types" "$ANY_COUNT 'any' types found in src/"
    else
        check_fail "any-types" "$ANY_COUNT 'any' types found in src/" "warn" 3
    fi
fi

# 5. Structure — file complexity
if [[ -d "src" ]]; then
    LONG_FILES=$(find src/ -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.rs' 2>/dev/null | while read -r f; do
        lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
        if [[ "$lines" -gt 500 ]]; then
            echo "$f ($lines lines)"
        fi
    done)
    if [[ -z "$LONG_FILES" ]]; then
        check_pass "file-size" "no files over 500 lines in src/"
    else
        FILE_COUNT=$(echo "$LONG_FILES" | wc -l | tr -d ' ')
        check_warn "file-size" "$FILE_COUNT files over 500 lines (complexity warning)"
    fi
fi

# === beliefs.yml checks ===

BELIEFS_FILE=".claude/evals/beliefs.yml"
if [[ -f "$BELIEFS_FILE" ]]; then
    # Parse content_check beliefs
    # Simple YAML parsing — look for type: content_check and their forbidden words
    in_content_check=false
    in_forbidden=false
    belief_id=""
    forbidden_words=()

    while IFS= read -r line; do
        # New belief entry
        if echo "$line" | grep -q '^\s*- id:'; then
            # Process previous belief if it was a content_check
            if [[ "$in_content_check" == "true" && ${#forbidden_words[@]} -gt 0 && -d "src" ]]; then
                found=0
                for word in "${forbidden_words[@]}"; do
                    count=$(grep -ri "$word" src/ 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
                    found=$((found + count))
                done
                if [[ "$found" -eq 0 ]]; then
                    check_pass "$belief_id" "0 forbidden words found"
                else
                    check_fail "$belief_id" "$found forbidden word occurrences" "warn" 2
                fi
            fi
            # Reset
            belief_id=$(echo "$line" | sed 's/.*id: *//')
            in_content_check=false
            in_forbidden=false
            forbidden_words=()
        fi

        # Check type
        if echo "$line" | grep -q '^\s*type: content_check'; then
            in_content_check=true
        fi

        # Parse forbidden list
        if echo "$line" | grep -q '^\s*forbidden:'; then
            in_forbidden=true
            # Check if inline array
            inline=$(echo "$line" | grep -o '\[.*\]' || true)
            if [[ -n "$inline" ]]; then
                # Parse inline array
                while IFS= read -r word; do
                    word=$(echo "$word" | tr -d '", []')
                    [[ -n "$word" ]] && forbidden_words+=("$word")
                done <<< "$(echo "$inline" | tr ',' '\n')"
                in_forbidden=false
            fi
            continue
        fi

        if [[ "$in_forbidden" == "true" ]]; then
            if echo "$line" | grep -q '^\s*-'; then
                word=$(echo "$line" | sed 's/^\s*- *//' | tr -d '"')
                [[ -n "$word" ]] && forbidden_words+=("$word")
            else
                in_forbidden=false
            fi
        fi

        # Check for route_graph type
        if echo "$line" | grep -q '^\s*type: route_graph'; then
            # Count route files for Next.js
            route_count=0
            if [[ -d "app" ]]; then
                route_count=$(find app/ -name 'page.tsx' -o -name 'page.ts' -o -name 'page.jsx' -o -name 'page.js' 2>/dev/null | wc -l | tr -d ' ')
                check_pass "$belief_id" "Next.js app/ routes: $route_count"
            elif [[ -d "pages" ]]; then
                route_count=$(find pages/ -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' 2>/dev/null | grep -v '_app\|_document\|_error\|api/' | wc -l | tr -d ' ')
                check_pass "$belief_id" "Next.js pages/ routes: $route_count"
            elif [[ -d "src/pages" ]]; then
                route_count=$(find src/pages/ -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' 2>/dev/null | grep -v '_app\|_document\|_error\|api/' | wc -l | tr -d ' ')
                check_pass "$belief_id" "Next.js src/pages/ routes: $route_count"
            else
                check_warn "$belief_id" "no Next.js route directories found"
            fi
        fi

        # Check for dom_check type — report what would be checked
        if echo "$line" | grep -q '^\s*type: dom_check'; then
            check_warn "$belief_id" "dom_check requires dev server (skipped)"
        fi

        # Check for playwright_task type
        if echo "$line" | grep -q '^\s*type: playwright_task'; then
            check_warn "$belief_id" "playwright_task requires dev server (skipped)"
        fi

    done < "$BELIEFS_FILE"

    # Process last belief if needed
    if [[ "$in_content_check" == "true" && ${#forbidden_words[@]} -gt 0 && -d "src" ]]; then
        found=0
        for word in "${forbidden_words[@]}"; do
            count=$(grep -ri "$word" src/ 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
            found=$((found + count))
        done
        if [[ "$found" -eq 0 ]]; then
            check_pass "$belief_id" "0 forbidden words found"
        else
            check_fail "$belief_id" "$found forbidden word occurrences" "warn" 2
        fi
    fi
fi

# === Summary ===
echo ""
echo "$PASS passed | $WARN warned | $FAIL failed"
if [[ "$SCORE_PENALTY" -gt 0 ]]; then
    echo "Score impact: -${SCORE_PENALTY} pts from failures"
fi

# Exit code
if [[ "$FAIL" -gt 0 ]]; then
    # Check if any were block severity — for now all are warn
    exit 0
fi
exit 0
