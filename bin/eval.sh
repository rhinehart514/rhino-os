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
NO_GENERATIVE=false
NO_LLM=false
EVAL_SAMPLES=3
FEATURE_FILTER=""
POSITIONAL=""
for arg in "$@"; do
    case "$arg" in
        --score) SCORE_MODE=true ;;
        --by-feature) BY_FEATURE=true ;;
        --json) JSON_OUTPUT=true ;;
        --fresh) FRESH_MODE=true ;;
        --no-generative) NO_GENERATIVE=true ;;
        --no-llm) NO_LLM=true; NO_GENERATIVE=true ;;
        --samples=*) EVAL_SAMPLES="${arg#--samples=}" ;;
        --samples) ;; # next arg is the count, handled below
        --feature=*) FEATURE_FILTER="${arg#--feature=}" ;;
        --feature) ;; # next arg is the feature name, handled below
        *)
            if [[ "${prev_arg:-}" == "--feature" ]]; then
                FEATURE_FILTER="$arg"
            elif [[ "${prev_arg:-}" == "--samples" ]]; then
                EVAL_SAMPLES="$arg"
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

# Per-quality tracking (quality_dim:pass:warn:fail accumulated as lines)
QUALITY_RESULTS=""

# Assertion history (date\tfeature\tid\ttype\tstatus\tseverity — written to .claude/evals/assertion-history.tsv)
ASSERTION_HISTORY=""

# Per-layer tracking (feature~layer:pass:warn:fail accumulated as lines)
LAYER_RESULTS=""

# Generative eval numeric scores (feature_name:score accumulated as lines)
# These contribute directly to the final score as numbers, not pass/warn/fail buckets.
GENERATIVE_SCORES=""
GENERATIVE_COUNT=0
GENERATIVE_SUM=0

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
SEP="  ${DIM}⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯${NC}"

print_score_bar() {
    local score=${1:-0}
    local filled=$(( (score + 2) / 5 ))
    [[ $filled -gt 20 ]] && filled=20
    local empty=$((20 - filled))
    local color="$RED"
    [[ $score -ge 50 ]] && color="$YELLOW"
    [[ $score -ge 80 ]] && color="$GREEN"
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    local trail=""
    for ((i=0; i<empty; i++)); do trail="${trail}░"; done
    printf "${color}${bar}${DIM}${trail}${NC}"
}

# Cross-platform file mtime in epoch seconds
# Returns empty string (not 0) on failure so callers can detect errors
file_mtime() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "" && return
    # macOS: stat -f %m, GNU/Linux: stat -c %Y
    stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo ""
}

# Result accumulation arrays
BELIEF_PASSES=()
BELIEF_WARNS=()
BELIEF_FAILS=()
GENERATIVE_DISPLAY=()

# --- Check functions ---

check_pass() {
    local name="$1"
    local desc="$2"
    PASS=$((PASS + 1))
    BELIEF_PASSES+=("${name}|${desc}")
}

check_warn() {
    local name="$1"
    local desc="$2"
    WARN=$((WARN + 1))
    BELIEF_WARNS+=("${name}|${desc}")
}

check_fail() {
    local name="$1"
    local desc="$2"
    local severity="${3:-warn}"
    local penalty="${4:-0}"
    FAIL=$((FAIL + 1))
    SCORE_PENALTY=$((SCORE_PENALTY + penalty))
    if [[ "$severity" == "block" ]]; then
        BELIEF_FAILS+=("${name}|${desc}|block")
    else
        BELIEF_FAILS+=("${name}|${desc}|warn")
    fi
}

# Early feature detection
HAS_FEATURES=false
if [[ -f "config/rhino.yml" ]] && grep -q '^features:' "config/rhino.yml" 2>/dev/null; then
    HAS_FEATURES=true
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

# Resolve RHINO_DIR early — needed by infrastructure checks and eval tools
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    RHINO_DIR="$CLAUDE_PLUGIN_ROOT"
else
    _EVAL_SOURCE="${BASH_SOURCE[0]}"
    while [[ -L "$_EVAL_SOURCE" ]]; do
        _EVAL_SOURCE="$(readlink "$_EVAL_SOURCE")"
    done
    RHINO_DIR="$(cd "$(dirname "$_EVAL_SOURCE")/.." && pwd)"
fi

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
_SKILL_DIR="$RHINO_DIR/skills"
for skill in "$_SKILL_DIR"/*/SKILL.md; do
    [[ ! -f "$skill" ]] && continue
    if ! grep -q 'If something breaks\|Errors' "$skill" 2>/dev/null; then
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
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    # Plugin mode: validate hooks.json references
    _HOOKS_JSON="$RHINO_DIR/hooks/hooks.json"
    if [[ -f "$_HOOKS_JSON" ]] && command -v jq &>/dev/null; then
        while IFS= read -r _hcmd; do
            [[ -z "$_hcmd" ]] && continue
            # Expand ${CLAUDE_PLUGIN_ROOT} template variable and strip quotes
            _hcmd="${_hcmd//\$\{CLAUDE_PLUGIN_ROOT\}/$RHINO_DIR}"
            _hcmd="${_hcmd//\"/}"
            _hcmd="${_hcmd%% *}"
            [[ ! -f "$_hcmd" ]] && HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
        done < <(jq -r '.. | .command? // empty' "$_HOOKS_JSON" 2>/dev/null)
    elif [[ ! -f "$_HOOKS_JSON" ]]; then
        HOOKS_BROKEN=1
    fi
    if [[ "$HOOKS_BROKEN" -eq 0 ]]; then
        check_pass "hooks-resolve" "hooks.json references resolve"
    else
        check_fail "hooks-resolve" "$HOOKS_BROKEN broken hook reference(s) in hooks.json" "warn" 3
    fi
else
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
fi

# mind-files-loaded
MIND_MISSING=0
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    # Plugin mode: mind delivered via SKILL.md
    if [[ ! -f "$RHINO_DIR/skills/rhino-mind/SKILL.md" ]]; then
        MIND_MISSING=1
    fi
    if [[ "$MIND_MISSING" -eq 0 ]]; then
        check_pass "mind-files-loaded" "mind delivered via skills/rhino-mind/SKILL.md"
    else
        check_fail "mind-files-loaded" "skills/rhino-mind/SKILL.md missing" "block" 5
    fi
else
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

# RHINO_DIR already resolved above (before infrastructure checks)

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
            local dom_script=""
            for _ds in "$RHINO_DIR"/lens/*/eval/dom-eval.mjs; do
                [[ -f "$_ds" ]] && dom_script="$_ds" && break
            done
            [[ -z "$dom_script" ]] && dom_script="$RHINO_DIR/bin/dom-eval.mjs"
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
            local copy_script=""
            for _cs in "$RHINO_DIR"/lens/*/eval/copy-eval.mjs; do
                [[ -f "$_cs" ]] && copy_script="$_cs" && break
            done
            [[ -z "$copy_script" ]] && copy_script="$RHINO_DIR/bin/copy-eval.mjs"
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
BELIEFS_CACHE_FILE="$EVAL_CACHE_DIR/beliefs-cache.json"

# Shared score formula: gen_avg - belief_penalty, or beliefs-only fallback
# Args: $1=gen_count $2=gen_sum $3=pass $4=warn $5=fail $6=has_block_fail (true/false)
# Outputs: score integer (or empty if no data)
compute_eval_score() {
    local _gen_count="$1" _gen_sum="$2" _pass="$3" _warn="$4" _fail="$5" _has_block="${6:-false}"
    local _total=$((_pass + _warn + _fail))

    if [[ "$_has_block" == "true" ]]; then
        echo 0
    elif [[ "$_gen_count" -gt 0 ]]; then
        local _gen_avg=$((_gen_sum / _gen_count))
        local _penalty=$((_warn * 3 + _fail * 5))
        local _score=$((_gen_avg - _penalty))
        [[ "$_score" -lt 0 ]] && _score=0
        echo "$_score"
    elif [[ "$_total" -gt 0 ]]; then
        echo $(( (_pass * 100 + _warn * 50) / _total ))
    fi
}

# Read features from rhino.yml using simple YAML parsing
# Outputs lines: feature_name|delivers|for|code_path1,code_path2|cmd1,cmd2
# Filters: skips features with status: killed or status: archived
parse_features() {
    local config_file="config/rhino.yml"
    [[ ! -f "$config_file" ]] && return

    local in_features=false
    local current_feat="" current_delivers="" current_for="" current_code="" current_commands="" current_status=""
    local in_code=false in_commands=false

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Detect features: section
        if echo "$line" | grep -q '^features:'; then
            in_features=true
            continue
        fi

        # Detect end of features section (new top-level key)
        if [[ "$in_features" == true ]] && echo "$line" | grep -qE '^[a-z]'; then
            if [[ -n "$current_feat" && "$current_status" != "killed" && "$current_status" != "archived" ]]; then
                echo "${current_feat}|${current_delivers}|${current_for}|${current_code}|${current_commands}"
            fi
            current_feat=""
            in_features=false
            continue
        fi

        [[ "$in_features" != true ]] && continue

        # New feature (2-space indent, key with colon, no value)
        if echo "$line" | grep -qE '^  [a-z][a-z0-9_-]*:$'; then
            # Emit previous feature
            if [[ -n "$current_feat" && "$current_status" != "killed" && "$current_status" != "archived" ]]; then
                echo "${current_feat}|${current_delivers}|${current_for}|${current_code}|${current_commands}"
            fi
            current_feat=$(echo "$line" | sed 's/^[[:space:]]*//;s/:[[:space:]]*$//')
            current_delivers=""
            current_for=""
            current_code=""
            current_commands=""
            current_status=""
            in_code=false
            in_commands=false
            continue
        fi

        # status:
        if echo "$line" | grep -q '^\s*status:'; then
            current_status=$(echo "$line" | sed 's/.*status: *//;s/^"//;s/"$//')
            in_code=false
            in_commands=false
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
            in_commands=false
            # Parse inline array: ["a", "b"]
            local inline
            inline=$(echo "$line" | grep -o '\[.*\]' || true)
            if [[ -n "$inline" ]]; then
                current_code=$(echo "$inline" | tr -d '[]"' | sed 's/, */,/g')
                in_code=false
            fi
            continue
        fi

        # commands: (inline array — CLI commands for UX eval)
        if echo "$line" | grep -q '^\s*commands:'; then
            in_commands=true
            in_code=false
            local inline
            inline=$(echo "$line" | grep -o '\[.*\]' || true)
            if [[ -n "$inline" ]]; then
                current_commands=$(echo "$inline" | tr -d '[]"' | sed 's/, */,/g')
                in_commands=false
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

        # commands array items
        if [[ "$in_commands" == true ]]; then
            if echo "$line" | grep -q '^\s*-'; then
                local item
                item=$(echo "$line" | sed 's/^[[:space:]]*- *//;s/^"//;s/"$//')
                if [[ -n "$current_commands" ]]; then
                    current_commands="${current_commands},${item}"
                else
                    current_commands="$item"
                fi
            else
                in_commands=false
            fi
        fi
    done < "$config_file"

    # Emit last feature
    if [[ -n "$current_feat" && "$current_status" != "killed" && "$current_status" != "archived" ]]; then
        echo "${current_feat}|${current_delivers}|${current_for}|${current_code}|${current_commands}"
    fi
}

