#!/usr/bin/env bash
# grade.sh — Auto-grade predictions by comparing claims against score history + external signals.
#
# Usage: bash bin/grade.sh [--quiet] [--dry-run] [predictions.tsv] [history.tsv] [score-cache.json]
#
# For each ungraded prediction:
#   1. Extract directional claim ("raise X from N to M", "will drop", etc.)
#   2. Find score data AFTER the prediction date
#   3. Compare direction + magnitude → grade yes/partial/no
#   4. If primary grading skips, try signal-based grading:
#      - customer-intel.json: user/customer/demand predictions matched against research themes
#      - strategy.yml: market/competitor/positioning predictions checked against strategy state
#      - eval-cache.json: feature-name predictions checked against current eval scores + deltas
#   5. Fill result, correct, model_update columns
#   6. Show coverage report: graded/total, patterns used, remaining ungraded
#
# Skips predictions with no extractable directional claim AND no signal match (leave for /retro).
# Called from: session_start.sh (--quiet), /retro, /plan step 3.

set -uo pipefail

QUIET=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --dry-run) DRY_RUN=true ;;
    esac
done
# Strip flags from positional args
POSITIONAL=()
for arg in "$@"; do
    case "$arg" in
        --quiet|--dry-run) ;;
        *) POSITIONAL+=("$arg") ;;
    esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PRED_FILE="${1:-$PROJECT_DIR/.claude/knowledge/predictions.tsv}"
HISTORY_FILE="${2:-$PROJECT_DIR/.claude/scores/history.tsv}"
CACHE_FILE="${3:-$PROJECT_DIR/.claude/cache/score-cache.json}"

# Additional data sources for signal-based grading
CUSTOMER_INTEL_FILE="$PROJECT_DIR/.claude/cache/customer-intel.json"
[[ ! -f "$CUSTOMER_INTEL_FILE" ]] && CUSTOMER_INTEL_FILE="$HOME/.claude/cache/customer-intel.json"
STRATEGY_FILE="$PROJECT_DIR/.claude/plans/strategy.yml"
EVAL_CACHE_FILE="$PROJECT_DIR/.claude/cache/eval-cache.json"

# Pattern usage counters (for coverage report) — bash 3 compatible
PATTERN_LOG=""  # space-separated pattern names (counted at end)
SKIP_COUNT=0
SKIP_PREDICTIONS=""

if [[ ! -f "$PRED_FILE" ]]; then
    $QUIET || echo "No predictions file: $PRED_FILE"
    exit 0
fi

# Count ungraded (column 6 = correct, empty means ungraded)
UNGRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "" { c++ } END { print c+0 }')
if [[ "$UNGRADED" -eq 0 ]]; then
    $QUIET || echo "All predictions graded."
    exit 0
fi

$QUIET || echo "Grading $UNGRADED ungraded prediction(s)..."

# Read current feature scores from cache
get_feature_score() {
    local feature="$1"
    if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
        # Try nested .features.X.score first, then top-level .X.score (eval-cache format)
        local score
        score=$(jq -r ".features.\"$feature\".score // empty" "$CACHE_FILE" 2>/dev/null)
        if [[ -z "$score" ]]; then
            score=$(jq -r ".\"$feature\".score // empty" "$CACHE_FILE" 2>/dev/null)
        fi
        echo "$score"
    fi
}

get_total_score() {
    if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
        local score
        score=$(jq -r '.score // empty' "$CACHE_FILE" 2>/dev/null)
        # Fallback: try score-cache.json in the same directory
        if [[ -z "$score" ]]; then
            local score_cache="${CACHE_FILE%/*}/score-cache.json"
            [[ -f "$score_cache" ]] && score=$(jq -r '.score // empty' "$score_cache" 2>/dev/null)
        fi
        echo "$score"
    fi
}

# Get a feature's eval sub-score (delivery_score, craft_score, viability_score)
get_feature_sub_score() {
    local feature="$1" sub="$2"
    if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
        local score
        score=$(jq -r ".\"$feature\".${sub} // empty" "$CACHE_FILE" 2>/dev/null)
        [[ -z "$score" ]] && score=$(jq -r ".features.\"$feature\".${sub} // empty" "$CACHE_FILE" 2>/dev/null)
        echo "$score"
    fi
}

# Get assertion pass rate from eval-cache or score-cache
get_assertion_pass_rate() {
    if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
        local pass total rate
        pass=$(jq -r '.assertion_pass_count // empty' "$CACHE_FILE" 2>/dev/null)
        total=$(jq -r '.assertion_total_count // empty' "$CACHE_FILE" 2>/dev/null)
        if [[ -n "$pass" && -n "$total" && "$total" -gt 0 ]]; then
            rate=$((pass * 100 / total))
            echo "$rate"
            return
        fi
        # Fallback: score-cache.json
        local score_cache="${CACHE_FILE%/*}/score-cache.json"
        if [[ -f "$score_cache" ]]; then
            pass=$(jq -r '.assertion_pass_count // .beliefs_passing // empty' "$score_cache" 2>/dev/null)
            total=$(jq -r '.assertion_total_count // .beliefs_total // empty' "$score_cache" 2>/dev/null)
            if [[ -n "$pass" && -n "$total" && "$total" -gt 0 ]]; then
                rate=$((pass * 100 / total))
                echo "$rate"
                return
            fi
        fi
    fi
}

# Get score delta: compare current score to score at prediction date
get_score_delta() {
    local pred_date="$1"
    local current
    current=$(get_total_score)
    [[ -z "$current" || ! "$current" =~ ^[0-9]+$ ]] && return
    local baseline
    baseline=$(find_score_at_date "$pred_date")
    [[ -z "$baseline" || ! "$baseline" =~ ^[0-9]+$ ]] && return
    echo "$((current - baseline))"
}

# Find the score closest to a given date in history.tsv
# History columns: timestamp build structure product capabilities hygiene project_type
# Returns min(build, structure, hygiene) as the composite score (matches score.sh formula)
find_score_at_date() {
    local target_date="$1"
    [[ -z "$target_date" || ! -f "$HISTORY_FILE" ]] && return

    # Convert target date to comparable format
    # Find the row with timestamp closest to (but not after) end of target_date
    # target_date is YYYY-MM-DD, timestamps are ISO (YYYY-MM-DDTHH:MM:SSZ)
    # Use target_date + "T23:59:59Z" so same-day entries are included
    awk -F'\t' -v target="${target_date}T23:59:59Z" '
    NR == 1 { next }  # skip header
    {
        ts = $1
        # Compute composite score: min(build=$2, structure=$3, hygiene=$6)
        s = $2 + 0
        if ($3+0 < s) s = $3 + 0
        if ($6+0 < s) s = $6 + 0

        if (ts <= target) {
            best = s
            best_ts = ts
        }
    }
    END {
        if (best != "") print best
    }
    ' "$HISTORY_FILE"
}

# --- Signal-based grading: check external data sources for qualitative predictions ---

