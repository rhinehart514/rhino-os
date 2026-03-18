#!/usr/bin/env bash
# spec-wire.sh — Reads product-spec.yml and outputs what needs to be created.
# Tells /discover what wiring is missing: features, assertions, roadmap, strategy.
# Usage: bash scripts/spec-wire.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"

SPEC="$PROJECT_DIR/config/product-spec.yml"
if [[ ! -f "$SPEC" ]]; then
    echo "ERROR: No product-spec.yml found at $SPEC"
    echo "Run /discover to generate one first."
    exit 1
fi

echo "=== WIRING CHECK ==="
echo ""

# --- Features needed ---
echo "--- Features ---"
RHINO="$PROJECT_DIR/config/rhino.yml"
if [[ -f "$RHINO" ]]; then
    EXISTING=$(grep -c "^  - name:" "$RHINO" 2>/dev/null || echo "0")
    echo "EXISTING FEATURES: $EXISTING"
else
    echo "EXISTING FEATURES: 0 (no rhino.yml)"
fi

# Check what spec implies
echo "SPEC IMPLIES:"
# core_loop → main feature
CORE_TRIGGER=$(grep "trigger:" "$SPEC" 2>/dev/null | head -1 || echo "")
if [[ -n "$CORE_TRIGGER" ]] && ! echo "$CORE_TRIGGER" | grep -q '""'; then
    echo "  NEED: core-loop feature (weight: 5) — from core_loop section"
else
    echo "  MISSING: core_loop.trigger is empty — can't derive core feature"
fi

# first_experience → onboarding feature
FE_STEP1=$(grep "step_1:" "$SPEC" 2>/dev/null | head -1 || echo "")
if [[ -n "$FE_STEP1" ]] && ! echo "$FE_STEP1" | grep -q '""'; then
    echo "  NEED: first-experience feature (weight: 4) — from first_experience section"
else
    echo "  MISSING: first_experience is empty — can't derive onboarding feature"
fi

# return_trigger → retention feature
RT_MECH=$(grep "mechanism:" "$SPEC" 2>/dev/null | head -1 || echo "")
if [[ -n "$RT_MECH" ]] && ! echo "$RT_MECH" | grep -q '""'; then
    echo "  NEED: return-trigger feature (weight: 4) — from return_trigger section"
else
    echo "  MISSING: return_trigger.mechanism is empty — can't derive retention feature"
fi
echo ""

# --- Assertions needed ---
echo "--- Assertions ---"
BELIEFS="$PROJECT_DIR/config/beliefs.yml"
if [[ -f "$BELIEFS" ]]; then
    EXISTING=$(grep -c "^- " "$BELIEFS" 2>/dev/null || echo "0")
    echo "EXISTING ASSERTIONS: $EXISTING"
else
    echo "EXISTING ASSERTIONS: 0 (no beliefs.yml)"
fi

# Count signals in spec
SIGNAL_COUNT=$(grep -c "behavior:" "$SPEC" 2>/dev/null || echo "0")
echo "SPEC SIGNALS: $SIGNAL_COUNT (each should become an assertion)"

# Count pivot triggers
PIVOT_COUNT=$(grep -c "signal:" "$SPEC" 2>/dev/null || echo "0")
# Subtract metadata lines that also have "signal:" pattern
echo "SPEC PIVOT TRIGGERS: $PIVOT_COUNT (each should become a monitoring assertion)"
echo ""

# --- Roadmap ---
echo "--- Roadmap ---"
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
if [[ -f "$ROADMAP" ]]; then
    echo "EXISTS — check if thesis matches spec"
    THESIS=$(grep "thesis:" "$ROADMAP" 2>/dev/null | head -1 || echo "(none)")
    echo "  CURRENT: $THESIS"
    CHANGE=$(grep "in_one_sentence:" "$SPEC" 2>/dev/null | head -1 || echo "(none)")
    echo "  SPEC SAYS: $CHANGE"
    echo "  ACTION: verify alignment or update"
else
    echo "MISSING — create from spec's change.in_one_sentence + signals"
fi
echo ""

# --- Strategy ---
echo "--- Strategy ---"
STRATEGY="$PROJECT_DIR/.claude/plans/strategy.yml"
if [[ -f "$STRATEGY" ]]; then
    echo "EXISTS — check if competitors match spec"
else
    echo "MISSING — populate from spec's competitors + why_now"
fi
echo ""

# --- rhino.yml value section ---
echo "--- rhino.yml value ---"
if [[ -f "$RHINO" ]]; then
    HAS_VALUE=$(grep -c "^value:" "$RHINO" 2>/dev/null || echo "0")
    if [[ "$HAS_VALUE" -gt 0 ]]; then
        echo "EXISTS — check alignment with spec"
    else
        echo "MISSING value section — write from spec's who + change"
    fi
else
    echo "NO rhino.yml — create with value section from spec"
fi
echo ""

echo "=== SUMMARY ==="
NEEDS=0
[[ ! -f "$ROADMAP" ]] && NEEDS=$((NEEDS + 1)) && echo "CREATE: roadmap.yml"
[[ ! -f "$STRATEGY" ]] && NEEDS=$((NEEDS + 1)) && echo "CREATE: strategy.yml"
[[ ! -f "$BELIEFS" ]] && NEEDS=$((NEEDS + 1)) && echo "CREATE: beliefs.yml"

# Check for missing value section
if [[ -f "$RHINO" ]]; then
    HAS_VALUE=$(grep -c "^value:" "$RHINO" 2>/dev/null || echo "0")
    [[ "$HAS_VALUE" -eq 0 ]] && NEEDS=$((NEEDS + 1)) && echo "UPDATE: rhino.yml (add value section)"
else
    NEEDS=$((NEEDS + 1)) && echo "CREATE: rhino.yml"
fi

echo ""
echo "WIRING NEEDED: $NEEDS items"