# Gather code content for a feature's code paths
# Smart reading: small files fully, large files with targeted extraction
gather_code_context() {
    local code_paths="$1"
    local feat_name="${2:-}"
    local context=""
    local OLD_IFS="$IFS"
    IFS=','
    for path in $code_paths; do
        IFS="$OLD_IFS"
        # Expand ~ to $HOME
        local expanded="${path/#\~/$HOME}"
        if [[ -f "$expanded" ]]; then
            local line_count
            line_count=$(wc -l < "$expanded" 2>/dev/null | tr -d ' ')
            if [[ "$line_count" -le 500 ]]; then
                # Small file: read entirely
                context+="=== $path (${line_count} lines) ===
$(cat "$expanded" 2>/dev/null)

"
            elif [[ "$line_count" -le 2000 ]]; then
                # Medium file: head + tail + feature-relevant functions
                context+="=== $path (${line_count} lines, smart extract) ===
--- first 200 lines ---
$(head -200 "$expanded" 2>/dev/null)
--- last 100 lines ---
$(tail -100 "$expanded" 2>/dev/null)
"
                # Extract functions matching feature name if provided
                if [[ -n "$feat_name" ]]; then
                    local feat_funcs
                    feat_funcs=$(grep -n -i "$feat_name" "$expanded" 2>/dev/null | head -5)
                    if [[ -n "$feat_funcs" ]]; then
                        context+="--- lines matching '$feat_name' ---
${feat_funcs}
"
                    fi
                fi
                context+="
"
            else
                # Large file: function index + most relevant function bodies
                context+="=== $path (${line_count} lines, function index) ===
--- function index ---
$(grep -n -E 'function |^[a-z_]+\(\)|^[a-z_]+ *\(\) *\{|^(export )?(const|let|var) [a-z_]+ *= *(function|\()' "$expanded" 2>/dev/null | head -30)
--- first 100 lines ---
$(head -100 "$expanded" 2>/dev/null)
"
                # Extract the 3 most relevant functions based on feature name
                if [[ -n "$feat_name" ]]; then
                    local match_lines
                    match_lines=$(grep -n -i "$feat_name" "$expanded" 2>/dev/null | head -3 | cut -d: -f1)
                    for ml in $match_lines; do
                        local start=$((ml - 2))
                        [[ "$start" -lt 1 ]] && start=1
                        local end=$((ml + 30))
                        context+="--- around line $ml ---
$(sed -n "${start},${end}p" "$expanded" 2>/dev/null)
"
                    done
                fi
                context+="
"
            fi
        elif [[ -d "$expanded" ]]; then
            context+=$(find "$expanded" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.mjs" -o -name "*.yml" -o -name "*.md" \) ! -path "*/node_modules/*" 2>/dev/null | head -12 | while read -r f; do
                local fc
                fc=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
                echo "=== $f (${fc} lines) ==="
                if [[ "$fc" -le 500 ]]; then
                    cat "$f" 2>/dev/null
                else
                    head -200 "$f" 2>/dev/null
                    echo "... (${fc} lines total, truncated)"
                fi
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
            cache_mtime=$(file_mtime "$EVAL_CACHE_FILE")
            cache_mtime="${cache_mtime:-0}"
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

# Generate a per-feature rubric via haiku (SWE-bench for features)
# Cached in .claude/cache/rubrics/<feature>.json with 24h TTL
generate_feature_rubric() {
    local feat_name="$1"
    local delivers="$2"
    local for_whom="$3"
    local code_context="$4"

    local rubric_dir=".claude/cache/rubrics"
    local rubric_file="${rubric_dir}/${feat_name}.json"

    # Check cache (24h TTL)
    if [[ -f "$rubric_file" && "$FRESH_MODE" != "true" ]]; then
        local now_ts rubric_mtime rubric_age
        now_ts=$(date +%s)
        rubric_mtime=$(file_mtime "$rubric_file")
        rubric_mtime="${rubric_mtime:-0}"
        rubric_age=$(( now_ts - rubric_mtime ))
        if [[ "$rubric_age" -lt 86400 ]]; then
            return  # Fresh enough
        fi
    fi

    mkdir -p "$rubric_dir"

    local rubric_prompt
    rubric_prompt="You are one of the best product engineers alive, generating a scoring rubric for a specific feature. This rubric will calibrate another engineer. Make it specific to THIS code.

Feature: \"${feat_name}\"
Claim: \"${delivers}\"
Target user: \"${for_whom}\"

Code sample (first 5000 chars):
$(echo "$code_context" | head -c 5000)

Generate a rubric with 4 axes. For EACH axis:
1. What would genuinely impress you (80+) for THIS feature
2. What would disappoint you (40) for THIS code
3. 2-3 concrete things to check (file patterns, function names, code paths)

Axes:
- VALUE: Does this feature deliver real value? Complete implementation vs half-built skeleton?
- QUALITY: Would you trust this code at 3am? What breaks? Where did someone think vs just compile?
- UX: What does using this feel like? Does it feel like the builder uses their own product?
- TASTE: Does this code have taste? Complexity appropriate? Abstractions earned? Or generated slop?

Output ONLY a JSON object:
{\"spec_alignment\":{\"check_80\":\"...\",\"check_40\":\"...\",\"specifics\":[\"...\"]},\"integrity\":{\"check_80\":\"...\",\"check_40\":\"...\",\"specifics\":[\"...\"]},\"ux\":{\"check_80\":\"...\",\"check_40\":\"...\",\"specifics\":[\"...\"]},\"anti_slop\":{\"check_80\":\"...\",\"check_40\":\"...\",\"specifics\":[\"...\"]}}"

    local api_key="${ANTHROPIC_API_KEY:-}"
    local rubric_result=""

    if [[ -z "$api_key" ]]; then
        local tmp_file
        tmp_file=$(mktemp)
        echo "$rubric_prompt" > "$tmp_file"
        rubric_result=$(claude -p "$(cat "$tmp_file")" --model haiku --output-format text --append-system-prompt "Output only valid JSON." 2>/dev/null </dev/null) || {
            # Retry without --output-format if flag not supported
            rubric_result=$(claude -p "$(cat "$tmp_file")" --model haiku --append-system-prompt "Output only valid JSON." 2>/dev/null </dev/null) || rubric_result=""
        }
        rm -f "$tmp_file"
    else
        local payload
        payload=$(jq -n \
            --arg prompt "$rubric_prompt" \
            '{model:"claude-haiku-4-5-20251001",max_tokens:1500,temperature:0,messages:[{role:"user",content:$prompt}]}')
        local response
        response=$(curl -s "https://api.anthropic.com/v1/messages" \
            -H "x-api-key: $api_key" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "$payload" 2>/dev/null)
        rubric_result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
    fi

    # Parse and cache the rubric
    if [[ -n "$rubric_result" ]]; then
        local cleaned
        cleaned=$(echo "$rubric_result" | sed -E '/^[[:space:]]*`{3,}[a-zA-Z]*[[:space:]]*$/d' | sed -e '/^[[:space:]]*$/d')
        # Extract JSON — try jq first, then python3, then perl
        local rubric_json=""
        if echo "$cleaned" | jq -c . &>/dev/null 2>&1; then
            rubric_json=$(echo "$cleaned" | jq -c .)
        else
            rubric_json=$(echo "$cleaned" | python3 -c '
import sys, json
text = sys.stdin.read()
depth = 0; start = -1
for i, c in enumerate(text):
    if c == "{":
        if depth == 0: start = i
        depth += 1
    elif c == "}":
        depth -= 1
        if depth == 0 and start >= 0:
            try:
                obj = json.loads(text[start:i+1])
                if isinstance(obj, dict):
                    print(json.dumps(obj, separators=(",",":")))
                    sys.exit(0)
            except: pass
            start = -1
' 2>/dev/null)
            [[ -z "$rubric_json" ]] && rubric_json=$(echo "$cleaned" | perl -0777 -ne 'if (/(\{(?:[^{}]|(?:\{(?:[^{}]|\{[^{}]*\})*\}))*\})/s) { print $1 }' 2>/dev/null)
        fi
        if [[ -n "$rubric_json" ]] && echo "$rubric_json" | jq -c . &>/dev/null 2>&1; then
            echo "$rubric_json" | jq -c . > "$rubric_file" 2>/dev/null || true
        fi
    fi
}

# Full product quality audit — evaluates whether a feature is genuinely good
# Returns JSON: {"delivery_score":N,"craft_score":N,"viability_score":N,"score":N,"verdict":"...","gaps":[...],"strengths":[...],"evidence":"..."}
run_logic_research() {
    local feat_name="$1"
    local delivers="$2"
    local for_whom="$3"
    local code_context="$4"

    # Check for per-feature rubric
    local rubric_file=".claude/cache/rubrics/${feat_name}.json"
    local rubric_section=""
    if [[ -f "$rubric_file" ]]; then
        local rubric_age rubric_mtime now_ts
        now_ts=$(date +%s)
        rubric_mtime=$(file_mtime "$rubric_file")
        rubric_mtime="${rubric_mtime:-0}"
        rubric_age=$(( now_ts - rubric_mtime ))
        if [[ "$rubric_age" -lt 86400 ]]; then
            local rubric_content
            rubric_content=$(cat "$rubric_file" 2>/dev/null)
            if [[ -n "$rubric_content" ]]; then
                rubric_section="
FEATURE-SPECIFIC RUBRIC (generated from code inspection — use this instead of generic anchors):
${rubric_content}
"
            fi
        fi
    fi

    local prompt
    prompt="You are one of the best product engineers alive. You have built features at companies people actually use — not enterprise middleware, real products that users love. You have shipped code that handles 10M requests, and you have shipped MVPs in a weekend that got their first 1000 users. You know what good looks like at every stage.

You grade the way you would assess a feature if you were deciding whether to join this startup or invest in it. Not by counting files or checking boxes — by reading the code and forming a judgment: is this good? Is this the work of someone who knows what they are doing? Would users love this?

You are tough but fair. You respect scrappy code that delivers real value over polished code that does not. You respect simplicity. You hate over-engineering, you hate code that claims to do things it does not, and you hate silent failures. You have seen enough code to know the difference between code that works and code that is good.

Feature: \"${feat_name}\"
Claim: \"${delivers}\"
Target user: \"${for_whom}\"

Code:
${code_context}

WHAT THE SCORES MEAN:
- 90-100: Genuinely excellent. You would show this to other engineers as an example. Rare.
- 70-89: Solid. Ships and works. A good engineer built this. Rough edges but nothing embarrassing.
- 50-69: It works but you would not be proud of it. Ships because it has to.
- 30-49: Half-built. Skeleton is there but does not really deliver.
- 0-29: Does not exist or fundamentally broken.

GRADE THESE THREE DIMENSIONS:

1. DELIVERY (delivery_score, 0-100)
   Does this feature deliver real value to the target user? Not does-a-file-exist — does the LOGIC work end-to-end?
   - Would the target user get something they actually care about? Would they come back?
   - Is this a complete feature or a half-finished skeleton with TODOs?
   - Does it solve the problem better than doing nothing? Better than the obvious alternative?
   - How does this compare to the best implementations you have seen of similar features?
   - Cite file:line for what works and what is missing.

2. CRAFT (craft_score, 0-100)
   Is this well-made? Judge both the code quality AND the experience quality:
   - Code: error handling, robustness, architecture fit, readability — does it read like someone who cares?
   - Experience: when it works, is the output clear and useful? When it fails, do you know why?
   - Robustness: first run, empty state, bad input, missing dependencies — does it handle reality?
   - Taste: does this feel like craft or like it was generated? Would you be proud to show it?
   - Cite file:line for the best and worst parts.

3. VIABILITY (viability_score, 0-100)
   Would this survive contact with the market? Judge adoption odds and competitive position:
   - Is there a real audience for this? How many people would actually use it?
   - What are the alternatives? Is this meaningfully better than what already exists?
   - Is there something novel here — a new approach, a unique angle, a fresh combination?
   - Would someone choose this over the obvious alternative? Why?
   - Cite specific evidence of viability or lack thereof.
${rubric_section}
PROCEDURE:
1. Read all the code. Form an overall impression first — good, bad, somewhere in between.
2. Score each dimension based on your judgment. Trust your instincts — you have seen enough code.
3. For each score, cite 1-2 specific file:line examples that drove your judgment up or down.
4. List the specific gaps (problems) and strengths.
5. DO NOT compute a weighted total — the caller does that.

INTEGRITY:
- You MUST find real problems. If you found zero, you did not look hard enough.
- Every gap must cite file:line. Vague praise or criticism = lazy review.
- Be honest about what stage this code is at. A weekend MVP scoring 85 is suspicious.
- You are grading against the best you have seen, not against average. 70 is genuinely good.

Output ONLY this JSON object — no markdown fences, no text before or after:
{\"delivery_score\":55,\"craft_score\":50,\"viability_score\":45,\"gaps\":[\"specific problem with file:line evidence\"],\"strengths\":[\"what genuinely works well\"],\"evidence\":\"1-2 sentence overall judgment\"}"

    local api_key="${ANTHROPIC_API_KEY:-}"
    local result=""
    local _parse_diag=""  # diagnostic info for stderr on parse failure

    if [[ -z "$api_key" ]]; then
        # Try claude CLI — use --output-format text for clean output
        local tmp_file
        tmp_file=$(mktemp)
        echo "$prompt" > "$tmp_file"
        # Capture both stdout and stderr to diagnose failures
        local cli_stderr
        cli_stderr=$(mktemp)
        result=$(claude -p "$(cat "$tmp_file")" --model haiku --output-format text --append-system-prompt "Be deterministic. Output only valid JSON. No markdown fences." 2>"$cli_stderr" </dev/null) || {
            _parse_diag="claude CLI exit code $?; stderr: $(head -5 "$cli_stderr" 2>/dev/null)"
            result=""
        }
        # If --output-format text is not supported, retry without it
        if [[ -z "$result" && -s "$cli_stderr" ]] && grep -qi 'output-format\|unknown.*flag\|unrecognized' "$cli_stderr" 2>/dev/null; then
            result=$(claude -p "$(cat "$tmp_file")" --model haiku --append-system-prompt "Be deterministic. Output only valid JSON. No markdown fences." 2>/dev/null </dev/null) || result=""
            _parse_diag=""
        fi
        rm -f "$tmp_file" "$cli_stderr"
    else
        # Direct API call with temperature 0 for deterministic output
        # Try structured output via tool_use first (guaranteed valid JSON)
        local use_structured=true
        local payload response
        if [[ "$use_structured" == true ]]; then
            payload=$(jq -n \
                --arg prompt "$prompt" \
                '{
                    model:"claude-haiku-4-5-20251001",
                    max_tokens:4096,
                    temperature:0,
                    tool_choice:{type:"tool",name:"audit_result"},
                    tools:[{
                        name:"audit_result",
                        description:"Top 0.01% product engineer code review — subjective judgment grounded in deep experience",
                        input_schema:{
                            type:"object",
                            properties:{
                                delivery_score:{type:"integer",description:"Delivery 0-100: does this feature deliver real value to the target user?"},
                                craft_score:{type:"integer",description:"Craft 0-100: is this well-made — both code quality and experience quality?"},
                                viability_score:{type:"integer",description:"Viability 0-100: would this survive the market — alternatives, novelty, adoption odds?"},
                                gaps:{type:"array",items:{type:"string"},description:"Specific problems with file:line citations"},
                                strengths:{type:"array",items:{type:"string"},description:"What genuinely works well"},
                                evidence:{type:"string",description:"1-2 sentence overall judgment"}
                            },
                            required:["delivery_score","craft_score","viability_score","gaps","strengths","evidence"]
                        }
                    }],
                    messages:[{role:"user",content:$prompt}]
                }')
            response=$(curl -s "https://api.anthropic.com/v1/messages" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                -H "content-type: application/json" \
                -d "$payload" 2>/dev/null)

            # Check for API errors first
            local api_error
            api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
            if [[ -n "$api_error" ]]; then
                _parse_diag="API error: $api_error"
                result=""
            else
                # Check stop_reason — max_tokens means truncated response
                local stop_reason
                stop_reason=$(echo "$response" | jq -r '.stop_reason // empty' 2>/dev/null)

                # Extract tool_use input (structured JSON)
                result=$(echo "$response" | jq -c '.content[] | select(.type=="tool_use") | .input // empty' 2>/dev/null)
                if [[ -n "$result" && "$result" != "null" && "$result" != "" ]]; then
                    # Structured output — already valid JSON
                    :
                elif [[ "$stop_reason" == "max_tokens" ]]; then
                    # Response was truncated — try to extract partial text content
                    _parse_diag="API response truncated (stop_reason: max_tokens)"
                    result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
                else
                    # Structured output failed — fall back to plain text
                    result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
                    [[ -z "$result" ]] && _parse_diag="API response had no tool_use or text content"
                fi
            fi
        else
            payload=$(jq -n \
                --arg prompt "$prompt" \
                '{model:"claude-haiku-4-5-20251001",max_tokens:2048,temperature:0,messages:[{role:"user",content:$prompt}]}')
            response=$(curl -s "https://api.anthropic.com/v1/messages" \
                -H "x-api-key: $api_key" \
                -H "anthropic-version: 2023-06-01" \
                -H "content-type: application/json" \
                -d "$payload" 2>/dev/null)
            # Check for API errors
            local api_error
            api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
            if [[ -n "$api_error" ]]; then
                _parse_diag="API error: $api_error"
                result=""
            else
                result=$(echo "$response" | jq -r '.content[0].text // empty' 2>/dev/null)
            fi
        fi
    fi

    # Parse the JSON response — robust extraction handles common LLM output formats
    if [[ -n "$result" ]]; then
        # Strip markdown fences: ```json, ```, and variations
        # Handles: leading whitespace, trailing whitespace, language tags, ````-style fences
        local cleaned
        cleaned=$(echo "$result" | sed -E '/^[[:space:]]*`{3,}[a-zA-Z]*[[:space:]]*$/d')
        # Also strip leading/trailing whitespace lines
        cleaned=$(echo "$cleaned" | sed -e '/^[[:space:]]*$/d')

        # Try 1: full response is valid JSON
        if echo "$cleaned" | jq -c . &>/dev/null 2>&1; then
            local parsed
            parsed=$(echo "$cleaned" | jq -c .)
            _validate_and_emit "$parsed"
            return
        fi

        # Try 2: extract from first { to last } on their own lines
        local json_part
        json_part=$(echo "$cleaned" | sed -n '/^[[:space:]]*{/,/^[[:space:]]*}/p')
        if [[ -n "$json_part" ]] && echo "$json_part" | jq -c . &>/dev/null 2>&1; then
            _validate_and_emit "$(echo "$json_part" | jq -c .)"
            return
        fi

        # Try 3: extract from first { to last } anywhere (not just line-start)
        json_part=$(echo "$cleaned" | sed -n '/[[:space:]]*{/,/}[[:space:]]*$/p')
        if [[ -n "$json_part" ]] && echo "$json_part" | jq -c . &>/dev/null 2>&1; then
            _validate_and_emit "$(echo "$json_part" | jq -c .)"
            return
        fi

        # Try 4: use python3 to extract first valid JSON object (most robust)
        json_part=$(echo "$cleaned" | python3 -c '
import sys, json, re
text = sys.stdin.read()
# Find all potential JSON objects by matching { to }
depth = 0
start = -1
for i, c in enumerate(text):
    if c == "{":
        if depth == 0:
            start = i
        depth += 1
    elif c == "}":
        depth -= 1
        if depth == 0 and start >= 0:
            candidate = text[start:i+1]
            try:
                obj = json.loads(candidate)
                if isinstance(obj, dict) and ("delivery_score" in obj or "score" in obj):
                    print(json.dumps(obj, separators=(",",":")))
                    sys.exit(0)
            except json.JSONDecodeError:
                pass
            start = -1
# If no object with scores found, try any valid JSON object
depth = 0
start = -1
for i, c in enumerate(text):
    if c == "{":
        if depth == 0:
            start = i
        depth += 1
    elif c == "}":
        depth -= 1
        if depth == 0 and start >= 0:
            candidate = text[start:i+1]
            try:
                obj = json.loads(candidate)
                if isinstance(obj, dict):
                    print(json.dumps(obj, separators=(",",":")))
                    sys.exit(0)
            except json.JSONDecodeError:
                pass
            start = -1
' 2>/dev/null)
        if [[ -n "$json_part" ]] && echo "$json_part" | jq -c . &>/dev/null 2>&1; then
            _validate_and_emit "$(echo "$json_part" | jq -c .)"
            return
        fi

        # Try 5: use perl to extract first balanced JSON object (handles multi-line, nested braces)
        json_part=$(echo "$cleaned" | perl -0777 -ne 'if (/(\{(?:[^{}]|(?:\{(?:[^{}]|\{[^{}]*\})*\}))*\})/s) { print $1 }' 2>/dev/null)
        if [[ -n "$json_part" ]] && echo "$json_part" | jq -c . &>/dev/null 2>&1; then
            _validate_and_emit "$(echo "$json_part" | jq -c .)"
            return
        fi

        # Try 6: grep any single-line JSON object containing "delivery_score" or "score"
        json_part=$(echo "$cleaned" | grep -o '{[^}]*"delivery_score"[^}]*}' | head -1)
        [[ -z "$json_part" ]] && json_part=$(echo "$cleaned" | grep -o '{[^}]*"score"[^}]*}' | head -1)
        if [[ -n "$json_part" ]] && echo "$json_part" | jq -c . &>/dev/null 2>&1; then
            _validate_and_emit "$(echo "$json_part" | jq -c .)"
            return
        fi

        # Try 7: extract sub-scores or single score from free text and build JSON
        local extracted_value extracted_quality extracted_ux extracted_verdict
        # Match both quoted and unquoted key names, colon with optional spaces
        extracted_value=$(echo "$cleaned" | grep -oE '("|'"'"')?delivery_score("|'"'"')?\s*:\s*[0-9]+' | head -1 | grep -oE '[0-9]+$')
        extracted_quality=$(echo "$cleaned" | grep -oE '("|'"'"')?craft_score("|'"'"')?\s*:\s*[0-9]+' | head -1 | grep -oE '[0-9]+$')
        extracted_ux=$(echo "$cleaned" | grep -oE '("|'"'"')?viability_score("|'"'"')?\s*:\s*[0-9]+' | head -1 | grep -oE '[0-9]+$')
        extracted_verdict=$(echo "$cleaned" | grep -oiE '("|'"'"')?verdict("|'"'"')?\s*:\s*"[A-Z]+"' | head -1 | grep -oE '"[A-Z]+"$' | tr -d '"')
        if [[ -n "$extracted_value" ]]; then
            echo "{\"delivery_score\":${extracted_value},\"craft_score\":${extracted_quality:-${extracted_value}},\"viability_score\":${extracted_ux:-${extracted_value}},\"verdict\":\"${extracted_verdict:-PARTIAL}\",\"gaps\":[\"response required free-text extraction — audit may be incomplete\"],\"strengths\":[],\"evidence\":\"parsed from non-JSON response\"}" | _apply_logic_antisycophancy
            return
        fi
        # Legacy fallback: single score
        local extracted_score
        extracted_score=$(echo "$cleaned" | grep -oE '("|'"'"')?score("|'"'"')?\s*:\s*[0-9]+' | head -1 | grep -oE '[0-9]+$')
        if [[ -n "$extracted_score" ]]; then
            echo "{\"delivery_score\":${extracted_score},\"craft_score\":${extracted_score},\"viability_score\":${extracted_score},\"verdict\":\"${extracted_verdict:-PARTIAL}\",\"gaps\":[\"response required free-text extraction — audit may be incomplete\"],\"strengths\":[],\"evidence\":\"parsed from non-JSON response\"}" | _apply_logic_antisycophancy
            return
        fi

        # All parsing attempts failed — log diagnostic
        _parse_diag="${_parse_diag:+$_parse_diag; }response length: ${#result}; first 200 chars: $(echo "$result" | head -c 200)"
    fi

    # Fallback: couldn't parse at all — log diagnostic to stderr
    if [[ -n "$_parse_diag" ]]; then
        echo "[eval] ${feat_name:-unknown}: LLM response unparseable — ${_parse_diag}" >&2
    else
        echo "[eval] ${feat_name:-unknown}: LLM returned empty response (no API key? CLI unavailable?)" >&2
    fi
    echo '{"delivery_score":30,"craft_score":30,"viability_score":30,"score":30,"verdict":"PARTIAL","gaps":["could not evaluate — LLM response unparseable"],"evidence":"eval failed"}'
}

# Validate parsed JSON has expected score fields, then emit through antisycophancy filter
# Usage: _validate_and_emit '{"delivery_score":55,...}'
_validate_and_emit() {
    local json="$1"

    # Ensure delivery_score exists and is a number
    local ds cs vs
    ds=$(echo "$json" | jq -r '.delivery_score // empty' 2>/dev/null)
    cs=$(echo "$json" | jq -r '.craft_score // empty' 2>/dev/null)
    vs=$(echo "$json" | jq -r '.viability_score // empty' 2>/dev/null)

    # If sub-scores are missing but legacy .score exists, derive from it
    if [[ -z "$ds" || ! "$ds" =~ ^[0-9]+$ ]]; then
        local legacy
        legacy=$(echo "$json" | jq -r '.score // empty' 2>/dev/null)
        if [[ -n "$legacy" && "$legacy" =~ ^[0-9]+$ ]]; then
            # Convert 1-5 scale to 0-100 if needed
            [[ "$legacy" -le 5 ]] && legacy=$((legacy * 20))
            # Use legacy score for any missing/non-numeric sub-scores
            local safe_cs="${cs}"
            local safe_vs="${vs}"
            [[ -z "$safe_cs" || ! "$safe_cs" =~ ^[0-9]+$ ]] && safe_cs="$legacy"
            [[ -z "$safe_vs" || ! "$safe_vs" =~ ^[0-9]+$ ]] && safe_vs="$legacy"
            json=$(echo "$json" | jq -c --argjson d "$legacy" --argjson c "$safe_cs" --argjson v "$safe_vs" \
                '.delivery_score = $d | .craft_score = $c | .viability_score = $v' 2>/dev/null) || true
        fi
    fi

    # Clamp scores to 0-100 range (LLMs occasionally return negatives or >100)
    json=$(echo "$json" | jq -c '
        def clamp: if . < 0 then 0 elif . > 100 then 100 else . end;
        if .delivery_score then .delivery_score = (.delivery_score | clamp) else . end |
        if .craft_score then .craft_score = (.craft_score | clamp) else . end |
        if .viability_score then .viability_score = (.viability_score | clamp) else . end
    ' 2>/dev/null) || true

    # Ensure gaps is an array (LLMs sometimes return a string)
    json=$(echo "$json" | jq -c '
        if (.gaps | type) == "string" then .gaps = [.gaps]
        elif (.gaps | type) != "array" then .gaps = []
        else . end
    ' 2>/dev/null) || true

    echo "$json" | _apply_logic_antisycophancy
}

# Anti-sycophancy filter for audit results (0-100 scale)
# Reads JSON from stdin, applies integrity checks on sub-scores,
# computes weighted total, outputs corrected JSON with .score field
_apply_logic_antisycophancy() {
    local input
    input=$(cat)

    # Extract sub-scores (fall back to legacy .score if sub-scores missing)
    local delivery_score craft_score viability_score
    delivery_score=$(echo "$input" | jq -r '.delivery_score // empty' 2>/dev/null)
    craft_score=$(echo "$input" | jq -r '.craft_score // empty' 2>/dev/null)
    viability_score=$(echo "$input" | jq -r '.viability_score // empty' 2>/dev/null)

    # Legacy fallback: if no sub-scores, derive from single .score
    if [[ -z "$delivery_score" || -z "$craft_score" || -z "$viability_score" ]]; then
        local legacy_score
        legacy_score=$(echo "$input" | jq -r '.score // 50' 2>/dev/null)
        [[ "$legacy_score" -le 5 ]] && legacy_score=$((legacy_score * 20))
        delivery_score="${delivery_score:-$legacy_score}"
        craft_score="${craft_score:-$legacy_score}"
        viability_score="${viability_score:-$legacy_score}"
        input=$(echo "$input" | jq -c --argjson v "$delivery_score" --argjson q "$craft_score" --argjson u "$viability_score" \
            '.delivery_score = $v | .craft_score = $q | .viability_score = $u')
    fi

    # Normalize: if any score came back on 1-5 scale, convert to 0-100
    [[ "$delivery_score" -le 5 ]] && delivery_score=$((delivery_score * 20))
    [[ "$craft_score" -le 5 ]] && craft_score=$((craft_score * 20))
    [[ "$viability_score" -le 5 ]] && viability_score=$((viability_score * 20))

    local gap_count
    gap_count=$(echo "$input" | jq -r '.gaps | length // 0' 2>/dev/null)

    # 0 gaps found → auditor didn't look hard enough. Cap all at 60.
    if [[ "$gap_count" -eq 0 ]]; then
        [[ "$delivery_score" -gt 60 ]] && delivery_score=60
        [[ "$craft_score" -gt 60 ]] && craft_score=60
        [[ "$viability_score" -gt 60 ]] && viability_score=60
        input=$(echo "$input" | jq -c '.gaps += ["integrity: 0 problems found — audit was not thorough enough"]')
    fi

    # Any sub-score > 80 with gaps → cap that sub-score at 75
    if [[ "$gap_count" -gt 0 ]]; then
        [[ "$delivery_score" -gt 80 ]] && delivery_score=75
        [[ "$craft_score" -gt 80 ]] && craft_score=75
        [[ "$viability_score" -gt 80 ]] && viability_score=75
    fi

    # Any sub-score > 70 with 3+ gaps → cap at 65
    if [[ "$gap_count" -ge 3 ]]; then
        [[ "$delivery_score" -gt 70 ]] && delivery_score=65
        [[ "$craft_score" -gt 70 ]] && craft_score=65
        [[ "$viability_score" -gt 70 ]] && viability_score=65
    fi

    # Stage cap: read project stage from rhino.yml
    local stage_cap=100
    if [[ -f "config/rhino.yml" ]]; then
        local stage
        stage=$(grep 'stage:' config/rhino.yml 2>/dev/null | head -1 | sed 's/.*stage: *//')
        case "$stage" in
            mvp)    stage_cap=65 ;;
            early)  stage_cap=75 ;;
            growth) stage_cap=85 ;;
            mature) stage_cap=95 ;;
        esac
    fi
    [[ "$delivery_score" -gt "$stage_cap" ]] && delivery_score="$stage_cap"
    [[ "$craft_score" -gt "$stage_cap" ]] && craft_score="$stage_cap"
    [[ "$viability_score" -gt "$stage_cap" ]] && viability_score="$stage_cap"

    # Compute weighted total in bash (not LLM): delivery*0.5 + craft*0.3 + viability*0.2
    local score=$(( delivery_score * 50 / 100 + craft_score * 30 / 100 + viability_score * 20 / 100 ))

    # Stage cap on total too
    [[ "$score" -gt "$stage_cap" ]] && score="$stage_cap"

    if [[ "$gap_count" -gt 0 && "$score" -gt 80 ]]; then
        input=$(echo "$input" | jq -c '.gaps += ["integrity: score capped — gaps exist"]')
        score=75
    fi

    # Write all scores back
    input=$(echo "$input" | jq -c --argjson v "$delivery_score" --argjson q "$craft_score" --argjson u "$viability_score" --argjson s "$score" \
        '.delivery_score = $v | .craft_score = $q | .viability_score = $u | .score = $s')

    echo "$input"
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

    while IFS='|' read -r feat_name delivers for_whom code_paths feat_commands; do
        [[ -z "$feat_name" ]] && continue

        # Feature filter
        if [[ -n "$FEATURE_FILTER" && "$feat_name" != "$FEATURE_FILTER" ]]; then
            continue
        fi

        # Check cache first
        local cached
        cached=$(check_eval_cache "$feat_name")

        local verdict="" gaps="" evidence="" feat_score=""
        local delivery_score="" craft_score="" viability_score=""

        if [[ -n "$cached" && "$cached" != "" ]]; then
            verdict=$(echo "$cached" | jq -r '.verdict // "PARTIAL"' 2>/dev/null)
            gaps=$(echo "$cached" | jq -r '.gaps // [] | join("; ")' 2>/dev/null)
            evidence=$(echo "$cached" | jq -r '.evidence // ""' 2>/dev/null)
            feat_score=$(echo "$cached" | jq -r '.score // 50' 2>/dev/null)
            delivery_score=$(echo "$cached" | jq -r '.delivery_score // empty' 2>/dev/null)
            craft_score=$(echo "$cached" | jq -r '.craft_score // empty' 2>/dev/null)
            viability_score=$(echo "$cached" | jq -r '.viability_score // empty' 2>/dev/null)
        else
            # Gather code and call Claude
            local code_context
            code_context=$(gather_code_context "$code_paths" "$feat_name")

            if [[ -n "$code_context" ]]; then
                # Generate per-feature rubric (async, cached 24h) — runs in background for next eval
                generate_feature_rubric "$feat_name" "$delivers" "$for_whom" "$code_context" &
                local judge_result best_result
                # Multi-sample median: run N times, take median score
                local n_samples="${EVAL_SAMPLES:-3}"
                if [[ "$n_samples" -le 1 ]]; then
                    judge_result=$(run_logic_research "$feat_name" "$delivers" "$for_whom" "$code_context")
                else
                    local sample_scores=() sample_results=()
                    for ((si=0; si<n_samples; si++)); do
                        local sample
                        sample=$(run_logic_research "$feat_name" "$delivers" "$for_whom" "$code_context")
                        local s_score
                        s_score=$(echo "$sample" | jq -r '.score // 50' 2>/dev/null)
                        [[ -z "$s_score" || ! "$s_score" =~ ^[0-9]+$ ]] && s_score=50
                        sample_scores+=("$s_score")
                        sample_results+=("$sample")
                    done
                    # Sort scores and pick median index
                    local sorted_indices
                    sorted_indices=$(for i in "${!sample_scores[@]}"; do echo "$i ${sample_scores[$i]}"; done | sort -k2 -n | awk '{print $1}')
                    local median_idx
                    median_idx=$(echo "$sorted_indices" | sed -n "$((n_samples / 2 + 1))p")
                    judge_result="${sample_results[$median_idx]}"
                fi
                verdict=$(echo "$judge_result" | jq -r '.verdict // "PARTIAL"' 2>/dev/null)
                gaps=$(echo "$judge_result" | jq -r '.gaps // [] | join("; ")' 2>/dev/null)
                evidence=$(echo "$judge_result" | jq -r '.evidence // ""' 2>/dev/null)
                feat_score=$(echo "$judge_result" | jq -r '.score // 50' 2>/dev/null)
                delivery_score=$(echo "$judge_result" | jq -r '.delivery_score // empty' 2>/dev/null)
                craft_score=$(echo "$judge_result" | jq -r '.craft_score // empty' 2>/dev/null)
                viability_score=$(echo "$judge_result" | jq -r '.viability_score // empty' 2>/dev/null)
            else
                verdict="MISSING"
                gaps="no code files found"
                evidence=""
                feat_score=0
                delivery_score=0
                craft_score=0
                viability_score=0
            fi
        fi

        # Pairwise delta tracking: compare against previous eval
        local delta="" delta_vs=""
        if [[ -f "$EVAL_CACHE_FILE" ]] && command -v jq &>/dev/null; then
            local prev_score
            prev_score=$(jq -r ".\"$feat_name\".score // empty" "$EVAL_CACHE_FILE" 2>/dev/null)
            if [[ -n "$prev_score" && "$prev_score" =~ ^[0-9]+$ && -n "$feat_score" && "$feat_score" =~ ^[0-9]+$ ]]; then
                delta_vs="$prev_score"
                local diff=$(( feat_score - prev_score ))
                if [[ "$diff" -gt 3 ]]; then
                    delta="better"
                elif [[ "$diff" -lt -3 ]]; then
                    delta="worse"
                else
                    delta="same"
                fi
            fi
        fi

        # Track as numeric score (0-100)
        # -1 signals eval failure — don't mask with a plausible number
        if [[ -z "$feat_score" || "$feat_score" == "null" ]]; then
            feat_score=-1
            GENERATIVE_DISPLAY+=("${feat_name}|-1|${delivers}|eval failed: no score returned|")
            continue
        fi
        # Normalize: if score came back on 1-5 scale, convert to 0-100
        if [[ "$feat_score" -le 5 ]]; then
            feat_score=$((feat_score * 20))
        fi
        GENERATIVE_SCORES="${GENERATIVE_SCORES}${feat_name}:${feat_score}
