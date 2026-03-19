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

# Source library files
source "${SCRIPT_DIR}/lib/grade-data.sh"
source "${SCRIPT_DIR}/lib/grade-signals.sh"
source "${SCRIPT_DIR}/lib/grade-claims.sh"
source "${SCRIPT_DIR}/lib/grade-consolidation.sh"

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

$DRY_RUN || consolidate_knowledge

detect_stale_entries
