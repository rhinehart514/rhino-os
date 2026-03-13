#!/usr/bin/env bash
# score.test.sh — Mechanical tests for bin/score.sh
# Tests the crown jewel: structural lint scoring.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RHINO_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
TEMP=""

check() {
  local name="$1"
  local condition="$2"
  if eval "$condition" >/dev/null 2>&1; then
    echo "  [PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

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

run_score() {
  bash "$RHINO_DIR/bin/score.sh" . --force --quiet 2>&1
}

# ── Build detection ─────────────────────────────────────

echo "-- Build detection --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src && echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "score.sh produces numeric output" "[ -n '$SCORE' ]"
check "score.sh output is a number" "echo '$SCORE' | grep -qE '^[0-9]+$'"
teardown_temp

# ── Hygiene: console.log penalty ────────────────────────

echo "-- Hygiene: console.log --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src
cat > src/index.ts << 'TSEOF'
export function main() {
  console.log("debug1");
  console.log("debug2");
  console.log("debug3");
  console.log("debug4");
  console.log("debug5");
  console.log("debug6");
}
TSEOF
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "web project with 6 console.logs scores < 100" "[ '$SCORE' -lt 100 ]"
teardown_temp

# ── Hygiene: clean project ──────────────────────────────

echo "-- Hygiene: clean project --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src tests
echo 'export const x = 1;' > src/index.ts
echo 'test("works", () => {});' > tests/basic.test.ts
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "clean web project with tests scores >= 90" "[ '$SCORE' -ge 90 ]"
teardown_temp

# ── Structure: no tests penalty ─────────────────────────

echo "-- Structure: no tests --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src
echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
SCORE_NO_TESTS=$(run_score)

mkdir -p tests
echo 'test("ok", () => {});' > tests/basic.test.ts
git add -A && git commit -q -m "add test"
SCORE_WITH_TESTS=$(run_score)

check "project with tests scores higher than without" "[ '$SCORE_WITH_TESTS' -gt '$SCORE_NO_TESTS' ]"
teardown_temp

# ── Structure: large file penalty ───────────────────────

echo "-- Structure: large files --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src tests
echo 'test("ok", () => {});' > tests/basic.test.ts
for i in 1 2 3; do
  {
    echo "export const file$i = {"
    for j in $(seq 1 510); do
      echo "  line$j: $j,"
    done
    echo "};"
  } > "src/big$i.ts"
done
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "3 large files (>500 lines) triggers penalty" "[ '$SCORE' -lt 100 ]"
teardown_temp

# ── Config: dimensions check (CLI project) ──────────────

echo "-- Config: dimensions --"

setup_temp
mkdir -p bin tests config
echo '#!/bin/bash' > bin/main.sh
chmod +x bin/main.sh
echo 'test("ok", () => {});' > tests/basic.test.ts

cat > config/rhino.yml << 'YMLEOF'
project:
  stage: early
YMLEOF
git add -A && git commit -q -m "init"
SCORE_NO_DIMS=$(run_score)

cat > config/rhino.yml << 'YMLEOF'
project:
  stage: early
scoring:
  dimensions:
    - quality
    - speed
YMLEOF
git add -A && git commit -q -m "add dims"
SCORE_WITH_DIMS=$(run_score)

check "config with dimensions scores >= without" "[ '$SCORE_WITH_DIMS' -ge '$SCORE_NO_DIMS' ]"
teardown_temp

# ── CLI project type ────────────────────────────────────

echo "-- CLI project type --"

setup_temp
mkdir -p bin tests
echo '#!/bin/bash' > bin/main.sh
chmod +x bin/main.sh
echo 'test("ok", () => {});' > tests/basic.test.ts
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "CLI project scores without crashing" "echo '$SCORE' | grep -qE '^[0-9]+$'"
teardown_temp

# ── Self-score ──────────────────────────────────────────

echo "-- Self-score --"

cd "$RHINO_DIR"
SCORE=$(run_score)
check "rhino-os self-score is numeric" "echo '$SCORE' | grep -qE '^[0-9]+$'"
check "rhino-os self-score is >= 80" "[ '$SCORE' -ge 80 ]"

# ── Results ─────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