"
        GENERATIVE_COUNT=$((GENERATIVE_COUNT + 1))
        GENERATIVE_SUM=$((GENERATIVE_SUM + feat_score))

        # Accumulate for display (include sub-scores)
        if [[ "$SCORE_MODE" != "true" ]]; then
            local _sub_scores=""
            [[ -n "$delivery_score" && "$delivery_score" != "null" ]] && _sub_scores="d:${delivery_score}"
            [[ -n "$craft_score" && "$craft_score" != "null" ]] && _sub_scores="${_sub_scores:+${_sub_scores} }c:${craft_score}"
            [[ -n "$viability_score" && "$viability_score" != "null" ]] && _sub_scores="${_sub_scores:+${_sub_scores} }v:${viability_score}"
            GENERATIVE_DISPLAY+=("${feat_name}|${feat_score}|${delivers}|${gaps}|${_sub_scores}")
        fi

        # Build cache entry with sub-scores and delta
        $cache_first || cache_json+=","
        local cache_extras=""
        [[ -n "$delivery_score" ]] && cache_extras+=",\"delivery_score\":${delivery_score}"
        [[ -n "$craft_score" ]] && cache_extras+=",\"craft_score\":${craft_score}"
        [[ -n "$viability_score" ]] && cache_extras+=",\"viability_score\":${viability_score}"
        [[ -n "$delta" ]] && cache_extras+=",\"delta\":\"${delta}\""
        [[ -n "$delta_vs" ]] && cache_extras+=",\"delta_vs\":${delta_vs}"
        # Use printf %s to avoid trailing newline that contaminates jq -Rs output
        cache_json+="\"$feat_name\":{\"verdict\":$(printf '%s' "$verdict" | jq -Rs .),\"gaps\":$(if [[ -n "$gaps" ]]; then printf '%s' "$gaps" | jq -Rs 'split("; ") | map(select(length > 0))'; else echo '[]'; fi),\"evidence\":$(printf '%s' "$evidence" | jq -Rs .),\"score\":${feat_score:-50}${cache_extras},\"cached_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
        cache_first=false
    done <<< "$features_data"

    cache_json+="}"

    # Wait for background rubric generation to finish
    wait 2>/dev/null || true

    # Write cache
    echo "$cache_json" > "$EVAL_CACHE_FILE" 2>/dev/null || true

    # Write delta history
    local delta_file="$EVAL_CACHE_DIR/eval-deltas.json"
    if command -v jq &>/dev/null; then
        local delta_entry
        delta_entry=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        # Build delta JSON using jq directly (avoids subshell variable mutation bug)
        local delta_features_json
        delta_features_json=$(echo "$cache_json" | jq -c '[to_entries[] | {key: .key, value: {score: (.value.score // 0), delta: (.value.delta // "unknown"), vs: (.value.delta_vs // null)}}] | from_entries' 2>/dev/null) || delta_features_json="{}"
        local delta_json
        delta_json=$(jq -nc --arg ts "$delta_entry" --argjson feats "$delta_features_json" '{timestamp: $ts, features: $feats}')

        # Append to delta history (keep last 50 entries)
        if [[ -f "$delta_file" ]]; then
            jq -c --argjson new "$delta_json" '. + [$new] | .[-50:]' "$delta_file" > "${delta_file}.tmp" 2>/dev/null && mv "${delta_file}.tmp" "$delta_file" 2>/dev/null || echo "[$delta_json]" > "$delta_file" 2>/dev/null || true
        else
            echo "[$delta_json]" > "$delta_file" 2>/dev/null || true
        fi
    fi
}

