#!/usr/bin/env bash
# self.test.sh — Tests for bin/self.sh 4-system diagnostic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RHINO_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

# ── --score mode ──────────────────────────────────────

echo "-- score mode --"

SCORE=$(bash "$RHINO_DIR/bin/self.sh" --score 2>&1)
echo "$SCORE" | grep -qE '^[0-9]+$' && pass "--score outputs integer" || fail "--score outputs integer (got: $SCORE)"
[[ "$SCORE" -ge 0 && "$SCORE" -le 100 ]] && pass "--score in 0-100 range" || fail "--score in 0-100 range (got: $SCORE)"

# ── --json mode ───────────────────────────────────────

echo "-- json mode --"

JSON=$(bash "$RHINO_DIR/bin/self.sh" --json 2>&1)
echo "$JSON" | grep -q '"measure"' && pass "--json has measure key" || fail "--json has measure key"
echo "$JSON" | grep -q '"think"' && pass "--json has think key" || fail "--json has think key"
echo "$JSON" | grep -q '"act"' && pass "--json has act key" || fail "--json has act key"
echo "$JSON" | grep -q '"learn"' && pass "--json has learn key" || fail "--json has learn key"
echo "$JSON" | grep -q '"total"' && pass "--json has total key" || fail "--json has total key"

# ── System scores sum to total ────────────────────────

echo "-- system scores --"

m=$(echo "$JSON" | sed 's/.*"measure":\([0-9]*\).*/\1/')
t=$(echo "$JSON" | sed 's/.*"think":\([0-9]*\).*/\1/')
a=$(echo "$JSON" | sed 's/.*"act":\([0-9]*\).*/\1/')
l=$(echo "$JSON" | sed 's/.*"learn":\([0-9]*\).*/\1/')
total=$(echo "$JSON" | sed 's/.*"total":\([0-9]*\).*/\1/')
computed=$((m + t + a + l))
[[ "$computed" -eq "$total" ]] && pass "M+T+A+L = total ($computed)" || fail "M+T+A+L ($computed) != total ($total)"

# Each system is 0-25
[[ "$m" -ge 0 && "$m" -le 25 ]] && pass "measure in 0-25 ($m)" || fail "measure out of range ($m)"
[[ "$t" -ge 0 && "$t" -le 25 ]] && pass "think in 0-25 ($t)" || fail "think out of range ($t)"
[[ "$a" -ge 0 && "$a" -le 25 ]] && pass "act in 0-25 ($a)" || fail "act out of range ($a)"
[[ "$l" -ge 0 && "$l" -le 25 ]] && pass "learn in 0-25 ($l)" || fail "learn out of range ($l)"

# ── Display mode ──────────────────────────────────────

echo "-- display mode --"

DISPLAY=$(bash "$RHINO_DIR/bin/self.sh" 2>&1)
echo "$DISPLAY" | grep -q 'Measure' && pass "display shows Measure system" || fail "display shows Measure system"
echo "$DISPLAY" | grep -q 'Think' && pass "display shows Think system" || fail "display shows Think system"
echo "$DISPLAY" | grep -q 'Act' && pass "display shows Act system" || fail "display shows Act system"
echo "$DISPLAY" | grep -q 'Learn' && pass "display shows Learn system" || fail "display shows Learn system"
echo "$DISPLAY" | grep -q 'Total:' && pass "display shows Total" || fail "display shows Total"

# ── Recursion guard ───────────────────────────────────

echo "-- recursion guard --"

GUARDED=$(RHINO_SELF_DEPTH=5 bash "$RHINO_DIR/bin/self.sh" --score 2>&1)
[[ "$GUARDED" == "50" ]] && pass "recursion guard returns 50" || fail "recursion guard returns 50 (got: $GUARDED)"

# ── Results ───────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
