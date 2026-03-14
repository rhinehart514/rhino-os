#!/usr/bin/env bash
# eval.sh — Generative eval runner
# Primary: reads features from rhino.yml, Claude judges gap between claim and code.
# Fallback: beliefs.yml mechanical checks (supplementary).

set -euo pipefail

# --- Recursion guard ---
RHINO_EVAL_DEPTH="${RHINO_EVAL_DEPTH:-0}"
if [[ "$RHINO_EVAL_DEPTH" -ge 2 ]]; then
    echo ""  # safe fallback — empty = no assertions
    exit 0
fi
export RHINO_EVAL_DEPTH=$((RHINO_EVAL_DEPTH + 1))

# --- Parse args ---
SCORE_MODE=false
BY_FEATURE=false
JSON_OUTPUT=false
FRESH_MODE=false
FEATURE_FILTER=""
POSITIONAL=""
for arg in "$@"; do
    case "$arg" in
        --score) SCORE_MODE=true ;;
        --by-feature) BY_FEATURE=true ;;
        --json) JSON_OUTPUT=true ;;
        --fresh) FRESH_MODE=true ;;
        --feature=*) FEATURE_FILTER="${arg#--feature=}" ;;
        --feature) ;; # next arg is the feature name, handled below
        *)
            if [[ "${prev_arg:-}" == "--feature" ]]; then
                FEATURE_FILTER="$arg"
            else
                POSITIONAL="$arg"
            fi
            ;;
    esac
    prev_arg="$arg"
done

PROJECT_ROOT="${POSITIONAL:-.}"
cd "$PROJECT_ROOT"

PROJECT_NAME=$(basename "$(pwd)")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

PASS=0
WARN=0
FAIL=0
SCORE_PENALTY=0

# Per-feature tracking (feature_name:pass:warn:fail accumulated as lines)
FEATURE_RESULTS=""

# Generative eval numeric scores (feature_name:score accumulated as lines)
# These contribute directly to the final score as numbers, not pass/warn/fail buckets.
GENERATIVE_SCORES=""
GENERATIVE_COUNT=0
GENERATIVE_SUM=0

# --- Check functions ---

check_pass() {
    local name="$1"
    local desc="$2"
    [[ "$SCORE_MODE" != "true" ]] && echo "  [PASS] $name    $desc    PASS"
    PASS=$((PASS + 1))
}

check_warn() {
    local name="$1"
    local desc="$2"
    [[ "$SCORE_MODE" != "true" ]] && echo "  [WARN] $name    $desc    WARN"
    WARN=$((WARN + 1))
}

check_fail() {
    local name="$1"
    local desc="$2"
    local severity="${3:-warn}"
    local penalty="${4:-0}"
    if [[ "$SCORE_MODE" != "true" ]]; then
        if [[ "$severity" == "block" ]]; then
            echo "  [FAIL] $name    $desc    FAIL [block]"
        else
            echo "  [FAIL] $name    $desc    FAIL [warn]"
        fi
    fi
    FAIL=$((FAIL + 1))
    SCORE_PENALTY=$((SCORE_PENALTY + penalty))
}

# Early feature detection for header logic
HAS_FEATURES=false
if [[ -f "config/rhino.yml" ]] && grep -q '^features:' "config/rhino.yml" 2>/dev/null; then
    HAS_FEATURES=true
fi

# Print header if generative eval didn't already
if [[ "$SCORE_MODE" != "true" && "$HAS_FEATURES" != true ]]; then
    echo "rhino eval — $PROJECT_NAME $TIMESTAMP"
    echo ""
fi

# Detect source directories (needed by both default checks and beliefs.yml)
SRC_DIRS=""
for d in src app pages source; do
    [[ -d "$d" ]] && SRC_DIRS="$SRC_DIRS $d"
done

# === Default checks (skip in --score mode — score only counts beliefs.yml assertions) ===
if [[ "$SCORE_MODE" != "true" ]]; then

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

if [[ -n "$SRC_DIRS" ]]; then
    # 2. Hygiene — console.log count
    CONSOLE_COUNT=$(grep -r 'console\.log' $SRC_DIRS 2>/dev/null | grep -v node_modules | grep -v '.test.' | grep -v '.spec.' | wc -l | tr -d ' ' || true)
    if [[ "$CONSOLE_COUNT" -eq 0 ]]; then
        check_pass "no-console-log" "0 console.log in source dirs"
    elif [[ "$CONSOLE_COUNT" -le 5 ]]; then
        check_warn "console-log" "$CONSOLE_COUNT console.log found"
    else
        check_fail "console-log" "$CONSOLE_COUNT console.log found" "warn" 3
    fi

    # 3. Hygiene — TODO count
    TODO_COUNT=$(grep -r 'TODO\|FIXME\|HACK\|XXX' $SRC_DIRS 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ' || true)
    if [[ "$TODO_COUNT" -eq 0 ]]; then
        check_pass "no-todos" "0 TODO/FIXME in source dirs"
    elif [[ "$TODO_COUNT" -le 5 ]]; then
        check_warn "todos" "$TODO_COUNT TODO/FIXME found"
    else
        check_fail "todos" "$TODO_COUNT TODO/FIXME found" "warn" 2
    fi

    # 4. Hygiene — any types (TypeScript)
    ANY_COUNT=$(grep -r ': any\b\|as any\b' $SRC_DIRS 2>/dev/null | grep -v node_modules | grep -v '.test.' | grep -v '.spec.' | grep -v '.d.ts' | wc -l | tr -d ' ' || true)
    if [[ "$ANY_COUNT" -eq 0 ]]; then
        check_pass "no-any-types" "0 'any' types in source dirs"
    elif [[ "$ANY_COUNT" -le 3 ]]; then
        check_warn "any-types" "$ANY_COUNT 'any' types found"
    else
        check_fail "any-types" "$ANY_COUNT 'any' types found" "warn" 3
    fi

    # 5. Structure — file complexity
    LONG_FILES=$(find $SRC_DIRS -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.py' -o -name '*.rs' 2>/dev/null | while read -r f; do
        lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
        if [[ "$lines" -gt 500 ]]; then
            echo "$f ($lines lines)"
        fi
    done)
    if [[ -z "$LONG_FILES" ]]; then
        check_pass "file-size" "no files over 500 lines"
    else
        FILE_COUNT=$(echo "$LONG_FILES" | wc -l | tr -d ' ')
        check_warn "file-size" "$FILE_COUNT files over 500 lines (complexity warning)"
    fi
fi

fi  # end SCORE_MODE != true (default checks)

# === Infrastructure checks (rhino-os only) ===
# These check host state (symlinks, hooks, knowledge model) which only
# makes sense when running inside the rhino-os repo itself.
# Sentinel: mind/identity.md exists only in rhino-os.

if [[ "$SCORE_MODE" != "true" && -f "mind/identity.md" ]]; then

# value-hypothesis-exists
if [[ -f "config/rhino.yml" ]] && grep -q '^value:' "config/rhino.yml" 2>/dev/null; then
    check_pass "value-hypothesis-exists" "rhino.yml has value: section"
else
    check_fail "value-hypothesis-exists" "rhino.yml missing value: section" "block" 5
fi

# knowledge-model-exists
LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]] && [[ -s "$LEARNINGS" ]]; then
    check_pass "knowledge-model-exists" "experiment-learnings.md exists with content"