# Check customer-intel.json for signals supporting/contradicting a prediction about users/customers/demand
grade_customer_signal() {
    local prediction="$1"
    [[ ! -f "$CUSTOMER_INTEL_FILE" ]] && { echo "SKIP"; return; }
    command -v jq &>/dev/null || { echo "SKIP"; return; }

    # Extract key terms from prediction for matching against customer themes
    local pred_lower
    pred_lower=$(echo "$prediction" | tr '[:upper:]' '[:lower:]')

    # Look for matching themes in customer-intel.json
    # themes[].theme, themes[].signal_strength, themes[].quotes[]
    local matching_themes=""
    local strong_match=false
    local theme_count=0

    while IFS= read -r theme_line; do
        [[ -z "$theme_line" ]] && continue
        local theme_lower
        theme_lower=$(echo "$theme_line" | tr '[:upper:]' '[:lower:]')

        # Extract key nouns from prediction and check if theme references them
        local match=false
        for keyword in agency agencies user users customer customers demand market pain friction switch switching adopt adoption churn retention onboard pricing price pay paying revenue; do
            if [[ "$pred_lower" == *"$keyword"* && "$theme_lower" == *"$keyword"* ]]; then
                match=true
                break
            fi
        done
        # Also match if prediction and theme share a 5+ char word
        if [[ "$match" == false ]]; then
            for word in $(echo "$pred_lower" | tr -cs '[:alpha:]' '\n' | sort -u); do
                [[ ${#word} -lt 5 ]] && continue
                if [[ "$theme_lower" == *"$word"* ]]; then
                    match=true
                    break
                fi
            done
        fi

        if [[ "$match" == true ]]; then
            theme_count=$((theme_count + 1))
            matching_themes="${matching_themes}${theme_line}; "
            # Check signal strength
            local strength
            strength=$(jq -r ".themes[] | select(.theme == \"$theme_line\") | .signal_strength // \"unknown\"" "$CUSTOMER_INTEL_FILE" 2>/dev/null)
            [[ "$strength" == "strong" ]] && strong_match=true
        fi
    done < <(jq -r '.themes[].theme // empty' "$CUSTOMER_INTEL_FILE" 2>/dev/null)

    if [[ "$theme_count" -gt 0 ]]; then
        matching_themes="${matching_themes%;*}"
        if [[ "$strong_match" == true ]]; then
            echo "YES|Confirmed by customer signal (${theme_count} theme(s), strong): ${matching_themes:0:120}"
        elif [[ "$theme_count" -ge 2 ]]; then
            echo "PARTIAL|Supported by customer signal (${theme_count} themes, moderate): ${matching_themes:0:120}"
        else
            echo "PARTIAL|Weak customer signal (1 theme): ${matching_themes:0:120}"
        fi
    else
        echo "SKIP"
    fi
}

# Check strategy.yml for signals about market/competitor/positioning predictions
grade_strategy_signal() {
    local prediction="$1"
    [[ ! -f "$STRATEGY_FILE" ]] && { echo "SKIP"; return; }

    local pred_lower
    pred_lower=$(echo "$prediction" | tr '[:upper:]' '[:lower:]')

    # Extract strategy state
    local stage bottleneck_name bottleneck_desc
    stage=$(grep '^  stage:' "$STRATEGY_FILE" | head -1 | sed 's/.*: *//' | tr -d '"' || true)
    bottleneck_name=$(grep '^  name:' "$STRATEGY_FILE" | head -1 | sed 's/.*: *//' | tr -d '"' || true)
    bottleneck_desc=$(grep '^  description:' "$STRATEGY_FILE" | head -1 | sed 's/.*: *//' | tr -d '"' || true)

    # Check if prediction aligns with or contradicts strategy
    local evidence=""
    local verdict="SKIP"

    # Check if prediction mentions the bottleneck
    local bn_lower
    bn_lower=$(echo "$bottleneck_name $bottleneck_desc" | tr '[:upper:]' '[:lower:]')
    for word in $(echo "$bn_lower" | tr -cs '[:alpha:]' '\n' | sort -u); do
        [[ ${#word} -lt 5 ]] && continue
        if [[ "$pred_lower" == *"$word"* ]]; then
            evidence="Prediction aligns with current bottleneck: ${bottleneck_name}"
            verdict="YES"
            break
        fi
    done

    # Check if prediction mentions stage-related concepts
    if [[ "$verdict" == "SKIP" ]]; then
        case "$stage" in
            one)
                if [[ "$pred_lower" == *"first user"* || "$pred_lower" == *"first loop"* || "$pred_lower" == *"external"* || "$pred_lower" == *"onboard"* ]]; then
                    evidence="Aligned with stage one focus (first user/loop). Stage: ${stage}"
                    verdict="YES"
                fi
                if [[ "$pred_lower" == *"growth"* || "$pred_lower" == *"scale"* || "$pred_lower" == *"distribution"* ]]; then
                    evidence="Contradicts stage one — prediction about growth/scale at stage ${stage}"
                    verdict="NO"
                fi
                ;;
            some)
                if [[ "$pred_lower" == *"retention"* || "$pred_lower" == *"come back"* || "$pred_lower" == *"return"* ]]; then
                    evidence="Aligned with stage some focus (retention). Stage: ${stage}"
                    verdict="YES"
                fi
                ;;
            many)
                if [[ "$pred_lower" == *"distribution"* || "$pred_lower" == *"discover"* ]]; then
                    evidence="Aligned with stage many focus (distribution). Stage: ${stage}"
                    verdict="YES"
                fi
                ;;
        esac
    fi

    # Check unknowns — if prediction matches a resolved unknown, grade it
    if [[ "$verdict" == "SKIP" ]]; then
        local resolved_results
        resolved_results=$(awk '/priority: resolved/{found=1} found && /result:/{print; found=0}' "$STRATEGY_FILE" 2>/dev/null)
        if [[ -n "$resolved_results" ]]; then
            local result_lower
            result_lower=$(echo "$resolved_results" | tr '[:upper:]' '[:lower:]')
            for word in $(echo "$pred_lower" | tr -cs '[:alpha:]' '\n' | sort -u); do
                [[ ${#word} -lt 5 ]] && continue
                if [[ "$result_lower" == *"$word"* ]]; then
                    evidence="Matches resolved strategy unknown: ${resolved_results:0:100}"
                    verdict="PARTIAL"
                    break
                fi
            done
        fi
    fi

    if [[ "$verdict" != "SKIP" ]]; then
        echo "${verdict}|Strategy signal: ${evidence:0:150}"
    else
        echo "SKIP"
    fi
}

# Check eval-cache for feature score changes when prediction names a feature
grade_eval_feature() {
    local prediction="$1" pred_date="$2"
    [[ ! -f "$EVAL_CACHE_FILE" ]] && { echo "SKIP"; return; }
    command -v jq &>/dev/null || { echo "SKIP"; return; }

    local pred_lower
    pred_lower=$(echo "$prediction" | tr '[:upper:]' '[:lower:]')

    # Get feature names from eval-cache
    local features
    features=$(jq -r 'keys[]' "$EVAL_CACHE_FILE" 2>/dev/null)
    [[ -z "$features" ]] && { echo "SKIP"; return; }

    # Check if prediction mentions any eval-cache feature by name
    local matched_feature="" matched_score=""
    while IFS= read -r feat; do
        [[ -z "$feat" ]] && continue
        local feat_lower
        feat_lower=$(echo "$feat" | tr '[:upper:]' '[:lower:]')
        # Match feature name in prediction (word boundary approximation)
        if [[ "$pred_lower" == *"$feat_lower"* ]]; then
            matched_feature="$feat"
            matched_score=$(jq -r ".\"$feat\".score // empty" "$EVAL_CACHE_FILE" 2>/dev/null)
            break
        fi
    done <<< "$features"

    [[ -z "$matched_feature" || -z "$matched_score" ]] && { echo "SKIP"; return; }

    # Determine if prediction claims improvement, decline, or a target
    local claim_dir=""
    if [[ "$pred_lower" =~ (improve|increase|raise|better|higher|grow|rise|push) ]]; then
        claim_dir="up"
    elif [[ "$pred_lower" =~ (decrease|drop|lower|decline|worse|fall|regress) ]]; then
        claim_dir="down"
    elif [[ "$pred_lower" =~ (stay|stable|hold|keep|maintain|unchanged) ]]; then
        claim_dir="stable"
    fi

    # Get delivery sub-score if available (since task focuses on delivery)
    local delivery_score
    delivery_score=$(jq -r ".\"$matched_feature\".delivery_score // empty" "$EVAL_CACHE_FILE" 2>/dev/null)

    local detail="Feature ${matched_feature} eval: score=${matched_score}"
    [[ -n "$delivery_score" ]] && detail="${detail}, delivery=${delivery_score}"

    # Check delta field if available
    local delta_field
    delta_field=$(jq -r ".\"$matched_feature\".delta // empty" "$EVAL_CACHE_FILE" 2>/dev/null)
    [[ -n "$delta_field" ]] && detail="${detail}, trend=${delta_field}"

    case "$claim_dir" in
        up)
            if [[ "$delta_field" == "better" ]]; then
                echo "YES|Eval confirms improvement: ${detail}"
            elif [[ -n "$matched_score" && "$matched_score" =~ ^[0-9]+$ && "$matched_score" -ge 70 ]]; then
                echo "PARTIAL|Feature healthy but delta unclear: ${detail}"
            else
                echo "NO|No improvement signal: ${detail}"
            fi
            ;;
        down)
            if [[ "$delta_field" == "worse" ]]; then
                echo "YES|Eval confirms decline: ${detail}"
            else
                echo "NO|No decline signal: ${detail}"
            fi
            ;;
        stable)
            if [[ "$delta_field" == "same" || -z "$delta_field" ]]; then
                echo "YES|Eval confirms stable: ${detail}"
            elif [[ "$delta_field" == "better" ]]; then
                echo "PARTIAL|Actually improved (predicted stable): ${detail}"
            else
                echo "NO|Changed (predicted stable): ${detail}"
            fi
            ;;
        *)
            # No directional claim but we found the feature — report current state
            if [[ -n "$matched_score" && "$matched_score" =~ ^[0-9]+$ && "$matched_score" -ge 70 ]]; then
                echo "PARTIAL|Feature referenced, currently healthy: ${detail}"
            else
                echo "SKIP"
            fi
            ;;
    esac
}

# Dispatch signal-based grading for predictions that parse_claim couldn't handle
grade_via_signals() {
    local prediction="$1" pred_date="$2"
    local pred_lower
    pred_lower=$(echo "$prediction" | tr '[:upper:]' '[:lower:]')

    # Try customer-intel for user/customer/demand predictions
    if [[ "$pred_lower" =~ (user|customer|demand|adoption|churn|retention|onboard|pain|friction|switch|market[[:space:]]+fit|persona|segment) ]]; then
        local result
        result=$(grade_customer_signal "$prediction")
        if [[ "${result%%|*}" != "SKIP" ]]; then
            echo "customer_signal|$result"
            return
        fi
    fi

    # Try strategy for market/competitor/positioning predictions
    if [[ "$pred_lower" =~ (market|competitor|positioning|stage|bottleneck|strategy|distribution|growth|retention|first[[:space:]]+loop|niche|moat) ]]; then
        local result
        result=$(grade_strategy_signal "$prediction")
        if [[ "${result%%|*}" != "SKIP" ]]; then
            echo "strategy_signal|$result"
            return
        fi
    fi

    # Try eval-cache for predictions mentioning feature names
    local result
    result=$(grade_eval_feature "$prediction" "$pred_date")
    if [[ "${result%%|*}" != "SKIP" ]]; then
        echo "eval_feature|$result"
        return
    fi

    echo "SKIP|SKIP"
}

# Helper: check if a word is a valid feature name (not a function word)
_is_feature_name() {
    local word="$1"
    case "$word" in
        will|the|this|that|its|and|but|for|not|has|was|are|can|may|our|all|any|how|who|with|from|into|also|very|just|only|then|than|when|what|which|each|some|most|such|much)
            return 1 ;;
        *)
            return 0 ;;
    esac
}

