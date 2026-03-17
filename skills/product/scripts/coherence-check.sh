#!/usr/bin/env bash
# coherence-check.sh — Checks that README, features, assertions, thesis, and narrative align.
# Finds contradictions between what the product claims and what it delivers.
set -euo pipefail

PROJECT_DIR="${1:-.}"

RHINO_YML="$PROJECT_DIR/config/rhino.yml"
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
BELIEFS="$PROJECT_DIR/config/beliefs.yml"
NARRATIVE="$PROJECT_DIR/.claude/cache/narrative.yml"
README="$PROJECT_DIR/README.md"

DISCONNECTS=0
CHECKS=0

echo "=== COHERENCE CHECK ==="
echo ""

# --- 1. README vs Features ---
echo "▾ README vs FEATURES"
CHECKS=$((CHECKS + 1))
if [[ -f "$README" ]] && [[ -f "$RHINO_YML" ]]; then
    # Extract feature names from rhino.yml
    FEATURES=$(grep -E '^\s+-\s+name:' "$RHINO_YML" 2>/dev/null | sed 's/.*name:\s*//' | tr -d '"' || true)
    if [[ -n "$FEATURES" ]]; then
        MISSING=""
        while IFS= read -r feat; do
            feat_clean=$(echo "$feat" | tr -d ' ')
            if ! grep -qi "$feat_clean" "$README" 2>/dev/null; then
                MISSING="$MISSING  MISSING in README: $feat_clean\n"
            fi
        done <<< "$FEATURES"
        if [[ -n "$MISSING" ]]; then
            echo -e "$MISSING"
            echo "  DISCONNECT: README doesn't mention all defined features"
            DISCONNECTS=$((DISCONNECTS + 1))
        else
            echo "  OK: all features mentioned in README"
        fi
    else
        echo "  (no features in rhino.yml)"
    fi
else
    echo "  SKIP: missing README or rhino.yml"
fi
echo ""

# --- 2. Features vs Assertions ---
echo "▾ FEATURES vs ASSERTIONS"
CHECKS=$((CHECKS + 1))
if [[ -f "$RHINO_YML" ]] && [[ -f "$BELIEFS" ]]; then
    FEATURES=$(grep -E '^\s+-\s+name:' "$RHINO_YML" 2>/dev/null | sed 's/.*name:\s*//' | tr -d '"' || true)
    if [[ -n "$FEATURES" ]]; then
        UNCOVERED=""
        while IFS= read -r feat; do
            feat_clean=$(echo "$feat" | tr -d ' ')
            if ! grep -qi "$feat_clean" "$BELIEFS" 2>/dev/null; then
                UNCOVERED="$UNCOVERED  NO ASSERTIONS: $feat_clean\n"
            fi
        done <<< "$FEATURES"
        if [[ -n "$UNCOVERED" ]]; then
            echo -e "$UNCOVERED"
            echo "  DISCONNECT: features exist without assertions to verify them"
            DISCONNECTS=$((DISCONNECTS + 1))
        else
            echo "  OK: all features have assertions"
        fi
    fi
else
    echo "  SKIP: missing rhino.yml or beliefs.yml"
fi
echo ""

# --- 3. Eval scores vs Thesis claims ---
echo "▾ EVAL SCORES vs THESIS"
CHECKS=$((CHECKS + 1))
if [[ -f "$EVAL_CACHE" ]] && [[ -f "$ROADMAP" ]] && command -v jq &>/dev/null; then
    # Get active thesis description
    THESIS=$(awk '/status: active/,/^  v[0-9]/{print}' "$ROADMAP" 2>/dev/null | head -5)
    echo "  thesis: $(echo "$THESIS" | grep 'description:' | sed 's/.*description:\s*//' | head -1)"

    # Check if any high-weight features are low-scoring
    LOW_HIGH=$(jq -r 'to_entries[] | select(.value.score != null and .value.score < 50 and (.value.weight // 3) >= 4) |
      "  HIGH-WEIGHT LOW-SCORE: \(.key) weight:\(.value.weight // 3) score:\(.value.score)"' "$EVAL_CACHE" 2>/dev/null)
    if [[ -n "$LOW_HIGH" ]]; then
        echo "$LOW_HIGH"
        echo "  DISCONNECT: thesis depends on features that aren't delivering"
        DISCONNECTS=$((DISCONNECTS + 1))
    else
        echo "  OK: high-weight features are scoring adequately"
    fi
else
    echo "  SKIP: missing eval-cache or roadmap"
fi
echo ""

# --- 4. Narrative vs Reality ---
echo "▾ NARRATIVE vs EVIDENCE"
CHECKS=$((CHECKS + 1))
if [[ -f "$NARRATIVE" ]] && [[ -f "$ROADMAP" ]]; then
    echo "  narrative: present"
    # Check if narrative references things that roadmap shows as unproven
    UNPROVEN=$(awk '/evidence:/{found=1; next} found && /proven: false|status: untested/{print "  UNPROVEN: " $0; next} found && /^[a-z]/{found=0}' "$ROADMAP" 2>/dev/null || true)
    if [[ -n "$UNPROVEN" ]]; then
        echo "$UNPROVEN"
        echo "  CHECK: ensure narrative doesn't claim things that evidence hasn't proven"
        DISCONNECTS=$((DISCONNECTS + 1))
    else
        echo "  OK: no unproven evidence items found"
    fi
else
    if [[ ! -f "$NARRATIVE" ]]; then
        echo "  (no narrative.yml — run /roadmap narrative to generate)"
    fi
fi
echo ""

# --- 5. Hypothesis vs Features ---
echo "▾ HYPOTHESIS vs FEATURES"
CHECKS=$((CHECKS + 1))
if [[ -f "$RHINO_YML" ]]; then
    HYPOTHESIS=$(grep -E '^\s+hypothesis:' "$RHINO_YML" 2>/dev/null | sed 's/.*hypothesis:\s*//' || true)
    FEAT_COUNT=$(grep -c -E '^\s+-\s+name:' "$RHINO_YML" 2>/dev/null | tail -1 || echo "0")
    FEAT_COUNT=$(echo "$FEAT_COUNT" | tr -d '[:space:]')
    if [[ -n "$HYPOTHESIS" ]]; then
        echo "  hypothesis: $HYPOTHESIS"
        echo "  features: $FEAT_COUNT defined"
        if [[ "$FEAT_COUNT" -eq 0 ]]; then
            echo "  DISCONNECT: hypothesis exists but no features to deliver it"
            DISCONNECTS=$((DISCONNECTS + 1))
        fi
    else
        echo "  DISCONNECT: no hypothesis — features exist without a reason"
        DISCONNECTS=$((DISCONNECTS + 1))
    fi
fi
echo ""

# --- Summary ---
echo "=== COHERENCE SUMMARY ==="
echo "  checks: $CHECKS"
echo "  disconnects: $DISCONNECTS"
if [[ $DISCONNECTS -eq 0 ]]; then
    echo "  status: COHERENT — claims align with evidence"
elif [[ $DISCONNECTS -le 2 ]]; then
    echo "  status: MINOR GAPS — some claims outpace evidence"
else
    echo "  status: INCOHERENT — product says one thing and does another"
fi
echo ""
echo "=== CHECK COMPLETE ==="
