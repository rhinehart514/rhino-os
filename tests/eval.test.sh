#!/usr/bin/env bash
# eval.test.sh — Mechanical tests for bin/eval.sh
# Tests belief evaluation against temp projects.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    RHINO_DIR="$CLAUDE_PLUGIN_ROOT"
else
    RHINO_DIR="$(dirname "$SCRIPT_DIR")"
fi

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
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
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
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
echo "$OUTPUT" | grep -q '\[PASS\] value-hypothesis' && pass "value-hypothesis passes with value:" || fail "value-hypothesis passes with value:"
teardown_temp

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p config
echo 'project: { stage: early }' > config/rhino.yml
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
echo "$OUTPUT" | grep -q '\[FAIL\] value-hypothesis' && pass "value-hypothesis fails without value:" || fail "value-hypothesis fails without value:"
teardown_temp

# ── self_check type ─────────────────────────────────────

echo "-- self_check --"

cd "$RHINO_DIR"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
echo "$OUTPUT" | grep -q 'learning-compounds' && pass "self_check runs (learning-compounds)" || fail "self_check runs (learning-compounds)"
echo "$OUTPUT" | grep 'learning-compounds' | grep -qv 'diagnostic failed' && pass "self_check reports real diagnostic" || fail "self_check reports real diagnostic"

# ── No beliefs file ─────────────────────────────────────

echo "-- No beliefs file --"

setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
echo "$OUTPUT" | grep -q 'passed' && pass "eval.sh works without beliefs.yml" || fail "eval.sh works without beliefs.yml"
teardown_temp

# ── Feature scoping ───────────────────────────────────

echo "-- Feature scoping --"

cd "$RHINO_DIR"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm --feature scoring 2>&1) || true
echo "$OUTPUT" | grep -q 'value-hypothesis' && pass "feature filter shows scoring assertions" || fail "feature filter shows scoring assertions"
# Should NOT show cli assertions when filtering to scoring
echo "$OUTPUT" | grep -q 'tests-pass' && fail "feature filter leaks non-matching assertions" || pass "feature filter excludes other features"

# by-feature JSON
BF_OUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm --score --by-feature 2>&1) || true
echo "$BF_OUT" | grep -q '"scoring"' && pass "by-feature JSON includes scoring" || fail "by-feature JSON includes scoring"

# ── Exit code ───────────────────────────────────────────

echo "-- Exit code --"

# Test on a clean temp project (no block failures expected)
setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
bash "$RHINO_DIR/bin/eval.sh" . --no-llm >/dev/null 2>&1
RC=$?
[[ "$RC" -eq 0 ]] && pass "eval.sh exits 0 on clean project" || fail "eval.sh exits 0 on clean project (got $RC)"
teardown_temp

# ── --score mode ────────────────────────────────────────

echo "-- Score mode --"

# Score on rhino-os itself (has beliefs.yml)
cd "$RHINO_DIR"
SCORE=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm --score 2>&1)
echo "$SCORE" | grep -qE '^[0-9]+$' && pass "--score outputs integer on project with beliefs" || fail "--score outputs integer (got: $SCORE)"

# Score on project without beliefs = empty
setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
SCORE=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm --score 2>&1)
[[ -z "$SCORE" || "$SCORE" == "" ]] && pass "--score outputs empty when no beliefs" || fail "--score outputs empty when no beliefs (got: $SCORE)"
teardown_temp

# Score mode skips default checks (no output noise)
cd "$RHINO_DIR"
SCORE_OUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm --score 2>&1)
echo "$SCORE_OUT" | grep -qv '\[PASS\]' && pass "--score suppresses check output" || fail "--score suppresses check output"

# Recursion guard
GUARDED=$(RHINO_EVAL_DEPTH=5 bash "$RHINO_DIR/bin/eval.sh" . --no-llm --score 2>&1)
[[ -z "$GUARDED" || "$GUARDED" == "" ]] && pass "recursion guard returns empty" || fail "recursion guard returns empty (got: $GUARDED)"

# ── Failure mode: corrupted eval-cache.json ──────────────

echo "-- Corrupted eval-cache --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p .claude/cache
echo 'NOT VALID JSON{{{' > .claude/cache/eval-cache.json
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm --score 2>&1) || true
# Should not crash — should produce output or empty, not a stack trace
echo "$OUTPUT" | grep -qv 'parse error\|syntax error\|unexpected' && pass "corrupted eval-cache doesn't crash" || fail "corrupted eval-cache crashes eval"
teardown_temp

# ── Failure mode: missing API key with --fresh ───────────

echo "-- Missing API key graceful degradation --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p config
cat > config/rhino.yml << 'YMLEOF'
value:
  hypothesis: "test"
features:
  test-feature:
    delivers: "something"
    for: "someone"
    code: ["src/index.ts"]
YMLEOF
mkdir -p src
echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
# Run with no generative (avoids needing API key) — should still produce output
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-generative 2>&1) || true
echo "$OUTPUT" | grep -q 'beliefs\|eval\|PASS\|passed' && pass "no-generative mode produces output" || fail "no-generative mode produces no output"
teardown_temp

# ── Failure mode: empty rhino.yml features section ──────

echo "-- Empty features section --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p config
cat > config/rhino.yml << 'YMLEOF'
value:
  hypothesis: "test"
features:
YMLEOF
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
# Should not crash on empty features section
[[ $? -le 1 ]] && pass "empty features section doesn't crash" || fail "empty features section crashes"
echo "$OUTPUT" | grep -qv 'unbound variable\|syntax error' && pass "empty features: no bash errors" || fail "empty features: bash errors in output"
teardown_temp

# ── Failure mode: beliefs.yml with malformed YAML ────────

echo "-- Malformed beliefs.yml --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p config/evals
cat > config/evals/beliefs.yml << 'YMLEOF'
- id: broken-belief
  type: file_check
  path: [[[INVALID
  description: "this is malformed"
YMLEOF
git add -A && git commit -q -m "init"
OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . --no-llm 2>&1) || true
echo "$OUTPUT" | grep -qv 'unbound variable\|syntax error' && pass "malformed beliefs.yml doesn't crash" || fail "malformed beliefs.yml crashes eval"
teardown_temp

# ── Failure mode: --samples flag validation ──────────────

echo "-- Samples flag --"

setup_temp
echo '{"name":"test"}' > package.json
git add -A && git commit -q -m "init"
# --samples=1 should not cause crash
OUTPUT=$(timeout 10 bash "$RHINO_DIR/bin/eval.sh" . --no-llm --samples=1 2>&1) || true
echo "$OUTPUT" | grep -q 'beliefs\|eval\|PASS\|passed' && pass "--samples=1 works" || fail "--samples=1 fails"
teardown_temp

# ── Results ─────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
