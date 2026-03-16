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
        jq -r ".features.\"$feature\".score // empty" "$CACHE_FILE" 2>/dev/null
    fi
}

get_total_score() {
    if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
        jq -r '.score // empty' "$CACHE_FILE" 2>/dev/null
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
    if [[ -z "$direction" || -z "$feature" ]]; then
        echo "SKIP"
        return
    fi

    # Get current score for that feature
    local current_score
    current_score=$(get_feature_score "$feature")

    # If feature not found by exact name, try total score
    if [[ -z "$current_score" ]]; then
        if [[ "$feature" == "score" || "$feature" == "total" ]]; then
            current_score=$(get_total_score)
        fi
    fi

    if [[ -z "$current_score" ]]; then
        echo "SKIP"
        return
    fi

    # Grade based on direction — expanded pattern matching

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

    # Already graded — pass through
    if [[ -n "$correct" ]]; then
        echo "$line" >> "$TEMP_FILE"
        continue
    fi

    # Try to grade
    grade_result=$(grade_prediction "$prediction")
    grade_verdict="${grade_result%%|*}"
    grade_detail="${grade_result#*|}"

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

    # Build model_update for wrong predictions
    local_model_update=""
    if [[ "$correct_val" == "no" ]]; then
        local_model_update="Prediction missed target. Actual outcome: ${grade_detail}"
    fi

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