else
    check_fail "knowledge-model-exists" "experiment-learnings.md missing or empty" "block" 5
fi

# no-dead-skills
SKILLS_MISSING_RECOVERY=0
for skill in .claude/commands/*.md; do
    [[ ! -f "$skill" ]] && continue
    if ! grep -q 'If something breaks' "$skill" 2>/dev/null; then
        SKILLS_MISSING_RECOVERY=$((SKILLS_MISSING_RECOVERY + 1))
    fi
done
if [[ "$SKILLS_MISSING_RECOVERY" -eq 0 ]]; then
    check_pass "no-dead-skills" "all skills have recovery blocks"
else
    check_fail "no-dead-skills" "$SKILLS_MISSING_RECOVERY skill(s) missing 'If something breaks'" "warn" 2
fi

# hooks-resolve
HOOKS_BROKEN=0
for hook in "$HOME/.claude/hooks/"*.sh; do
    [[ ! -L "$hook" ]] && continue
    target=$(readlink "$hook" 2>/dev/null)
    if [[ ! -f "$target" ]]; then
        HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
    fi
done
if [[ "$HOOKS_BROKEN" -eq 0 ]]; then
    check_pass "hooks-resolve" "all hook symlinks resolve"
else
    check_fail "hooks-resolve" "$HOOKS_BROKEN broken hook symlink(s)" "warn" 3
fi

# mind-files-loaded
MIND_MISSING=0
for mf in identity.md thinking.md standards.md self.md; do
    if [[ ! -L "$HOME/.claude/rules/$mf" ]] || [[ ! -f "$HOME/.claude/rules/$mf" ]]; then
        MIND_MISSING=$((MIND_MISSING + 1))
    fi
done
if [[ "$MIND_MISSING" -eq 0 ]]; then
    check_pass "mind-files-loaded" "all mind files symlinked in ~/.claude/rules/"
else
    check_fail "mind-files-loaded" "$MIND_MISSING mind file(s) not in ~/.claude/rules/" "block" 5
fi

fi  # end SCORE_MODE != true

# === URL detection for DOM/copy/playwright checks ===
# Skip port scanning in --score mode (not needed for score computation)

EVAL_URL="${EVAL_URL:-}"
if [[ -z "$EVAL_URL" && "$SCORE_MODE" != "true" ]]; then
    for port in 3000 3001 5173 8080 4321 4000; do
        if curl -s --connect-timeout 1 -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -qE "^(200|301|302|304)"; then
            EVAL_URL="http://localhost:$port"
            break
        fi
    done
fi

# Resolve RHINO_DIR for eval tools
_EVAL_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_EVAL_SOURCE" ]]; do
    _EVAL_SOURCE="$(readlink "$_EVAL_SOURCE")"
done
RHINO_DIR="$(cd "$(dirname "$_EVAL_SOURCE")/.." && pwd)"

# Cached eval results (lazy-loaded)
DOM_RESULTS=""
DOM_RAN=false
COPY_RESULTS=""
COPY_RAN=false
SELF_RESULTS=""
SELF_RAN=false

run_dom_eval() {
    if [[ "$DOM_RAN" != "true" ]]; then
        DOM_RAN=true
        if [[ -n "$EVAL_URL" ]]; then
            local dom_script="$RHINO_DIR/lens/product/eval/dom-eval.mjs"
            [[ ! -f "$dom_script" ]] && dom_script="$RHINO_DIR/bin/dom-eval.mjs"
            if [[ -f "$dom_script" ]]; then
                DOM_RESULTS=$(node "$dom_script" --url "$EVAL_URL" --eval 2>/dev/null) || DOM_RESULTS=""
            fi
        fi
    fi
}

run_copy_eval() {
    if [[ "$COPY_RAN" != "true" ]]; then
        COPY_RAN=true
        if [[ -n "$EVAL_URL" ]]; then
            local copy_script="$RHINO_DIR/lens/product/eval/copy-eval.mjs"
            [[ ! -f "$copy_script" ]] && copy_script="$RHINO_DIR/bin/copy-eval.mjs"
            if [[ -f "$copy_script" ]]; then
                COPY_RESULTS=$(node "$copy_script" --url "$EVAL_URL" --eval 2>/dev/null) || COPY_RESULTS=""
            fi
        fi
    fi
}

run_self_eval() {
    if [[ "$SELF_RAN" != "true" ]]; then
        SELF_RAN=true
        SELF_RESULTS=$(bash "$RHINO_DIR/bin/self.sh" --eval 2>/dev/null) || true
    fi
}

# ============================================================
# GENERATIVE EVAL — features from rhino.yml
# ============================================================

EVAL_CACHE_DIR=".claude/cache"
EVAL_CACHE_FILE="$EVAL_CACHE_DIR/eval-cache.json"

# Read features from rhino.yml using simple YAML parsing
# Outputs lines: feature_name|delivers|for|code_path1,code_path2
parse_features() {
    local config_file="config/rhino.yml"
    [[ ! -f "$config_file" ]] && return

    local in_features=false
    local current_feat="" current_delivers="" current_for="" current_code=""
    local in_code=false

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Detect features: section
        if echo "$line" | grep -q '^features:'; then
            in_features=true
            continue
        fi

        # Detect end of features section (new top-level key)
        if [[ "$in_features" == true ]] && echo "$line" | grep -qE '^[a-z]'; then
            # Emit last feature
            if [[ -n "$current_feat" ]]; then
                echo "${current_feat}|${current_delivers}|${current_for}|${current_code}"
                current_feat=""
            fi
            in_features=false
            continue
        fi

        [[ "$in_features" != true ]] && continue

        # New feature (2-space indent, key with colon, no value)
        if echo "$line" | grep -qE '^  [a-z][a-z0-9_-]*:$'; then
            # Emit previous feature
            if [[ -n "$current_feat" ]]; then
                echo "${current_feat}|${current_delivers}|${current_for}|${current_code}"
            fi
            current_feat=$(echo "$line" | sed 's/^[[:space:]]*//;s/:[[:space:]]*$//')
            current_delivers=""
            current_for=""
            current_code=""
            in_code=false
            continue
        fi

        # delivers:
        if echo "$line" | grep -q '^\s*delivers:'; then
            current_delivers=$(echo "$line" | sed 's/.*delivers: *//;s/^"//;s/"$//')
            in_code=false
            continue
        fi

        # for:
        if echo "$line" | grep -q '^\s*for:'; then
            current_for=$(echo "$line" | sed 's/.*for: *//;s/^"//;s/"$//')
            in_code=false
            continue
        fi

        # code: (inline array)
        if echo "$line" | grep -q '^\s*code:'; then
            in_code=true
            # Parse inline array: ["a", "b"]
            local inline
            inline=$(echo "$line" | grep -o '\[.*\]' || true)
            if [[ -n "$inline" ]]; then
                current_code=$(echo "$inline" | tr -d '[]"' | sed 's/, */,/g')
                in_code=false
            fi
            continue
        fi

        # code array items
        if [[ "$in_code" == true ]]; then
            if echo "$line" | grep -q '^\s*-'; then
                local item
                item=$(echo "$line" | sed 's/^[[:space:]]*- *//;s/^"//;s/"$//')
                if [[ -n "$current_code" ]]; then
                    current_code="${current_code},${item}"
                else
                    current_code="$item"
                fi
            else
                in_code=false
            fi
        fi
    done < "$config_file"

    # Emit last feature
    if [[ -n "$current_feat" ]]; then
        echo "${current_feat}|${current_delivers}|${current_for}|${current_code}"
    fi
}

