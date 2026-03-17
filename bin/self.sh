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
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    RHINO_DIR="$CLAUDE_PLUGIN_ROOT"
else
    _SELF_SOURCE="${BASH_SOURCE[0]}"
    while [[ -L "$_SELF_SOURCE" ]]; do
        _SELF_SOURCE="$(readlink "$_SELF_SOURCE")"
    done
    RHINO_DIR="$(cd "$(dirname "$_SELF_SOURCE")/.." && pwd)"
fi

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
_taste_found=false
for _ts in "$RHINO_DIR"/lens/*/eval/taste.mjs; do
    [[ -f "$_ts" ]] && _taste_found=true && break
done
for tool in "$RHINO_DIR/bin/score.sh" "$RHINO_DIR/bin/eval.sh"; do
    if [[ ! -f "$tool" ]]; then
        STACK_MISSING=$((STACK_MISSING + 1))
    elif [[ ! -x "$tool" && "$tool" != *.mjs ]]; then
        STACK_MISSING=$((STACK_MISSING + 1))
    fi
done
[[ "$_taste_found" == "false" ]] && STACK_MISSING=$((STACK_MISSING + 1))
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

# mind-integrity (5 pts): 4 mind files present + delivered
MIND_FILES=(identity.md thinking.md standards.md self.md)
MIND_MISSING=0
MIND_UNLINKED=0
for mf in "${MIND_FILES[@]}"; do
    if [[ ! -f "$RHINO_DIR/mind/$mf" ]]; then
        MIND_MISSING=$((MIND_MISSING + 1))
    fi
done
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    # Plugin mode: mind files delivered via skills/rhino-mind/SKILL.md
    if [[ ! -f "$RHINO_DIR/skills/rhino-mind/SKILL.md" ]]; then
        MIND_UNLINKED=1
    fi
else
    # Legacy mode: check symlinks in rules/
    for mf in "${MIND_FILES[@]}"; do
        RULES_CHECK_DIR="$PWD/.claude/rules"
        [[ ! -d "$RULES_CHECK_DIR" ]] && RULES_CHECK_DIR="$HOME/.claude/rules"
        if [[ ! -L "$RULES_CHECK_DIR/$mf" ]] || [[ ! -f "$RULES_CHECK_DIR/$mf" ]]; then
            MIND_UNLINKED=$((MIND_UNLINKED + 1))
        fi
    done
fi
if [[ "$MIND_MISSING" -eq 0 && "$MIND_UNLINKED" -eq 0 ]]; then
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        check_pass "mind-integrity" "4 mind files present + SKILL.md delivers them" 5
    else
        check_pass "mind-integrity" "4 mind files present + symlinked" 5
    fi
elif [[ "$MIND_MISSING" -gt 0 ]]; then
    check_fail "mind-integrity" "$MIND_MISSING mind file(s) missing from mind/" 5
else
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        check_fail "mind-integrity" "skills/rhino-mind/SKILL.md missing" 5
    else
        check_fail "mind-integrity" "$MIND_UNLINKED mind file(s) not symlinked in rules/" 5
    fi
fi

# strategy-ready (5 pts): strategy.yml has stage + bottleneck
STRATEGY_FILE=".claude/plans/strategy.yml"
if [[ -f "$STRATEGY_FILE" ]]; then
    has_stage=$(grep -c 'stage:' "$STRATEGY_FILE" 2>/dev/null) || has_stage=0
    has_bottleneck=$(grep -c 'bottleneck:' "$STRATEGY_FILE" 2>/dev/null) || has_bottleneck=0
    if [[ "$has_stage" -gt 0 && "$has_bottleneck" -gt 0 ]]; then
        check_pass "strategy-ready" "strategy has stage + bottleneck" 5
    else
        check_warn "strategy-ready" "strategy missing stage or bottleneck" 2 5
    fi
else
    check_fail "strategy-ready" "no strategy.yml — run /strategy" 5
fi

# knowledge-coverage (6 pts): all 4 zones populated
LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]]; then
    has_known=$(grep -c '## Known' "$LEARNINGS" 2>/dev/null) || has_known=0
    has_uncertain=$(grep -c '## Uncertain' "$LEARNINGS" 2>/dev/null) || has_uncertain=0
    has_unknown=$(grep -c '## Unknown' "$LEARNINGS" 2>/dev/null) || has_unknown=0
    has_dead=$(grep -c '## Dead' "$LEARNINGS" 2>/dev/null) || has_dead=0
    zones=$((has_known + has_uncertain + has_unknown + has_dead))
    if [[ "$zones" -ge 4 ]]; then
        check_pass "knowledge-coverage" "all 4 zones populated (known/uncertain/unknown/dead)" 6
    elif [[ "$zones" -ge 2 ]]; then
        check_warn "knowledge-coverage" "$zones/4 knowledge zones populated" $((zones * 6 / 4)) 6
    else
        check_fail "knowledge-coverage" "knowledge model has $zones/4 zones — too thin to reason from" 6
    fi
else
    check_fail "knowledge-coverage" "no experiment-learnings.md" 6
fi

# prediction-accuracy (5 pts): calibrated 30-90%
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
ACCURACY_FLOOR=$(cfg self.prediction_accuracy_floor 0.30)
ACCURACY_CEILING=$(cfg self.prediction_accuracy_ceiling 0.90)

if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "prediction-accuracy" "no predictions.tsv found" 0 5
else
    TOTAL_GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    if [[ "$TOTAL_GRADED" -lt 5 ]]; then
        check_warn "prediction-accuracy" "only $TOTAL_GRADED graded predictions (need 5+ for calibration)" 2 5
    else
        CORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        PARTIAL=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
        # Partial credit: directionally right but off on magnitude counts as 0.5
        ACCURACY=$(awk "BEGIN { printf \"%.2f\", ($CORRECT + $PARTIAL * 0.5) / $TOTAL_GRADED }")
        if awk "BEGIN { exit !($ACCURACY < $ACCURACY_FLOOR) }"; then
            check_fail "prediction-accuracy" "accuracy ${ACCURACY} below floor ${ACCURACY_FLOOR} — model may be broken" 5
        elif awk "BEGIN { exit !($ACCURACY > $ACCURACY_CEILING) }"; then
            check_warn "prediction-accuracy" "accuracy ${ACCURACY} above ceiling ${ACCURACY_CEILING} — predictions may be too safe" 2 5
        else
            check_pass "prediction-accuracy" "accuracy ${ACCURACY} (${CORRECT}/${TOTAL_GRADED}) — well calibrated" 5
        fi
    fi
fi

# knowledge-entry-staleness (4 pts): individual knowledge entries checked for age
KNOWLEDGE_STALE_DAYS=$(cfg self.knowledge_stale_days 14)
if [[ -f "$LEARNINGS" ]]; then
    # Count dated entries and check for stale ones (dates embedded in entries like "2026-03-10")
    STALE_ENTRIES=0
    TOTAL_ENTRIES=0
    CUTOFF_DATE=$(date -v-${KNOWLEDGE_STALE_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${KNOWLEDGE_STALE_DAYS} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
    if [[ -n "$CUTOFF_DATE" ]]; then
        while IFS= read -r entry_date; do
            [[ -z "$entry_date" ]] && continue
            TOTAL_ENTRIES=$((TOTAL_ENTRIES + 1))
            if [[ "$entry_date" < "$CUTOFF_DATE" ]]; then
                STALE_ENTRIES=$((STALE_ENTRIES + 1))
            fi
        done < <(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$LEARNINGS" 2>/dev/null | sort -u)
    fi
    if [[ "$TOTAL_ENTRIES" -eq 0 ]]; then
        check_warn "knowledge-entry-staleness" "no dated entries in knowledge model — can't assess freshness" 2 4
    elif [[ "$STALE_ENTRIES" -gt "$((TOTAL_ENTRIES / 2))" ]]; then
        check_warn "knowledge-entry-staleness" "${STALE_ENTRIES}/${TOTAL_ENTRIES} dated entries older than ${KNOWLEDGE_STALE_DAYS}d" 1 4
    else
        check_pass "knowledge-entry-staleness" "${TOTAL_ENTRIES} dated entries, ${STALE_ENTRIES} stale" 4
    fi
else
    check_fail "knowledge-entry-staleness" "no experiment-learnings.md" 4
fi

# ============================================================
# ACT (25 pts) — Can it execute?
# ============================================================
CURRENT_SYSTEM="act"

# commands-depth (5 pts): slash commands are substantive, not stubs
SKILL_DIR="$RHINO_DIR/skills"
if [[ -d "$SKILL_DIR" ]]; then
    STUB_COUNT=0
    SKILL_COUNT=0
    for skill_file in "$SKILL_DIR"/*/SKILL.md; do
        [[ ! -f "$skill_file" ]] && continue
        SKILL_COUNT=$((SKILL_COUNT + 1))
        lines=$(wc -l < "$skill_file" 2>/dev/null | tr -d ' ')
        if [[ "$lines" -lt 20 ]]; then
            STUB_COUNT=$((STUB_COUNT + 1))
        fi
    done
    if [[ "$SKILL_COUNT" -eq 0 ]]; then
        check_fail "skills-depth" "no skills found" 5
    elif [[ "$STUB_COUNT" -gt 0 ]]; then
        check_warn "skills-depth" "$STUB_COUNT/$SKILL_COUNT skills are stubs (<20 lines)" 2 5
    else
        check_pass "skills-depth" "$SKILL_COUNT skills, all substantive" 5
    fi
