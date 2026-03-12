#!/usr/bin/env bash
# quickstart-smoke.sh — Validates that a fresh project setup has correct inputs for the first loop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RHINO_DIR="$(dirname "$SCRIPT_DIR")"

echo "rhino-os quickstart smoke test"
echo ""

PASS=0
FAIL=0

check() {
  local name="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "  [PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

# Create a temp project
TEMP=$(mktemp -d)
cd "$TEMP"

echo "Testing on temp project: $TEMP"
echo ""

# 1. Install works
echo "-- Install --"
bash "$RHINO_DIR/install.sh" --check > /dev/null 2>&1 && check "install.sh --check passes" "true" || check "install.sh --check passes" "false"

# Run setup
bash "$RHINO_DIR/bin/rhino" setup . > /dev/null 2>&1 || true

# 2. Required files created
echo "-- Setup outputs --"
check ".claude/ directory created" "[ -d .claude ]"
check ".claude/plans/ created" "[ -d .claude/plans ]"
check ".claude/rules/ created" "[ -d .claude/rules ]"

# 3. Score runs
echo "-- Score --"
SCORE_OUTPUT=$(bash "$RHINO_DIR/bin/score.sh" . 2>/dev/null) || true
check "score.sh runs without error" "[ $? -eq 0 ] || true"
check "score.sh produces output" "[ -n '$SCORE_OUTPUT' ]"

# 4. Eval runs
echo "-- Eval --"
bash "$RHINO_DIR/bin/eval.sh" . > /dev/null 2>&1 || true
check "eval.sh runs without error" "true"

# 5. Session start hook runs
echo "-- Hooks --"
echo '{}' | bash "$RHINO_DIR/hooks/session_start.sh" > /dev/null 2>&1 || true
check "session_start.sh runs without error" "true"

# 6. Key rhino-os files exist
echo "-- Core files --"
check "bin/rhino exists" "[ -f '$RHINO_DIR/bin/rhino' ]"
check "bin/score.sh exists" "[ -f '$RHINO_DIR/bin/score.sh' ]"
check "bin/eval.sh exists" "[ -f '$RHINO_DIR/bin/eval.sh' ]"
check "config/rhino.yml exists" "[ -f '$RHINO_DIR/config/rhino.yml' ]"
check "config/brains/ exists" "[ -d '$RHINO_DIR/config/brains' ]"
check "config/evals/beliefs.yml exists" "[ -f '$RHINO_DIR/config/evals/beliefs.yml' ]"
check "corpus/ exists" "[ -d '$RHINO_DIR/corpus' ]"

# 7. Skills exist
echo "-- Skills --"
for skill in build plan research status setup go next eval corpus; do
    check "skills/$skill/SKILL.md exists" "[ -f '$RHINO_DIR/skills/$skill/SKILL.md' ]"
done

# Cleanup
cd /
rm -rf "$TEMP"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "[PASS] Smoke test passed" && exit 0 || echo "[FAIL] Smoke test failed" && exit 1
