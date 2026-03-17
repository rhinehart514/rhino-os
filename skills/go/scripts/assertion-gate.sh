#!/usr/bin/env bash
# Quick assertion gate for /go build loop
# Usage: bash scripts/assertion-gate.sh [feature]
# Output: pass_count/total status
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FEATURE="${1:-}"

RESULT=$("$RHINO_DIR/bin/eval.sh" --no-llm --score ${FEATURE:+--feature "$FEATURE"} 2>/dev/null || echo "")

if [[ -z "$RESULT" ]]; then
    echo "0/0 error"
    exit 1
fi

# Parse output — eval.sh --score outputs JSON or plain number
if command -v jq &>/dev/null; then
    PASS=$(echo "$RESULT" | jq -r '.assertion_pass_count // .pass // 0' 2>/dev/null || echo "0")
    TOTAL=$(echo "$RESULT" | jq -r '.assertion_count // .total // 0' 2>/dev/null || echo "0")
else
    PASS="?"
    TOTAL="?"
fi

if [[ "$PASS" == "$TOTAL" && "$TOTAL" != "0" ]]; then
    echo "$PASS/$TOTAL pass"
else
    echo "$PASS/$TOTAL check"
fi