# Extract claim components from prediction text.
# Returns: direction feature from_val to_val
# direction: raise|drop|improve|stable
parse_claim() {
    local text="$1"
    local direction="" feature="" from_val="" to_val=""

    # Pre-processing: strip "because Y" clause to prevent greedy interference.
    # Save the full text for causal fallback, but match patterns against the claim part only.
    local claim_text="$text"
    if [[ "$text" =~ ^(.+)[[:space:]]+because[[:space:]] ]]; then
        claim_text="${BASH_REMATCH[1]}"
    fi

    # --- TIER 1: Numeric patterns (most specific — "X from N to M") ---

    # Pattern: "X eval/feature from N to M" or "X eval/feature to N" (eval-cache lookup — BEFORE generic "from N to M")
    if [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(eval|feature)[[:space:]]+(from[[:space:]]+[0-9]+[[:space:]]+)?to[[:space:]]+([0-9]+) ]]; then
        direction="eval_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[4]}"
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?score[[:space:]]+([0-9]+) ]]; then
        direction="eval_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "raise X from N to M+"
    elif [[ "$claim_text" =~ raise[[:space:]]+([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "will raise X from N to M+"
    elif [[ "$claim_text" =~ will[[:space:]]+raise[[:space:]]+([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "X from N to M+"
    elif [[ "$claim_text" =~ ([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "X will reach/exceed/hit N" (numeric target)
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(reach|exceed|hit)[[:space:]]+([0-9]+) ]]; then
        direction="numeric_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[4]}"
    elif [[ "$claim_text" =~ (reach|exceed|hit|get[[:space:]]+to)[[:space:]]+([0-9]+) ]]; then
        direction="numeric_target"
        to_val="${BASH_REMATCH[2]}"
        if [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(reach|exceed|hit|get[[:space:]]+to) ]]; then
            feature="${BASH_REMATCH[1]}"
        fi
    # Pattern: "N assertions will pass"
    elif [[ "$claim_text" =~ ([0-9]+)[[:space:]]+assertions?[[:space:]]+will[[:space:]]+pass ]]; then
        direction="assertion_count"
        to_val="${BASH_REMATCH[1]}"
    # Pattern: "score N" / "to score N" (overall score target)
    elif [[ "$claim_text" =~ (score|scoring)[[:space:]]+(stays?[[:space:]]+at[[:space:]]+|at[[:space:]]+|to[[:space:]]+)?([0-9]+) ]]; then
        direction="score_target"
        feature="score"
        to_val="${BASH_REMATCH[3]}"

    # --- TIER 2: Verb patterns with named subjects ("X will work/fail") ---

    # Pattern: "X will work" / "X will succeed"
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(work|succeed|pass) ]]; then
        direction="will_work"
        feature="${BASH_REMATCH[1]}"
    # Pattern: "X will fail" / "X will break"
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(fail|break|crash) ]]; then
        direction="will_fail"
        feature="${BASH_REMATCH[1]}"

    # --- TIER 3: Filesystem patterns ---

    # Pattern: "feature X exists" / "file X exists"
    elif [[ "$claim_text" =~ (feature|file)[[:space:]]+([a-zA-Z_./-]+)[[:space:]]+exists ]]; then
        direction="exists"
        feature="${BASH_REMATCH[2]}"
    # Pattern: "file X contains Y" / "X contains Y"
    elif [[ "$claim_text" =~ ([a-zA-Z_./-]+)[[:space:]]+contains ]]; then
        direction="contains"
        feature="${BASH_REMATCH[1]}"

    fi

    # --- TIER 4: Directional patterns (post-chain, since feature name validation can fail) ---
    if [[ -z "$direction" ]]; then
        # Try "X will improve/increase" with valid feature name
        if [[ "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(improve|increase|raise|grow|rise) ]]; then
            local _feat="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat"; then
                direction="directional_up"
                feature="$_feat"
            fi
        fi
        # Try "X improve/increase" (no "will")
        if [[ -z "$direction" && "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+(improve|increase|raise|grow|rise) ]]; then
            local _feat2="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat2"; then
                direction="directional_up"
                feature="$_feat2"
            fi
        fi
        # Try "X will decrease/drop"
        if [[ -z "$direction" && "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(decrease|drop|lower|decline|shrink|fall) ]]; then
            local _feat3="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat3"; then
                direction="directional_down"
                feature="$_feat3"
            fi
        fi
        # Try "X decrease/drop" (no "will")
        if [[ -z "$direction" && "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+(decrease|drop|lower|decline|shrink|fall) ]]; then
            local _feat4="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat4"; then
                direction="directional_down"
                feature="$_feat4"
            fi
        fi
        # No-subject fallback: "will drop" / "will decrease"
        if [[ -z "$direction" && "$claim_text" =~ will[[:space:]]+(drop|decrease|lower) ]]; then
            direction="drop"
        fi
        # No-subject fallback: "will improve" / "will increase"
        if [[ -z "$direction" && "$claim_text" =~ will[[:space:]]+(improve|increase) ]]; then
            direction="raise"
        fi

    # --- TIER 4.5: Qualitative patterns (adjective/verb/noun claims) ---

        # "will be [adjective]" — qualitative comparison claim
        # better, faster, simpler, cleaner, easier, more reliable, more accurate, higher, lower
        if [[ -z "$direction" && "$claim_text" =~ will[[:space:]]+be[[:space:]]+(better|faster|simpler|cleaner|easier|smoother|stronger|more[[:space:]]+reliable|more[[:space:]]+accurate|more[[:space:]]+stable|more[[:space:]]+honest|higher|lower) ]]; then
            local _adj="${BASH_REMATCH[1]}"
            # Try to extract subject before "will be"
            if [[ "$claim_text" =~ ([a-zA-Z_.-]{3,})[[:space:]]+will[[:space:]]+be[[:space:]]+ ]]; then
                feature="${BASH_REMATCH[1]}"
                _is_feature_name "$feature" || feature=""
            fi
            case "$_adj" in
                lower) direction="qualitative_down" ;;
                *)     direction="qualitative_up" ;;
            esac
        fi

        # "should [verb]" — expectation claim checked via assertions
        if [[ -z "$direction" && "$claim_text" =~ should[[:space:]]+(work|pass|succeed|improve|hold|transfer|apply|scale|run|compile|build) ]]; then
            direction="should_verb"
            local _verb="${BASH_REMATCH[1]}"
            # Try to extract subject before "should"
            if [[ "$claim_text" =~ ([a-zA-Z_.-]{3,})[[:space:]]+should ]]; then
                feature="${BASH_REMATCH[1]}"
                _is_feature_name "$feature" || feature=""
            fi
        fi

        # "expect [noun]" — expectation claim checked via score delta
        if [[ -z "$direction" && "$claim_text" =~ expect[[:space:]]+(improvement|regression|increase|decrease|drop|gain|decline|progress|growth|stability) ]]; then
            local _noun="${BASH_REMATCH[1]}"
            case "$_noun" in
                regression|decrease|drop|decline) direction="expect_down" ;;
                stability) direction="expect_stable" ;;
                *) direction="expect_up" ;;
            esac
            # Try to extract subject before "expect"
            if [[ "$claim_text" =~ ([a-zA-Z_.-]{3,})[[:space:]]+expect ]]; then
                feature="${BASH_REMATCH[1]}"
                _is_feature_name "$feature" || feature=""
            fi
        fi
        # Also handle "I expect" / "we expect" form
        if [[ -z "$direction" && "$claim_text" =~ (I|we)[[:space:]]+expect[[:space:]]+(improvement|regression|increase|decrease|drop|gain|decline|progress|growth|stability) ]]; then
            local _noun2="${BASH_REMATCH[2]}"
            case "$_noun2" in
                regression|decrease|drop|decline) direction="expect_down" ;;
                stability) direction="expect_stable" ;;
                *) direction="expect_up" ;;
            esac
        fi
    fi

    # --- TIER 5: Broad patterns (lowest priority) ---
    if [[ -z "$direction" ]]; then
        if [[ "$claim_text" =~ ([0-9]+)[[:space:]]+(sessions?|days?|weeks?|months?) ]]; then
            direction="time_based"
            to_val="${BASH_REMATCH[1]}"
            feature="${BASH_REMATCH[2]}"
        # Pattern: "X depends on Y" / "feature X depends on Y" / "X requires Y"
        elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(depends[[:space:]]+on|requires)[[:space:]]+([a-zA-Z_.-]+) ]]; then
            direction="dependency"
            feature="${BASH_REMATCH[1]}"
            to_val="${BASH_REMATCH[3]}"  # the dependency (Y)
        # Pattern: "users will [verb]" / "founders will [verb]" / "people will [verb]"
        elif [[ "$claim_text" =~ (users?|founders?|people|devs?|developers?|customers?)[[:space:]]+(will[[:space:]]+)?(adopt|install|use|try|ignore|skip|love|hate|churn|return|click|bounce|convert|upgrade|downgrade|complain|recommend|share|discover|find|prefer|avoid|switch|choose|leave|stay|sign[[:space:]]*up|drop[[:space:]]*off|pay|buy|subscribe) ]]; then
            direction="user_behavior"
            feature="${BASH_REMATCH[1]}"
            to_val="${BASH_REMATCH[3]}"
        elif [[ "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(produce|generate|create|enable|reduce|eliminate) ]]; then
            direction="will_work"
            feature="${BASH_REMATCH[1]}"
        elif [[ "$claim_text" =~ will[[:space:]]+be[[:space:]]+the[[:space:]]+(highest|best|hardest|most|lowest|worst|easiest) ]]; then
            direction="superlative"
        # Causal fallback: if we stripped "because" earlier and nothing matched
        elif [[ "$claim_text" != "$text" ]]; then
            if [[ "$claim_text" =~ (will[[:space:]]+)?(work|succeed|pass|ship|land|hold|transfer|get) ]]; then
                direction="causal_bool"
                feature="causal"
            fi
        fi
    fi

    echo "$direction|$feature|$from_val|$to_val"
}

# Grade a single prediction
grade_prediction() {
    local prediction="$1"
    local pred_date="${2:-}"
    local claim
    claim=$(parse_claim "$prediction")

    local direction feature from_val to_val
    IFS='|' read -r direction feature from_val to_val <<< "$claim"

    # Can't extract a directional claim — skip for manual grading
    if [[ -z "$direction" ]]; then
        echo "SKIP"
        return
    fi

    # Some patterns don't need a feature name — only skip if the specific pattern requires one
    if [[ -z "$feature" && "$direction" != "assertion_count" && "$direction" != "score_target" \
        && "$direction" != "causal_bool" && "$direction" != "time_based" \
        && "$direction" != "superlative" && "$direction" != "numeric_target" \
        && "$direction" != "qualitative_up" && "$direction" != "qualitative_down" \
        && "$direction" != "should_verb" \
        && "$direction" != "expect_up" && "$direction" != "expect_down" && "$direction" != "expect_stable" \
        && "$direction" != "user_behavior" ]]; then
        echo "SKIP"
        return
    fi

    # --- Patterns that don't need a score (git-based, filesystem-based) ---

    # "X will work" — check git log for reverts (failure) or success
    if [[ "$direction" == "will_work" ]]; then
        # Check if feature was reverted recently
        REVERTED=$(git log --oneline -20 2>/dev/null | grep -i "revert.*${feature}" | head -1 || true)
        if [[ -n "$REVERTED" ]]; then
            echo "NO|Reverted: ${REVERTED}"
        else
            # Check if feature appears in recent successful commits
            COMMITTED=$(git log --oneline -20 2>/dev/null | grep -i "${feature}" | head -1 || true)
            if [[ -n "$COMMITTED" ]]; then
                echo "YES|Committed: ${COMMITTED}"
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "X will fail" — inverse of will_work
    if [[ "$direction" == "will_fail" ]]; then
        REVERTED=$(git log --oneline -20 2>/dev/null | grep -i "revert.*${feature}" | head -1 || true)
        if [[ -n "$REVERTED" ]]; then
            echo "YES|Failed and reverted: ${REVERTED}"
        else
            COMMITTED=$(git log --oneline -20 2>/dev/null | grep -i "${feature}" | head -1 || true)
            if [[ -n "$COMMITTED" ]]; then
                echo "NO|Succeeded: ${COMMITTED}"
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "N assertions will pass" — check score-cache.json assertion counts
    if [[ "$direction" == "assertion_count" && -n "$to_val" ]]; then
        if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
            ACTUAL_PASS=$(jq -r '.assertion_pass_count // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
            if [[ "$ACTUAL_PASS" -ge "$to_val" ]]; then
                echo "YES|${ACTUAL_PASS} assertions passing (target was ${to_val})"
            elif [[ "$ACTUAL_PASS" -gt 0 ]]; then
                echo "PARTIAL|${ACTUAL_PASS} assertions passing (target was ${to_val})"
            else
                echo "NO|${ACTUAL_PASS} assertions passing (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "feature/file X exists" — check filesystem
    if [[ "$direction" == "exists" ]]; then
        if [[ -f "$feature" || -d "$feature" ]]; then
            echo "YES|${feature} exists"
        else
            # Try finding it in common locations
            FOUND=$(find . -name "$(basename "$feature")" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 || true)
            if [[ -n "$FOUND" ]]; then
                echo "YES|Found at ${FOUND}"
            else
                echo "NO|${feature} not found"
            fi
        fi
        return
    fi

    # "X contains Y" — check file contents
    if [[ "$direction" == "contains" && -f "$feature" ]]; then
        echo "SKIP"  # Would need the Y part — too complex for pattern matching
        return
    fi

    # --- Score-based patterns (need current_score) ---
    local current_score
    current_score=$(get_feature_score "$feature")

    # If feature not found by exact name, fall back to total score
    if [[ -z "$current_score" ]]; then
        current_score=$(get_total_score)
    fi

    # --- NEW GRADING LOGIC (v9.0.1) ---

    # "directional_up" — check if feature score went up vs baseline at prediction time
    if [[ "$direction" == "directional_up" ]]; then
        if [[ -n "$current_score" && "$current_score" -gt 0 ]]; then
            local baseline
            baseline=$(find_score_at_date "$pred_date")
            if [[ -n "$baseline" && "$baseline" =~ ^[0-9]+$ ]]; then
                if [[ "$current_score" -gt "$baseline" ]]; then
                    echo "YES|Improved: ${baseline}→${current_score}"
                elif [[ "$current_score" -eq "$baseline" ]]; then
                    echo "NO|Unchanged at ${current_score}"
                else
                    echo "NO|Decreased: ${baseline}→${current_score}"
                fi
            else
                echo "SKIP"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "directional_down" — check if feature score went down vs baseline at prediction time
    if [[ "$direction" == "directional_down" ]]; then
        if [[ -n "$current_score" ]]; then
            local baseline
            baseline=$(find_score_at_date "$pred_date")
            if [[ -n "$baseline" && "$baseline" =~ ^[0-9]+$ ]]; then
                if [[ "$current_score" -lt "$baseline" ]]; then
                    echo "YES|Decreased: ${baseline}→${current_score}"
                else
                    echo "NO|Did not decrease: ${baseline}→${current_score}"
                fi
            else
                echo "SKIP"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "numeric_target" — check if a feature/total score reached the target
    if [[ "$direction" == "numeric_target" && -n "$to_val" ]]; then
        local check_score="${current_score}"
        [[ -z "$check_score" ]] && check_score=$(get_total_score)
        if [[ -n "$check_score" && "$check_score" =~ ^[0-9]+$ ]]; then
            if [[ "$check_score" -ge "$to_val" ]]; then
                echo "YES|Reached ${check_score} (target was ${to_val})"
            elif [[ "$check_score" -ge "$((to_val * 80 / 100))" ]]; then
                echo "PARTIAL|At ${check_score} (target was ${to_val}, within 80%)"
            else
                echo "NO|At ${check_score} (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "eval_target" — check eval-cache for feature score
    if [[ "$direction" == "eval_target" && -n "$to_val" ]]; then
        local eval_score=""
        eval_score=$(get_feature_score "$feature")
        [[ -z "$eval_score" ]] && eval_score=$(get_total_score)
        if [[ -n "$eval_score" && "$eval_score" =~ ^[0-9]+$ ]]; then
            if [[ "$eval_score" -ge "$to_val" ]]; then
                echo "YES|Eval score ${eval_score} (target was ${to_val})"
            elif [[ "$eval_score" -ge "$((to_val * 75 / 100))" ]]; then
                echo "PARTIAL|Eval score ${eval_score} (target was ${to_val})"
            else
                echo "NO|Eval score ${eval_score} (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "score_target" — check total score against target
    if [[ "$direction" == "score_target" && -n "$to_val" ]]; then
        local total
        total=$(get_total_score)
        if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
            local diff=$(( total - to_val ))
            [[ $diff -lt 0 ]] && diff=$(( -diff ))
            if [[ "$diff" -le 5 ]]; then
                echo "YES|Score ${total} (target was ${to_val}, within 5pt margin)"
            elif [[ "$total" -ge "$to_val" ]]; then
                echo "PARTIAL|Score ${total} exceeded target ${to_val}"
            else
                echo "NO|Score ${total} (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # --- NEW QUALITATIVE GRADING (v9.4.1) ---

    # "will be [adjective]" — grade by checking if related eval sub-scores improved
    if [[ "$direction" == "qualitative_up" || "$direction" == "qualitative_down" ]]; then
        # Strategy: check if feature's eval sub-scores improved vs baseline at prediction date
        # If no feature, check total score delta
        local delta
        delta=$(get_score_delta "$pred_date")
        if [[ -n "$delta" ]]; then
            if [[ "$direction" == "qualitative_up" ]]; then
                if [[ "$delta" -gt 5 ]]; then
                    echo "YES|Score improved by ${delta} points"
                elif [[ "$delta" -ge 0 ]]; then
                    echo "PARTIAL|Score delta ${delta} (marginal improvement)"
                else
                    echo "NO|Score decreased by ${delta#-} points"
                fi
            else  # qualitative_down
                if [[ "$delta" -lt -5 ]]; then
                    echo "YES|Score decreased by ${delta#-} points"
                elif [[ "$delta" -le 0 ]]; then
                    echo "PARTIAL|Score delta ${delta} (marginal decrease)"
                else
                    echo "NO|Score increased by ${delta} points"
                fi
            fi
        else
            # Fallback: check feature-specific eval sub-scores if feature is set
            if [[ -n "$feature" ]]; then
                local feat_score
                feat_score=$(get_feature_score "$feature")
                if [[ -n "$feat_score" && "$feat_score" =~ ^[0-9]+$ ]]; then
                    if [[ "$direction" == "qualitative_up" && "$feat_score" -ge 60 ]]; then
                        echo "YES|Feature ${feature} at ${feat_score} (above threshold)"
                    elif [[ "$direction" == "qualitative_up" && "$feat_score" -ge 40 ]]; then
                        echo "PARTIAL|Feature ${feature} at ${feat_score}"
                    else
                        echo "NO|Feature ${feature} at ${feat_score}"
                    fi
                else
                    echo "SKIP"
                fi
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "should [verb]" — grade by checking assertion pass rates
    if [[ "$direction" == "should_verb" ]]; then
        local pass_rate
        pass_rate=$(get_assertion_pass_rate)
        if [[ -n "$pass_rate" && "$pass_rate" =~ ^[0-9]+$ ]]; then
            if [[ "$pass_rate" -ge 85 ]]; then
                echo "YES|Assertion pass rate ${pass_rate}%"
            elif [[ "$pass_rate" -ge 60 ]]; then
                echo "PARTIAL|Assertion pass rate ${pass_rate}%"
            else
                echo "NO|Assertion pass rate ${pass_rate}%"
            fi
        else
            # Fallback: check git log for evidence of the verb's subject
            if [[ -n "$feature" ]]; then
                COMMITTED=$(git log --oneline -20 2>/dev/null | grep -i "${feature}" | head -1 || true)
                REVERTED=$(git log --oneline -20 2>/dev/null | grep -i "revert.*${feature}" | head -1 || true)
                if [[ -n "$REVERTED" ]]; then
                    echo "NO|Reverted: ${REVERTED}"
                elif [[ -n "$COMMITTED" ]]; then
                    echo "YES|Committed: ${COMMITTED}"
                else
                    echo "SKIP"
                fi
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "expect [noun]" — grade by checking score delta
    if [[ "$direction" == "expect_up" || "$direction" == "expect_down" || "$direction" == "expect_stable" ]]; then
        local delta
        delta=$(get_score_delta "$pred_date")
        if [[ -n "$delta" ]]; then
            case "$direction" in
                expect_up)
                    if [[ "$delta" -gt 5 ]]; then
                        echo "YES|Score improved by ${delta} points"
                    elif [[ "$delta" -ge 0 ]]; then
                        echo "PARTIAL|Score delta +${delta} (marginal)"
                    else
                        echo "NO|Score decreased by ${delta#-} points"
                    fi
                    ;;
                expect_down)
                    if [[ "$delta" -lt -5 ]]; then
                        echo "YES|Score decreased by ${delta#-} points"
                    elif [[ "$delta" -le 0 ]]; then
                        echo "PARTIAL|Score delta ${delta} (marginal)"
                    else
                        echo "NO|Score increased by ${delta} points"
                    fi
                    ;;
                expect_stable)
                    local abs_delta="${delta#-}"
                    if [[ "$abs_delta" -le 3 ]]; then
                        echo "YES|Score stable (delta ${delta})"
                    elif [[ "$abs_delta" -le 8 ]]; then
                        echo "PARTIAL|Score delta ${delta} (slightly unstable)"
                    else
                        echo "NO|Score delta ${delta} (not stable)"
                    fi
                    ;;
            esac
        else
            echo "SKIP"
        fi
        return
    fi

    # "time_based" — grade "X will take N sessions/days" by checking date diff or git log session count
    if [[ "$direction" == "time_based" ]]; then
        local predicted_count="$to_val"
        local unit="$feature"  # feature field holds the time unit for time_based
        if [[ -z "$pred_date" || -z "$predicted_count" ]]; then
            echo "SKIP"
            return
        fi
        local today
        today=$(date '+%Y-%m-%d' 2>/dev/null || echo "")
        [[ -z "$today" ]] && { echo "SKIP"; return; }

        case "$unit" in
            session|sessions)
                # Count distinct build sessions (days with commits) since prediction
                local actual_sessions
                actual_sessions=$(git log --format='%ad' --date=short --after="$pred_date" 2>/dev/null | sort -u | wc -l | tr -d ' ')
                if [[ "$actual_sessions" -le "$predicted_count" ]]; then
                    echo "YES|Completed in ${actual_sessions} sessions (predicted ${predicted_count})"
                elif [[ "$actual_sessions" -le "$((predicted_count * 2))" ]]; then
                    echo "PARTIAL|Took ${actual_sessions} sessions (predicted ${predicted_count})"
                else
                    echo "NO|Took ${actual_sessions} sessions (predicted ${predicted_count})"
                fi
                ;;
            day|days)
                # Calculate actual days elapsed
                local pred_epoch today_epoch
                if date -v+0d &>/dev/null 2>&1; then
                    # macOS
                    pred_epoch=$(date -j -f '%Y-%m-%d' "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                else
                    # GNU
                    pred_epoch=$(date -d "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                fi
                if [[ -n "$pred_epoch" ]]; then
                    local actual_days=$(( (today_epoch - pred_epoch) / 86400 ))
                    if [[ "$actual_days" -le "$predicted_count" ]]; then
                        echo "YES|Completed in ${actual_days} days (predicted ${predicted_count})"
                    elif [[ "$actual_days" -le "$((predicted_count * 2))" ]]; then
                        echo "PARTIAL|Took ${actual_days} days (predicted ${predicted_count})"
                    else
                        echo "NO|Took ${actual_days} days (predicted ${predicted_count})"
                    fi
                else
                    echo "SKIP"
                fi
                ;;
            week|weeks)
                local pred_epoch today_epoch
                if date -v+0d &>/dev/null 2>&1; then
                    pred_epoch=$(date -j -f '%Y-%m-%d' "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                else
                    pred_epoch=$(date -d "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                fi
                if [[ -n "$pred_epoch" ]]; then
                    local actual_weeks=$(( (today_epoch - pred_epoch) / 604800 ))
                    if [[ "$actual_weeks" -le "$predicted_count" ]]; then
                        echo "YES|Completed in ${actual_weeks} weeks (predicted ${predicted_count})"
                    elif [[ "$actual_weeks" -le "$((predicted_count * 2))" ]]; then
                        echo "PARTIAL|Took ${actual_weeks} weeks (predicted ${predicted_count})"
                    else
                        echo "NO|Took ${actual_weeks} weeks (predicted ${predicted_count})"
                    fi
                else
                    echo "SKIP"
                fi
                ;;
            *)
                echo "SKIP"
                ;;
        esac
        return
    fi

    # "dependency" — grade "feature X depends on Y" by checking if Y's score improved before X was attempted
    if [[ "$direction" == "dependency" ]]; then
        local dep_feature="$to_val"  # Y — the dependency
        local dep_score
        dep_score=$(get_feature_score "$dep_feature")
        local main_score
        main_score=$(get_feature_score "$feature")
        if [[ -n "$dep_score" && "$dep_score" =~ ^[0-9]+$ ]]; then
            if [[ "$dep_score" -ge 50 ]]; then
                # Dependency is healthy — check if main feature benefited
                if [[ -n "$main_score" && "$main_score" =~ ^[0-9]+$ && "$main_score" -ge 40 ]]; then
                    echo "YES|${dep_feature} at ${dep_score}, ${feature} at ${main_score} — dependency held"
                else
                    echo "PARTIAL|${dep_feature} at ${dep_score} (healthy), but ${feature} at ${main_score:-unknown}"
                fi
            else
                # Dependency is weak — did main feature suffer?
                if [[ -n "$main_score" && "$main_score" =~ ^[0-9]+$ && "$main_score" -lt 40 ]]; then
                    echo "YES|${dep_feature} at ${dep_score} (weak), ${feature} at ${main_score} (blocked) — dependency confirmed"
                else
                    echo "NO|${dep_feature} at ${dep_score} (weak) but ${feature} at ${main_score:-unknown} (not blocked)"
                fi
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "user_behavior" — check customer-intel.json first, fall back to manual
    if [[ "$direction" == "user_behavior" ]]; then
        local ci_result
        ci_result=$(grade_customer_signal "$prediction")
        if [[ "${ci_result%%|*}" != "SKIP" ]]; then
            echo "$ci_result"
        else
            echo "NEEDS_MANUAL|User behavior claim: \"${feature} will ${to_val}\" — check customer-intel.json, support tickets, or analytics. Grade manually in /retro."
        fi
        return
    fi

    # "superlative" — can't auto-grade subjective superlatives
    if [[ "$direction" == "superlative" ]]; then
        echo "SKIP"
        return
    fi

    # "causal_bool" — check git log for evidence of the causal claim
    if [[ "$direction" == "causal_bool" ]]; then
        # Look for commits mentioning the prediction text (first 30 chars)
        local search_term="${prediction:0:30}"
        FOUND=$(git log --oneline -30 2>/dev/null | grep -i "${search_term:0:15}" | head -1 || true)
        if [[ -n "$FOUND" ]]; then
            echo "YES|Evidence in commits: ${FOUND}"
        else
            echo "SKIP"
        fi
        return
    fi

    # Original directional grading
    if [[ "$direction" == "raise" && -n "$to_val" && -n "$from_val" ]]; then
        if [[ "$current_score" -ge "$to_val" ]]; then
            echo "YES|Score reached ${current_score} (target was ${to_val}+)"
        elif [[ "$current_score" -gt "$from_val" ]]; then
            echo "PARTIAL|Score at ${current_score} (up from ${from_val}, target was ${to_val}+)"
        else
            echo "NO|Score at ${current_score} (target was ${to_val}+, baseline was ${from_val})"
        fi
    elif [[ "$direction" == "drop" ]]; then
        if [[ -n "$from_val" && "$current_score" -lt "$from_val" ]]; then
            echo "YES|Score dropped to ${current_score}"
        else
            echo "PARTIAL|Score at ${current_score}"
        fi
    else
        echo "SKIP"
    fi
}

# Process predictions: read, grade, write atomically
TEMP_FILE=$(mktemp)
GRADED_COUNT=0
HEADER=""
LINE_NUM=0

while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Preserve header
    if [[ "$LINE_NUM" -eq 1 ]]; then
        HEADER="$line"
        echo "$line" >> "$TEMP_FILE"
        continue
    fi

    # Parse columns (tab-separated)
    IFS=$'\t' read -r date agent prediction evidence result correct model_update <<< "$line"

    # Skip empty lines
    [[ -z "$date" ]] && continue

    # TSV validation: skip malformed rows (missing required fields, bad date format)
    if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        $QUIET || echo "  ! Skipping malformed row $LINE_NUM: bad date '$date'"
        echo "$line" >> "$TEMP_FILE"
        continue
    fi
    if [[ -z "$prediction" ]]; then
        $QUIET || echo "  ! Skipping malformed row $LINE_NUM: empty prediction"
        echo "$line" >> "$TEMP_FILE"
        continue
    fi

    # Already graded — pass through
    if [[ -n "$correct" ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi

    # Try to grade — first try prediction column, then agent column
    # (some rows have shifted columns when agent field is missing)
    grade_result=$(grade_prediction "$prediction" "$date")
    grade_verdict="${grade_result%%|*}"
    grade_detail="${grade_result#*|}"

    # If prediction column didn't match, try agent column (column shift recovery)
    if [[ "$grade_verdict" == "SKIP" && -n "$agent" && ${#agent} -gt 20 ]]; then
        grade_result=$(grade_prediction "$agent" "$date")
        grade_verdict="${grade_result%%|*}"
        grade_detail="${grade_result#*|}"
    fi

    # If primary grading skipped, try signal-based grading from external data sources
    if [[ "$grade_verdict" == "SKIP" ]]; then
        signal_result=$(grade_via_signals "$prediction" "$date")
        signal_pattern="${signal_result%%|*}"
        signal_grade="${signal_result#*|}"

        # Also try agent column for shifted rows
        if [[ "$signal_pattern" == "SKIP" && -n "$agent" && ${#agent} -gt 20 ]]; then
            signal_result=$(grade_via_signals "$agent" "$date")
            signal_pattern="${signal_result%%|*}"
            signal_grade="${signal_result#*|}"
        fi

        if [[ "$signal_pattern" != "SKIP" ]]; then
            grade_verdict="${signal_grade%%|*}"
            grade_detail="${signal_grade#*|}"
            # Track which signal pattern was used
            PATTERN_LOG="${PATTERN_LOG} ${signal_pattern}"
        fi
    fi

    if [[ "$grade_verdict" == "SKIP" ]]; then
        # Can't auto-grade — pass through unchanged
        echo "$line" >> "$TEMP_FILE"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        [[ "$SKIP_COUNT" -le 3 ]] && SKIP_PREDICTIONS="${SKIP_PREDICTIONS}${prediction:0:70}; "
        continue
    fi

    # Track pattern for graded predictions (primary patterns)
    _claim_dir=$(parse_claim "$prediction")
    _claim_dir="${_claim_dir%%|*}"
    [[ -n "$_claim_dir" ]] && PATTERN_LOG="${PATTERN_LOG} ${_claim_dir}"

    # NEEDS_MANUAL: write the helpful prompt as result but leave correct empty for manual grading
    if [[ "$grade_verdict" == "NEEDS_MANUAL" ]]; then
        if $DRY_RUN; then
            [[ "$QUIET" == false ]] && echo "  ? \"$prediction\" → [needs manual] $grade_detail"
        else
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
                "$date" "$agent" "$prediction" "$evidence" \
                "$grade_detail" "" "" >> "$TEMP_FILE"
            [[ "$QUIET" == false ]] && echo "  ? \"$prediction\" → needs manual: $grade_detail"
        fi
        continue
    fi

    # Map verdict to correct column value
    case "$grade_verdict" in
        YES)     correct_val="yes" ;;
        PARTIAL) correct_val="partial" ;;
        NO)      correct_val="no" ;;
        *)       echo "$line" >> "$TEMP_FILE"; continue ;;
    esac

    # Build model_update for ALL graded predictions (not just failures)
    local_model_update=""
    case "$correct_val" in
        no)
            local_model_update="Prediction missed target. Actual outcome: ${grade_detail}"
            ;;
        yes)
            local_model_update="Confirmed: ${grade_detail}"
            ;;
        partial)
            local_model_update="Partially confirmed: ${grade_detail}"
            ;;
    esac

    if $DRY_RUN; then
        # Show what would be graded without writing
        echo "$line" >> "$TEMP_FILE"
    else
        # Write graded row
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$date" "$agent" "$prediction" "$evidence" \
            "$grade_detail" "$correct_val" "$local_model_update" >> "$TEMP_FILE"
    fi

    GRADED_COUNT=$((GRADED_COUNT + 1))

    if [[ "$QUIET" == false ]]; then
        prefix=""
        $DRY_RUN && prefix="[dry-run] "
        case "$correct_val" in
            yes)     echo "  ✓ ${prefix}\"$prediction\" → $grade_detail" ;;
            partial) echo "  · ${prefix}\"$prediction\" → $grade_detail" ;;
            no)      echo "  ✗ ${prefix}\"$prediction\" → $grade_detail" ;;
        esac
    fi