# === Run generative eval ===
# HAS_FEATURES already detected earlier (before header)
# ONLY run on explicit eval calls (not --score mode).
# Score mode uses cached results if available, skips otherwise.
# This keeps `rhino score .` fast and free (no LLM calls).
if [[ "$HAS_FEATURES" == true && "$SCORE_MODE" != "true" && "$NO_GENERATIVE" != "true" ]]; then
    run_generative_eval
elif [[ "$HAS_FEATURES" == true && "$SCORE_MODE" == "true" && "$NO_GENERATIVE" != "true" ]]; then
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
                # Expand ~ to $HOME, resolve relative paths against project root
                local expanded_path="${belief_path/#\~/$HOME}"
                if [[ "$expanded_path" != /* ]]; then
                    expanded_path="${PROJECT_ROOT}/${expanded_path}"
                fi
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
            # In --score or --no-llm mode: count as WARN (not invisible)
            # This prevents inflated scores when LLM checks haven't run
            if [[ "$SCORE_MODE" == "true" || "$NO_LLM" == "true" ]]; then
                check_warn "$belief_id" "llm_judge: not evaluated (run rhino eval . for full score)"
            elif [[ -n "$belief_prompt" ]]; then
                local judge_context=""
                # Gather context from specified paths or feature files
                if [[ -n "$belief_path" ]]; then
                    local expanded_path="${belief_path/#\~/$HOME}"
                    # Resolve relative paths against project root
                    if [[ "$expanded_path" != /* ]]; then
                        expanded_path="${PROJECT_ROOT}/${expanded_path}"
                    fi
                    if [[ -f "$expanded_path" ]]; then
                        judge_context=$(head -500 "$expanded_path" 2>/dev/null)
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
                        # Direct API call with curl (faster, no CLI overhead, temperature 0)
                        local judge_payload
                        judge_payload=$(jq -n \
                            --arg prompt "$belief_prompt" \
                            --arg context "$(echo "$judge_context" | head -500)" \
                            '{model:"claude-haiku-4-5-20251001",max_tokens:100,temperature:0,messages:[{role:"user",content:("Evaluate this code. Answer ONLY pass or fail on the first line, then a one-sentence reason on the second line.\n\nQuestion: " + $prompt + "\n\nCode:\n" + $context)}]}')
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
            # In --score or --no-llm mode: count as WARN (not invisible)
            if [[ "$SCORE_MODE" == "true" || "$NO_LLM" == "true" ]]; then
                check_warn "$belief_id" "feature_review: not evaluated (run rhino eval . for full score)"
            else

            # Gather code context for the feature
            local review_context=""
            if [[ -n "$belief_path" ]]; then
                local expanded_path="${belief_path/#\~/$HOME}"
                # Resolve relative paths against project root
                if [[ "$expanded_path" != /* ]]; then
                    expanded_path="${PROJECT_ROOT}/${expanded_path}"
                fi
                if [[ -f "$expanded_path" ]]; then
                    review_context=$(head -500 "$expanded_path" 2>/dev/null)
                elif [[ -d "$expanded_path" ]]; then
                    review_context=$(find "$expanded_path" -type f \( -name "*.sh" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.mjs" -o -name "*.yml" -o -name "*.md" \) ! -path "*/node_modules/*" 2>/dev/null | head -10 | while read -r f; do
                        echo "=== $f ==="
                        head -150 "$f" 2>/dev/null
                    done)
                fi
            elif [[ -n "$belief_feature" ]]; then
                # Auto-discover: find files related to this feature
                review_context=$(grep -rl "$belief_feature" bin/ skills/ lens/ config/ 2>/dev/null | grep -v node_modules | head -8 | while read -r f; do
                    echo "=== $f ==="
                    head -150 "$f" 2>/dev/null
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
                    '{model:"claude-haiku-4-5-20251001",max_tokens:500,temperature:0,messages:[{role:"user",content:$prompt}]}')
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
            fi  # end SCORE_MODE/NO_LLM check
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
            # Commands run in the project directory, not rhino-os
            if [[ -n "$belief_command" ]]; then
                local cmd_output
                cmd_output=$(cd "$PROJECT_ROOT" && eval "$belief_command" 2>&1) && \
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
                local blind_script=""
                for _bs in "$RHINO_DIR"/lens/*/eval/blind-eval.mjs; do
                    [[ -f "$_bs" ]] && blind_script="$_bs" && break
                done
                [[ -z "$blind_script" ]] && blind_script="$RHINO_DIR/bin/blind-eval.mjs"
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
        assertion_trend)
            # Check if assertions are graduating (fail→pass) over time
            # Reads eval cache history to see if assertions improve across sessions
            local trend_direction="${belief_direction:-graduating}"
            local trend_window="${belief_window:-5}"
            local history_file=".claude/scores/history.tsv"
            if [[ -f "$history_file" ]]; then
                local hist_lines
                hist_lines=$(wc -l < "$history_file" | tr -d ' ')
                if [[ "$hist_lines" -le 2 ]]; then
                    check_warn "$belief_id" "assertion_trend: not enough history (${hist_lines} entries)"
                else
                    # Check if pass count is increasing over last N entries
                    local scores
                    scores=$(tail -n "$trend_window" "$history_file" | cut -f5 | grep -E '^[0-9]+$')
                    local first_score last_score
                    first_score=$(echo "$scores" | head -1)
                    last_score=$(echo "$scores" | tail -1)
                    if [[ "$trend_direction" == "graduating" ]]; then
                        if [[ -n "$first_score" && -n "$last_score" && "$last_score" -ge "$first_score" ]]; then
                            check_pass "$belief_id" "assertions graduating: ${first_score} → ${last_score}"
                        else
                            check_fail "$belief_id" "assertions not graduating: ${first_score:-?} → ${last_score:-?}" "warn" 3
                        fi
                    elif [[ "$trend_direction" == "not_regressing" ]]; then
                        if [[ -n "$first_score" && -n "$last_score" && "$last_score" -ge "$((first_score - 5))" ]]; then
                            check_pass "$belief_id" "assertions stable: ${first_score} → ${last_score}"
                        else
                            check_fail "$belief_id" "assertions regressing: ${first_score:-?} → ${last_score:-?}" "warn" 3
                        fi
                    fi
                fi
            else
                check_warn "$belief_id" "assertion_trend: no history.tsv found"
            fi
            ;;
        session_continuity)
            # Check if the system is being used regularly (files modified recently)
            local max_gap="${belief_max_gap_days:-14}"
            local now
            now=$(date +%s)
            local most_recent=0
            for _sc_file in .claude/plans/plan.yml ~/.claude/knowledge/predictions.tsv .claude/scores/history.tsv; do
                local _sc_expanded="${_sc_file/#\~/$HOME}"
                if [[ -f "$_sc_expanded" ]]; then
                    local _sc_mtime
                    _sc_mtime=$(file_mtime "$_sc_expanded")
                    _sc_mtime="${_sc_mtime:-0}"
                    [[ "$_sc_mtime" -gt "$most_recent" ]] && most_recent="$_sc_mtime"
                fi
            done
            if [[ "$most_recent" -eq 0 ]]; then
                check_warn "$belief_id" "session_continuity: no trackable files found"
            else
                local gap_days=$(( (now - most_recent) / 86400 ))
                if [[ "$gap_days" -le "$max_gap" ]]; then
                    check_pass "$belief_id" "last session ${gap_days} days ago (max ${max_gap})"
                else
                    check_fail "$belief_id" "last session ${gap_days} days ago (max ${max_gap})" "warn" 3
                fi
            fi
            ;;
        value_velocity)
            # Check how fast score improves from baseline (time between history entries)
            local history_file=".claude/scores/history.tsv"
            if [[ -f "$history_file" ]]; then
                local hist_lines
                hist_lines=$(wc -l < "$history_file" | tr -d ' ')
                if [[ "$hist_lines" -le 2 ]]; then
                    check_warn "$belief_id" "value_velocity: not enough history"
                else
                    # Check if score improved between first and last entry
                    local first_score last_score
                    first_score=$(sed -n '2p' "$history_file" | cut -f5)
                    last_score=$(tail -1 "$history_file" | cut -f5)
                    if [[ -n "$first_score" && -n "$last_score" && "$first_score" =~ ^[0-9]+$ && "$last_score" =~ ^[0-9]+$ ]]; then
                        local delta=$((last_score - first_score))
                        if [[ "$delta" -gt 0 ]]; then
                            check_pass "$belief_id" "score improved by ${delta} points (${first_score} → ${last_score})"
                        elif [[ "$delta" -eq 0 ]]; then
                            check_warn "$belief_id" "value_velocity: score unchanged (${first_score})"
                        else
                            check_fail "$belief_id" "score declined by ${delta#-} points (${first_score} → ${last_score})" "warn" 3
                        fi
                    else
                        check_warn "$belief_id" "value_velocity: could not parse scores"
                    fi
                fi
            else
                check_warn "$belief_id" "value_velocity: no history.tsv found"
            fi
            ;;
    esac

    # Track per-feature results
    local _feat="${belief_feature:-unscoped}"
    local _dp=$((PASS - _pre_pass)) _dw=$((WARN - _pre_warn)) _df=$((FAIL - _pre_fail))
    FEATURE_RESULTS="${FEATURE_RESULTS}${_feat}:${_dp}:${_dw}:${_df}