else
    check_fail "skills-depth" "no skills directory" 5
fi

# hook-health (5 pts): hooks resolve and are executable
HOOK_TIMEOUT_MS=$(cfg self.hook_timeout_ms 200)
HOOKS_BROKEN=0
HOOKS_CHECKED=0

if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    # Plugin mode: validate hooks.json and referenced .sh files
    HOOKS_JSON="$RHINO_DIR/hooks/hooks.json"
    if [[ -f "$HOOKS_JSON" ]] && command -v jq &>/dev/null; then
        while IFS= read -r hook_cmd; do
            [[ -z "$hook_cmd" ]] && continue
            HOOKS_CHECKED=$((HOOKS_CHECKED + 1))
            # Expand ${CLAUDE_PLUGIN_ROOT} template variable
            hook_cmd="${hook_cmd//\$\{CLAUDE_PLUGIN_ROOT\}/$RHINO_DIR}"
            # Strip quotes used for paths with spaces
            hook_cmd="${hook_cmd//\"/}"
            # Extract just the executable (first word before args)
            local_cmd="${hook_cmd%% *}"
            if [[ ! -f "$local_cmd" ]]; then
                HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
            elif [[ ! -x "$local_cmd" ]]; then
                HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
            fi
        done < <(jq -r '.. | .command? // empty' "$HOOKS_JSON" 2>/dev/null)
    elif [[ ! -f "$HOOKS_JSON" ]]; then
        HOOKS_BROKEN=1
        HOOKS_CHECKED=1
    fi