done < "$PRED_FILE"

# Atomic write
if [[ "$GRADED_COUNT" -gt 0 ]]; then
    if $DRY_RUN; then
        rm -f "$TEMP_FILE"
        $QUIET || echo ""
        $QUIET || echo "[dry-run] Would grade $GRADED_COUNT prediction(s). $(( UNGRADED - GRADED_COUNT )) remaining for manual review."
        $QUIET || echo "[dry-run] No files modified."
    else
        mv "$TEMP_FILE" "$PRED_FILE"
        $QUIET || echo ""
        $QUIET || echo "Graded $GRADED_COUNT prediction(s). $(( UNGRADED - GRADED_COUNT )) remaining for manual review."
    fi
else
    rm -f "$TEMP_FILE"
    $QUIET || echo "No predictions could be auto-graded. Run /retro for manual grading."
fi

# --- Coverage report (non-quiet mode only) ---
if [[ "$QUIET" == false ]]; then
    TOTAL_PRED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$3 != "" { c++ } END { print c+0 }')
    TOTAL_GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    # In dry-run mode, file isn't updated yet — add this run's grades
    $DRY_RUN && TOTAL_GRADED=$((TOTAL_GRADED + GRADED_COUNT))
    if [[ "$TOTAL_PRED" -gt 0 ]]; then
        PCT=$((TOTAL_GRADED * 100 / TOTAL_PRED))

        # Build pattern summary from PATTERN_LOG (bash 3 compatible)
        PATTERN_SUMMARY=""
        if [[ -n "$PATTERN_LOG" ]]; then
            PATTERN_SUMMARY=$(echo "$PATTERN_LOG" | tr ' ' '\n' | sort | uniq -c | sort -rn | while read -r count pat; do
                [[ -z "$pat" ]] && continue
                printf "%s(%d), " "$pat" "$count"
            done)
            PATTERN_SUMMARY="${PATTERN_SUMMARY%, }"
        fi

        echo ""
        echo "Coverage: ${TOTAL_GRADED}/${TOTAL_PRED} (${PCT}%)"
        [[ -n "$PATTERN_SUMMARY" ]] && echo "  Patterns used: ${PATTERN_SUMMARY}"

        # Show remaining ungraded predictions (first 3)
        REMAINING=$((TOTAL_PRED - TOTAL_GRADED))
        if [[ "$REMAINING" -gt 0 && -n "$SKIP_PREDICTIONS" ]]; then
            SKIP_PREDICTIONS="${SKIP_PREDICTIONS%;*}"
            echo "  Ungraded (${REMAINING}): ${SKIP_PREDICTIONS:0:200}"
        fi
    fi