# Gather code content for a feature's code paths
gather_code_context() {
    local code_paths="$1"
    local context=""
    local OLD_IFS="$IFS"
    IFS=','
    for path in $code_paths; do
        IFS="$OLD_IFS"
        # Expand ~ to $HOME
        local expanded="${path/#\~/$HOME}"
        if [[ -f "$expanded" ]]; then
            context+="=== $path ===
$(head -200 "$expanded" 2>/dev/null)

"
        elif [[ -d "$expanded" ]]; then
            context+=$(find "$expanded" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.mjs" -o -name "*.yml" -o -name "*.md" \) ! -path "*/node_modules/*" 2>/dev/null | head -8 | while read -r f; do
                echo "=== $f ==="
                head -80 "$f" 2>/dev/null
                echo ""
            done)
            context+="
"
        fi
    done
    IFS="$OLD_IFS"
    echo "$context"
}

# Check eval cache for a feature
# Returns cached verdict if fresh, empty string if stale/missing
check_eval_cache() {
    local feat_name="$1"
    if [[ "$FRESH_MODE" == true ]]; then
        echo ""
        return
    fi
    if [[ -f "$EVAL_CACHE_FILE" ]] && command -v jq &>/dev/null; then
        local cached_at
        cached_at=$(jq -r ".\"$feat_name\".cached_at // empty" "$EVAL_CACHE_FILE" 2>/dev/null)
        if [[ -n "$cached_at" ]]; then
            # Check if code files have changed since cache
            local cache_mtime
            cache_mtime=$(stat -f %m "$EVAL_CACHE_FILE" 2>/dev/null || stat -c %Y "$EVAL_CACHE_FILE" 2>/dev/null || echo 0)
            local now
            now=$(date +%s)
            local age=$(( now - cache_mtime ))
            # Cache valid for same session (1 hour)
            if [[ "$age" -lt 3600 ]]; then
                jq -c ".\"$feat_name\"" "$EVAL_CACHE_FILE" 2>/dev/null
                return
            fi
        fi
    fi
    echo ""
}

# Call Claude to judge a feature
judge_feature() {
    local feat_name="$1"
    local delivers="$2"
    local for_whom="$3"
    local code_context="$4"

    local prompt="This feature claims to deliver: \"${delivers}\"
For: \"${for_whom}\"

Here is the code:
${code_context}

Questions:
1. Does the code actually deliver what it claims? (DELIVERS / PARTIAL / MISSING)
2. What specific gaps exist between the claim and the code?
3. If a \"${for_whom}\" person used this right now, what would break or disappoint them?

Respond as JSON only, no markdown fences:
{\"verdict\": \"DELIVERS\" or \"PARTIAL\" or \"MISSING\", \"gaps\": [\"gap 1\", \"gap 2\"], \"evidence\": \"specific code references\", \"score\": 0-100}"

    local api_key="${ANTHROPIC_API_KEY:-}"
    local result=""

    if [[ -z "$api_key" ]]; then
        # Try claude CLI
        local tmp_file
        tmp_file=$(mktemp)
        echo "$prompt" > "$tmp_file"
        result=$(claude -p "$(cat "$tmp_file")" --model haiku 2>/dev/null </dev/null) || result=""
        rm -f "$tmp_file"
    else
        # Direct API call
        local payload
        payload=$(jq -n \
            --arg prompt "$prompt" \
            '{model:"claude-haiku-4-5-20251001",max_tokens:500,messages:[{role:"user",content:$prompt}]}')
        local response
        response=$(curl -s "https://api.anthropic.com/v1/messages" \
            -H "x-api-key: $api_key" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "$payload" 2>/dev/null)
        result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
    fi

    # Parse the JSON response
    if [[ -n "$result" ]]; then
        # Extract JSON from response (might have surrounding text)
        local json_part
        json_part=$(echo "$result" | grep -o '{[^}]*}' | head -1)
        if [[ -n "$json_part" ]] && echo "$json_part" | jq . &>/dev/null; then
            echo "$json_part"
            return
        fi
    fi

    # Fallback: couldn't parse
    echo '{"verdict":"PARTIAL","gaps":["could not evaluate"],"evidence":"eval failed","score":50}'
}

# Run generative eval for all features (or filtered)
run_generative_eval() {
    local features_data
    features_data=$(parse_features)

    [[ -z "$features_data" ]] && return

    mkdir -p "$EVAL_CACHE_DIR"

    # Build cache JSON incrementally
    local cache_json="{"
    local cache_first=true

    while IFS='|' read -r feat_name delivers for_whom code_paths; do
        [[ -z "$feat_name" ]] && continue

        # Feature filter
        if [[ -n "$FEATURE_FILTER" && "$feat_name" != "$FEATURE_FILTER" ]]; then
            continue
        fi

        # Check cache first
        local cached
        cached=$(check_eval_cache "$feat_name")

        local verdict="" gaps="" evidence="" feat_score=""

        if [[ -n "$cached" && "$cached" != "" ]]; then
            verdict=$(echo "$cached" | jq -r '.verdict // "PARTIAL"' 2>/dev/null)
            gaps=$(echo "$cached" | jq -r '.gaps // [] | join("; ")' 2>/dev/null)
            evidence=$(echo "$cached" | jq -r '.evidence // ""' 2>/dev/null)
            feat_score=$(echo "$cached" | jq -r '.score // 50' 2>/dev/null)
        else
            # Gather code and call Claude
            local code_context
            code_context=$(gather_code_context "$code_paths")

            if [[ -n "$code_context" ]]; then
                local judge_result
                judge_result=$(judge_feature "$feat_name" "$delivers" "$for_whom" "$code_context")
                verdict=$(echo "$judge_result" | jq -r '.verdict // "PARTIAL"' 2>/dev/null)
                gaps=$(echo "$judge_result" | jq -r '.gaps // [] | join("; ")' 2>/dev/null)
                evidence=$(echo "$judge_result" | jq -r '.evidence // ""' 2>/dev/null)
                feat_score=$(echo "$judge_result" | jq -r '.score // 50' 2>/dev/null)
            else
                verdict="MISSING"
                gaps="no code files found"
                evidence=""
                feat_score=0
            fi
        fi

        # Track as numeric score (not pass/warn/fail buckets)
        [[ -z "$feat_score" || "$feat_score" == "null" ]] && feat_score=50
        GENERATIVE_SCORES="${GENERATIVE_SCORES}${feat_name}:${feat_score}
"
        GENERATIVE_COUNT=$((GENERATIVE_COUNT + 1))
        GENERATIVE_SUM=$((GENERATIVE_SUM + feat_score))

        # Display output (non-score mode only)
        if [[ "$SCORE_MODE" != "true" ]]; then
            if [[ "$feat_score" -ge 80 ]]; then
                echo "  [${feat_score}] $feat_name    delivers: $delivers"
            elif [[ "$feat_score" -ge 40 ]]; then
                echo "  [${feat_score}] $feat_name    partial: $gaps"
            else
                echo "  [${feat_score}] $feat_name    missing: $gaps"
            fi
        fi

        # Build cache entry
        $cache_first || cache_json+=","
        cache_json+="\"$feat_name\":{\"verdict\":\"$verdict\",\"gaps\":$(echo "[\"${gaps//; /\",\"}\"]" | sed 's/\[""]/[]/'),\"evidence\":$(echo "$evidence" | jq -Rs .),\"score\":${feat_score:-50},\"cached_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
        cache_first=false
    done <<< "$features_data"

    cache_json+="}"

    # Write cache
    echo "$cache_json" > "$EVAL_CACHE_FILE" 2>/dev/null || true
}

# === Run generative eval ===
# HAS_FEATURES already detected earlier (before header)
# ONLY run on explicit eval calls (not --score mode).
# Score mode uses cached results if available, skips otherwise.
# This keeps `rhino score .` fast and free (no LLM calls).
if [[ "$HAS_FEATURES" == true && "$SCORE_MODE" != "true" ]]; then
    echo "  generative eval (Claude judges feature claims)"
    echo ""
    run_generative_eval
    echo ""
elif [[ "$HAS_FEATURES" == true && "$SCORE_MODE" == "true" ]]; then
    # In --score mode: read cached generative scores as numbers, don't call Claude
    if [[ -f "$EVAL_CACHE_FILE" ]] && command -v jq &>/dev/null; then
        while IFS= read -r feat_name; do
            [[ -z "$feat_name" ]] && continue
            # Feature filter
            if [[ -n "$FEATURE_FILTER" && "$feat_name" != "$FEATURE_FILTER" ]]; then
                continue
            fi
            feat_score=$(jq -r ".\"$feat_name\".score // empty" "$EVAL_CACHE_FILE" 2>/dev/null)
            if [[ -n "$feat_score" && "$feat_score" =~ ^[0-9]+$ ]]; then
                GENERATIVE_SCORES="${GENERATIVE_SCORES}${feat_name}:${feat_score}
"
                GENERATIVE_COUNT=$((GENERATIVE_COUNT + 1))
                GENERATIVE_SUM=$((GENERATIVE_SUM + feat_score))
            fi
        done < <(jq -r 'keys[]' "$EVAL_CACHE_FILE" 2>/dev/null)
    fi
    # If no cache exists, generative features simply don't contribute to score.
    # Run `rhino eval .` first to populate the cache.
fi

# Process a belief based on its type
process_belief() {
    [[ -z "$belief_id" ]] && return

    # Feature filter: skip beliefs that don't match
    if [[ -n "$FEATURE_FILTER" && "$belief_feature" != "$FEATURE_FILTER" ]]; then
        return
    fi

    # Track pre-counts to detect what this belief contributed
    local _pre_pass=$PASS _pre_warn=$WARN _pre_fail=$FAIL

    case "$belief_type" in
        file_check)
            # Machine-evaluable file assertions from beliefs.yml
            if [[ -n "$belief_path" ]]; then
                # Expand ~ to $HOME
                local expanded_path="${belief_path/#\~/$HOME}"
                if [[ "$belief_exists" == "false" ]]; then
                    # File should NOT exist
                    if [[ ! -e "$expanded_path" ]]; then
                        check_pass "$belief_id" "$belief_path does not exist"
                    else
                        check_fail "$belief_id" "$belief_path exists but shouldn't" "warn" 2
                    fi
                elif [[ ! -e "$expanded_path" ]]; then
                    # File should exist but doesn't
                    check_fail "$belief_id" "$belief_path not found" "warn" 2
                else
                    # File exists — check contents if specified
                    local file_ok=true
                    local detail="$belief_path exists"
                    if [[ -n "$belief_contains" ]]; then
                        if grep -q "$belief_contains" "$expanded_path" 2>/dev/null; then
                            detail="$belief_path contains '$belief_contains'"
                        else
                            file_ok=false
                            detail="$belief_path missing '$belief_contains'"
                        fi
                    fi
                    if [[ -n "$belief_not_contains" ]]; then
                        if grep -q "$belief_not_contains" "$expanded_path" 2>/dev/null; then
                            file_ok=false
                            detail="$belief_path contains '$belief_not_contains' (forbidden)"
                        fi
                    fi
                    if [[ -n "$belief_min_lines" ]]; then
                        local lines
                        lines=$(wc -l < "$expanded_path" 2>/dev/null | tr -d ' ')
                        if [[ "$lines" -lt "$belief_min_lines" ]]; then
                            file_ok=false
                            detail="$belief_path has $lines lines (need $belief_min_lines)"
                        fi
                    fi
                    if $file_ok; then
                        check_pass "$belief_id" "$detail"
                    else
                        check_fail "$belief_id" "$detail" "warn" 2
                    fi
                fi
            fi
            ;;
        content_check)
            if [[ ${#forbidden_words[@]} -gt 0 && -n "$SRC_DIRS" ]]; then
                local found=0
                for word in "${forbidden_words[@]}"; do
                    local count=$(grep -ri "$word" $SRC_DIRS 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
                    found=$((found + count))
                done
                if [[ "$found" -eq 0 ]]; then
                    check_pass "$belief_id" "0 forbidden words found"
                else
                    check_fail "$belief_id" "$found forbidden word occurrences" "warn" 2
                fi
            fi
            ;;
        route_graph)
            if [[ -d "app" ]]; then
                local route_count=$(find app/ -name 'page.tsx' -o -name 'page.ts' -o -name 'page.jsx' -o -name 'page.js' 2>/dev/null | wc -l | tr -d ' ')
                check_pass "$belief_id" "Next.js app/ routes: $route_count"
            elif [[ -d "pages" ]]; then
                local route_count=$(find pages/ -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' 2>/dev/null | grep -v '_app\|_document\|_error\|api/' | wc -l | tr -d ' ')
                check_pass "$belief_id" "Next.js pages/ routes: $route_count"
            elif [[ -d "src/pages" ]]; then
                local route_count=$(find src/pages/ -name '*.tsx' -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' 2>/dev/null | grep -v '_app\|_document\|_error\|api/' | wc -l | tr -d ' ')
                check_pass "$belief_id" "Next.js src/pages/ routes: $route_count"
            else
                check_warn "$belief_id" "no Next.js route directories found"
            fi
            ;;
        dom_check)
            run_dom_eval
            if [[ -n "$DOM_RESULTS" && -n "$belief_metric" ]]; then
                local result=$(echo "$DOM_RESULTS" | grep "^${belief_metric}:" | head -1)
                local status=$(echo "$result" | cut -d: -f2)
                local detail=$(echo "$result" | cut -d: -f3-)
                if [[ "$status" == "pass" ]]; then
                    check_pass "$belief_id" "$detail"
                else
                    check_fail "$belief_id" "${detail:-dom check failed}" "warn" 3
                fi
            elif [[ -z "$EVAL_URL" ]]; then
                check_warn "$belief_id" "dom_check: no dev server (set EVAL_URL)"
            else
                check_warn "$belief_id" "dom_check: evaluation failed"
            fi
            ;;
        copy_check)
            run_copy_eval
            if [[ -n "$COPY_RESULTS" && -n "$belief_metric" ]]; then
                local result=$(echo "$COPY_RESULTS" | grep "^${belief_metric}:" | head -1)
                local status=$(echo "$result" | cut -d: -f2)
                local detail=$(echo "$result" | cut -d: -f3-)
                if [[ "$status" == "pass" ]]; then
                    check_pass "$belief_id" "$detail"
                else
                    check_fail "$belief_id" "${detail:-copy check failed}" "warn" 3
                fi
            elif [[ -z "$EVAL_URL" ]]; then
                check_warn "$belief_id" "copy_check: no dev server (set EVAL_URL)"
            else
                check_warn "$belief_id" "copy_check: evaluation failed"
            fi
            ;;
        positioning_check)
            run_copy_eval
            if [[ -n "$COPY_RESULTS" && -n "$belief_metric" ]]; then
                local result=$(echo "$COPY_RESULTS" | grep "^${belief_metric}:" | head -1)
                local status=$(echo "$result" | cut -d: -f2)
                local detail=$(echo "$result" | cut -d: -f3-)
                if [[ "$status" == "pass" ]]; then
                    check_pass "$belief_id" "$detail"
                else
                    check_fail "$belief_id" "${detail:-positioning check failed}" "warn" 3
                fi
            elif [[ -z "$EVAL_URL" ]]; then
                check_warn "$belief_id" "positioning_check: no dev server (set EVAL_URL)"
            else
                check_warn "$belief_id" "positioning_check: evaluation failed"
            fi
            ;;
        self_check)
            run_self_eval
            if [[ -n "$SELF_RESULTS" && -n "$belief_metric" ]]; then
                local result=$(echo "$SELF_RESULTS" | grep "^${belief_metric}:" | head -1)
                local status=$(echo "$result" | cut -d: -f2)
                local detail=$(echo "$result" | cut -d: -f3-)
                if [[ "$status" == "pass" ]]; then
                    check_pass "$belief_id" "$detail"
                else
                    check_fail "$belief_id" "${detail:-self check failed}" "warn" 3
                fi
            else
                check_fail "$belief_id" "self check: diagnostic failed" "warn" 3
            fi
            ;;
        llm_judge)
            # LLM-as-judge: Claude evaluates code/files against a quality prompt
            # Skip entirely in --score mode — don't count in totals at all
            if [[ "$SCORE_MODE" == "true" ]]; then
                return
            elif [[ -n "$belief_prompt" ]]; then
                local judge_context=""
                # Gather context from specified paths or feature files
                if [[ -n "$belief_path" ]]; then
                    local expanded_path="${belief_path/#\~/$HOME}"
                    if [[ -f "$expanded_path" ]]; then
                        judge_context=$(head -200 "$expanded_path" 2>/dev/null)
                    elif [[ -d "$expanded_path" ]]; then
                        # Directory: concatenate first 50 lines of each file
                        judge_context=$(find "$expanded_path" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.sh" -o -name "*.md" \) ! -path "*/node_modules/*" 2>/dev/null | head -10 | while read -r f; do
                            echo "=== $(basename "$f") ==="
                            head -50 "$f" 2>/dev/null
                        done)
                    fi
                elif [[ -n "$belief_feature" ]]; then
                    # Auto-gather context for the feature from SRC_DIRS
                    if [[ -n "$SRC_DIRS" ]]; then
                        judge_context=$(grep -rl "$belief_feature" $SRC_DIRS 2>/dev/null | grep -v node_modules | head -5 | while read -r f; do
                            echo "=== $(basename "$f") ==="
                            head -50 "$f" 2>/dev/null
                        done)
                    fi
                fi

                if [[ -z "$judge_context" ]]; then
                    check_warn "$belief_id" "llm_judge: no context files found"
                else
                    # Call Claude via the Anthropic API (requires ANTHROPIC_API_KEY)
                    local api_key="${ANTHROPIC_API_KEY:-}"
                    if [[ -z "$api_key" ]]; then
                        # Try to use claude CLI as fallback
                        local judge_input="Evaluate this code. Answer ONLY 'pass' or 'fail' on the first line, then a one-sentence reason on the second line.

Question: ${belief_prompt}

Code:
${judge_context}"
                        local judge_result=""
                        # Use a temp file for the prompt to avoid shell escaping issues
                        local judge_tmp
                        judge_tmp=$(mktemp)
                        echo "$judge_input" > "$judge_tmp"
                        judge_result=$(claude -p "$(cat "$judge_tmp")" --model haiku 2>/dev/null </dev/null | head -2) || judge_result=""
                        rm -f "$judge_tmp"

                        if [[ -z "$judge_result" ]]; then
                            check_warn "$belief_id" "llm_judge: claude CLI not available"
                        else
                            local verdict
                            verdict=$(echo "$judge_result" | head -1 | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
                            local reason
                            reason=$(echo "$judge_result" | tail -1)
                            if [[ "$verdict" == "pass" ]]; then
                                check_pass "$belief_id" "$reason"
                            else
                                check_fail "$belief_id" "$reason" "warn" 3
                            fi
                        fi
                    else
                        # Direct API call with curl (faster, no CLI overhead)
                        local judge_payload
                        judge_payload=$(jq -n \
                            --arg prompt "$belief_prompt" \
                            --arg context "$(echo "$judge_context" | head -100)" \
                            '{model:"claude-haiku-4-5-20251001",max_tokens:100,messages:[{role:"user",content:("Evaluate this code. Answer ONLY pass or fail on the first line, then a one-sentence reason on the second line.\n\nQuestion: " + $prompt + "\n\nCode:\n" + $context)}]}')
                        local judge_response
                        judge_response=$(curl -s "https://api.anthropic.com/v1/messages" \
                            -H "x-api-key: $api_key" \
                            -H "anthropic-version: 2023-06-01" \
                            -H "content-type: application/json" \
                            -d "$judge_payload" 2>/dev/null)
                        local judge_text
                        judge_text=$(echo "$judge_response" | grep -o '"text":"[^"]*"' | head -1 | sed 's/"text":"//;s/"$//')
                        if [[ -z "$judge_text" ]]; then
                            check_warn "$belief_id" "llm_judge: API call failed"
                        else
                            local verdict
                            verdict=$(echo "$judge_text" | tr '[:upper:]' '[:lower:]' | head -1)
                            if echo "$verdict" | grep -q "pass"; then
                                check_pass "$belief_id" "$(echo "$judge_text" | tail -1)"
                            else
                                check_fail "$belief_id" "$(echo "$judge_text" | tail -1)" "warn" 3
                            fi
                        fi
                    fi
                fi
            else
                check_warn "$belief_id" "llm_judge: no prompt: field"
            fi
            ;;
        feature_review)
            # Claude evaluates feature completeness — explicit capabilities or inferred
            # Skip in --score mode (expensive LLM call)
            if [[ "$SCORE_MODE" == "true" ]]; then
                return
            fi

            # Gather code context for the feature
            local review_context=""
            if [[ -n "$belief_path" ]]; then
                local expanded_path="${belief_path/#\~/$HOME}"
                if [[ -f "$expanded_path" ]]; then
                    review_context=$(head -300 "$expanded_path" 2>/dev/null)
                elif [[ -d "$expanded_path" ]]; then
                    review_context=$(find "$expanded_path" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.mjs" -o -name "*.yml" -o -name "*.md" \) ! -path "*/node_modules/*" 2>/dev/null | head -10 | while read -r f; do
                        echo "=== $f ==="
                        head -80 "$f" 2>/dev/null
                    done)
                fi
            elif [[ -n "$belief_feature" ]]; then
                # Auto-discover: find files related to this feature
                review_context=$(grep -rl "$belief_feature" bin/ .claude/commands/ lens/ config/ 2>/dev/null | grep -v node_modules | head -8 | while read -r f; do
                    echo "=== $f ==="
                    head -80 "$f" 2>/dev/null
                done)
            fi

            if [[ -z "$review_context" ]]; then
                check_warn "$belief_id" "feature_review: no code found for feature"
            else

            # Build the prompt
            local review_prompt="You are reviewing a feature for completeness. Be honest and critical.

"
            if [[ ${#capabilities[@]} -gt 0 ]]; then
                review_prompt+="The feature claims these capabilities:
"
                for cap in "${capabilities[@]}"; do
                    review_prompt+="- $cap
"
                done
                review_prompt+="
For each capability, respond IMPLEMENTED or MISSING.
Then on the final line write: COMPLETENESS: X/Y (where X = implemented, Y = total)
"
            else
                review_prompt+="Analyze this feature's code. Identify:
1. What capabilities are implemented (working code, not stubs)
2. What's obviously missing for this feature to be complete
3. On the final line: COMPLETENESS: X/Y (your best estimate of implemented/total capabilities)

Be specific. 'Error handling' is too vague. 'Handles invalid input gracefully' is specific.
"
            fi
            review_prompt+="
Feature: ${belief_feature:-unknown}
Code:
${review_context}"

            # Call Claude (reuse llm_judge calling pattern)
            local review_tmp review_result
            review_tmp=$(mktemp)
            echo "$review_prompt" > "$review_tmp"

            local api_key="${ANTHROPIC_API_KEY:-}"
            if [[ -z "$api_key" ]]; then
                review_result=$(claude -p "$(cat "$review_tmp")" --model haiku 2>/dev/null </dev/null) || review_result=""
            else
                local review_payload
                review_payload=$(jq -n \
                    --rawfile prompt "$review_tmp" \
                    '{model:"claude-haiku-4-5-20251001",max_tokens:500,messages:[{role:"user",content:$prompt}]}')
                local review_response
                review_response=$(curl -s "https://api.anthropic.com/v1/messages" \
                    -H "x-api-key: $api_key" \
                    -H "anthropic-version: 2023-06-01" \
                    -H "content-type: application/json" \
                    -d "$review_payload" 2>/dev/null)
                review_result=$(echo "$review_response" | jq -r '.content[0].text // empty' 2>/dev/null)
            fi
            rm -f "$review_tmp"

            if [[ -z "$review_result" ]]; then
                check_warn "$belief_id" "feature_review: Claude not available"
            else
                # Parse COMPLETENESS: X/Y from response
                local completeness
                completeness=$(echo "$review_result" | grep -o 'COMPLETENESS: [0-9]*/[0-9]*' | tail -1)
                if [[ -n "$completeness" ]]; then
                    local impl total pct
                    impl=$(echo "$completeness" | grep -o '[0-9]*' | head -1)
                    total=$(echo "$completeness" | grep -o '[0-9]*' | tail -1)
                    if [[ "$total" -gt 0 ]]; then
                        pct=$(( impl * 100 / total ))
                        if [[ "$pct" -ge 70 ]]; then
                            check_pass "$belief_id" "${belief_feature}: ${impl}/${total} capabilities (${pct}%)"
                        else
                            check_fail "$belief_id" "${belief_feature}: ${impl}/${total} capabilities (${pct}%)" "warn" 3
                        fi
                    else
                        check_warn "$belief_id" "feature_review: could not parse completeness"
                    fi
                else
                    check_warn "$belief_id" "feature_review: no COMPLETENESS line in response"
                fi
            fi
            fi  # end review_context not empty
            ;;
        bench_check)
            # Run rhino bench --json and check calibration percentage
            local bench_result
            bench_result=$("$RHINO_DIR/bin/bench.sh" --json 2>/dev/null) || bench_result=""
            if [[ -n "$bench_result" ]] && command -v jq &>/dev/null; then
                local calibration
                calibration=$(echo "$bench_result" | jq -r '.calibration // 0' 2>/dev/null)
                local min_cal="${belief_min_calibration:-80}"
                if [[ "$calibration" -ge "$min_cal" ]]; then
                    local bench_passed bench_total
                    bench_passed=$(echo "$bench_result" | jq -r '.passed // 0' 2>/dev/null)
                    bench_total=$(echo "$bench_result" | jq -r '.total // 0' 2>/dev/null)
                    check_pass "$belief_id" "calibration ${calibration}% (${bench_passed}/${bench_total} fixtures)"
                else
                    check_fail "$belief_id" "calibration ${calibration}% (need ${min_cal}%)" "warn" 5
                fi
            else
                check_warn "$belief_id" "bench_check: rhino bench failed"
            fi
            ;;
        command_check)
            # Run arbitrary shell command — PASS if exit 0, FAIL otherwise
            if [[ -n "$belief_command" ]]; then
                local cmd_output
                cmd_output=$(eval "$belief_command" 2>&1) && \
                    check_pass "$belief_id" "$cmd_output" || \
                    check_fail "$belief_id" "${cmd_output:-command failed}" "warn" 3
            else
                check_warn "$belief_id" "command_check: no command: field"
            fi
            ;;
        score_trend)
            # Check if score has changed over recent history
            local history_file=".claude/scores/history.tsv"
            local window="${belief_window:-10}"
            local direction="${belief_direction:-not_flat}"
            if [[ -f "$history_file" ]]; then
                local hist_lines
                hist_lines=$(wc -l < "$history_file" | tr -d ' ')
                if [[ "$hist_lines" -le 2 ]]; then
                    check_warn "$belief_id" "score_trend: not enough history (${hist_lines} lines)"
                else
                    # Get last N product scores (column 5)
                    local scores
                    scores=$(tail -n "$window" "$history_file" | cut -f5 | grep -E '^[0-9]+$')
                    local unique
                    unique=$(echo "$scores" | sort -u | wc -l | tr -d ' ')
                    if [[ "$direction" == "not_flat" ]]; then
                        if [[ "$unique" -gt 1 ]]; then
                            check_pass "$belief_id" "score variance: ${unique} unique values in last ${window} runs"
                        else
                            check_fail "$belief_id" "score flat: 1 unique value in last ${window} runs" "warn" 3
                        fi
                    elif [[ "$direction" == "up" ]]; then
                        local first_score last_score
                        first_score=$(echo "$scores" | head -1)
                        last_score=$(echo "$scores" | tail -1)
                        if [[ -n "$first_score" && -n "$last_score" && "$last_score" -gt "$first_score" ]]; then
                            check_pass "$belief_id" "score trending up: ${first_score} → ${last_score}"
                        else
                            check_fail "$belief_id" "score not trending up: ${first_score:-?} → ${last_score:-?}" "warn" 3
                        fi
                    fi
                fi
            else
                check_warn "$belief_id" "score_trend: no history.tsv found"
            fi
            ;;
        playwright_task)
            if [[ -n "$EVAL_URL" && -n "$belief_scenario" ]]; then
                local threshold="${belief_threshold:-180}"
                local blind_result
                local blind_script="$RHINO_DIR/lens/product/eval/blind-eval.mjs"
                [[ ! -f "$blind_script" ]] && blind_script="$RHINO_DIR/bin/blind-eval.mjs"
                blind_result=$(node "$blind_script" --url "$EVAL_URL" --task "$belief_scenario" --timeout "$threshold" --eval 2>/dev/null) || blind_result=""
                if [[ -n "$blind_result" && -n "$belief_metric" ]]; then
                    local result=$(echo "$blind_result" | grep "^${belief_metric}:" | head -1)
                    local status=$(echo "$result" | cut -d: -f2)
                    local detail=$(echo "$result" | cut -d: -f3-)
                    if [[ "$status" == "pass" ]]; then
                        check_pass "$belief_id" "$detail"
                    else
                        check_fail "$belief_id" "${detail:-blind eval failed}" "warn" 3
                    fi
                else
                    check_warn "$belief_id" "playwright_task: evaluation failed"
                fi
            else
                check_warn "$belief_id" "playwright_task: no dev server or no scenario (set EVAL_URL)"
            fi
            ;;
    esac

    # Track per-feature results
    local _feat="${belief_feature:-unscoped}"
    local _dp=$((PASS - _pre_pass)) _dw=$((WARN - _pre_warn)) _df=$((FAIL - _pre_fail))
    FEATURE_RESULTS="${FEATURE_RESULTS}${_feat}:${_dp}:${_dw}:${_df}