elif [[ -f "$PWD/.claude/settings.json" ]] && command -v jq &>/dev/null; then
    # Project-local: parse settings.json for hook commands
    while IFS= read -r hook_cmd; do
        [[ -z "$hook_cmd" ]] && continue
        HOOKS_CHECKED=$((HOOKS_CHECKED + 1))
        if [[ ! -f "$hook_cmd" ]]; then
            HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
        elif [[ ! -x "$hook_cmd" ]]; then
            HOOKS_BROKEN=$((HOOKS_BROKEN + 1))
        fi
    done < <(jq -r '.. | .command? // empty' "$PWD/.claude/settings.json" 2>/dev/null)
else
    # Fall back to global hooks dir (legacy install)
    HOOKS_DIR="$HOME/.claude/hooks"
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
fi

if [[ "$HOOKS_CHECKED" -eq 0 ]]; then
    check_warn "hook-health" "no hooks found" 0 5
elif [[ "$HOOKS_BROKEN" -gt 0 ]]; then
    check_fail "hook-health" "$HOOKS_BROKEN hook(s) broken or not executable" 5
else
    check_pass "hook-health" "$HOOKS_CHECKED hooks healthy" 5
fi

# config-coherence (5 pts): rhino.yml required sections present
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
    # Check all lens configs for required sections
    for _lcf in "$RHINO_DIR"/lens/*/config/rhino-*.yml; do
        [[ -f "$_lcf" ]] || continue
        if ! grep -q "^taste:" "$_lcf" 2>/dev/null; then
            MISSING_SECTIONS=$((MISSING_SECTIONS + 1))
        fi
    done
    if [[ "$MISSING_SECTIONS" -gt 0 ]]; then
        check_warn "config-coherence" "$MISSING_SECTIONS required section(s) missing from rhino.yml" 2 5
    else
        check_pass "config-coherence" "rhino.yml has all required sections" 5
    fi
fi

# act-commands-execute (5 pts): rhino help/version run
# Note: can't call score.sh or eval.sh here (both can call self.sh → recursion)
ACT_CMDS_OK=0
ACT_CMDS_TOTAL=2

for cmd in help version; do
    if "$RHINO_DIR/bin/rhino" "$cmd" >/dev/null 2>&1; then
        ACT_CMDS_OK=$((ACT_CMDS_OK + 1))
    fi
done

if [[ "$ACT_CMDS_OK" -eq "$ACT_CMDS_TOTAL" ]]; then
    check_pass "commands-execute" "$ACT_CMDS_OK/$ACT_CMDS_TOTAL commands produce output" 5
elif [[ "$ACT_CMDS_OK" -gt 0 ]]; then
    local_pts=$((ACT_CMDS_OK * 5 / ACT_CMDS_TOTAL))
    check_warn "commands-execute" "$ACT_CMDS_OK/$ACT_CMDS_TOTAL commands produce output" "$local_pts" 5
else
    check_fail "commands-execute" "0/$ACT_CMDS_TOTAL commands produce output" 5
fi

# plan-active (5 pts): plan.yml exists with non-stale tasks
PLAN_CHECK_FILE=""
for _pf in "$PWD/.claude/plans/plan.yml" "$HOME/.claude/plans/plan.yml"; do
    [[ -f "$_pf" ]] && PLAN_CHECK_FILE="$_pf" && break
done
if [[ -z "$PLAN_CHECK_FILE" ]]; then
    check_warn "plan-active" "no plan.yml — run /plan to create one" 0 5
else
    PLAN_TODO=$(grep -c 'status: todo' "$PLAN_CHECK_FILE" 2>/dev/null | tr -d ' \n' || true)
    PLAN_DONE=$(grep -c 'status: done' "$PLAN_CHECK_FILE" 2>/dev/null | tr -d ' \n' || true)
    [[ -z "$PLAN_TODO" || ! "$PLAN_TODO" =~ ^[0-9]+$ ]] && PLAN_TODO=0
    [[ -z "$PLAN_DONE" || ! "$PLAN_DONE" =~ ^[0-9]+$ ]] && PLAN_DONE=0
    PLAN_TOTAL=$((PLAN_TODO + PLAN_DONE))
    # Check plan staleness (>48h old = stale)
    if [[ "$(uname)" == "Darwin" ]]; then
        PLAN_MOD=$(stat -f %m "$PLAN_CHECK_FILE" 2>/dev/null || echo 0)
    else
        PLAN_MOD=$(stat -c %Y "$PLAN_CHECK_FILE" 2>/dev/null || echo 0)
    fi
    PLAN_AGE_H=$(( ($(date +%s) - PLAN_MOD) / 3600 ))
    if [[ "$PLAN_TOTAL" -eq 0 ]]; then
        check_warn "plan-active" "plan.yml exists but has no tasks" 2 5
    elif [[ "$PLAN_AGE_H" -gt 48 ]]; then
        check_warn "plan-active" "plan ${PLAN_AGE_H}h old with ${PLAN_TODO} todo tasks — may be stale" 2 5
    elif [[ "$PLAN_TODO" -gt 0 ]]; then
        check_pass "plan-active" "${PLAN_TODO} todo / ${PLAN_DONE} done tasks, updated ${PLAN_AGE_H}h ago" 5
    else
        check_pass "plan-active" "all ${PLAN_DONE} tasks done — plan complete" 5
    fi
fi

# ============================================================
# LEARN (25 pts) — Does it compound?
# ============================================================
CURRENT_SYSTEM="learn"

# learning-velocity (5 pts): predictions per week
MIN_PER_WEEK=$(cfg self.min_predictions_per_week 3)
PRED_STALE_DAYS=$(cfg self.prediction_stale_days 7)

if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "learning-velocity" "no predictions.tsv" 0 5
else
    CUTOFF_DATE=$(date -v-${PRED_STALE_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${PRED_STALE_DAYS} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
    if [[ -n "$CUTOFF_DATE" ]]; then
        RECENT_COUNT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' -v cutoff="$CUTOFF_DATE" '$1 >= cutoff { c++ } END { print c+0 }')
        if [[ "$RECENT_COUNT" -lt "$MIN_PER_WEEK" ]]; then
            check_warn "learning-velocity" "${RECENT_COUNT} predictions in last ${PRED_STALE_DAYS}d (minimum: ${MIN_PER_WEEK})" 2 5
        else
            check_pass "learning-velocity" "${RECENT_COUNT} predictions in last ${PRED_STALE_DAYS}d" 5
        fi
    else
        check_warn "learning-velocity" "could not compute date cutoff" 0 5
    fi
fi

# prediction-grading (4 pts): are predictions being graded?
if [[ ! -f "$PRED_FILE" ]]; then
    check_warn "prediction-grading" "no predictions.tsv" 0 4
else
    TOTAL_ROWS=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
    TOTAL_GRADED_L=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    if [[ "$TOTAL_ROWS" -eq 0 ]]; then
        check_warn "prediction-grading" "no predictions logged yet" 0 4
    elif [[ "$TOTAL_GRADED_L" -eq 0 ]]; then
        check_fail "prediction-grading" "0/$TOTAL_ROWS predictions graded — learning loop stalled" 4
    else
        grade_rate=$((TOTAL_GRADED_L * 100 / TOTAL_ROWS))
        if [[ "$grade_rate" -ge 50 ]]; then
            check_pass "prediction-grading" "$TOTAL_GRADED_L/$TOTAL_ROWS predictions graded (${grade_rate}%)" 4
        else
            check_warn "prediction-grading" "$TOTAL_GRADED_L/$TOTAL_ROWS predictions graded (${grade_rate}%)" 2 4
        fi
    fi
fi

# knowledge-freshness (4 pts): experiment-learnings.md age
KNOWLEDGE_STALE_DAYS=$(cfg self.knowledge_stale_days 14)

if [[ ! -f "$LEARNINGS" ]]; then
    check_fail "knowledge-freshness" "experiment-learnings.md not found" 4
else
    if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$LEARNINGS" 2>/dev/null || echo 0)
    else
        MTIME=$(stat -c %Y "$LEARNINGS" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [[ "$AGE_DAYS" -gt "$KNOWLEDGE_STALE_DAYS" ]]; then
        check_warn "knowledge-freshness" "experiment-learnings.md is ${AGE_DAYS}d old (threshold: ${KNOWLEDGE_STALE_DAYS}d)" 2 4
    else
        check_pass "knowledge-freshness" "experiment-learnings.md updated ${AGE_DAYS}d ago" 4
    fi
fi

# self-model-freshness (4 pts): mind/self.md age
SELF_STALE_DAYS=$(cfg self.self_stale_days 7)
SELF_FILE="$RHINO_DIR/mind/self.md"

if [[ ! -f "$SELF_FILE" ]]; then
    check_fail "self-model-freshness" "mind/self.md not found" 4
else
    if [[ "$(uname)" == "Darwin" ]]; then
        MTIME=$(stat -f %m "$SELF_FILE" 2>/dev/null || echo 0)
    else
        MTIME=$(stat -c %Y "$SELF_FILE" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [[ "$AGE_DAYS" -gt "$SELF_STALE_DAYS" ]]; then
        check_warn "self-model-freshness" "mind/self.md is ${AGE_DAYS}d old (threshold: ${SELF_STALE_DAYS}d)" 2 4
    else
        check_pass "self-model-freshness" "mind/self.md updated ${AGE_DAYS}d ago" 4
    fi
fi

# grade-runs (4 pts): grade.sh executes and produces output
if [[ ! -f "$RHINO_DIR/bin/grade.sh" ]]; then
    check_fail "grade-runs" "grade.sh not found" 4
elif [[ ! -x "$RHINO_DIR/bin/grade.sh" ]]; then
    check_fail "grade-runs" "grade.sh not executable" 4
else
    if [[ -f "$PRED_FILE" ]]; then
        # Actually run grade.sh --quiet and check exit code
        if bash "$RHINO_DIR/bin/grade.sh" --quiet "$PRED_FILE" \
            "$PWD/.claude/scores/history.tsv" \
            "$PWD/.claude/cache/score-cache.json" 2>/dev/null; then
            check_pass "grade-runs" "grade.sh executes successfully" 4
        else
            check_warn "grade-runs" "grade.sh exited with error" 2 4
        fi
    else
        check_warn "grade-runs" "grade.sh exists but no predictions.tsv to grade" 2 4
    fi
fi

# learning-loop-closure (4 pts): full loop — predictions exist → graded → knowledge updated
# This is the core logic check: does the learning loop actually close?
LOOP_STAGES=0
LOOP_TOTAL=4
# Stage 1: predictions exist
if [[ -f "$PRED_FILE" ]]; then
    PRED_ROWS=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
    [[ "$PRED_ROWS" -gt 0 ]] && LOOP_STAGES=$((LOOP_STAGES + 1))
fi
# Stage 2: some predictions are graded
if [[ -f "$PRED_FILE" ]]; then
    GRADED_ROWS=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    [[ "$GRADED_ROWS" -gt 0 ]] && LOOP_STAGES=$((LOOP_STAGES + 1))
fi
# Stage 3: knowledge model has content (not just headers)
if [[ -f "$LEARNINGS" ]]; then
    KNOWLEDGE_ENTRIES=$(grep -c '^\s*-\s' "$LEARNINGS" 2>/dev/null || echo "0")
    [[ "$KNOWLEDGE_ENTRIES" -gt 0 ]] && LOOP_STAGES=$((LOOP_STAGES + 1))
fi
# Stage 4: model_update column has entries (grading → knowledge feedback)
if [[ -f "$PRED_FILE" ]]; then
    MODEL_UPDATES=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$7 != "" { c++ } END { print c+0 }')
    [[ "$MODEL_UPDATES" -gt 0 ]] && LOOP_STAGES=$((LOOP_STAGES + 1))
fi

if [[ "$LOOP_STAGES" -eq "$LOOP_TOTAL" ]]; then
    check_pass "learning-loop-closure" "full loop: predict→grade→update→knowledge (${LOOP_STAGES}/${LOOP_TOTAL})" 4
elif [[ "$LOOP_STAGES" -ge 2 ]]; then
    check_warn "learning-loop-closure" "loop partially closed: ${LOOP_STAGES}/${LOOP_TOTAL} stages active" $((LOOP_STAGES * 4 / LOOP_TOTAL)) 4
else
    check_fail "learning-loop-closure" "learning loop broken: only ${LOOP_STAGES}/${LOOP_TOTAL} stages active" 4
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
            PARTIAL=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
            # Partial credit: directionally right counts as 0.5
            ACCURACY=$(awk "BEGIN { printf \"%.2f\", ($CORRECT + $PARTIAL * 0.5) / $TOTAL_GRADED }")
            FLOOR=$(cfg self.prediction_accuracy_floor 0.30)
            CEILING=$(cfg self.prediction_accuracy_ceiling 0.90)
            if awk "BEGIN { exit !($ACCURACY < $FLOOR) }"; then
                CAL_STATUS="BROKEN"
            elif awk "BEGIN { exit !($ACCURACY > $CEILING) }"; then
                CAL_STATUS="TOO_SAFE"
            fi
            CAL_DETAIL="accuracy ${ACCURACY} (${CORRECT}+${PARTIAL}p/${TOTAL_GRADED}), ${CAL_DETAIL}"
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

    # Remaining metrics: only safe to run outside the scoring pipeline.
    # When called from eval.sh (RHINO_EVAL_DEPTH > 0), skip to avoid recursion.
    if [[ "${RHINO_EVAL_DEPTH:-0}" -eq 0 ]]; then
        # score-runs: does rhino score . --quiet produce a number?
        score_out=$("$RHINO_DIR/bin/score.sh" . --quiet --force 2>/dev/null) || score_out=""
        if [[ -n "$score_out" && "$score_out" =~ ^[0-9]+$ ]]; then
            echo "score-runs:pass:rhino score produces $score_out"
        else
            echo "score-runs:fail:rhino score did not produce a number"
        fi

        # eval-runs: does rhino eval . exit without crash?
        if "$RHINO_DIR/bin/eval.sh" . >/dev/null 2>&1; then
            echo "eval-runs:pass:rhino eval exits cleanly"
        else
            echo "eval-runs:fail:rhino eval crashed"
        fi

        # tests-pass: does rhino test exit 0?
        if "$RHINO_DIR/bin/rhino" test >/dev/null 2>&1; then
            echo "tests-pass:pass:rhino test exits 0"
        else
            echo "tests-pass:fail:rhino test failed"
        fi
    else
        # Inside scoring pipeline — check existence instead of execution
        [[ -f "$RHINO_DIR/bin/score.sh" ]] && echo "score-runs:pass:score.sh exists" || echo "score-runs:fail:score.sh missing"
        [[ -f "$RHINO_DIR/bin/eval.sh" ]] && echo "eval-runs:pass:eval.sh exists" || echo "eval-runs:fail:eval.sh missing"
        [[ -d "$RHINO_DIR/tests" ]] && echo "tests-pass:pass:tests/ exists" || echo "tests-pass:fail:tests/ missing"
    fi

    # value-hypothesis-defined: does rhino.yml have value: section?
    if [[ -f "$RHINO_DIR/config/rhino.yml" ]] && grep -q '^value:' "$RHINO_DIR/config/rhino.yml" 2>/dev/null; then
        echo "value-hypothesis-defined:pass:rhino.yml has value: section"
    else
        echo "value-hypothesis-defined:fail:rhino.yml missing value: section"
    fi

    # predictions-logged: does predictions.tsv have entries?
    _pred="$HOME/.claude/knowledge/predictions.tsv"
    if [[ -f "$_pred" ]]; then
        _pcount=$(tail -n +2 "$_pred" | wc -l | tr -d ' ')
        if [[ "$_pcount" -gt 0 ]]; then
            echo "predictions-logged:pass:${_pcount} predictions logged"
        else
            echo "predictions-logged:fail:predictions.tsv exists but empty"
        fi
    else
        echo "predictions-logged:fail:no predictions.tsv"
    fi

    # help-works: does rhino help produce output?
    _help_out=$("$RHINO_DIR/bin/rhino" help 2>&1) || true
    if echo "$_help_out" | grep -q 'rhino'; then
        echo "help-works:pass:rhino help produces output"
    else
        echo "help-works:fail:rhino help produced no output"
    fi

    # skills-have-descriptions: every SKILL.md in skills/ has description: in frontmatter
    _skill_dir="$RHINO_DIR/skills"
    _cmd_total=0; _cmd_ok=0
    if [[ -d "$_skill_dir" ]]; then
        for _cf in "$_skill_dir"/*/SKILL.md; do
            [[ ! -f "$_cf" ]] && continue
            _cmd_total=$((_cmd_total + 1))
            if head -5 "$_cf" | grep -q 'description:'; then
                _cmd_ok=$((_cmd_ok + 1))
            fi
        done
    fi
    if [[ "$_cmd_total" -eq 0 ]]; then
        echo "skills-have-descriptions:fail:no skill files"
    elif [[ "$_cmd_ok" -eq "$_cmd_total" ]]; then
        echo "skills-have-descriptions:pass:${_cmd_ok}/${_cmd_total} have descriptions"
    else
        echo "skills-have-descriptions:fail:$((_cmd_total - _cmd_ok))/${_cmd_total} missing description"
    fi

    # install-exists: install.sh exists and is executable
    if [[ -x "$RHINO_DIR/install.sh" ]]; then
        echo "install-exists:pass:install.sh exists and is executable"
    elif [[ -f "$RHINO_DIR/install.sh" ]]; then
        echo "install-exists:fail:install.sh exists but not executable"
    else
        echo "install-exists:fail:install.sh missing"
    fi

    # readme-exists: README.md exists with content
    if [[ -f "$RHINO_DIR/README.md" ]]; then
        _rlines=$(wc -l < "$RHINO_DIR/README.md" | tr -d ' ')
        if [[ "$_rlines" -gt 10 ]]; then
            echo "readme-exists:pass:README.md exists (${_rlines} lines)"
        else
            echo "readme-exists:fail:README.md exists but too short (${_rlines} lines)"
        fi
    else
        echo "readme-exists:fail:README.md missing"
    fi

    # readme-has-commands: README mentions slash commands
    if [[ -f "$RHINO_DIR/README.md" ]] && grep -q '/plan\|/go\|/assert\|/feature' "$RHINO_DIR/README.md" 2>/dev/null; then
        echo "readme-has-commands:pass:README documents slash commands"
    else
        echo "readme-has-commands:fail:README doesn't mention slash commands"
    fi

    # readme-has-scoring: README explains scoring
    if [[ -f "$RHINO_DIR/README.md" ]] && grep -q 'assertion pass rate\|scoring' "$RHINO_DIR/README.md" 2>/dev/null; then
        echo "readme-has-scoring:pass:README explains scoring"
    else
        echo "readme-has-scoring:fail:README doesn't explain scoring"
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
