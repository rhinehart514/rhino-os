#!/usr/bin/env bash
# Pre-flight check before shipping
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "── pre-flight ──"
PASS=0
FAIL=0
WARN=0
# 1. Score check
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]] && command -v jq &>/dev/null; then
    SCORE=$(jq -r '.score // 0' "$SCORE_CACHE" 2>/dev/null)
    if [[ "$SCORE" -lt 30 ]]; then
        echo "  ✗ score: $SCORE (below 30 threshold)"
        FAIL=$((FAIL+1))
    else
        echo "  ✓ score: $SCORE"
        PASS=$((PASS+1))
    fi
else
    echo "  ⚠ no score cache"
    WARN=$((WARN+1))
fi
# 2. Uncommitted changes
DIRTY=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$DIRTY" -gt 0 ]]; then
    echo "  ⚠ $DIRTY uncommitted files"
    WARN=$((WARN+1))
else
    echo "  ✓ clean working tree"
    PASS=$((PASS+1))
fi
# 3. Deploy confidence
CONFIDENCE=$("$RHINO_DIR/bin/compute-deploy-confidence.sh" 2>/dev/null | grep 'confidence:' | awk '{print $2}')
if [[ -n "$CONFIDENCE" && "$CONFIDENCE" -lt 50 ]]; then
    echo "  ✗ deploy confidence: ${CONFIDENCE}%"
    FAIL=$((FAIL+1))
elif [[ -n "$CONFIDENCE" ]]; then
    echo "  ✓ deploy confidence: ${CONFIDENCE}%"
    PASS=$((PASS+1))
fi
# 4. Secret detection in staged diff
SECRETS=$(git -C "$PROJECT_DIR" diff --cached 2>/dev/null | grep -iE '(api_key|secret|password|token|credential).*=' | wc -l | tr -d ' ')
if [[ "$SECRETS" -gt 0 ]]; then
    echo "  ✗ $SECRETS potential secrets in diff"
    FAIL=$((FAIL+1))
else
    echo "  ✓ no secrets detected"
    PASS=$((PASS+1))
fi
echo ""
echo "  result: $PASS pass · $FAIL fail · $WARN warn"
if [[ "$FAIL" -gt 0 ]]; then
    echo "  verdict: BLOCK"
    exit 1
else
    echo "  verdict: SHIP"
fi
