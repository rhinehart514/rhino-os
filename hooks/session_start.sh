#!/usr/bin/env bash
# session_start.sh — SessionStart hook (v6)
# Boot card: project state, score, plan, staleness, integrity, prediction accuracy.
set -euo pipefail

PROJECT_DIR=$(pwd)
INPUT=$(cat)

# --- Resolve RHINO_DIR for config access ---
_SS_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_SS_SOURCE" ]]; do
    _SS_SOURCE="$(readlink "$_SS_SOURCE")"
done
_SS_DIR="$(cd "$(dirname "$_SS_SOURCE")" && pwd)"
# hooks/ is at RHINO_DIR/hooks/
RHINO_DIR="$(cd "$_SS_DIR/.." && pwd)"
if [[ -f "$RHINO_DIR/bin/lib/config.sh" ]]; then
    source "$RHINO_DIR/bin/lib/config.sh"
fi
SESSION_TYPE=$(echo "$INPUT" | jq -r '.type // "startup"' 2>/dev/null || echo "startup")

# --- Project name ---
PROJECT_NAME=""
if [[ -f "$PROJECT_DIR/config/rhino.yml" ]]; then
    PROJECT_NAME=$(grep -m1 '^name:' "$PROJECT_DIR/config/rhino.yml" 2>/dev/null | sed 's/^name: *//' || true)
fi
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME=$(basename "$PROJECT_DIR")

