#!/usr/bin/env bash
# grade.sh — Auto-grade predictions by comparing claims against score history.
#
# Usage: bash bin/grade.sh [predictions.tsv] [history.tsv] [score-cache.json]
#
# For each ungraded prediction:
#   1. Extract directional claim ("raise X from N to M", "will drop", etc.)
#   2. Find score data AFTER the prediction date
#   3. Compare direction + magnitude → grade yes/partial/no
#   4. Fill result, correct, model_update columns
#
# Skips predictions with no extractable directional claim (leave for /retro).
# Called from: session_start.sh (--quiet), /retro, /plan step 3.

set -uo pipefail

QUIET=false
if [[ "${1:-}" == "--quiet" ]]; then
    QUIET=true
    shift
fi

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PRED_FILE="${1:-$PROJECT_DIR/.claude/knowledge/predictions.tsv}"
HISTORY_FILE="${2:-$PROJECT_DIR/.claude/scores/history.tsv}"
CACHE_FILE="${3:-$PROJECT_DIR/.claude/cache/score-cache.json}"

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

# Extract claim components from prediction text.
# Returns: direction feature from_val to_val
# direction: raise|drop|improve|stable
parse_claim() {
    local text="$1"
    local direction="" feature="" from_val="" to_val=""

    # Pattern: "raise X from N to M+"
    if [[ "$text" =~ raise[[:space:]]+([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "will raise X from N to M+"
    elif [[ "$text" =~ will[[:space:]]+raise[[:space:]]+([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "X from N to M+"
    elif [[ "$text" =~ ([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "will drop" / "will decrease"
    elif [[ "$text" =~ will[[:space:]]+(drop|decrease|lower) ]]; then
        direction="drop"
    # Pattern: "will improve" / "will increase"
    elif [[ "$text" =~ will[[:space:]]+(improve|increase) ]]; then
        direction="raise"
    # Pattern: "X will work" / "X will succeed"
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(work|succeed|pass) ]]; then
        direction="will_work"
        feature="${BASH_REMATCH[1]}"
    # Pattern: "X will fail" / "X will break"
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(fail|break|crash) ]]; then
        direction="will_fail"
        feature="${BASH_REMATCH[1]}"
    # Pattern: "N assertions will pass"
    elif [[ "$text" =~ ([0-9]+)[[:space:]]+assertions?[[:space:]]+will[[:space:]]+pass ]]; then
        direction="assertion_count"
        to_val="${BASH_REMATCH[1]}"
    # Pattern: "feature X exists" / "file X exists"
    elif [[ "$text" =~ (feature|file)[[:space:]]+([a-zA-Z_./-]+)[[:space:]]+exists ]]; then
        direction="exists"
        feature="${BASH_REMATCH[2]}"
    # Pattern: "file X contains Y" / "X contains Y"
    elif [[ "$text" =~ ([a-zA-Z_./-]+)[[:space:]]+contains ]]; then
        direction="contains"
        feature="${BASH_REMATCH[1]}"
    # --- NEW PATTERNS (v9.0.1) ---
    # Pattern: "X will improve/increase/decrease/drop" (directional, no numbers)
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(improve|increase|raise|grow|rise) ]]; then
        direction="directional_up"
        feature="${BASH_REMATCH[1]}"
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(decrease|drop|lower|decline|shrink|fall) ]]; then
        direction="directional_down"
        feature="${BASH_REMATCH[1]}"
    # Pattern: "X will reach/exceed/hit N" (numeric target)
    elif [[ "$text" =~ (reach|exceed|hit|get[[:space:]]+to)[[:space:]]+([0-9]+) ]]; then
        direction="numeric_target"
        to_val="${BASH_REMATCH[2]}"
        # Try to extract feature name before the verb
        if [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(reach|exceed|hit|get[[:space:]]+to) ]]; then
            feature="${BASH_REMATCH[1]}"
        fi
    # Pattern: "X eval/score N" or "X feature will score N" (eval-cache lookup)
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+(eval|feature)[[:space:]]+(from[[:space:]]+[0-9]+[[:space:]]+)?to[[:space:]]+([0-9]+) ]]; then
        direction="eval_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[4]}"
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?score[[:space:]]+([0-9]+) ]]; then
        direction="eval_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "score N" / "to score N" (overall score target)
    elif [[ "$text" =~ (score|scoring)[[:space:]]+(stays?[[:space:]]+at[[:space:]]+|at[[:space:]]+|to[[:space:]]+)?([0-9]+) ]]; then
        direction="score_target"
        feature="score"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "N sessions/days/weeks/months to..." (time-based — can check elapsed)
    elif [[ "$text" =~ ([0-9]+)[[:space:]]+(sessions?|days?|weeks?|months?) ]]; then
        direction="time_based"
        to_val="${BASH_REMATCH[1]}"
        feature="${BASH_REMATCH[2]}"
    # Pattern: "will produce/generate/create" (output claim — boolean)
    elif [[ "$text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(produce|generate|create|enable|reduce|eliminate) ]]; then
        direction="will_work"
        feature="${BASH_REMATCH[1]}"
    # Pattern: "will be the highest/best/hardest/most" (superlative — can't auto-grade)
    elif [[ "$text" =~ will[[:space:]]+be[[:space:]]+the[[:space:]]+(highest|best|hardest|most|lowest|worst|easiest) ]]; then
        direction="superlative"
    # Pattern: "X because Y" (causal — extract the X claim as boolean)
    elif [[ "$text" =~ (.+)[[:space:]]+because[[:space:]] ]]; then
        local causal_claim="${BASH_REMATCH[1]}"
        # If the causal claim itself contains a gradeable verb, recurse-parse it
        if [[ "$causal_claim" =~ (will[[:space:]]+)?(work|succeed|pass|ship|land|hold|transfer|get) ]]; then
            direction="causal_bool"
            feature="causal"
        fi
    fi

    echo "$direction|$feature|$from_val|$to_val"
}

# Grade a single prediction
grade_prediction() {
    local prediction="$1"
    local claim
    claim=$(parse_claim "$prediction")

    local direction feature from_val to_val
    IFS='|' read -r direction feature from_val to_val <<< "$claim"

    # Can't extract a directional claim — skip for manual grading
    if [[ -z "$direction" ]]; then
        echo "SKIP"
        return
    fi

    # Some patterns (assertion_count, score_target, causal_bool, time_based, superlative)
    # don't need a feature name — only skip if the specific pattern requires one
    if [[ -z "$feature" && "$direction" != "assertion_count" && "$direction" != "score_target" \
        && "$direction" != "causal_bool" && "$direction" != "time_based" \
        && "$direction" != "superlative" && "$direction" != "numeric_target" ]]; then
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

    # If feature not found by exact name, try total score
    if [[ -z "$current_score" ]]; then
        if [[ "$feature" == "score" || "$feature" == "total" ]]; then
            current_score=$(get_total_score)
        fi
    fi

    # --- NEW GRADING LOGIC (v9.0.1) ---

    # "directional_up" — check if feature score went up vs any baseline
    if [[ "$direction" == "directional_up" ]]; then
        if [[ -n "$current_score" && "$current_score" -gt 0 ]]; then
            # Check history for a prior score to compare
            if [[ -f "$HISTORY_FILE" ]]; then
                PREV=$(tail -n +2 "$HISTORY_FILE" 2>/dev/null | head -1 | cut -f5 2>/dev/null || echo "")
                if [[ -n "$PREV" && "$PREV" =~ ^[0-9]+$ && "$current_score" -gt "$PREV" ]]; then
                    echo "YES|Improved: ${PREV}→${current_score}"
                elif [[ -n "$PREV" && "$PREV" =~ ^[0-9]+$ && "$current_score" -eq "$PREV" ]]; then
                    echo "NO|Unchanged at ${current_score}"
                else
                    echo "SKIP"
                fi
            else
                echo "SKIP"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "directional_down" — check if feature score went down
    if [[ "$direction" == "directional_down" ]]; then
        if [[ -n "$current_score" && -f "$HISTORY_FILE" ]]; then
            PREV=$(tail -n +2 "$HISTORY_FILE" 2>/dev/null | head -1 | cut -f5 2>/dev/null || echo "")
            if [[ -n "$PREV" && "$PREV" =~ ^[0-9]+$ && "$current_score" -lt "$PREV" ]]; then
                echo "YES|Decreased: ${PREV}→${current_score}"
            elif [[ -n "$PREV" && "$PREV" =~ ^[0-9]+$ ]]; then
                echo "NO|Did not decrease: ${PREV}→${current_score}"
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

    # "time_based" — can't verify time claims mechanically
    if [[ "$direction" == "time_based" ]]; then
        echo "SKIP"
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
    grade_result=$(grade_prediction "$prediction")
    grade_verdict="${grade_result%%|*}"
    grade_detail="${grade_result#*|}"

    # If prediction column didn't match, try agent column (column shift recovery)
    if [[ "$grade_verdict" == "SKIP" && -n "$agent" && ${#agent} -gt 20 ]]; then
        grade_result=$(grade_prediction "$agent")
        grade_verdict="${grade_result%%|*}"
        grade_detail="${grade_result#*|}"
    fi

    if [[ "$grade_verdict" == "SKIP" ]]; then
        # Can't auto-grade — pass through unchanged
        echo "$line" >> "$TEMP_FILE"
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

    # Write graded row
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$date" "$agent" "$prediction" "$evidence" \
        "$grade_detail" "$correct_val" "$local_model_update" >> "$TEMP_FILE"

    GRADED_COUNT=$((GRADED_COUNT + 1))

    if [[ "$QUIET" == false ]]; then
        case "$correct_val" in
            yes)     echo "  ✓ \"$prediction\" → $grade_detail" ;;
            partial) echo "  · \"$prediction\" → $grade_detail" ;;
            no)      echo "  ✗ \"$prediction\" → $grade_detail" ;;
        esac
    fi
done < "$PRED_FILE"

# Atomic write
if [[ "$GRADED_COUNT" -gt 0 ]]; then
    mv "$TEMP_FILE" "$PRED_FILE"
    $QUIET || echo ""
    $QUIET || echo "Graded $GRADED_COUNT prediction(s). $(( UNGRADED - GRADED_COUNT )) remaining for manual review."
else
    rm -f "$TEMP_FILE"
    $QUIET || echo "No predictions could be auto-graded. Run /retro for manual grading."
fi

# --- Consolidate knowledge: append model_updates to experiment-learnings.md ---
consolidate_knowledge() {
    local learnings_file="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && learnings_file="$HOME/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && return 0

    # Collect new updates (not already in the file)
    local new_entries=""
    local consolidated=0

    while IFS=$'\t' read -r _date _agent _prediction _evidence _result _correct model_update; do
        [[ -z "$model_update" ]] && continue
        [[ -z "$_correct" ]] && continue

        # Deduplicate: skip if first 40 chars already present
        local dedup_key="${model_update:0:40}"
        if grep -qF "$dedup_key" "$learnings_file" 2>/dev/null; then
            continue
        fi

        new_entries="${new_entries}\n- **Auto-graded** (${_date}): ${model_update}"
        consolidated=$((consolidated + 1))
    done < <(tail -n +2 "$PRED_FILE")

    [[ "$consolidated" -eq 0 ]] && return 0

    # Insert before "## Unknown Territory" (which follows Uncertain Patterns)
    local marker="## Unknown Territory"
    if grep -q "^${marker}" "$learnings_file"; then
        local temp_learnings
        temp_learnings=$(mktemp)
        local inserted=false

        while IFS= read -r line; do
            if [[ "$line" == "$marker"* ]] && ! $inserted; then
                # Insert new entries before Unknown Territory
                printf "%b\n\n" "$new_entries" >> "$temp_learnings"
                inserted=true
            fi
            printf "%s\n" "$line" >> "$temp_learnings"
        done < "$learnings_file"

        if $inserted; then
            mv "$temp_learnings" "$learnings_file"
        else
            rm -f "$temp_learnings"
        fi
    else
        # No Unknown Territory section — append at end
        printf "\n%b\n" "$new_entries" >> "$learnings_file"
    fi

    $QUIET || echo "Consolidated $consolidated learning(s) into experiment-learnings.md"
}

consolidate_knowledge

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
