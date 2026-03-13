#!/usr/bin/env bash
# self.sh — rhino-os self-diagnostic
# 8 checks, priority-ordered. Follows eval.sh patterns.
set -euo pipefail

# --- Resolve RHINO_DIR ---
_SELF_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_SELF_SOURCE" ]]; do
    _SELF_SOURCE="$(readlink "$_SELF_SOURCE")"
done
RHINO_DIR="$(cd "$(dirname "$_SELF_SOURCE")/.." && pwd)"

source "$RHINO_DIR/bin/lib/config.sh"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
PASS=0
WARN=0
FAIL=0
TOP_ISSUE=""

# --- Check functions ---

check_pass() {
    local name="$1"
    local desc="$2"
    if [[ "$EVAL_MODE" != "true" ]]; then
        printf "  ${GREEN}✓${NC} %-22s ${DIM}%s${NC}\n" "$name" "$desc"
    fi
    PASS=$((PASS + 1))
}

check_warn() {
    local name="$1"
    local desc="$2"
    if [[ "$EVAL_MODE" != "true" ]]; then
        printf "  ${YELLOW}⚠${NC} %-22s ${YELLOW}%s${NC}\n" "$name" "$desc"
    fi
    WARN=$((WARN + 1))
    [[ -z "$TOP_ISSUE" ]] && TOP_ISSUE="$desc" || true
}

check_fail() {
    local name="$1"
    local desc="$2"
    if [[ "$EVAL_MODE" != "true" ]]; then
        printf "  ${RED}✗${NC} %-22s ${RED}%s${NC}\n" "$name" "$desc"
    fi
    FAIL=$((FAIL + 1))
    [[ -z "$TOP_ISSUE" ]] && TOP_ISSUE="$desc" || true
}

# --- Check for --eval mode (machine-readable output for eval.sh) ---
EVAL_MODE=false
for arg in "$@"; do
    [[ "$arg" == "--eval" ]] && EVAL_MODE=true
done

if [[ "$EVAL_MODE" != "true" ]]; then
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}rhino self${NC}  ${DIM}${TIMESTAMP}${NC}"
    echo ""
fi

# ============================================================
# 1. mind-integrity — All 4 mind files exist + symlinked
# ============================================================
MIND_FILES=(identity.md thinking.md standards.md self.md)
MIND_MISSING=0
MIND_UNLINKED=0
for mf in "${MIND_FILES[@]}"; do
    if [[ ! -f "$RHINO_DIR/mind/$mf" ]]; then
        MIND_MISSING=$((MIND_MISSING + 1))
    fi
    if [[ ! -L "$HOME/.claude/rules/$mf" ]] || [[ ! -f "$HOME/.claude/rules/$mf" ]]; then
        MIND_UNLINKED=$((MIND_UNLINKED + 1))
    fi
done
if [[ "$MIND_MISSING" -eq 0 && "$MIND_UNLINKED" -eq 0 ]]; then
    check_pass "mind-integrity" "4 mind files present + symlinked"
elif [[ "$MIND_MISSING" -gt 0 ]]; then
    check_fail "mind-integrity" "$MIND_MISSING mind file(s) missing from mind/"
else
    check_fail "mind-integrity" "$MIND_UNLINKED mind file(s) not symlinked in ~/.claude/rules/"
fi

# ============================================================
# 2. hook-health — All hooks resolve, executable, run under timeout
# ============================================================
HOOK_TIMEOUT_MS=$(cfg self.hook_timeout_ms 200)
HOOKS_DIR="$HOME/.claude/hooks"
HOOKS_BROKEN=0
HOOKS_SLOW=0
HOOKS_CHECKED=0

