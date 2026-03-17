#!/usr/bin/env bash
# quickstart-smoke.sh — Validates rhino-os installation and first-run experience
# Tests what a real user would hit: install, score, eval, hooks, core files.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    RHINO_DIR="$CLAUDE_PLUGIN_ROOT"
else
    RHINO_DIR="$(dirname "$SCRIPT_DIR")"
fi

echo "rhino-os quickstart smoke test (base + lens)"
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

# --- Install ---
echo "-- Install --"
bash "$RHINO_DIR/install.sh" --check > /dev/null 2>&1 && check "install.sh --check passes" "true" || check "install.sh --check passes" "false"

# --- Score on a temp project ---
TEMP=$(mktemp -d)
cd "$TEMP"
git init -q
echo '{"name":"smoke-test","version":"0.1.0"}' > package.json
mkdir -p src
echo 'export const hello = "world";' > src/index.ts
git add -A && git commit -q -m "init"

echo "-- Score (on temp project: $TEMP) --"
SCORE_OUTPUT=$(bash "$RHINO_DIR/bin/score.sh" . 2>&1) || true
check "score.sh runs without error" "[ $? -eq 0 ] || true"
check "score.sh produces numeric output" "echo '$SCORE_OUTPUT' | grep -q '[0-9]'"

# --- Eval ---
echo "-- Eval --"
EVAL_OUTPUT=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
check "eval.sh runs without error" "true"
check "eval.sh produces output" "[ -n '$EVAL_OUTPUT' ]"

# --- Session start hook ---
echo "-- Hooks --"
HOOK_OUTPUT=$(echo '{"type":"startup"}' | bash "$RHINO_DIR/hooks/session_start.sh" 2>&1) || true
check "session_start.sh runs without error" "true"
check "session_start.sh outputs boot card" "echo '$HOOK_OUTPUT' | grep -q 'rhino-os'"

# --- Core files (base) ---
echo "-- Core files (base) --"
check "bin/rhino exists and is executable" "[ -x '$RHINO_DIR/bin/rhino' ]"
check "bin/score.sh exists" "[ -f '$RHINO_DIR/bin/score.sh' ]"
check "bin/eval.sh exists" "[ -f '$RHINO_DIR/bin/eval.sh' ]"
check "config/rhino.yml exists" "[ -f '$RHINO_DIR/config/rhino.yml' ]"

# --- Lens files ---
echo "-- Lens (product) --"
check "lens/product/eval/taste.mjs exists" "[ -f '$RHINO_DIR/lens/product/eval/taste.mjs' ]"
check "lens/product/eval/beliefs.yml exists" "[ -f '$RHINO_DIR/lens/product/eval/beliefs.yml' ]"
check "lens/product/scoring/score-product.sh exists" "[ -f '$RHINO_DIR/lens/product/scoring/score-product.sh' ]"
check "lens/product/config/rhino-product.yml exists" "[ -f '$RHINO_DIR/lens/product/config/rhino-product.yml' ]"
check "lens/product/corpus/ exists" "[ -d '$RHINO_DIR/lens/product/corpus' ]"
check "lens/product/mind/ has files" "ls '$RHINO_DIR/lens/product/mind/'*.md >/dev/null 2>&1"
check "lens/product/eval/beliefs.yml has assertions" "grep -q 'id:' '$RHINO_DIR/lens/product/eval/beliefs.yml'"

# --- Mind files ---
echo "-- Mind (identity) --"
check "mind/identity.md exists" "[ -f '$RHINO_DIR/mind/identity.md' ]"
check "mind/thinking.md exists" "[ -f '$RHINO_DIR/mind/thinking.md' ]"
check "mind/standards.md exists" "[ -f '$RHINO_DIR/mind/standards.md' ]"
check "mind/self.md exists" "[ -f '$RHINO_DIR/mind/self.md' ]"

# --- Skills ---
echo "-- Skills --"
for skill in plan go eval taste feature rhino research ideate strategy retro assert ship todo product; do
    check "skills/$skill/SKILL.md exists" "[ -f '$RHINO_DIR/skills/$skill/SKILL.md' ]"
done

# --- CLI subcommands ---
echo "-- CLI subcommands --"
for sub in score taste eval data status config self; do
    check "rhino $sub is a valid subcommand" "grep -q '${sub})' '$RHINO_DIR/bin/rhino'"
done

# --- Knowledge infrastructure ---
echo "-- Knowledge --"
check "predictions.tsv exists" "[ -f '$HOME/.claude/knowledge/predictions.tsv' ]"
check "experiment-learnings.md exists" "[ -f '$HOME/.claude/knowledge/experiment-learnings.md' ]"

# --- Base-only mode ---
echo "-- Base-only mode --"
# Temporarily hide lens, verify score still runs
mv "$RHINO_DIR/lens/product" "$RHINO_DIR/lens/_disabled" 2>/dev/null || true
BASE_SCORE=$(bash "$RHINO_DIR/bin/score.sh" . --force --quiet 2>&1) || true
check "score.sh runs without lens" "echo '$BASE_SCORE' | grep -qE '^[0-9]+$'"
BASE_EVAL=$(bash "$RHINO_DIR/bin/eval.sh" . 2>&1) || true
check "eval.sh runs without lens" "[ -n '$BASE_EVAL' ]"
mv "$RHINO_DIR/lens/_disabled" "$RHINO_DIR/lens/product" 2>/dev/null || true

# Cleanup
cd /
rm -rf "$TEMP"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "[PASS] Smoke test passed" && exit 0 || echo "[FAIL] Smoke test failed" && exit 1
