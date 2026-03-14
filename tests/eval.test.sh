#!/usr/bin/env bash
# eval.test.sh — Mechanical tests for bin/eval.sh
# Tests belief evaluation against temp projects.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RHINO_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
TEMP=""

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

setup_temp() {
  TEMP=$(mktemp -d)
  cd "$TEMP"
  git init -q
}

teardown_temp() {
  cd /
  [[ -n "$TEMP" ]] && rm -rf "$TEMP"
  TEMP=""
}

# ── Basic run ───────────────────────────────────────────

echo "-- Basic run --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src
echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
echo "$OUTPUT" | grep -q 'passed' && pass "eval.sh produces summary" || fail "eval.sh produces summary"
teardown_temp

# ── file_check: value-hypothesis ────────────────────────

echo "-- file_check: value-hypothesis --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p config
cat > config/rhino.yml << 'YMLEOF'
value:
  hypothesis: "Users get value"
YMLEOF
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
echo "$OUTPUT" | grep -q '\[PASS\] value-hypothesis' && pass "value-hypothesis passes with value:" || fail "value-hypothesis passes with value:"
teardown_temp

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p config
echo 'project: { stage: early }' > config/rhino.yml
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
echo "$OUTPUT" | grep -q '\[FAIL\] value-hypothesis' && pass "value-hypothesis fails without value:" || fail "value-hypothesis fails without value:"
teardown_temp

# ── self_check type ─────────────────────────────────────

echo "-- self_check --"

cd "$RHINO_DIR"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
echo "$OUTPUT" | grep -q 'learning-compounds' && pass "self_check runs (learning-compounds)" || fail "self_check runs (learning-compounds)"
echo "$OUTPUT" | grep 'learning-compounds' | grep -qv 'diagnostic failed' && pass "self_check reports real diagnostic" || fail "self_check reports real diagnostic"

# ── No beliefs file ─────────────────────────────────────

echo "-- No beliefs file --"

setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
echo "$OUTPUT" | grep -q 'passed' && pass "eval.sh works without beliefs.yml" || fail "eval.sh works without beliefs.yml"
teardown_temp

# ── URL-dependent checks warn ───────────────────────────

echo "-- No dev server warns --"

cd "$RHINO_DIR"
unset EVAL_URL
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
echo "$OUTPUT" | grep 'dom_check' | grep -q 'WARN' && pass "dom_check warns without dev server" || fail "dom_check warns without dev server"
echo "$OUTPUT" | grep 'copy_check' | grep -q 'WARN' && pass "copy_check warns without dev server" || fail "copy_check warns without dev server"
echo "$OUTPUT" | grep 'playwright_task' | grep -q 'WARN' && pass "playwright_task warns without dev server" || fail "playwright_task warns without dev server"

# ── Exit code ───────────────────────────────────────────

echo "-- Exit code --"

# Test on a clean temp project (no block failures expected)
setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
bash "$RHINO_DIR/bin/eval.sh" . >/dev/null 2>&1
RC=$?
[[ "$RC" -eq 0 ]] && pass "eval.sh exits 0 on clean project" || fail "eval.sh exits 0 on clean project (got $RC)"
teardown_temp

# ── --score mode ────────────────────────────────────────

echo "-- Score mode --"

# Score on rhino-os itself (has beliefs.yml)
cd "$RHINO_DIR"
SCORE=$(bash "$RHINO_DIR/bin/eval.sh" . --score 2>&1)
echo "$SCORE" | grep -qE '^[0-9]+$' && pass "--score outputs integer on project with beliefs" || fail "--score outputs integer (got: $SCORE)"

# Score on project without beliefs = empty
setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
SCORE=$(bash "$RHINO_DIR/bin/eval.sh" . --score 2>&1)
[[ -z "$SCORE" || "$SCORE" == "" ]] && pass "--score outputs empty when no beliefs" || fail "--score outputs empty when no beliefs (got: $SCORE)"
teardown_temp

# Score mode skips default checks (no output noise)
cd "$RHINO_DIR"
SCORE_OUT=$(bash "$RHINO_DIR/bin/eval.sh" . --score 2>&1)
echo "$SCORE_OUT" | grep -qv '\[PASS\]' && pass "--score suppresses check output" || fail "--score suppresses check output"

# Recursion guard
GUARDED=$(RHINO_EVAL_DEPTH=5 bash "$RHINO_DIR/bin/eval.sh" . --score 2>&1)
[[ -z "$GUARDED" || "$GUARDED" == "" ]] && pass "recursion guard returns empty" || fail "recursion guard returns empty (got: $GUARDED)"

# ── Results ─────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