fi

# --- Consolidate knowledge: append model_updates to experiment-learnings.md ---
consolidate_knowledge() {
    local learnings_file="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && learnings_file="$HOME/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && return 0

    # Collect new updates by zone: known, uncertain, dead_end
    local known_entries="" uncertain_entries="" dead_entries=""
    local consolidated=0

    while IFS=$'\t' read -r _date _agent _prediction _evidence _result _correct model_update; do
        [[ -z "$model_update" ]] && continue
        [[ -z "$_correct" ]] && continue

        # Deduplicate: skip if first 40 chars already present
        local dedup_key="${model_update:0:40}"
        if grep -qF "$dedup_key" "$learnings_file" 2>/dev/null; then
            continue
        fi

        local entry="- **Auto-graded** (${_date}): ${model_update}"

        # Route to correct zone based on grading result
        case "$_correct" in
            yes)
                # Count how many similar entries already exist in Known Patterns
                local known_count=0
                # Extract a keyword from the prediction for matching (first 3+ char word)
                local keyword=""
                if [[ "$_prediction" =~ ([a-zA-Z_-]{4,}) ]]; then
                    keyword="${BASH_REMATCH[1]}"
                fi
                if [[ -n "$keyword" ]]; then
                    # Count entries in Known Patterns section that reference this keyword
                    known_count=$(awk '/^## Known Patterns/,/^## [A-Z]/' "$learnings_file" | grep -ciF "$keyword" 2>/dev/null || echo "0")
                fi
                if [[ "$known_count" -ge 2 ]]; then
                    # 2+ existing matches + this new one = 3+ → Known Patterns
                    known_entries="${known_entries}\n${entry}"
                else
                    # <3 matching entries → Uncertain Patterns
                    uncertain_entries="${uncertain_entries}\n${entry}"
                fi
                ;;
            no)
                # Check if this is a repeated failure (dead end candidate)
                local fail_count=0
                local fail_keyword=""
                if [[ "$_prediction" =~ ([a-zA-Z_-]{4,}) ]]; then
                    fail_keyword="${BASH_REMATCH[1]}"
                fi
                if [[ -n "$fail_keyword" ]]; then
                    fail_count=$(awk '/^## Dead Ends/,0' "$learnings_file" | grep -ciF "$fail_keyword" 2>/dev/null || echo "0")
                fi
                if [[ "$fail_count" -ge 1 ]]; then
                    # Already a dead end entry → add to Dead Ends
                    dead_entries="${dead_entries}\n${entry}"
                else
                    # First failure → Uncertain Patterns (might be noise)
                    uncertain_entries="${uncertain_entries}\n${entry}"
                fi
                ;;
            partial)
                # Partial results always go to Uncertain Patterns
                uncertain_entries="${uncertain_entries}\n${entry}"
                ;;
        esac
        consolidated=$((consolidated + 1))
    done < <(tail -n +2 "$PRED_FILE")

    [[ "$consolidated" -eq 0 ]] && return 0

    # Insert entries into their correct zones
    local temp_learnings
    temp_learnings=$(mktemp)
    local inserted_known=false inserted_uncertain=false inserted_dead=false

    while IFS= read -r line; do
        # Insert known entries before "## Uncertain Patterns"
        if [[ "$line" == "## Uncertain Patterns"* ]] && ! $inserted_known && [[ -n "$known_entries" ]]; then
            printf "%b\n\n" "$known_entries" >> "$temp_learnings"
            inserted_known=true
        fi
        # Insert uncertain entries before "## Unknown Territory"
        if [[ "$line" == "## Unknown Territory"* ]] && ! $inserted_uncertain && [[ -n "$uncertain_entries" ]]; then
            printf "%b\n\n" "$uncertain_entries" >> "$temp_learnings"
            inserted_uncertain=true
        fi
        # Insert dead end entries before end-of-file (after "## Dead Ends" section heading)
        if [[ "$line" == "## Dead Ends"* ]] && ! $inserted_dead && [[ -n "$dead_entries" ]]; then
            printf "%s\n" "$line" >> "$temp_learnings"
            # Read next line (usually blank or first entry) then insert
            printf "%b\n" "$dead_entries" >> "$temp_learnings"
            inserted_dead=true
            continue
        fi
        printf "%s\n" "$line" >> "$temp_learnings"
    done < "$learnings_file"

    # Fallback: if sections weren't found, append at end
    if [[ -n "$known_entries" ]] && ! $inserted_known; then
        printf "\n%b\n" "$known_entries" >> "$temp_learnings"
    fi
    if [[ -n "$uncertain_entries" ]] && ! $inserted_uncertain; then
        printf "\n%b\n" "$uncertain_entries" >> "$temp_learnings"
    fi
    if [[ -n "$dead_entries" ]] && ! $inserted_dead; then
        printf "\n%b\n" "$dead_entries" >> "$temp_learnings"
    fi

    mv "$temp_learnings" "$learnings_file"
    $QUIET || echo "Consolidated $consolidated learning(s) into experiment-learnings.md"
}

