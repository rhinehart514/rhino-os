#!/usr/bin/env bash
# self.sh — rhino-os self-diagnostic
# 4 systems × 25 pts each = 100 pts total: Measure, Think, Act, Learn
set -euo pipefail

# --- Recursion guard ---
# score.sh calls self.sh, self.sh must never call score.sh/eval.sh back.
# This guard catches any future accidental cross-calls.
RHINO_SELF_DEPTH="${RHINO_SELF_DEPTH:-0}"
if [[ "$RHINO_SELF_DEPTH" -ge 2 ]]; then
    echo "50"  # safe fallback
    exit 0
fi
export RHINO_SELF_DEPTH=$((RHINO_SELF_DEPTH + 1))

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
TOP_ISSUE=""

# --- Per-system point tracking ---
MEASURE_PTS=0; MEASURE_MAX=0
THINK_PTS=0;   THINK_MAX=0
ACT_PTS=0;     ACT_MAX=0
LEARN_PTS=0;   LEARN_MAX=0

# Current system context (set before each check)
CURRENT_SYSTEM=""

# Collected check results for display mode
declare -a CHECK_RESULTS=()

add_pts() {
    local pts="$1" max="$2"
    case "$CURRENT_SYSTEM" in
        measure) MEASURE_PTS=$((MEASURE_PTS + pts)); MEASURE_MAX=$((MEASURE_MAX + max)) ;;
        think)   THINK_PTS=$((THINK_PTS + pts));     THINK_MAX=$((THINK_MAX + max)) ;;
        act)     ACT_PTS=$((ACT_PTS + pts));         ACT_MAX=$((ACT_MAX + max)) ;;
        learn)   LEARN_PTS=$((LEARN_PTS + pts));     LEARN_MAX=$((LEARN_MAX + max)) ;;
    esac
}

check_pass() {
    local name="$1" desc="$2" pts="${3:-0}"
    add_pts "$pts" "$pts"
    CHECK_RESULTS+=("pass|$CURRENT_SYSTEM|$name|$desc|$pts/$pts")
}

check_warn() {
    local name="$1" desc="$2" pts="${3:-0}" max="${4:-0}"
    add_pts "$pts" "$max"
    CHECK_RESULTS+=("warn|$CURRENT_SYSTEM|$name|$desc|$pts/$max")
    [[ -z "$TOP_ISSUE" ]] && TOP_ISSUE="$desc" || true
}

check_fail() {
    local name="$1" desc="$2" max="${3:-0}"
    add_pts 0 "$max"
    CHECK_RESULTS+=("fail|$CURRENT_SYSTEM|$name|$desc|0/$max")
    [[ -z "$TOP_ISSUE" ]] && TOP_ISSUE="$desc" || true
}

# --- Check for --eval, --score, --json modes ---
EVAL_MODE=false
SCORE_MODE=false
JSON_MODE=false
for arg in "$@"; do
    [[ "$arg" == "--eval" ]] && EVAL_MODE=true
    [[ "$arg" == "--score" ]] && SCORE_MODE=true
    [[ "$arg" == "--json" ]] && JSON_MODE=true
done

SILENT=$([[ "$EVAL_MODE" == "true" || "$SCORE_MODE" == "true" || "$JSON_MODE" == "true" ]] && echo true || echo false)

if [[ "$SILENT" != "true" ]]; then
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}rhino self${NC}  ${DIM}${TIMESTAMP}${NC}"
    echo ""
fi

# ============================================================
# MEASURE (25 pts) — Can it see?
# ============================================================
CURRENT_SYSTEM="measure"

# measurement-stack (8 pts): score.sh, eval.sh, taste.mjs exist
STACK_MISSING=0
for tool in "$RHINO_DIR/bin/score.sh" "$RHINO_DIR/lens/product/eval/taste.mjs" "$RHINO_DIR/bin/eval.sh"; do
    if [[ ! -f "$tool" ]]; then
        STACK_MISSING=$((STACK_MISSING + 1))
    elif [[ ! -x "$tool" && "$tool" != *.mjs ]]; then
        STACK_MISSING=$((STACK_MISSING + 1))
    fi