# --- Last score + integrity ---
SCORE_DISPLAY=""
INTEGRITY_WARNINGS=""
SCORING_MODE=""
ASSERTION_COUNT=0
ASSERTION_PASS_COUNT=0
HEALTH_GATE=""
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]] && command -v jq &>/dev/null; then
    TOTAL=$(jq -r '.score // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    SCORING_MODE=$(jq -r '.scoring_mode // "empty"' "$SCORE_CACHE" 2>/dev/null || echo "empty")
    ASSERTION_COUNT=$(jq -r '.assertion_count // 0' "$SCORE_CACHE" 2>/dev/null || echo "0")
    ASSERTION_PASS_COUNT=$(jq -r '.assertion_pass_count // 0' "$SCORE_CACHE" 2>/dev/null || echo "0")
    HEALTH_GATE=$(jq -r '.health_gate // "PASS"' "$SCORE_CACHE" 2>/dev/null || echo "PASS")
    HEALTH_MIN=$(jq -r '.health_min // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")

    if [[ "$SCORING_MODE" == "assertions" ]]; then
        SCORE_DISPLAY="Score: ${TOTAL}/100 (${ASSERTION_PASS_COUNT}/${ASSERTION_COUNT} assertions)"
    elif [[ "$SCORING_MODE" == "onboarding" ]]; then
        SCORE_DISPLAY="Score: ${TOTAL}/50 (onboarding)"
    else
        SCORE_DISPLAY="Score: ${TOTAL}/100"
    fi

    # Health gate status
    if [[ "$HEALTH_GATE" == "FAIL" ]]; then
        SCORE_DISPLAY="${SCORE_DISPLAY} [HEALTH GATE FAIL]"
    fi

    # Surface integrity warnings
    WARNINGS_JSON=$(jq -r '.integrity_warnings // [] | .[]' "$SCORE_CACHE" 2>/dev/null || true)
    if [[ -n "$WARNINGS_JSON" ]]; then
        INTEGRITY_WARNINGS="$WARNINGS_JSON"
    fi
fi

# --- Active plan ---
PLAN_FILE=""
for p in "$PROJECT_DIR/.claude/plans/plan.yml" "$HOME/.claude/plans/plan.yml"; do
    if [[ -f "$p" ]]; then PLAN_FILE="$p"; break; fi
done

TASKS_REMAINING=0
NEXT_TASK=""
PLAN_STALE=""
if [[ -n "$PLAN_FILE" ]]; then
    TOTAL_TASKS=$(grep -c '- title:' "$PLAN_FILE" 2>/dev/null || echo 0)
    DONE_TASKS=$(grep -c 'status: done' "$PLAN_FILE" 2>/dev/null || echo 0)
    TASKS_REMAINING=$((TOTAL_TASKS - DONE_TASKS))
    NEXT_TASK=$(grep -B1 'status: todo' "$PLAN_FILE" 2>/dev/null | grep 'title:' | head -1 | sed 's/.*title: *//' || true)

    # Staleness check (>24h)
    if [[ "$(uname)" == "Darwin" ]]; then
        PLAN_MTIME=$(stat -f %m "$PLAN_FILE" 2>/dev/null || echo 0)
    else
        PLAN_MTIME=$(stat -c %Y "$PLAN_FILE" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_HOURS=$(( (NOW - PLAN_MTIME) / 3600 ))
    if (( AGE_HOURS > 24 )); then
        PLAN_STALE="(${AGE_HOURS}h old — consider /plan)"
    fi
fi

# --- Strategy staleness ---
STRATEGY_STALE=""
STRATEGY_FILE="$PROJECT_DIR/.claude/plans/strategy.yml"
if [[ -f "$STRATEGY_FILE" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        STRAT_MTIME=$(stat -f %m "$STRATEGY_FILE" 2>/dev/null || echo 0)
    else
        STRAT_MTIME=$(stat -c %Y "$STRATEGY_FILE" 2>/dev/null || echo 0)
    fi
    NOW=${NOW:-$(date +%s)}
    STRAT_AGE_DAYS=$(( (NOW - STRAT_MTIME) / 86400 ))
    if (( STRAT_AGE_DAYS > 3 )); then
        STRATEGY_STALE="Strategy: ${STRAT_AGE_DAYS}d old — stale"
    fi
fi

# --- Assertion status (value signal) ---
ASSERT_DISPLAY=""
BELIEFS_FILE=""
for _bf in "$PROJECT_DIR/lens/product/eval/beliefs.yml" "$PROJECT_DIR/config/evals/beliefs.yml"; do
    [[ -f "$_bf" ]] && BELIEFS_FILE="$_bf" && break
done
if [[ -f "$BELIEFS_FILE" ]]; then
    TOTAL_BELIEFS=$(grep -c '^\s*- id:' "$BELIEFS_FILE" 2>/dev/null || echo "0")
    if (( TOTAL_BELIEFS > 0 )); then
        ASSERT_DISPLAY="Assertions: ${TOTAL_BELIEFS} planted"
    fi
fi

# --- Prediction accuracy (last 10) ---
PRED_DISPLAY=""
UNGRADED_COUNT=0
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    PRED_COUNT=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
    if (( PRED_COUNT > 0 )); then
        # Count correct/partial predictions (column 6) in last 10
        CORRECT=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        PARTIAL_CT=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
        FILLED=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
        # Count all ungraded (column 6 empty)
        UNGRADED_COUNT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "" { c++ } END { print c+0 }')
        if (( FILLED > 0 )); then
            # Partial credit: partials count as 0.5 (matches self.sh formula)
            EFFECTIVE=$(awk "BEGIN { printf \"%d\", $CORRECT + $PARTIAL_CT * 0.5 }")
            PRED_DISPLAY="Predictions: ${EFFECTIVE}/${FILLED} correct"
            [[ "$PARTIAL_CT" -gt 0 ]] && PRED_DISPLAY="${PRED_DISPLAY} (${PARTIAL_CT} partial)"
        else
            PRED_DISPLAY="Predictions: ${PRED_COUNT} logged, 0 graded"
        fi
    fi
fi

# --- Agent experiment status ---
AGENT_EXP_DISPLAY=""
AGENT_EXP_FILE="$PROJECT_DIR/agent-experiments.tsv"
if [[ -f "$AGENT_EXP_FILE" ]]; then
    # Find rows with empty result column (column 6)
    UNRESOLVED=$(tail -n +2 "$AGENT_EXP_FILE" | awk -F'\t' '$6 == "" { print $2 " (" $3 "→" $4 ")" }' | tail -1)
    if [[ -n "$UNRESOLVED" ]]; then
        AGENT_EXP_DISPLAY="Agent experiment: ${UNRESOLVED} — ungraded"
    fi
fi

# === Output ===
# Colors
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'
C_NC='\033[0m'

print_score_bar() {
    local score=${1:-0}
    local filled=$(( (score + 2) / 5 ))
    [[ $filled -gt 20 ]] && filled=20
    local empty=$((20 - filled))
    local color="$C_RED"
    [[ $score -ge 50 ]] && color="$C_YELLOW"
    [[ $score -ge 80 ]] && color="$C_GREEN"
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    local trail=""
    for ((i=0; i<empty; i++)); do trail="${trail}░"; done
    printf "${color}${bar}${C_DIM}${trail}${C_NC}"
}

# Color a sub-score value
color_score() {
    local score=${1:-0}
    if [[ "$score" == "?" ]]; then
        printf "${C_DIM}?${C_NC}"
    elif [[ $score -ge 80 ]]; then
        printf "${C_GREEN}${score}${C_NC}"
    elif [[ $score -ge 50 ]]; then
        printf "${C_YELLOW}${score}${C_NC}"
    else
        printf "${C_RED}${score}${C_NC}"
    fi
}

SEP="  ${C_DIM}⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯${C_NC}"

echo ""
echo -e "${SEP}"
echo -e "  ${C_CYAN}◆${C_NC} ${C_BOLD}rhino-os${C_NC}  ${C_DIM}·${C_NC}  ${PROJECT_NAME}"
echo -e "${SEP}"
echo ""

# Score with bar
if [[ -n "$SCORE_DISPLAY" ]]; then
    if [[ "$SCORING_MODE" == "onboarding" ]]; then
        SCORE_BAR=$(print_score_bar "$((TOTAL * 2))")  # scale 0-50 to 0-100 for bar
    else
        SCORE_BAR=$(print_score_bar "$TOTAL")
    fi
    echo -e "  ${C_DIM}score${C_NC}       ${C_BOLD}${TOTAL}${C_NC}${C_DIM}/100${C_NC}  ${SCORE_BAR}"
    if [[ "$SCORING_MODE" == "assertions" ]]; then
        echo -e "              ${C_DIM}assertions${C_NC} ${ASSERTION_PASS_COUNT}/${ASSERTION_COUNT}  ${C_DIM}·${C_NC}  ${C_DIM}health${C_NC} $(color_score "$HEALTH_MIN")"
        # Show feature scores (worst to best, compact)
        if command -v jq &>/dev/null && [[ -f "$SCORE_CACHE" ]]; then
            FEAT_LIST=$(jq -r '.features // {} | to_entries | sort_by(if .value.type == "generative" then .value.score else (.value.pass / (.value.total + 0.001) * 100) end) | .[:3] | .[] | if .value.type == "generative" then "\(.key)|\(.value.score)" else "\(.key)|\(.value.pass * 100 / (.value.total + 1) | floor)" end' "$SCORE_CACHE" 2>/dev/null || true)
            if [[ -n "$FEAT_LIST" ]]; then
                FEAT_DISPLAY=""
                FIRST=true
                while IFS='|' read -r fname fscore; do
                    [[ -z "$fname" ]] && continue
                    $FIRST || FEAT_DISPLAY="${FEAT_DISPLAY}  "
                    if [[ "$fscore" -ge 70 ]]; then
                        FEAT_DISPLAY="${FEAT_DISPLAY}${C_DIM}${fname}${C_NC} ${C_GREEN}${fscore}${C_NC}"
                    elif [[ "$fscore" -ge 50 ]]; then
                        FEAT_DISPLAY="${FEAT_DISPLAY}${C_DIM}${fname}${C_NC} ${C_YELLOW}${fscore}${C_NC}"
                    else
                        FEAT_DISPLAY="${FEAT_DISPLAY}${C_RED}▸${C_NC} ${fname} ${C_RED}${fscore}${C_NC}"
                    fi
                    FIRST=false
                done <<< "$FEAT_LIST"
                echo -e "              ${FEAT_DISPLAY}"
            fi
        fi
    elif [[ "$SCORING_MODE" == "onboarding" ]]; then
        echo -e "              ${C_DIM}onboarding${C_NC}  ${C_DIM}·${C_NC}  ${C_DIM}health${C_NC} $(color_score "$HEALTH_MIN")"
    else
        echo -e "              ${C_DIM}no value hypothesis${C_NC}  ${C_DIM}·${C_NC}  ${C_DIM}health${C_NC} $(color_score "$HEALTH_MIN")"
    fi
    # Show score reasons if available
    if command -v jq &>/dev/null && [[ -f "$SCORE_CACHE" ]]; then
        REASONS=$(jq -r '.reasons // {} | to_entries[] | .value[] // empty' "$SCORE_CACHE" 2>/dev/null | head -3)
        if [[ -n "$REASONS" ]]; then
            while IFS= read -r reason; do
                [[ -n "$reason" ]] && echo -e "              ${C_DIM}· ${reason}${C_NC}"
            done <<< "$REASONS"
        fi
    fi
else
    echo -e "  ${C_DIM}score${C_NC}       ${C_DIM}none yet — run${C_NC} rhino score ."
fi

# Plan + next task (compact)
if [[ -n "$PLAN_FILE" && "$TASKS_REMAINING" -gt 0 ]]; then
    PLAN_LINE="  ${C_DIM}plan${C_NC}        ${TASKS_REMAINING} tasks"
    [[ -n "$PLAN_STALE" ]] && PLAN_LINE="${PLAN_LINE}  ${C_YELLOW}${PLAN_STALE}${C_NC}"
    [[ -n "$NEXT_TASK" ]] && PLAN_LINE="${PLAN_LINE}  ${C_DIM}·${C_NC}  ${C_GREEN}▸${C_NC} ${NEXT_TASK}"
    echo -e "$PLAN_LINE"
fi

# Signals (assertions + predictions on separate lines for clarity)
if [[ -n "$ASSERT_DISPLAY" || -n "$PRED_DISPLAY" ]]; then
    SIG_PARTS=""
    [[ -n "$ASSERT_DISPLAY" ]] && SIG_PARTS="${ASSERT_DISPLAY}"
    if [[ -n "$PRED_DISPLAY" ]]; then
        SIG_PARTS="${SIG_PARTS:+$SIG_PARTS  ${C_DIM}·${C_NC}  }${PRED_DISPLAY}"
    fi
    echo -e "  ${C_DIM}signals${C_NC}     ${SIG_PARTS}"
fi

# Experiment results stats
RESULTS_TSV="$PROJECT_DIR/.claude/experiments/results.tsv"
if [[ -f "$RESULTS_TSV" ]]; then
    EXP_TOTAL=$(tail -n +2 "$RESULTS_TSV" | wc -l | tr -d ' ')
    if [[ "$EXP_TOTAL" -gt 0 ]]; then
        EXP_KEPT=$(tail -n +2 "$RESULTS_TSV" | awk -F'\t' '$7 == "kept"' | wc -l | tr -d ' ')
        EXP_DISCARDED=$(tail -n +2 "$RESULTS_TSV" | awk -F'\t' '$7 == "discarded"' | wc -l | tr -d ' ')
        EXP_CRASHED=$(tail -n +2 "$RESULTS_TSV" | awk -F'\t' '$7 == "crashed"' | wc -l | tr -d ' ')
        EXP_DECIDABLE=$((EXP_KEPT + EXP_DISCARDED))
        EXP_KEEP_RATE=""
        if [[ "$EXP_DECIDABLE" -gt 0 ]]; then
            EXP_KEEP_RATE="  ${C_DIM}·${C_NC}  $(( EXP_KEPT * 100 / EXP_DECIDABLE ))% kept"
        fi
        EXP_LINE="${EXP_TOTAL} total${EXP_KEEP_RATE}"
        if [[ "$EXP_CRASHED" -gt 0 ]]; then
            EXP_LINE="${EXP_LINE}  ${C_DIM}·${C_NC}  ${C_RED}${EXP_CRASHED} crashed${C_NC}"
        fi
        echo -e "  ${C_DIM}experiments${C_NC} ${EXP_LINE}"
    fi
fi

echo ""

# Alerts — blockers first, then warnings
HAS_ALERTS=false

if [[ -n "$INTEGRITY_WARNINGS" ]]; then
    echo -e "  ${C_RED}●${C_NC} $(echo "$INTEGRITY_WARNINGS" | head -1)"
    HAS_ALERTS=true
fi

if (( UNGRADED_COUNT > 0 )); then
    echo -e "  ${C_RED}●${C_NC} ${UNGRADED_COUNT} ungraded predictions — run /retro"
    HAS_ALERTS=true
fi

[[ -n "$STRATEGY_STALE" ]] && { echo -e "  ${C_YELLOW}⚠${C_NC} ${STRATEGY_STALE}"; HAS_ALERTS=true; }
[[ -n "$AGENT_EXP_DISPLAY" ]] && { echo -e "  ${C_YELLOW}⚠${C_NC} ${AGENT_EXP_DISPLAY}"; HAS_ALERTS=true; }

[[ "$HAS_ALERTS" == true ]] && echo ""

# --- Self-awareness recommendation (first match wins) ---
SELF_REC=""

# 1. Hooks broken?
HOOKS_BROKEN_COUNT=0
if [[ -f "$PROJECT_DIR/.claude/settings.json" ]] && command -v jq &>/dev/null; then
    # Check project-local hooks from settings.json
    while IFS= read -r hook_cmd; do
        [[ -z "$hook_cmd" ]] && continue
        [[ ! -f "$hook_cmd" ]] && HOOKS_BROKEN_COUNT=$((HOOKS_BROKEN_COUNT + 1))
    done < <(jq -r '.. | .command? // empty' "$PROJECT_DIR/.claude/settings.json" 2>/dev/null)
else
    # Fall back to global hooks dir (legacy install)
    for hook in "$HOME/.claude/hooks/"*.sh; do
        [[ ! -f "$hook" ]] && continue
        if [[ -L "$hook" ]]; then
            target=$(readlink "$hook" 2>/dev/null)
            [[ ! -f "$target" ]] && HOOKS_BROKEN_COUNT=$((HOOKS_BROKEN_COUNT + 1))
        fi
    done
fi
if [[ "$HOOKS_BROKEN_COUNT" -gt 0 ]]; then
    SELF_REC="[self] $HOOKS_BROKEN_COUNT broken hook(s) — run \`rhino self\`"
fi

# 2. Mind files missing?
if [[ -z "$SELF_REC" ]]; then
    MIND_MISSING_COUNT=0
    # Check project-local first, fall back to global
    RULES_DIR="$PROJECT_DIR/.claude/rules"
    [[ ! -d "$RULES_DIR" ]] && RULES_DIR="$HOME/.claude/rules"
    for mf in identity.md thinking.md standards.md self.md; do
        if [[ ! -L "$RULES_DIR/$mf" ]] || [[ ! -f "$RULES_DIR/$mf" ]]; then
            MIND_MISSING_COUNT=$((MIND_MISSING_COUNT + 1))
        fi
    done
    if [[ "$MIND_MISSING_COUNT" -gt 0 ]]; then
        SELF_REC="[self] $MIND_MISSING_COUNT mind file(s) not loaded — run \`rhino self\`"
    fi
fi

# 3. Prediction accuracy out of range?
if [[ -z "$SELF_REC" && -f "$PRED_FILE" ]]; then
    GRADED=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
    if [[ "$GRADED" -ge 5 ]]; then
        PCORRECT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        FLOOR=$(cfg self.prediction_accuracy_floor 0.30)
        CEILING=$(cfg self.prediction_accuracy_ceiling 0.90)
        ACC=$(awk "BEGIN { printf \"%.2f\", $PCORRECT / $GRADED }")
        if awk "BEGIN { exit !($ACC < $FLOOR) }"; then
            SELF_REC="[self] prediction accuracy ${ACC} — model may be miscalibrated"
        elif awk "BEGIN { exit !($ACC > $CEILING) }"; then
            SELF_REC="[self] prediction accuracy ${ACC} — predictions may be too safe"
        fi
    fi
fi

# 4. No predictions recently?
if [[ -z "$SELF_REC" ]]; then
    STALE_DAYS=$(cfg self.prediction_stale_days 7)
    if [[ -f "$PRED_FILE" ]]; then
        CUTOFF=$(date -v-${STALE_DAYS}d '+%Y-%m-%d' 2>/dev/null || date -d "${STALE_DAYS} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
        if [[ -n "$CUTOFF" ]]; then
            RECENT_PREDS=$(tail -n +2 "$PRED_FILE" | awk -F'\t' -v cutoff="$CUTOFF" '$1 >= cutoff { c++ } END { print c+0 }')
            MIN_PREDS=$(cfg self.min_predictions_per_week 3)
            if [[ "$RECENT_PREDS" -lt "$MIN_PREDS" ]]; then
                SELF_REC="[self] ${RECENT_PREDS} predictions in ${STALE_DAYS}d — learning loop stalled"
            fi
        fi
    else
        SELF_REC="[self] no predictions.tsv — learning loop not started"
    fi
fi

# 5. Knowledge model stale?
if [[ -z "$SELF_REC" ]]; then
    KN_STALE=$(cfg self.knowledge_stale_days 14)
    LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
    if [[ -f "$LEARNINGS" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            KN_MTIME=$(stat -f %m "$LEARNINGS" 2>/dev/null || echo 0)
        else
            KN_MTIME=$(stat -c %Y "$LEARNINGS" 2>/dev/null || echo 0)
        fi
        KN_AGE=$(( ($(date +%s) - KN_MTIME) / 86400 ))
        if [[ "$KN_AGE" -gt "$KN_STALE" ]]; then
            SELF_REC="[self] knowledge model ${KN_AGE}d old — consider /research"
        fi
    fi
fi

[[ -n "$SELF_REC" ]] && echo -e "  ${C_DIM}⚙${C_NC} ${SELF_REC#\[self\] }"

echo -e "${SEP}"
echo ""

# --- Compaction recovery ---
if [[ "$SESSION_TYPE" == "compact" ]]; then
    echo ""
    echo -e "  ${C_YELLOW}↻${C_NC} ${C_BOLD}Context compacted.${C_NC} Re-read:"
    echo -e "    ${C_DIM}1.${C_NC} mind/thinking.md"
    echo -e "    ${C_DIM}2.${C_NC} ~/.claude/knowledge/experiment-learnings.md"
    echo -e "    ${C_DIM}3.${C_NC} .claude/plans/plan.yml"
fi