$DRY_RUN || consolidate_knowledge

# --- Staleness detection: flag entries not referenced by predictions in 30+ days ---
detect_stale_entries() {
    local learnings_file="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && learnings_file="$HOME/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && return 0

    local stale_days=30
    local cutoff_date
    cutoff_date=$(date -v-${stale_days}d '+%Y-%m-%d' 2>/dev/null || date -d "${stale_days} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
    [[ -z "$cutoff_date" ]] && return 0

    # Extract dated entries and check which are stale
    local stale_entries=0
    local total_dated=0
    local stale_list=""

    while IFS= read -r entry_line; do
        local entry_date=""
        if [[ "$entry_line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            entry_date="${BASH_REMATCH[1]}"
        else
            continue
        fi
        total_dated=$((total_dated + 1))

        if [[ "$entry_date" < "$cutoff_date" ]]; then
            # Check if any recent prediction references this entry
            local entry_snippet="${entry_line:0:60}"
            entry_snippet="${entry_snippet//\"/}"
            local referenced=false
            if [[ -f "$PRED_FILE" ]]; then
                if tail -n +2 "$PRED_FILE" | awk -F'\t' -v cutoff="$cutoff_date" '$1 >= cutoff' | grep -qiF "${entry_snippet:0:25}" 2>/dev/null; then
                    referenced=true
                fi
            fi
            if [[ "$referenced" == "false" ]]; then
                stale_entries=$((stale_entries + 1))
                local display="${entry_line:0:80}"
                stale_list="${stale_list}\n    ${display}..."
            fi
        fi
    done < <(grep '^\s*-\s.*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$learnings_file" 2>/dev/null)

    if [[ "$stale_entries" -gt 0 ]]; then
        $QUIET || echo ""
        $QUIET || echo "Stale knowledge: ${stale_entries} entries not referenced in ${stale_days}d"
        if [[ "$QUIET" == false && -n "$stale_list" ]]; then
            echo -e "$stale_list" | head -5
            [[ "$stale_entries" -gt 5 ]] && echo "    ... and $((stale_entries - 5)) more. Run /retro to prune."
        fi
    fi
}

detect_stale_entries