"
}

# === beliefs.yml checks ===

BELIEFS_FILE=""
for bf in "lens/product/eval/beliefs.yml" "config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS_FILE="$bf" && break
done
if [[ -f "$BELIEFS_FILE" ]]; then
    belief_id=""
    belief_type=""
    belief_metric=""
    belief_scenario=""
    belief_threshold=""
    belief_feature=""
    in_forbidden=false
    in_capabilities=false
    forbidden_words=()
    capabilities=()

    while IFS= read -r line; do
        # New belief entry
        if echo "$line" | grep -q '^\s*- id:'; then
            # Process previous belief
            process_belief
            # Reset
            belief_id=$(echo "$line" | sed 's/.*id: *//')
            belief_type=""
            belief_metric=""
            belief_scenario=""
            belief_threshold=""
            belief_feature=""
            belief_path=""
            belief_contains=""
            belief_not_contains=""
            belief_exists=""
            belief_min_lines=""
            belief_prompt=""
            belief_min_calibration=""
            belief_window=""
            belief_direction=""
            belief_command=""
            in_forbidden=false
            in_capabilities=false
            forbidden_words=()
            capabilities=()
        fi

        # Type
        if echo "$line" | grep -q '^\s*type:'; then
            belief_type=$(echo "$line" | sed 's/.*type: *//')
        fi

        # Feature
        if echo "$line" | grep -q '^\s*feature:'; then
            belief_feature=$(echo "$line" | sed 's/.*feature: *//')
        fi

        # Metric
        if echo "$line" | grep -q '^\s*metric:'; then
            belief_metric=$(echo "$line" | sed 's/.*metric: *//')
        fi

        # Path (for file_check)
        if echo "$line" | grep -q '^\s*path:'; then
            belief_path=$(echo "$line" | sed 's/.*path: *//' | tr -d '"')
        fi

        # Contains (for file_check)
        if echo "$line" | grep -q '^\s*contains:'; then
            belief_contains=$(echo "$line" | sed 's/.*contains: *//' | tr -d '"')
        fi

        # Not contains (for file_check)
        if echo "$line" | grep -q '^\s*not_contains:'; then
            belief_not_contains=$(echo "$line" | sed 's/.*not_contains: *//' | tr -d '"')
        fi

        # Exists (for file_check)
        if echo "$line" | grep -q '^\s*exists:'; then
            belief_exists=$(echo "$line" | sed 's/.*exists: *//' | tr -d '"')
        fi

        # Min lines (for file_check)
        if echo "$line" | grep -q '^\s*min_lines:'; then
            belief_min_lines=$(echo "$line" | sed 's/.*min_lines: *//')
        fi

        # Prompt (for llm_judge)
        if echo "$line" | grep -q '^\s*prompt:'; then
            belief_prompt=$(echo "$line" | sed 's/.*prompt: *//' | tr -d '"')
        fi

        # Scenario (for playwright_task)
        if echo "$line" | grep -q '^\s*scenario:'; then
            belief_scenario=$(echo "$line" | sed 's/.*scenario: *//' | tr -d '"')
        fi

        # Threshold (for playwright_task)
        if echo "$line" | grep -q '^\s*threshold_seconds:'; then
            belief_threshold=$(echo "$line" | sed 's/.*threshold_seconds: *//')
        fi

        # Min calibration (for bench_check)
        if echo "$line" | grep -q '^\s*min_calibration:'; then
            belief_min_calibration=$(echo "$line" | sed 's/.*min_calibration: *//')
        fi

        # Window (for score_trend)
        if echo "$line" | grep -q '^\s*window:'; then
            belief_window=$(echo "$line" | sed 's/.*window: *//')
        fi

        # Direction (for score_trend)
        if echo "$line" | grep -q '^\s*direction:'; then
            belief_direction=$(echo "$line" | sed 's/.*direction: *//')
        fi

        # Command (for command_check)
        if echo "$line" | grep -q '^\s*command:'; then
            belief_command=$(echo "$line" | sed 's/.*command: *//')
        fi

        # Forbidden list parsing (for content_check)
        if echo "$line" | grep -q '^\s*forbidden:'; then
            in_forbidden=true
            inline=$(echo "$line" | grep -o '\[.*\]' || true)
            if [[ -n "$inline" ]]; then
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

        # Capabilities list parsing (for feature_review)
        if echo "$line" | grep -q '^\s*capabilities:'; then
            in_capabilities=true
            continue
        fi

        if [[ "$in_capabilities" == "true" ]]; then
            if echo "$line" | grep -q '^\s*-'; then
                _cap=$(echo "$line" | sed 's/^\s*- *//' | tr -d '"')
                [[ -n "$_cap" ]] && capabilities+=("$_cap")
            else
                in_capabilities=false
            fi
        fi

    done < "$BELIEFS_FILE"

    # Process last belief
    process_belief
