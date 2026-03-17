#!/usr/bin/env bash
# Show rubric status for all features
# Usage: bash scripts/rubric-status.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUBRIC_DIR="$PROJECT_DIR/.claude/cache/rubrics"

echo "── rubric status ──"
if [[ ! -d "$RUBRIC_DIR" ]]; then
    echo "  no rubrics directory"
    exit 0
fi

for f in "$RUBRIC_DIR"/*.json; do
    [[ ! -f "$f" ]] && continue
    NAME=$(basename "$f" .json)
    if command -v jq &>/dev/null; then
        SCORE=$(jq -r '.last_score // "?"' "$f" 2>/dev/null)
        DATE=$(jq -r '.last_scored // "?"' "$f" 2>/dev/null | cut -d'T' -f1)
        GAPS=$(jq -r '.known_gaps | length // 0' "$f" 2>/dev/null)
        echo "  $NAME: $SCORE/100 (scored $DATE, $GAPS known gaps)"
    else
        echo "  $NAME: $(wc -l < "$f" | tr -d ' ') lines"
    fi
done
