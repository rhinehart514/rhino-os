#!/usr/bin/env bash
# spec-quality.sh — Grades product-spec.yml completeness and quality.
# Outputs a score 0-100, section-by-section breakdown, and specific weaknesses.
# Usage: bash scripts/spec-quality.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"
SPEC="$PROJECT_DIR/config/product-spec.yml"

if [[ ! -f "$SPEC" ]]; then
    echo "SCORE: 0"
    echo "REASON: No product-spec.yml found"
    exit 0
fi

SCORE=0
ISSUES=""
STRENGTHS=""

# --- Completeness (50 points) ---
# Count empty fields (lines with "")
EMPTY=$(grep -c '""' "$SPEC" 2>/dev/null || echo "0")
TOTAL_FIELDS=25  # approximate total fields in template

if [[ "$EMPTY" -eq 0 ]]; then
    SCORE=$((SCORE + 50))
    STRENGTHS="${STRENGTHS}\n  ✓ all fields filled"
elif [[ "$EMPTY" -lt 5 ]]; then
    SCORE=$((SCORE + 40))
    ISSUES="${ISSUES}\n  · $EMPTY empty fields remain"
elif [[ "$EMPTY" -lt 10 ]]; then
    SCORE=$((SCORE + 25))
    ISSUES="${ISSUES}\n  · $EMPTY empty fields — spec is incomplete"
elif [[ "$EMPTY" -lt 15 ]]; then
    SCORE=$((SCORE + 10))
    ISSUES="${ISSUES}\n  · $EMPTY empty fields — spec is mostly empty"
else
    ISSUES="${ISSUES}\n  · $EMPTY empty fields — spec is a skeleton"
fi

# --- Who quality (15 points) ---
WHO_PERSON=$(grep "person:" "$SPEC" 2>/dev/null | head -1 || echo "")
WHO_EVIDENCE=$(grep "evidence:" "$SPEC" 2>/dev/null | head -1 || echo "")

if echo "$WHO_PERSON" | grep -q '""'; then
    ISSUES="${ISSUES}\n  · who.person is EMPTY — critical gap"
elif echo "$WHO_PERSON" | grep -qiE 'users|developers|teams|people|everyone'; then
    SCORE=$((SCORE + 5))
    ISSUES="${ISSUES}\n  · who.person is too vague — name a specific person in a specific situation"
else
    SCORE=$((SCORE + 10))
    STRENGTHS="${STRENGTHS}\n  ✓ who.person is specific"
fi

if echo "$WHO_EVIDENCE" | grep -q '""'; then
    ISSUES="${ISSUES}\n  · who.evidence is EMPTY — building on assumption"
else
    SCORE=$((SCORE + 5))
    STRENGTHS="${STRENGTHS}\n  ✓ who.evidence exists"
fi

# --- Core loop quality (10 points) ---
CORE_FIELDS=0
for field in "trigger:" "action:" "reward:" "frequency:"; do
    LINE=$(grep "$field" "$SPEC" 2>/dev/null | head -1 || echo "")
    if [[ -n "$LINE" ]] && ! echo "$LINE" | grep -q '""'; then
        CORE_FIELDS=$((CORE_FIELDS + 1))
    fi
done

if [[ "$CORE_FIELDS" -eq 4 ]]; then
    SCORE=$((SCORE + 10))
    STRENGTHS="${STRENGTHS}\n  ✓ core_loop fully defined"
elif [[ "$CORE_FIELDS" -ge 2 ]]; then
    SCORE=$((SCORE + 5))
    ISSUES="${ISSUES}\n  · core_loop partially defined ($CORE_FIELDS/4 fields)"
else
    ISSUES="${ISSUES}\n  · core_loop mostly empty ($CORE_FIELDS/4 fields)"
fi

# --- Not building (kill list) quality (10 points) ---
# Count non-empty items in not_building
KILL_ITEMS=$(grep -A 20 "not_building:" "$SPEC" 2>/dev/null | grep "^  - " | grep -vc '""' 2>/dev/null || echo "0")

if [[ "$KILL_ITEMS" -ge 5 ]]; then
    SCORE=$((SCORE + 10))
    STRENGTHS="${STRENGTHS}\n  ✓ kill list is strong ($KILL_ITEMS items)"
elif [[ "$KILL_ITEMS" -ge 3 ]]; then
    SCORE=$((SCORE + 7))
    STRENGTHS="${STRENGTHS}\n  ✓ kill list exists ($KILL_ITEMS items)"
elif [[ "$KILL_ITEMS" -ge 1 ]]; then
    SCORE=$((SCORE + 3))
    ISSUES="${ISSUES}\n  · kill list too short ($KILL_ITEMS items) — haven't killed enough"
else
    ISSUES="${ISSUES}\n  · NO kill list — what are you refusing to build?"
fi

# --- Why now / 2026 context (10 points) ---
WHY_NOW=$(grep -A 5 "why_now:" "$SPEC" 2>/dev/null || echo "")
if echo "$WHY_NOW" | grep -qiE '2026|MCP|claude code|marketplace|agent|solo founder'; then
    SCORE=$((SCORE + 10))
    STRENGTHS="${STRENGTHS}\n  ✓ why_now cites 2026-specific signal"
elif [[ -n "$WHY_NOW" ]] && ! echo "$WHY_NOW" | grep -q '""'; then
    SCORE=$((SCORE + 5))
    ISSUES="${ISSUES}\n  · why_now exists but doesn't cite 2026-specific signal"
else
    ISSUES="${ISSUES}\n  · why_now is empty — timing matters"
fi

# --- Pivot triggers (5 points) ---
PIVOT_ITEMS=$(grep -A 30 "pivot_triggers:" "$SPEC" 2>/dev/null | grep "signal:" | grep -vc '""' 2>/dev/null || echo "0")
if [[ "$PIVOT_ITEMS" -ge 3 ]]; then
    SCORE=$((SCORE + 5))
    STRENGTHS="${STRENGTHS}\n  ✓ pivot triggers defined ($PIVOT_ITEMS)"
elif [[ "$PIVOT_ITEMS" -ge 1 ]]; then
    SCORE=$((SCORE + 2))
    ISSUES="${ISSUES}\n  · only $PIVOT_ITEMS pivot triggers — need at least 3"
else
    ISSUES="${ISSUES}\n  · NO pivot triggers — when do you change direction?"
fi

# --- Output ---
echo "=== SPEC QUALITY ==="
echo "SCORE: $SCORE / 100"
echo ""

if [[ "$SCORE" -ge 80 ]]; then
    echo "GRADE: STRONG — ready to wire"
elif [[ "$SCORE" -ge 60 ]]; then
    echo "GRADE: DECENT — wire-able but has gaps"
elif [[ "$SCORE" -ge 40 ]]; then
    echo "GRADE: WEAK — needs founder input on key sections"
else
    echo "GRADE: SKELETON — most fields empty, needs full discovery session"
fi

echo ""
if [[ -n "$STRENGTHS" ]]; then
    echo "STRENGTHS:"
    echo -e "$STRENGTHS"
    echo ""
fi

if [[ -n "$ISSUES" ]]; then
    echo "ISSUES:"
    echo -e "$ISSUES"
fi
