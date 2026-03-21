#!/usr/bin/env bash
# benchmark.sh — Run eval against a project and save results for calibration.
#
# Usage:
#   calibration/benchmark.sh <project-dir>
#   calibration/benchmark.sh .                    # benchmark rhino-os itself
#   calibration/benchmark.sh tests/fixtures/healthy

set -uo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: calibration/benchmark.sh <project-dir>"
    exit 1
fi

PROJECT_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

mkdir -p "$RESULTS_DIR"

# Resolve project path
if [[ ! "$PROJECT_DIR" = /* ]]; then
    PROJECT_DIR="$REPO_ROOT/$PROJECT_DIR"
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "  error: directory not found: $PROJECT_DIR"
    exit 1
fi

# Derive project name from path
PROJECT_NAME=$(basename "$PROJECT_DIR")
if [[ "$PROJECT_NAME" == "." || "$PROJECT_NAME" == ".." ]]; then
    PROJECT_NAME=$(basename "$(cd "$PROJECT_DIR" && pwd)")
fi

DATE=$(date +%Y-%m-%d)
RESULT_FILE="$RESULTS_DIR/${PROJECT_NAME}-${DATE}.json"

echo ""
echo "=== benchmark: $PROJECT_NAME ==="
echo ""

# Run eval with --json --score --no-generative (mechanical checks only for reproducibility)
echo "  running eval..."
EVAL_JSON=$("$REPO_ROOT/bin/eval.sh" "$PROJECT_DIR" --json --score --no-generative 2>/dev/null) || EVAL_JSON=""

if [[ -z "$EVAL_JSON" ]]; then
    echo "  error: eval produced no output for $PROJECT_DIR"
    exit 1
fi

# Extract score
if command -v jq &>/dev/null; then
    SCORE=$(echo "$EVAL_JSON" | jq -r '.score // "null"')
else
    SCORE=$(echo "$EVAL_JSON" | grep -o '"score":[0-9]*' | head -1 | grep -o '[0-9]*$')
fi

echo "  score: $SCORE"

# Save result with metadata
if command -v jq &>/dev/null; then
    echo "$EVAL_JSON" | jq --arg name "$PROJECT_NAME" --arg date "$DATE" \
        '. + {benchmark_name: $name, benchmark_date: $date}' > "$RESULT_FILE"
else
    echo "$EVAL_JSON" > "$RESULT_FILE"
fi

echo "  saved: $RESULT_FILE"

# Check for previous results and show delta
PREV_FILES=$(ls -t "$RESULTS_DIR/${PROJECT_NAME}"-*.json 2>/dev/null | grep -v "$RESULT_FILE" | head -1)

if [[ -n "$PREV_FILES" && -f "$PREV_FILES" ]]; then
    if command -v jq &>/dev/null; then
        PREV_SCORE=$(jq -r '.score // "null"' "$PREV_FILES")
        PREV_DATE=$(jq -r '.benchmark_date // "unknown"' "$PREV_FILES")

        if [[ "$PREV_SCORE" != "null" && "$SCORE" != "null" ]]; then
            DELTA=$((SCORE - PREV_SCORE))
            if [[ "$DELTA" -gt 0 ]]; then
                echo "  delta: +${DELTA} (vs $PREV_DATE: $PREV_SCORE)"
            elif [[ "$DELTA" -lt 0 ]]; then
                echo "  delta: ${DELTA} (vs $PREV_DATE: $PREV_SCORE)"
            else
                echo "  delta: unchanged (vs $PREV_DATE: $PREV_SCORE)"
            fi
        fi
    else
        echo "  (install jq for delta comparison)"
    fi
fi

# Check against expected range from benchmarks.json
BENCHMARKS_FILE="$SCRIPT_DIR/benchmarks.json"
if [[ -f "$BENCHMARKS_FILE" ]] && command -v jq &>/dev/null; then
    # Match by name OR by path (basename of path matches project name)
    EXPECTED=$(jq -r --arg name "$PROJECT_NAME" \
        '.benchmarks[] | select(.name == $name or (.path | split("/") | last) == $name) | "\(.expected_range[0]) \(.expected_range[1])"' \
        "$BENCHMARKS_FILE" 2>/dev/null)

    if [[ -n "$EXPECTED" && "$SCORE" != "null" ]]; then
        read -r RANGE_MIN RANGE_MAX <<< "$EXPECTED"
        if [[ "$SCORE" -ge "$RANGE_MIN" && "$SCORE" -le "$RANGE_MAX" ]]; then
            echo "  range: PASS ($SCORE in [$RANGE_MIN, $RANGE_MAX])"
        else
            echo "  range: FAIL ($SCORE outside [$RANGE_MIN, $RANGE_MAX])"
        fi
    fi
fi

echo ""