done
if [[ "$STACK_MISSING" -eq 0 ]]; then
    check_pass "measurement-stack" "score.sh, taste.mjs, eval.sh all present" 8
else
    check_fail "measurement-stack" "$STACK_MISSING measurement tool(s) missing" 8
fi

# commands-work (9 pts): rhino help/version execute + bin/rhino exists
# Note: can't call score.sh or eval.sh (both can trigger self.sh → recursion)
CMDS_OK=0
CMDS_TOTAL=0
for cmd in help version; do
    CMDS_TOTAL=$((CMDS_TOTAL + 1))
    if "$RHINO_DIR/bin/rhino" "$cmd" >/dev/null 2>&1; then
        CMDS_OK=$((CMDS_OK + 1))
    fi
done
# Check bin/rhino is executable
CMDS_TOTAL=$((CMDS_TOTAL + 1))
if [[ -x "$RHINO_DIR/bin/rhino" ]]; then
    CMDS_OK=$((CMDS_OK + 1))
fi

if [[ "$CMDS_OK" -eq "$CMDS_TOTAL" ]]; then
    check_pass "commands-work" "$CMDS_OK/$CMDS_TOTAL core commands execute" 9
elif [[ "$CMDS_OK" -gt 0 ]]; then
    local_pts=$((CMDS_OK * 9 / CMDS_TOTAL))
    check_warn "commands-work" "$CMDS_OK/$CMDS_TOTAL core commands execute" "$local_pts" 9
else
    check_fail "commands-work" "0/$CMDS_TOTAL commands crashed" 9
fi