"
    # Track per-feature~quality results
    local _qual="${belief_quality:-unscoped}"
    QUALITY_RESULTS="${QUALITY_RESULTS}${_feat}~${_qual}:${_dp}:${_dw}:${_df}
"
    # Track per-feature~layer results
    local _layer="${belief_layer:-unscoped}"
    LAYER_RESULTS="${LAYER_RESULTS}${_feat}~${_layer}:${_dp}:${_dw}:${_df}
"
    # Track assertion history (for /eval trend)
    local _ah_status="PASS"
    if [[ "$_df" -gt 0 ]]; then _ah_status="FAIL"
    elif [[ "$_dw" -gt 0 ]]; then _ah_status="WARN"
    fi
    ASSERTION_HISTORY="${ASSERTION_HISTORY}$(date '+%Y-%m-%d')\t${_feat}\t${belief_id}\t${belief_type:-unknown}\t${_ah_status}\twarn
"
}

# === beliefs.yml checks (parser extracted to bin/lib/beliefs-parser.sh) ===

source "$RHINO_DIR/bin/lib/beliefs-parser.sh"

BELIEFS_FILE=""
for bf in lens/*/eval/beliefs.yml "config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS_FILE="$bf" && break
done
if [[ -f "$BELIEFS_FILE" ]]; then
    parse_beliefs_file "$BELIEFS_FILE"
fi

# === Write assertion history (for /eval trend) ===
if [[ -n "$ASSERTION_HISTORY" && "$SCORE_MODE" != "true" ]]; then
    ASSERTION_HISTORY_FILE=".claude/evals/assertion-history.tsv"
    mkdir -p "$(dirname "$ASSERTION_HISTORY_FILE")"
    if [[ ! -f "$ASSERTION_HISTORY_FILE" ]]; then
        printf 'date\tfeature\tassertion_id\ttype\tstatus\tseverity\n' > "$ASSERTION_HISTORY_FILE"
    fi
    printf '%b' "$ASSERTION_HISTORY" >> "$ASSERTION_HISTORY_FILE"
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

    # Aggregate per-feature~quality results
    _fq_tmpdir=$(mktemp -d)
    while IFS=: read -r _fq_key _fq_p _fq_w _fq_f; do
        [[ -z "$_fq_key" ]] && continue
        # _fq_key is "feature~quality"
        _fq_feat="${_fq_key%%~*}"
        _fq_qual="${_fq_key##*~}"
        [[ "$_fq_qual" == "unscoped" ]] && continue
        mkdir -p "$_fq_tmpdir/$_fq_feat"
        _fq_pp=0; _fq_pw=0; _fq_pf=0
        if [[ -f "$_fq_tmpdir/$_fq_feat/$_fq_qual" ]]; then
            IFS=: read -r _fq_pp _fq_pw _fq_pf < "$_fq_tmpdir/$_fq_feat/$_fq_qual"
        fi
        echo "$((_fq_pp + _fq_p)):$((_fq_pw + _fq_w)):$((_fq_pf + _fq_f))" > "$_fq_tmpdir/$_fq_feat/$_fq_qual"
    done <<< "$QUALITY_RESULTS"

    # Aggregate per-feature~layer results
    _fl_tmpdir=$(mktemp -d)
    while IFS=: read -r _fl_key _fl_p _fl_w _fl_f; do
        [[ -z "$_fl_key" ]] && continue
        _fl_feat="${_fl_key%%~*}"
        _fl_layer="${_fl_key##*~}"
        [[ "$_fl_layer" == "unscoped" ]] && continue
        mkdir -p "$_fl_tmpdir/$_fl_feat"
        _fl_pp=0; _fl_pw=0; _fl_pf=0
        if [[ -f "$_fl_tmpdir/$_fl_feat/$_fl_layer" ]]; then
            IFS=: read -r _fl_pp _fl_pw _fl_pf < "$_fl_tmpdir/$_fl_feat/$_fl_layer"
        fi
        echo "$((_fl_pp + _fl_p)):$((_fl_pw + _fl_w)):$((_fl_pf + _fl_f))" > "$_fl_tmpdir/$_fl_feat/$_fl_layer"
    done <<< "$LAYER_RESULTS"

    # Add generative scores to feature JSON
    while IFS=: read -r _gf_name _gf_score; do
        [[ -z "$_gf_name" ]] && continue
        echo "gen:${_gf_score}" > "$_bf_tmpdir/$_gf_name.gen"
    done <<< "$GENERATIVE_SCORES"

    # Build features JSON with nested quality
    # Collect unique feature names (beliefs + generative merged)
    _bf_names=""
    for _bf_file in "$_bf_tmpdir"/*; do
        [[ ! -f "$_bf_file" ]] && continue
        _bf_n=$(basename "$_bf_file")
        _bf_n="${_bf_n%.gen}"  # strip .gen suffix
        echo "$_bf_n"
    done | sort -u > "$_bf_tmpdir/.names"

    _bf_json="{"
    _bf_first=true
    while IFS= read -r _bf_fname; do
        [[ -z "$_bf_fname" ]] && continue
        $_bf_first || _bf_json+=","
        _bf_first=false

        _has_gen=false; _has_beliefs=false
        _gf_s=0
        _bf_p=0; _bf_w=0; _bf_f=0; _bf_t=0

        # Check for generative score
        if [[ -f "$_bf_tmpdir/$_bf_fname.gen" ]]; then
            _has_gen=true
            _gf_s=$(cut -d: -f2 < "$_bf_tmpdir/$_bf_fname.gen")
        fi

        # Check for beliefs data
        if [[ -f "$_bf_tmpdir/$_bf_fname" ]]; then
            _has_beliefs=true
            IFS=: read -r _bf_p _bf_w _bf_f < "$_bf_tmpdir/$_bf_fname"
            _bf_t=$((_bf_p + _bf_w + _bf_f))
        fi

        # Build quality JSON fragment
        _qual_frag=""
        if [[ -d "$_fq_tmpdir/$_bf_fname" ]]; then
            _qual_frag=",\"quality\":{"
            _bfq_first=true
            for _qdim in correctness craft completeness; do
                if [[ -f "$_fq_tmpdir/$_bf_fname/$_qdim" ]]; then
                    IFS=: read -r _qp _qw _qf < "$_fq_tmpdir/$_bf_fname/$_qdim"
                    _qt=$((_qp + _qw + _qf))
                    [[ "$_qt" -eq 0 ]] && continue
                    $_bfq_first || _qual_frag+=","
                    _qual_frag+="\"$_qdim\":{\"pass\":$_qp,\"total\":$_qt}"
                    _bfq_first=false
                fi
            done
            _qual_frag+="}"
        fi

        # Build layer JSON fragment — compute 1-5 score per layer from pass rates
        _layer_frag=""
        if [[ -d "$_fl_tmpdir/$_bf_fname" ]]; then
            _layer_frag=",\"layers\":{"
            _bfl_first=true
            for _ldim in infrastructure logic ux; do
                if [[ -f "$_fl_tmpdir/$_bf_fname/$_ldim" ]]; then
                    IFS=: read -r _lp _lw _lf < "$_fl_tmpdir/$_bf_fname/$_ldim"
                    _lt=$((_lp + _lw + _lf))
                    [[ "$_lt" -eq 0 ]] && continue
                    # Compute 1-5 from pass rate: 100%=5, 80-99%=4, 60-79%=3, 40-59%=2, <40%=1
                    _lpct=0
                    [[ "$_lt" -gt 0 ]] && _lpct=$((_lp * 100 / _lt))
                    if [[ "$_lpct" -ge 100 ]]; then _lscore=5
                    elif [[ "$_lpct" -ge 80 ]]; then _lscore=4
                    elif [[ "$_lpct" -ge 60 ]]; then _lscore=3
                    elif [[ "$_lpct" -ge 40 ]]; then _lscore=2
                    else _lscore=1
                    fi
                    $_bfl_first || _layer_frag+=","
                    _layer_frag+="\"$_ldim\":{\"score\":$_lscore,\"pass\":$_lp,\"total\":$_lt}"
                    _bfl_first=false
                fi
            done
            _layer_frag+="}"
        fi

        # Infrastructure gates: if infra < 3, cap logic and ux at 2
        if [[ -f "$_fl_tmpdir/$_bf_fname/infrastructure" ]]; then
            IFS=: read -r _gi_p _gi_w _gi_f < "$_fl_tmpdir/$_bf_fname/infrastructure"
            _gi_t=$((_gi_p + _gi_w + _gi_f))
            _gi_pct=0
            [[ "$_gi_t" -gt 0 ]] && _gi_pct=$((_gi_p * 100 / _gi_t))
            if [[ "$_gi_pct" -ge 100 ]]; then _gi_score=5
            elif [[ "$_gi_pct" -ge 80 ]]; then _gi_score=4
            elif [[ "$_gi_pct" -ge 60 ]]; then _gi_score=3
            elif [[ "$_gi_pct" -ge 40 ]]; then _gi_score=2
            else _gi_score=1
            fi
            if [[ "$_gi_score" -lt 3 ]]; then
                # Cap logic and ux layer scores at 2
                for _gated_layer in logic ux; do
                    if echo "$_layer_frag" | grep -q "\"$_gated_layer\""; then
                        _layer_frag=$(echo "$_layer_frag" | sed "s/\"$_gated_layer\":{\"score\":[0-9]*/\"$_gated_layer\":{\"score\":2/")
                    fi
                done
            fi
        fi

        # Use generative score as logic layer score if present and no belief-based logic layer
        if [[ "$_has_gen" == true ]]; then
            if ! echo "$_layer_frag" | grep -q '"logic"'; then
                if [[ -z "$_layer_frag" ]]; then
                    _layer_frag=",\"layers\":{\"logic\":{\"score\":$_gf_s,\"pass\":0,\"total\":0}}"
                else
                    _layer_frag="${_layer_frag%\}},\"logic\":{\"score\":$_gf_s,\"pass\":0,\"total\":0}}"
                fi
            fi
        fi

        if [[ "$_has_gen" == true && "$_has_beliefs" == true ]]; then
            _bf_json+="\"$_bf_fname\":{\"score\":$_gf_s,\"type\":\"generative\",\"pass\":$_bf_p,\"warn\":$_bf_w,\"fail\":$_bf_f,\"total\":$_bf_t${_qual_frag}${_layer_frag}}"
        elif [[ "$_has_gen" == true ]]; then
            _bf_json+="\"$_bf_fname\":{\"score\":$_gf_s,\"type\":\"generative\"${_layer_frag}}"
        else
            _bf_json+="\"$_bf_fname\":{\"pass\":$_bf_p,\"warn\":$_bf_w,\"fail\":$_bf_f,\"total\":$_bf_t${_qual_frag}${_layer_frag}}"
        fi
    done < "$_bf_tmpdir/.names"
    _bf_json+="}"
    rm -rf "$_bf_tmpdir" "$_fq_tmpdir" "$_fl_tmpdir"

    # Merge cached belief quality data (from last full eval run)
    # This fills in craft/completeness dimensions that --score mode skips
    if [[ -f "$BELIEFS_CACHE_FILE" ]] && command -v jq &>/dev/null; then
        _bc_mtime=$(file_mtime "$BELIEFS_CACHE_FILE")
        _bc_age=$(( $(date +%s) - ${_bc_mtime:-0} ))
        if [[ "$_bc_age" -lt 3600 ]]; then
            # Use temp file to avoid shell escaping issues with JSON in --argjson
            _merge_tmp=$(mktemp)
            echo "$_bf_json" > "$_merge_tmp"
            _merged=$(jq -c --slurpfile cache "$BELIEFS_CACHE_FILE" '
                . | to_entries | map(
                    .key as $k |
                    ($cache[0].features[$k].quality // null) as $cached_q |
                    (.value.quality // {}) as $current_q |
                    if $cached_q != null then
                        .value.quality = (
                            ($cached_q | keys) as $all_dims |
                            (($current_q | keys) + $all_dims) | unique | map(
                                . as $dim |
                                ($current_q[$dim] // null) as $cv |
                                ($cached_q[$dim] // null) as $kv |
                                if $cv != null and ($cv.total // 0) > 0 then {($dim): $cv}
                                elif $kv != null then {($dim): $kv}
                                else empty
                                end
                            ) | add // {}
                        ) | .
                    else .
                    end
                ) | from_entries
            ' "$_merge_tmp" 2>/dev/null) || _merged=""
            rm -f "$_merge_tmp"
            [[ -n "$_merged" ]] && _bf_json="$_merged"
        fi
    fi

    # ── Score formula (uses shared compute_eval_score) ──
    _has_block_fail=false
    for _entry in "${BELIEF_FAILS[@]+"${BELIEF_FAILS[@]}"}"; do
        if echo "$_entry" | grep -q '|block$'; then
            _has_block_fail=true
            break
        fi
    done
    _eval_score=$(compute_eval_score "$GENERATIVE_COUNT" "$GENERATIVE_SUM" "$PASS" "$WARN" "$FAIL" "$_has_block_fail")

    # Aggregate per-quality results (global, across all features)
    _bq_tmpdir=$(mktemp -d)
    while IFS=: read -r _bq_key _bq_p _bq_w _bq_f; do
        [[ -z "$_bq_key" ]] && continue
        # _bq_key is "feature~quality" — extract quality part
        _bq_name="${_bq_key##*~}"
        [[ "$_bq_name" == "unscoped" ]] && continue
        _bq_pp=0; _bq_pw=0; _bq_pf=0
        if [[ -f "$_bq_tmpdir/$_bq_name" ]]; then
            IFS=: read -r _bq_pp _bq_pw _bq_pf < "$_bq_tmpdir/$_bq_name"
        fi
        echo "$((_bq_pp + _bq_p)):$((_bq_pw + _bq_w)):$((_bq_pf + _bq_f))" > "$_bq_tmpdir/$_bq_name"
    done <<< "$QUALITY_RESULTS"

    _bq_json="{"
    _bq_first=true
    for _bq_file in "$_bq_tmpdir"/*; do
        [[ ! -f "$_bq_file" ]] && continue
        _bq_fname=$(basename "$_bq_file")
        IFS=: read -r _bq_p _bq_w _bq_f < "$_bq_file"
        _bq_t=$((_bq_p + _bq_w + _bq_f))
        $_bq_first || _bq_json+=","
        _bq_json+="\"$_bq_fname\":{\"pass\":$_bq_p,\"warn\":$_bq_w,\"fail\":$_bq_f,\"total\":$_bq_t}"
        _bq_first=false
    done
    _bq_json+="}"
    rm -rf "$_bq_tmpdir"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"score\":${_eval_score:-null},\"pass\":$PASS,\"warn\":$WARN,\"fail\":$FAIL,\"beliefs_total\":$BELIEFS_TOTAL,\"generative_count\":$GENERATIVE_COUNT,\"generative_sum\":$GENERATIVE_SUM,\"layer_count\":${_layer_count:-0},\"layer_sum\":${_layer_sum:-0},\"features\":$_bf_json,\"quality\":$_bq_json}"
    elif [[ "$BY_FEATURE" == "true" ]]; then
        echo "$_bf_json"
    else
        echo "$_eval_score"
    fi
    exit 0
fi

# === Display (voice.md format) ===
if [[ "$SCORE_MODE" != "true" ]]; then
    # Compute display score (shared formula)
    BELIEFS_TOTAL=$((PASS + WARN + FAIL))
    _display_score=$(compute_eval_score "$GENERATIVE_COUNT" "$GENERATIVE_SUM" "$PASS" "$WARN" "$FAIL" "false")

    # Aggregate layer results for display
    _display_layer_tmpdir=$(mktemp -d)
    while IFS=: read -r _dl_key _dl_p _dl_w _dl_f; do
        [[ -z "$_dl_key" ]] && continue
        _dl_feat="${_dl_key%%~*}"
        _dl_layer="${_dl_key##*~}"
        [[ "$_dl_layer" == "unscoped" ]] && continue
        mkdir -p "$_display_layer_tmpdir/$_dl_feat"
        _dl_pp=0; _dl_pw=0; _dl_pf=0
        if [[ -f "$_display_layer_tmpdir/$_dl_feat/$_dl_layer" ]]; then
            IFS=: read -r _dl_pp _dl_pw _dl_pf < "$_display_layer_tmpdir/$_dl_feat/$_dl_layer"
        fi
        echo "$((_dl_pp + _dl_p)):$((_dl_pw + _dl_w)):$((_dl_pf + _dl_f))" > "$_display_layer_tmpdir/$_dl_feat/$_dl_layer"
    done <<< "$LAYER_RESULTS"

    echo ""
    echo -e "$SEP"

    # Score bar at top
    if [[ -n "$_display_score" ]]; then
        SCORE_BAR=$(print_score_bar "$_display_score")
        echo -e "  ${DIM}eval${NC}  ${BOLD}${_display_score}/100${NC}  ${SCORE_BAR}"
        # Sub-line: feature count + belief count
        _sub_parts=""
        if [[ "$GENERATIVE_COUNT" -gt 0 ]]; then
            _gen_avg=$((GENERATIVE_SUM / GENERATIVE_COUNT))
            _sub_parts="${GENERATIVE_COUNT} features (avg ${_gen_avg})"
        else
            _sub_parts="beliefs-only"
        fi
        if [[ "$BELIEFS_TOTAL" -gt 0 ]]; then
            [[ -n "$_sub_parts" ]] && _sub_parts="${_sub_parts}  ${DIM}·${NC}  "
            _sub_parts="${_sub_parts}${PASS}/${BELIEFS_TOTAL} beliefs"
        fi
        [[ -n "$_sub_parts" ]] && echo -e "        $_sub_parts"
    fi

    echo -e "$SEP"
    echo ""

    # Features section — score, sub-scores, gap
    if [[ ${#GENERATIVE_DISPLAY[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}features${NC}"
        printf '%s\n' "${GENERATIVE_DISPLAY[@]}" | sort -t'|' -k2 -n | while IFS='|' read -r _fname _fscore _fdelivers _fgaps _fsub; do
            # Color by score band
            if [[ "$_fscore" -ge 70 ]]; then
                _score_color="${GREEN}"
            elif [[ "$_fscore" -ge 50 ]]; then
                _score_color="${YELLOW}"
            else
                _score_color="${RED}"
            fi
            # Score bar (20-char)
            _filled=$(( (_fscore + 2) / 5 ))
            [[ $_filled -gt 20 ]] && _filled=20
            _empty=$((20 - _filled))
            _fbar=""
            for ((i=0; i<_filled; i++)); do _fbar+="█"; done
            for ((i=0; i<_empty; i++)); do _fbar+="░"; done

            # Score line with sub-scores
            if [[ -n "$_fsub" ]]; then
                printf "  %-16s %b%s%b  %b%-3s%b  ${DIM}%s${NC}\n" "$_fname" "$_score_color" "$_fbar" "$NC" "$_score_color" "$_fscore" "$NC" "$_fsub"
            else
                printf "  %-16s %b%s%b  %b%-3s%b\n" "$_fname" "$_score_color" "$_fbar" "$NC" "$_score_color" "$_fscore" "$NC"
            fi

            # Show gap
            if [[ -n "$_fgaps" && "$_fgaps" != "null" ]]; then
                _desc="$_fgaps"
                [[ ${#_desc} -gt 60 ]] && _desc="${_desc:0:57}..."
                echo -e "    ${DIM}${_desc}${NC}"
            fi
        done
        echo ""
    fi

    # Beliefs section — per-feature with quality breakdown
    if [[ "$BELIEFS_TOTAL" -gt 0 ]]; then
        echo -e "  ${BOLD}beliefs${NC}  ${PASS} ${GREEN}✓${NC}  ${DIM}·${NC}  ${WARN} ${YELLOW}⚠${NC}  ${DIM}·${NC}  ${FAIL} ${RED}✗${NC}"
        echo ""

        # Build per-feature quality breakdown
        _fqd_tmpdir=$(mktemp -d)
        while IFS=: read -r _fqd_key _fqd_p _fqd_w _fqd_f; do
            [[ -z "$_fqd_key" ]] && continue
            _fqd_feat="${_fqd_key%%~*}"
            _fqd_qual="${_fqd_key##*~}"
            [[ "$_fqd_qual" == "unscoped" || "$_fqd_feat" == "unscoped" ]] && continue
            mkdir -p "$_fqd_tmpdir/$_fqd_feat"
            _fqd_pp=0; _fqd_pw=0; _fqd_pf=0
            if [[ -f "$_fqd_tmpdir/$_fqd_feat/$_fqd_qual" ]]; then
                IFS=: read -r _fqd_pp _fqd_pw _fqd_pf < "$_fqd_tmpdir/$_fqd_feat/$_fqd_qual"
            fi
            echo "$((_fqd_pp + _fqd_p)):$((_fqd_pw + _fqd_w)):$((_fqd_pf + _fqd_f))" > "$_fqd_tmpdir/$_fqd_feat/$_fqd_qual"
        done <<< "$QUALITY_RESULTS"

        # Also aggregate per-feature totals
        _ftd_tmpdir=$(mktemp -d)
        while IFS=: read -r _ftd_name _ftd_p _ftd_w _ftd_f; do
            [[ -z "$_ftd_name" || "$_ftd_name" == "unscoped" ]] && continue
            _ftd_pp=0; _ftd_pw=0; _ftd_pf=0
            if [[ -f "$_ftd_tmpdir/$_ftd_name" ]]; then
                IFS=: read -r _ftd_pp _ftd_pw _ftd_pf < "$_ftd_tmpdir/$_ftd_name"
            fi
            echo "$((_ftd_pp + _ftd_p)):$((_ftd_pw + _ftd_w)):$((_ftd_pf + _ftd_f))" > "$_ftd_tmpdir/$_ftd_name"
        done <<< "$FEATURE_RESULTS"

        # Display each feature with quality sub-lines
        for _feat_file in "$_ftd_tmpdir"/*; do
            [[ ! -f "$_feat_file" ]] && continue
            _feat_name=$(basename "$_feat_file")
            IFS=: read -r _fp _fw _ff < "$_feat_file"
            _ft=$((_fp + _fw + _ff))
            [[ "$_ft" -eq 0 ]] && continue
            _fpct=$((_fp * 100 / _ft))
            if [[ "$_fpct" -ge 80 ]]; then _fcolor="${GREEN}"
            elif [[ "$_fpct" -ge 50 ]]; then _fcolor="${YELLOW}"
            else _fcolor="${RED}"
            fi
            printf "  ${BOLD}%-16s${NC} ${_fcolor}%s/%s${NC}\n" "$_feat_name" "$_fp" "$_ft"
            # Quality sub-lines
            if [[ -d "$_fqd_tmpdir/$_feat_name" ]]; then
                _qual_line="    "
                for _qdim in correctness craft completeness; do
                    if [[ -f "$_fqd_tmpdir/$_feat_name/$_qdim" ]]; then
                        IFS=: read -r _qp _qw _qf < "$_fqd_tmpdir/$_feat_name/$_qdim"
                        _qt=$((_qp + _qw + _qf))
                        [[ "$_qt" -eq 0 ]] && continue
                        if [[ "$_qp" -eq "$_qt" ]]; then _qcolor="${GREEN}"
                        elif [[ $((_qp * 100 / _qt)) -ge 50 ]]; then _qcolor="${YELLOW}"
                        else _qcolor="${RED}"
                        fi
                        _qual_line+="${DIM}${_qdim}${NC} ${_qcolor}${_qp}/${_qt}${NC}  "
                    fi
                done
                echo -e "$_qual_line"
            fi
        done
        rm -rf "$_fqd_tmpdir" "$_ftd_tmpdir"
        echo ""

        # Show failures first
        for _entry in "${BELIEF_FAILS[@]+"${BELIEF_FAILS[@]}"}"; do
            IFS='|' read -r _bname _bdesc _bsev <<< "$_entry"
            if [[ "$_bsev" == "block" ]]; then
                echo -e "  ${RED}●${NC} ${_bname}  ${DIM}${_bdesc}${NC}"
            else
                echo -e "  ${RED}✗${NC} ${_bname}  ${DIM}${_bdesc}${NC}"
            fi
        done

        # Show warnings
        for _entry in "${BELIEF_WARNS[@]+"${BELIEF_WARNS[@]}"}"; do
            IFS='|' read -r _bname _bdesc <<< "$_entry"
            echo -e "  ${YELLOW}⚠${NC} ${_bname}  ${DIM}${_bdesc}${NC}"
        done

        # Passes: just a count, don't list them
        echo ""
    fi

    # Next action line
    if [[ "$FAIL" -gt 0 ]]; then
        echo -e "  ${DIM}next: /plan to fix the ${FAIL} failure(s)${NC}"
    elif [[ "$WARN" -gt 0 ]]; then
        echo -e "  ${DIM}next: /plan to address ${WARN} warning(s)${NC}"
    else
        echo -e "  ${DIM}next: /go${NC}"
    fi

    echo -e "$SEP"
    echo ""

    rm -rf "$_display_layer_tmpdir"

    # Cache per-feature quality results for --score mode to use later
    # This lets score.sh show craft/completeness without re-running LLM judges
    if [[ "$BELIEFS_TOTAL" -gt 0 ]]; then
        mkdir -p "$EVAL_CACHE_DIR"
        _cache_tmpdir=$(mktemp -d)

        # Aggregate feature results
        while IFS=: read -r _cf_name _cf_p _cf_w _cf_f; do
            [[ -z "$_cf_name" || "$_cf_name" == "unscoped" ]] && continue
            _cf_pp=0; _cf_pw=0; _cf_pf=0
            if [[ -f "$_cache_tmpdir/$_cf_name" ]]; then
                IFS=: read -r _cf_pp _cf_pw _cf_pf < "$_cache_tmpdir/$_cf_name"
            fi
            echo "$((_cf_pp + _cf_p)):$((_cf_pw + _cf_w)):$((_cf_pf + _cf_f))" > "$_cache_tmpdir/$_cf_name"
        done <<< "$FEATURE_RESULTS"

        # Aggregate quality per feature
        _cq_tmpdir=$(mktemp -d)
        while IFS=: read -r _cq_key _cq_p _cq_w _cq_f; do
            [[ -z "$_cq_key" ]] && continue
            _cq_feat="${_cq_key%%~*}"
            _cq_qual="${_cq_key##*~}"
            [[ "$_cq_qual" == "unscoped" || "$_cq_feat" == "unscoped" ]] && continue
            mkdir -p "$_cq_tmpdir/$_cq_feat"
            _cq_pp=0; _cq_pw=0; _cq_pf=0
            if [[ -f "$_cq_tmpdir/$_cq_feat/$_cq_qual" ]]; then
                IFS=: read -r _cq_pp _cq_pw _cq_pf < "$_cq_tmpdir/$_cq_feat/$_cq_qual"
            fi
            echo "$((_cq_pp + _cq_p)):$((_cq_pw + _cq_w)):$((_cq_pf + _cq_f))" > "$_cq_tmpdir/$_cq_feat/$_cq_qual"
        done <<< "$QUALITY_RESULTS"

        # Build JSON cache
        _bc_json="{"
        _bc_first=true
        for _bc_file in "$_cache_tmpdir"/*; do
            [[ ! -f "$_bc_file" ]] && continue
            _bc_fname=$(basename "$_bc_file")
            IFS=: read -r _bc_p _bc_w _bc_f < "$_bc_file"
            _bc_t=$((_bc_p + _bc_w + _bc_f))
            $_bc_first || _bc_json+=","
            _bc_json+="\"$_bc_fname\":{\"pass\":$_bc_p,\"warn\":$_bc_w,\"fail\":$_bc_f,\"total\":$_bc_t"
            if [[ -d "$_cq_tmpdir/$_bc_fname" ]]; then
                _bc_json+=",\"quality\":{"
                _bcq_first=true
                for _qdim in correctness craft completeness; do
                    if [[ -f "$_cq_tmpdir/$_bc_fname/$_qdim" ]]; then
                        IFS=: read -r _qp _qw _qf < "$_cq_tmpdir/$_bc_fname/$_qdim"
                        _qt=$((_qp + _qw + _qf))
                        [[ "$_qt" -eq 0 ]] && continue
                        $_bcq_first || _bc_json+=","
                        _bc_json+="\"$_qdim\":{\"pass\":$_qp,\"total\":$_qt}"
                        _bcq_first=false
                    fi
                done
                _bc_json+="}"
            fi
            _bc_json+="}"
            _bc_first=false
        done
        _bc_json+="}"
        echo "{\"cached_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"features\":$_bc_json}" > "$BELIEFS_CACHE_FILE" 2>/dev/null || true
        rm -rf "$_cache_tmpdir" "$_cq_tmpdir"
    fi
fi

# Exit code — block severity failures return non-zero
BLOCK_FAILS=0
BELIEFS_FILE_CHECK=""
for bf in lens/*/eval/beliefs.yml "config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS_FILE_CHECK="$bf" && break
done
if [[ -f "$BELIEFS_FILE_CHECK" && "$FAIL" -gt 0 ]]; then
    BLOCK_ON=$(grep -c 'block_on_failure: true' config/rhino.yml 2>/dev/null) || BLOCK_ON=0
    if [[ "$BLOCK_ON" -gt 0 ]]; then
        BLOCK_FAILS=$FAIL
    fi
fi

if [[ "$BLOCK_FAILS" -gt 0 ]]; then
    exit 1
fi
exit 0
