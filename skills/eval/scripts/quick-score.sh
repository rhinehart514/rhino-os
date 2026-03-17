#!/usr/bin/env bash
# Quick assertion score — no LLM, just mechanical checks
# Usage: bash scripts/quick-score.sh [feature]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FEATURE="${1:-}"
if [[ -n "$FEATURE" ]]; then
    "$RHINO_DIR/bin/eval.sh" --no-llm --score --feature "$FEATURE" 2>/dev/null
else
    "$RHINO_DIR/bin/eval.sh" --no-llm --score 2>/dev/null
fi