# tests-exist/pass (8 pts)
if [[ -d "$RHINO_DIR/tests" ]] && ls "$RHINO_DIR/tests"/*.test.sh >/dev/null 2>&1; then
    TESTS_TOTAL=0
    for t in "$RHINO_DIR/tests"/*.test.sh; do
        [[ -f "$t" ]] && TESTS_TOTAL=$((TESTS_TOTAL + 1))
    done
    if [[ "$SCORE_MODE" == "true" || "$JSON_MODE" == "true" || "$EVAL_MODE" == "true" ]]; then
        # Fast path: tests exist = pass (running them risks recursion via score.test.sh)
        check_pass "tests-exist" "$TESTS_TOTAL test suites present" 8
    else
        TESTS_PASS=0
        for t in "$RHINO_DIR/tests"/*.test.sh; do
            [[ ! -f "$t" ]] && continue
            if bash "$t" >/dev/null 2>&1; then
                TESTS_PASS=$((TESTS_PASS + 1))
            fi
        done
        if [[ "$TESTS_PASS" -eq "$TESTS_TOTAL" ]]; then
            check_pass "tests-pass" "$TESTS_PASS/$TESTS_TOTAL test suites pass" 8
        elif [[ "$TESTS_PASS" -gt 0 ]]; then
            local_pts=$((TESTS_PASS * 8 / TESTS_TOTAL))
            check_warn "tests-pass" "$TESTS_PASS/$TESTS_TOTAL test suites pass" "$local_pts" 8
        else
            check_fail "tests-pass" "0/$TESTS_TOTAL test suites pass" 8
        fi
    fi
else
    check_warn "tests-pass" "no test suites found" 0 8
fi

# ============================================================
# THINK (25 pts) — Can it reason?
# ============================================================
CURRENT_SYSTEM="think"

# mind-integrity (6 pts): 4 mind files present + symlinked
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
    check_pass "mind-integrity" "4 mind files present + symlinked" 6
elif [[ "$MIND_MISSING" -gt 0 ]]; then
    check_fail "mind-integrity" "$MIND_MISSING mind file(s) missing from mind/" 6
else
    check_fail "mind-integrity" "$MIND_UNLINKED mind file(s) not symlinked in ~/.claude/rules/" 6
fi

# strategy-ready (6 pts): strategy.yml has stage + bottleneck
STRATEGY_FILE=".claude/plans/strategy.yml"
if [[ -f "$STRATEGY_FILE" ]]; then
    has_stage=$(grep -c 'stage:' "$STRATEGY_FILE" 2>/dev/null) || has_stage=0
    has_bottleneck=$(grep -c 'bottleneck:' "$STRATEGY_FILE" 2>/dev/null) || has_bottleneck=0
    if [[ "$has_stage" -gt 0 && "$has_bottleneck" -gt 0 ]]; then
        check_pass "strategy-ready" "strategy has stage + bottleneck" 6
    else
        check_warn "strategy-ready" "strategy missing stage or bottleneck" 3 6
    fi
else
    check_fail "strategy-ready" "no strategy.yml — run /strategy" 6
fi

# knowledge-coverage (7 pts): all 4 zones populated
LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]]; then
    has_known=$(grep -c '## Known' "$LEARNINGS" 2>/dev/null) || has_known=0
    has_uncertain=$(grep -c '## Uncertain' "$LEARNINGS" 2>/dev/null) || has_uncertain=0
    has_unknown=$(grep -c '## Unknown' "$LEARNINGS" 2>/dev/null) || has_unknown=0
    has_dead=$(grep -c '## Dead' "$LEARNINGS" 2>/dev/null) || has_dead=0
    zones=$((has_known + has_uncertain + has_unknown + has_dead))
    if [[ "$zones" -ge 4 ]]; then
        check_pass "knowledge-coverage" "all 4 zones populated (known/uncertain/unknown/dead)" 7
    elif [[ "$zones" -ge 2 ]]; then
        check_warn "knowledge-coverage" "$zones/4 knowledge zones populated" $((zones * 7 / 4)) 7
    else
        check_fail "knowledge-coverage" "knowledge model has $zones/4 zones — too thin to reason from" 7
    fi
else
    check_fail "knowledge-coverage" "no experiment-learnings.md" 7
fi

# prediction-accuracy (6 pts): calibrated 30-90%
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
ACCURACY_FLOOR=$(cfg self.prediction_accuracy_floor 0.30)
ACCURACY_CEILING=$(cfg self.prediction_accuracy_ceiling 0.90)

if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "prediction-accuracy" "no predictions.tsv found" 0 6
else
    TOTAL_GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    if [[ "$TOTAL_GRADED" -lt 5 ]]; then
        check_warn "prediction-accuracy" "only $TOTAL_GRADED graded predictions (need 5+ for calibration)" 3 6
    else
        CORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        ACCURACY=$(awk "BEGIN { printf \"%.2f\", $CORRECT / $TOTAL_GRADED }")
        if awk "BEGIN { exit !($ACCURACY < $ACCURACY_FLOOR) }"; then
            check_fail "prediction-accuracy" "accuracy ${ACCURACY} below floor ${ACCURACY_FLOOR} — model may be broken" 6
        elif awk "BEGIN { exit !($ACCURACY > $ACCURACY_CEILING) }"; then
            check_warn "prediction-accuracy" "accuracy ${ACCURACY} above ceiling ${ACCURACY_CEILING} — predictions may be too safe" 3 6
        else
            check_pass "prediction-accuracy" "accuracy ${ACCURACY} (${CORRECT}/${TOTAL_GRADED}) — well calibrated" 6
        fi
    fi
fi

# ============================================================
# ACT (25 pts) — Can it execute?
# ============================================================
CURRENT_SYSTEM="act"

# commands-depth (6 pts): slash commands are substantive, not stubs
CMD_DIR="$HOME/.claude/commands"
[[ ! -d "$CMD_DIR" ]] && CMD_DIR=".claude/commands"
if [[ -d "$CMD_DIR" ]]; then
    STUB_COUNT=0
    CMD_COUNT=0
    for cmd_file in "$CMD_DIR"/*.md; do
        [[ ! -f "$cmd_file" ]] && continue
        CMD_COUNT=$((CMD_COUNT + 1))
        lines=$(wc -l < "$cmd_file" 2>/dev/null | tr -d ' ')
        if [[ "$lines" -lt 20 ]]; then
            STUB_COUNT=$((STUB_COUNT + 1))
        fi
    done
    if [[ "$CMD_COUNT" -eq 0 ]]; then
        check_fail "commands-depth" "no slash commands found" 6
    elif [[ "$STUB_COUNT" -gt 0 ]]; then
        check_warn "commands-depth" "$STUB_COUNT/$CMD_COUNT commands are stubs (<20 lines)" 3 6
    else
        check_pass "commands-depth" "$CMD_COUNT commands, all substantive" 6
    fi
else
    check_fail "commands-depth" "no commands directory" 6
fi

# hook-health (6 pts): hooks resolve and are executable
HOOK_TIMEOUT_MS=$(cfg self.hook_timeout_ms 200)
HOOKS_DIR="$HOME/.claude/hooks"
HOOKS_BROKEN=0
HOOKS_CHECKED=0

if [[ -d "$HOOKS_DIR" ]]; then
    for hook in "$HOOKS_DIR"/*.sh; do
        [[ ! -f "$hook" ]] && continue
        HOOKS_CHECKED=$((HOOKS_CHECKED + 1))
        if [[ -L "$hook" ]]; then
            target=$(readlink "$hook" 2>/dev/null)
            if [[ ! -f "$target" ]]; then
                HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
                continue
            fi
        fi
        if [[ ! -x "$hook" ]]; then
            HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
            continue
        fi
    done
fi

if [[ "$HOOKS_CHECKED" -eq 0 ]]; then
    check_warn "hook-health" "no hooks found" 0 6
elif [[ "$HOOKS_BROKEN" -gt 0 ]]; then
    check_fail "hook-health" "$HOOKS_BROKEN hook(s) broken or not executable" 6
else
    check_pass "hook-health" "$HOOKS_CHECKED hooks healthy" 6
fi

# config-coherence (6 pts): rhino.yml required sections present
CONFIG_FILE="$RHINO_DIR/config/rhino.yml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    check_fail "config-coherence" "rhino.yml not found" 6
else
    MISSING_SECTIONS=0
    for section in value scoring integrity experiments self; do
        if ! grep -q "^${section}:" "$CONFIG_FILE" 2>/dev/null; then
            MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
        fi
    done
    LENS_CONFIG="$RHINO_DIR/lens/product/config/rhino-product.yml"
    if [[ -f "$LENS_CONFIG" ]] && ! grep -q "^taste:" "$LENS_CONFIG" 2>/dev/null; then
        MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
    fi
    if [[ "$MISSING_SECTIONS" -gt 0 ]]; then
        check_warn "config-coherence" "$MISSING_SECTIONS required section(s) missing from rhino.yml" 3 6
    else
        check_pass "config-coherence" "rhino.yml has all required sections" 6
    fi
fi

# act-commands-execute (7 pts): rhino help/version run
# Note: can't call score.sh or eval.sh here (both can call self.sh → recursion)
ACT_CMDS_OK=0
ACT_CMDS_TOTAL=2

for cmd in help version; do
    if "$RHINO_DIR/bin/rhino" "$cmd" >/dev/null 2>&1; then
        ACT_CMDS_OK=$((ACT_CMDS_OK + 1))
    fi
done

if [[ "$ACT_CMDS_OK" -eq "$ACT_CMDS_TOTAL" ]]; then
    check_pass "commands-execute" "$ACT_CMDS_OK/$ACT_CMDS_TOTAL commands produce output" 7
elif [[ "$ACT_CMDS_OK" -gt 0 ]]; then
    local_pts=$((ACT_CMDS_OK * 7 / ACT_CMDS_TOTAL))
    check_warn "commands-execute" "$ACT_CMDS_OK/$ACT_CMDS_TOTAL commands produce output" "$local_pts" 7
else
    check_fail "commands-execute" "0/$ACT_CMDS_TOTAL commands produce output" 7
fi

# ============================================================
# LEARN (25 pts) — Does it compound?
# ============================================================
CURRENT_SYSTEM="learn"

# learning-velocity (7 pts): predictions per week
MIN_PER_WEEK=$(cfg self.min_predictions_per_week 3)
PRED_STALE_DAYS=$(cfg self.prediction_stale_days 7)

if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "learning-velocity" "no predictions.tsv" 0 7
else
    CUTOFF_DATE=$(date -v-${PRED_STALE_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${PRED_STALE_DAYS} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
    if [[ -n "$CUTOFF_DATE" ]]; then
        RECENT_COUNT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' -v cutoff="$CUTOFF_DATE" '$1 >= cutoff { c++ } END { print c+0 }')
        if [[ "$RECENT_COUNT" -lt "$MIN_PER_WEEK" ]]; then
            check_warn "learning-velocity" "${RECENT_COUNT} predictions in last ${PRED_STALE_DAYS}d (minimum: ${MIN_PER_WEEK})" 3 7
        else
            check_pass "learning-velocity" "${RECENT_COUNT} predictions in last ${PRED_STALE_DAYS}d" 7
        fi
    else
        check_warn "learning-velocity" "could not compute date cutoff" 0 7
    fi
fi

# prediction-grading (6 pts): are predictions being graded?
if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "prediction-grading" "no predictions.tsv" 0 6
else
    TOTAL_ROWS=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
    TOTAL_GRADED_L=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    if [[ "$TOTAL_ROWS" -eq 0 ]]; then
        check_warn "prediction-grading" "no predictions logged yet" 0 6
    elif [[ "$TOTAL_GRADED_L" -eq 0 ]]; then
        check_fail "prediction-grading" "0/$TOTAL_ROWS predictions graded — learning loop stalled" 6
    else
        grade_rate=$((TOTAL_GRADED_L * 100 / TOTAL_ROWS))
        if [[ "$grade_rate" -ge 50 ]]; then
            check_pass "prediction-grading" "$TOTAL_GRADED_L/$TOTAL_ROWS predictions graded (${grade_rate}%)" 6
        else
            check_warn "prediction-grading" "$TOTAL_GRADED_L/$TOTAL_ROWS predictions graded (${grade_rate}%)" 3 6
        fi
    fi
fi

# knowledge-freshness (6 pts): experiment-learnings.md age
KNOWLEDGE_STALE_DAYS=$(cfg self.knowledge_stale_days 14)

if [[ ! -f "$LEARNINGS" ]]; then
    check_fail "knowledge-freshness" "experiment-learnings.md not found" 6
else
    if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$LEARNINGS" 2>/dev/null || echo 0)
    else
        MTIME=$(stat -c %Y "$LEARNINGS" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [[ "$AGE_DAYS" -gt "$KNOWLEDGE_STALE_DAYS" ]]; then
        check_warn "knowledge-freshness" "experiment-learnings.md is ${AGE_DAYS}d old (threshold: ${KNOWLEDGE_STALE_DAYS}d)" 3 6
    else
        check_pass "knowledge-freshness" "experiment-learnings.md updated ${AGE_DAYS}d ago" 6
    fi
fi

# self-model-freshness (6 pts): mind/self.md age
SELF_STALE_DAYS=$(cfg self.self_stale_days 7)
SELF_FILE="$RHINO_DIR/mind/self.md"

if [[ ! -f "$SELF_FILE" ]]; then
    check_fail "self-model-freshness" "mind/self.md not found" 6
else
    if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$SELF_FILE" 2>/dev/null || echo 0)
    else
        MTIME=$(stat -c %Y "$SELF_FILE" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [[ "$AGE_DAYS" -gt "$SELF_STALE_DAYS" ]]; then
        check_warn "self-model-freshness" "mind/self.md is ${AGE_DAYS}d old (threshold: ${SELF_STALE_DAYS}d)" 3 6
    else
        check_pass "self-model-freshness" "mind/self.md updated ${AGE_DAYS}d ago" 6
    fi
fi

# ============================================================
# Compute system scores (normalize to 25 pts each)
# ============================================================
normalize() {
    local pts="$1" max="$2"
    if [[ "$max" -eq 0 ]]; then echo 0; return; fi
    echo $(( pts * 25 / max ))
}

MEASURE_SCORE=$(normalize "$MEASURE_PTS" "$MEASURE_MAX")
THINK_SCORE=$(normalize "$THINK_PTS" "$THINK_MAX")
ACT_SCORE=$(normalize "$ACT_PTS" "$ACT_MAX")
LEARN_SCORE=$(normalize "$LEARN_PTS" "$LEARN_MAX")
TOTAL_SCORE=$((MEASURE_SCORE + THINK_SCORE + ACT_SCORE + LEARN_SCORE))

# === --score mode: output 0-100 ===
if [[ "$SCORE_MODE" == "true" ]]; then
    echo "$TOTAL_SCORE"
    exit 0
fi

# === --json mode: output system breakdown ===
if [[ "$JSON_MODE" == "true" ]]; then
    echo "{\"measure\":$MEASURE_SCORE,\"think\":$THINK_SCORE,\"act\":$ACT_SCORE,\"learn\":$LEARN_SCORE,\"total\":$TOTAL_SCORE}"
    exit 0
fi

# === --eval mode: machine-readable output for eval.sh ===
if [[ "$EVAL_MODE" == "true" ]]; then
    PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
    CAL_STATUS="HEALTHY"
    CAL_DETAIL="score ${TOTAL_SCORE}/100 (M:${MEASURE_SCORE} T:${THINK_SCORE} A:${ACT_SCORE} L:${LEARN_SCORE})"
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
            CAL_DETAIL="accuracy ${ACCURACY} (${CORRECT}/${TOTAL_GRADED}), ${CAL_DETAIL}"
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
    exit 0
fi

# === Display mode: grouped by system with subtotals ===

sys_color() {
    local pts="$1"
    if [[ "$pts" -ge 20 ]]; then echo "$GREEN"
    elif [[ "$pts" -ge 12 ]]; then echo "$YELLOW"
    else echo "$RED"
    fi
}

render_system() {
    local sys_name="$1" sys_key="$2" sys_score="$3"
    local color
    color=$(sys_color "$sys_score")
    echo -e "  ${BOLD}${sys_name}${NC} ${color}${sys_score}/25${NC}"

    for entry in "${CHECK_RESULTS[@]}"; do
        local status sys name desc pts
        IFS='|' read -r status sys name desc pts <<< "$entry"
        [[ "$sys" != "$sys_key" ]] && continue
        case "$status" in
            pass) printf "    ${GREEN}✓${NC} %-22s ${DIM}%s${NC}\n" "$name" "$desc" ;;
            warn) printf "    ${YELLOW}⚠${NC} %-22s ${YELLOW}%s${NC}\n" "$name" "$desc" ;;
            fail) printf "    ${RED}✗${NC} %-22s ${RED}%s${NC}\n" "$name" "$desc" ;;
        esac
    done
    echo ""
}

render_system "Measure" "measure" "$MEASURE_SCORE"
render_system "Think"   "think"   "$THINK_SCORE"
render_system "Act"     "act"     "$ACT_SCORE"
render_system "Learn"   "learn"   "$LEARN_SCORE"

# Overall
overall_color=$(sys_color "$((TOTAL_SCORE / 4))")
echo -e "  ${BOLD}Total: ${overall_color}${TOTAL_SCORE}/100${NC}"

if [[ -n "$TOP_ISSUE" ]]; then
    echo -e "  ${DIM}→${NC} $TOP_ISSUE"
fi
echo ""

# Weakest system
weakest_score=$MEASURE_SCORE; weakest_name="Measure"
[[ "$THINK_SCORE" -lt "$weakest_score" ]] && weakest_score=$THINK_SCORE && weakest_name="Think"
[[ "$ACT_SCORE" -lt "$weakest_score" ]] && weakest_score=$ACT_SCORE && weakest_name="Act"
[[ "$LEARN_SCORE" -lt "$weakest_score" ]] && weakest_score=$LEARN_SCORE && weakest_name="Learn"

if [[ "$weakest_score" -lt 20 ]]; then
    echo -e "  ${DIM}weakest system: ${BOLD}${weakest_name}${NC} ${DIM}(${weakest_score}/25)${NC}"
    echo ""
fi

exit 0