fi

# === --score mode: output single integer, per-feature JSON, or combined JSON ===
if [[ "$SCORE_MODE" == "true" ]]; then
    BELIEFS_TOTAL=$((PASS + WARN + FAIL))

    # Aggregate per-feature results from beliefs (always needed for --json and --by-feature)
    _bf_tmpdir=$(mktemp -d)
    while IFS=: read -r _bf_name _bf_p _bf_w _bf_f; do
        [[ -z "$_bf_name" ]] && continue
        _bf_pp=0; _bf_pw=0; _bf_pf=0
        if [[ -f "$_bf_tmpdir/$_bf_name" ]]; then
            IFS=: read -r _bf_pp _bf_pw _bf_pf < "$_bf_tmpdir/$_bf_name"
        fi
        echo "$((_bf_pp + _bf_p)):$((_bf_pw + _bf_w)):$((_bf_pf + _bf_f))" > "$_bf_tmpdir/$_bf_name"
    done <<< "$FEATURE_RESULTS"

    # Add generative scores to feature JSON
    while IFS=: read -r _gf_name _gf_score; do
        [[ -z "$_gf_name" ]] && continue
        echo "gen:${_gf_score}" > "$_bf_tmpdir/$_gf_name.gen"
    done <<< "$GENERATIVE_SCORES"

    _bf_json="{"
    _bf_first=true
    for _bf_file in "$_bf_tmpdir"/*; do
        [[ ! -f "$_bf_file" ]] && continue
        _bf_fname=$(basename "$_bf_file")
        if [[ "$_bf_fname" == *.gen ]]; then
            # Generative feature — numeric score
            _bf_fname="${_bf_fname%.gen}"
            _gf_s=$(cut -d: -f2 < "$_bf_file")
            $_bf_first || _bf_json+=","
            _bf_json+="\"$_bf_fname\":{\"score\":$_gf_s,\"type\":\"generative\"}"
            _bf_first=false
        else
            # Beliefs feature — pass/warn/fail
            IFS=: read -r _bf_p _bf_w _bf_f < "$_bf_file"
            _bf_t=$((_bf_p + _bf_w + _bf_f))
            $_bf_first || _bf_json+=","
            _bf_json+="\"$_bf_fname\":{\"pass\":$_bf_p,\"warn\":$_bf_w,\"fail\":$_bf_f,\"total\":$_bf_t}"
            _bf_first=false
        fi
    done
    _bf_json+="}"
    rm -rf "$_bf_tmpdir"

    # Compute blended score:
    # beliefs contribute: (PASS*100 + WARN*50) / BELIEFS_TOTAL
    # generative contributes: GENERATIVE_SUM / GENERATIVE_COUNT
    # Final = weighted average by count
    _eval_score=""
    _total_weight=$((BELIEFS_TOTAL + GENERATIVE_COUNT))
    if [[ "$_total_weight" -gt 0 ]]; then
        _beliefs_points=0
        [[ "$BELIEFS_TOTAL" -gt 0 ]] && _beliefs_points=$(( PASS * 100 + WARN * 50 ))
        _eval_score=$(( (_beliefs_points + GENERATIVE_SUM) / _total_weight ))
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"score\":${_eval_score:-null},\"pass\":$PASS,\"warn\":$WARN,\"fail\":$FAIL,\"beliefs_total\":$BELIEFS_TOTAL,\"generative_count\":$GENERATIVE_COUNT,\"generative_sum\":$GENERATIVE_SUM,\"total\":$_total_weight,\"features\":$_bf_json}"
    elif [[ "$BY_FEATURE" == "true" ]]; then
        echo "$_bf_json"
    else
        echo "$_eval_score"
    fi
    exit 0
fi

# === Summary ===
echo ""
if [[ "$GENERATIVE_COUNT" -gt 0 ]]; then
    _gen_avg=$((GENERATIVE_SUM / GENERATIVE_COUNT))
    echo "generative: ${GENERATIVE_COUNT} features, avg ${_gen_avg}/100"
fi
if [[ "$((PASS + WARN + FAIL))" -gt 0 ]]; then
    echo "beliefs: $PASS passed | $WARN warned | $FAIL failed"
fi
if [[ "$SCORE_PENALTY" -gt 0 ]]; then
    echo "Score impact: -${SCORE_PENALTY} pts from failures"
fi

# Exit code — block severity failures return non-zero
BLOCK_FAILS=0
BELIEFS_FILE=""
for bf in "lens/product/eval/beliefs.yml" "config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS_FILE="$bf" && break
done
if [[ -f "$BELIEFS_FILE" && "$FAIL" -gt 0 ]]; then
    # Count beliefs with severity: block that were checked and failed
    # For now, any FAIL with block_on_failure config = non-zero exit
    BLOCK_ON=$(grep -c 'block_on_failure: true' config/rhino.yml 2>/dev/null) || BLOCK_ON=0
    if [[ "$BLOCK_ON" -gt 0 ]]; then
        BLOCK_FAILS=$FAIL
    fi
fi

if [[ "$BLOCK_FAILS" -gt 0 ]]; then
    echo "Blocking: $BLOCK_FAILS failure(s) with block_on_failure enabled"
    exit 1
fi
exit 0
