#!/usr/bin/env bash
# Show assertion statistics: pass rates by type, distribution, orphans
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BELIEFS=""
for bf in "$PROJECT_DIR/lens/product/eval/beliefs.yml" "$PROJECT_DIR/config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS="$bf" && break
done
echo "── assertion stats ──"
if [[ -z "$BELIEFS" ]]; then
    echo "  no beliefs.yml found"
    exit 0
fi
TOTAL=$(grep -c '^\s*- id:' "$BELIEFS" 2>/dev/null || echo "0")
echo "  total: $TOTAL"
echo ""
echo "  by type:"
for type in file_check content_check command_check score_check llm_judge score_trend; do
    COUNT=$(grep -c "type: $type" "$BELIEFS" 2>/dev/null || echo "0")
    [[ "$COUNT" -gt 0 ]] && echo "    $type: $COUNT"
done
echo ""
echo "  by severity:"
for sev in block warn info; do
    COUNT=$(grep -c "severity: $sev" "$BELIEFS" 2>/dev/null || echo "0")
    [[ "$COUNT" -gt 0 ]] && echo "    $sev: $COUNT"
done