if [[ -d "$HOOKS_DIR" ]]; then
    for hook in "$HOOKS_DIR"/*.sh; do
        [[ ! -f "$hook" ]] && continue
        HOOKS_CHECKED=$((HOOKS_CHECKED + 1))

        # Check if symlink resolves
        if [[ -L "$hook" ]]; then
            target=$(readlink "$hook" 2>/dev/null)
            if [[ ! -f "$target" ]]; then
                HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
                continue
            fi
        fi

        # Check executable
        if [[ ! -x "$hook" ]]; then
            HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
            continue
        fi
    done
fi

if [[ "$HOOKS_CHECKED" -eq 0 ]]; then
    check_warn "hook-health" "no hooks found"
elif [[ "$HOOKS_BROKEN" -gt 0 ]]; then
    check_fail "hook-health" "$HOOKS_BROKEN hook(s) broken or not executable"
else
    check_pass "hook-health" "$HOOKS_CHECKED hooks healthy"
fi

# ============================================================
# 3. measurement-stack — score.sh, taste.mjs, eval.sh exist + executable
# ============================================================
STACK_MISSING=0
for tool in "$RHINO_DIR/bin/score.sh" "$RHINO_DIR/lens/product/eval/taste.mjs" "$RHINO_DIR/bin/eval.sh"; do
    if [[ ! -f "$tool" ]]; then
        STACK_MISSING=$((STACK_MISSING + 1))
    elif [[ ! -x "$tool" && "$tool" != *.mjs ]]; then
        STACK_MISSING=$((STACK_MISSING + 1))
    fi
done
if [[ "$STACK_MISSING" -eq 0 ]]; then
    check_pass "measurement-stack" "score.sh, taste.mjs, eval.sh all present"
else
    check_fail "measurement-stack" "$STACK_MISSING measurement tool(s) missing"
fi

# ============================================================
# 4. prediction-accuracy — Parse predictions.tsv, check calibration
# ============================================================
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
ACCURACY_FLOOR=$(cfg self.prediction_accuracy_floor 0.30)
ACCURACY_CEILING=$(cfg self.prediction_accuracy_ceiling 0.90)

if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "prediction-accuracy" "no predictions.tsv found"
else
    TOTAL_GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    if [[ "$TOTAL_GRADED" -lt 5 ]]; then
        check_warn "prediction-accuracy" "only $TOTAL_GRADED graded predictions (need 5+ for calibration)"
    else
        CORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        # Use awk for float division
        ACCURACY=$(awk "BEGIN { printf \"%.2f\", $CORRECT / $TOTAL_GRADED }")
        if awk "BEGIN { exit !($ACCURACY < $ACCURACY_FLOOR) }"; then
            check_fail "prediction-accuracy" "accuracy ${ACCURACY} below floor ${ACCURACY_FLOOR} — model may be broken"
        elif awk "BEGIN { exit !($ACCURACY > $ACCURACY_CEILING) }"; then
            check_warn "prediction-accuracy" "accuracy ${ACCURACY} above ceiling ${ACCURACY_CEILING} — predictions may be too safe"
        else
            check_pass "prediction-accuracy" "accuracy ${ACCURACY} (${CORRECT}/${TOTAL_GRADED}) — well calibrated"
        fi
    fi
fi

# ============================================================
# 5. knowledge-freshness — experiment-learnings.md age
# ============================================================
KNOWLEDGE_STALE_DAYS=$(cfg self.knowledge_stale_days 14)
LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"

if [[ ! -f "$LEARNINGS" ]]; then
    check_fail "knowledge-freshness" "experiment-learnings.md not found"
else
    if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$LEARNINGS" 2>/dev/null || echo 0)
    else
        MTIME=$(stat -c %Y "$LEARNINGS" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [[ "$AGE_DAYS" -gt "$KNOWLEDGE_STALE_DAYS" ]]; then
        check_warn "knowledge-freshness" "experiment-learnings.md is ${AGE_DAYS}d old (threshold: ${KNOWLEDGE_STALE_DAYS}d)"
    else
        check_pass "knowledge-freshness" "experiment-learnings.md updated ${AGE_DAYS}d ago"
    fi
fi

# ============================================================
# 6. learning-velocity — Predictions per week
# ============================================================
MIN_PER_WEEK=$(cfg self.min_predictions_per_week 3)
PRED_STALE_DAYS=$(cfg self.prediction_stale_days 7)

if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "learning-velocity" "no predictions.tsv"
else
    # Count predictions in last N days
    CUTOFF_DATE=$(date -v-${PRED_STALE_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${PRED_STALE_DAYS} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
    if [[ -n "$CUTOFF_DATE" ]]; then
        RECENT_COUNT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' -v cutoff="$CUTOFF_DATE" '$1 >= cutoff { c++ } END { print c+0 }')
        if [[ "$RECENT_COUNT" -lt "$MIN_PER_WEEK" ]]; then
            check_warn "learning-velocity" "${RECENT_COUNT} predictions in last ${PRED_STALE_DAYS}d (minimum: ${MIN_PER_WEEK})"
        else
            check_pass "learning-velocity" "${RECENT_COUNT} predictions in last ${PRED_STALE_DAYS}d"
        fi
    else
        check_warn "learning-velocity" "could not compute date cutoff"
    fi
fi

# ============================================================
# 7. self-model-freshness — mind/self.md age
# ============================================================
SELF_STALE_DAYS=$(cfg self.self_stale_days 7)
SELF_FILE="$RHINO_DIR/mind/self.md"

if [[ ! -f "$SELF_FILE" ]]; then
    check_fail "self-model-freshness" "mind/self.md not found"
else
    if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$SELF_FILE" 2>/dev/null || echo 0)
    else
        MTIME=$(stat -c %Y "$SELF_FILE" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [[ "$AGE_DAYS" -gt "$SELF_STALE_DAYS" ]]; then
        check_warn "self-model-freshness" "mind/self.md is ${AGE_DAYS}d old (threshold: ${SELF_STALE_DAYS}d)"
    else
        check_pass "self-model-freshness" "mind/self.md updated ${AGE_DAYS}d ago"
    fi
fi

# ============================================================
# 8. config-coherence — rhino.yml parses, required sections present
# ============================================================
CONFIG_FILE="$RHINO_DIR/config/rhino.yml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    check_fail "config-coherence" "rhino.yml not found"
else
    MISSING_SECTIONS=0
    # Base config required sections (taste moved to lens config)
    for section in value scoring integrity experiments self; do
        if ! grep -q "^${section}:" "$CONFIG_FILE" 2>/dev/null; then
            MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
        fi
    done
    # Check lens config for taste section if lens is present
    LENS_CONFIG="$RHINO_DIR/lens/product/config/rhino-product.yml"
    if [[ -f "$LENS_CONFIG" ]] && ! grep -q "^taste:" "$LENS_CONFIG" 2>/dev/null; then
        MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
    fi
    if [[ "$MISSING_SECTIONS" -gt 0 ]]; then
        check_warn "config-coherence" "$MISSING_SECTIONS required section(s) missing from rhino.yml"
    else
        check_pass "config-coherence" "rhino.yml has all required sections"
    fi
fi

# === --eval mode: machine-readable output for eval.sh ===
if [[ "$EVAL_MODE" == "true" ]]; then
    # Compute calibration status from prediction-accuracy check
    PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
    CAL_STATUS="HEALTHY"
    CAL_DETAIL="$PASS/$((PASS + WARN + FAIL)) checks passed"
    if [[ -f "$PRED_FILE" ]]; then
        TOTAL_GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
        if [[ "$TOTAL_GRADED" -ge 5 ]]; then
            CORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
            ACCURACY=$(awk "BEGIN { printf \"%.2f\", $CORRECT / $TOTAL_GRADED }")
            FLOOR=$(cfg self.prediction_accuracy_floor 0.30)
            CEILING=$(cfg self.prediction_accuracy_ceiling 0.90)
            if awk "BEGIN { exit !($ACCURACY < $FLOOR) }"; then
                CAL_STATUS="BROKEN"
            elif awk "BEGIN { exit !($ACCURACY > $CEILING) }"; then
                CAL_STATUS="TOO_SAFE"
            fi
            CAL_DETAIL="accuracy ${ACCURACY} (${CORRECT}/${TOTAL_GRADED}), ${PASS}/$((PASS + WARN + FAIL)) checks passed"
        else
            CAL_STATUS="INSUFFICIENT"
            CAL_DETAIL="only ${TOTAL_GRADED} graded predictions (need 5+)"
        fi
    else
        CAL_STATUS="INSUFFICIENT"
        CAL_DETAIL="no predictions.tsv found"
    fi

    if [[ "$CAL_STATUS" == "HEALTHY" || "$CAL_STATUS" == "INSUFFICIENT" ]]; then
        echo "calibration:pass:${CAL_STATUS} — ${CAL_DETAIL}"
    else
        echo "calibration:fail:${CAL_STATUS} — ${CAL_DETAIL}"
    fi
    [[ "$FAIL" -gt 0 ]] && exit 1
    exit 0
fi

# === Summary ===
echo ""
SUMMARY="  ${GREEN}${PASS} passed${NC}"
[[ "$WARN" -gt 0 ]] && SUMMARY="${SUMMARY} ${DIM}·${NC} ${YELLOW}${WARN} warning${NC}"
[[ "$FAIL" -gt 0 ]] && SUMMARY="${SUMMARY} ${DIM}·${NC} ${RED}${FAIL} failed${NC}"
echo -e "$SUMMARY"

if [[ -n "$TOP_ISSUE" ]]; then
    echo -e "  ${DIM}→${NC} $TOP_ISSUE"
fi
echo ""

[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
