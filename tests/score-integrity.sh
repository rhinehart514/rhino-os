#!/usr/bin/env bash
# score-integrity.sh — Validates scoring system produces correct relative ordering.
# Run: bash tests/score-integrity.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

assert() {
    local name="$1" condition="$2"
    if eval "$condition"; then
        PASS=$((PASS + 1))
        echo "  PASS  $name"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL  $name"
    fi
}

echo ""
echo "=== score integrity tests ==="
echo ""

# Score each fixture
echo "--- scoring fixtures ---"

HEALTHY=$("$PROJECT_ROOT/bin/score.sh" "$PROJECT_ROOT/tests/fixtures/healthy" --quiet --force 2>/dev/null)
echo "  healthy: $HEALTHY"

MIXED=$("$PROJECT_ROOT/bin/score.sh" "$PROJECT_ROOT/tests/fixtures/mixed" --quiet --force 2>/dev/null)
echo "  mixed:   $MIXED"

BROKEN=$("$PROJECT_ROOT/bin/score.sh" "$PROJECT_ROOT/tests/fixtures/broken" --quiet --force 2>/dev/null)
echo "  broken:  $BROKEN"

echo ""
echo "--- relative ordering ---"

assert "healthy > mixed" "[[ $HEALTHY -gt $MIXED ]]"
assert "mixed > broken" "[[ $MIXED -gt $BROKEN ]]"
assert "healthy > broken" "[[ $HEALTHY -gt $BROKEN ]]"

echo ""
echo "--- absolute thresholds ---"

assert "healthy >= 80" "[[ $HEALTHY -ge 80 ]]"
assert "broken <= 30" "[[ $BROKEN -le 30 ]]"

echo ""
echo "--- summary ---"
TOTAL=$((PASS + FAIL))
echo "  $PASS/$TOTAL passed"

if [[ "$FAIL" -gt 0 ]]; then
    echo "  FAIL — $FAIL assertion(s) failed"
    exit 1
else
    echo "  ALL PASS"
    exit 0
fi
