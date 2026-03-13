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
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]] && command -v jq &>/dev/null; then
    TOTAL=$(jq -r '.total // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    BUILD=$(jq -r '.build // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    STRUCT=$(jq -r '.structure // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    HYGIENE=$(jq -r '.hygiene // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    SCORE_DISPLAY="Score: ${TOTAL}/100 (Build:${BUILD} Struct:${STRUCT} Hygiene:${HYGIENE})"

    # Surface integrity warnings
    WARNINGS_JSON=$(jq -r '.integrity_warnings // [] | .[]' "$SCORE_CACHE" 2>/dev/null || true)
    if [[ -n "$WARNINGS_JSON" ]]; then
        INTEGRITY_WARNINGS="$WARNINGS_JSON"
    fi
fi

# --- Active plan ---
PLAN_FILE=""
for p in "$PROJECT_DIR/.claude/plans/active-plan.md" "$HOME/.claude/plans/active-plan.md"; do
    if [[ -f "$p" ]]; then PLAN_FILE="$p"; break; fi
done

TASKS_REMAINING=0
NEXT_TASK=""
PLAN_STALE=""
if [[ -n "$PLAN_FILE" ]]; then
    TOTAL_TASKS=$(grep -c '^\- \[' "$PLAN_FILE" 2>/dev/null || echo 0)
    DONE_TASKS=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
    TASKS_REMAINING=$((TOTAL_TASKS - DONE_TASKS))
    NEXT_TASK=$(grep -m1 '^\- \[ \]' "$PLAN_FILE" 2>/dev/null | sed 's/^- \[ \] //' || true)

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
PRODUCT_MODEL="$PROJECT_DIR/.claude/plans/product-model.md"
if [[ -f "$PRODUCT_MODEL" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        STRAT_MTIME=$(stat -f %m "$PRODUCT_MODEL" 2>/dev/null || echo 0)
    else
        STRAT_MTIME=$(stat -c %Y "$PRODUCT_MODEL" 2>/dev/null || echo 0)
    fi
    NOW=${NOW:-$(date +%s)}
    STRAT_AGE_DAYS=$(( (NOW - STRAT_MTIME) / 86400 ))
    if (( STRAT_AGE_DAYS > 3 )); then
        STRATEGY_STALE="Strategy: ${STRAT_AGE_DAYS}d old — stale"
    fi
fi

# --- Assertion status (value signal) ---
ASSERT_DISPLAY=""
BELIEFS_FILE="$PROJECT_DIR/config/evals/beliefs.yml"
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
        # Count correct predictions (column 6) in last 10
        CORRECT=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        FILLED=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$6 != "" { c++ } END { print c+0 }')
        # Count all ungraded (column 6 empty)
        UNGRADED_COUNT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "" { c++ } END { print c+0 }')
        if (( FILLED > 0 )); then
            PRED_DISPLAY="Predictions: ${CORRECT}/${FILLED} correct"
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

echo ""
echo -e "  ${C_CYAN}◆${C_NC} ${C_BOLD}rhino-os${C_NC}"
echo ""

# Project + score line
if [[ -n "$SCORE_DISPLAY" ]]; then
    echo -e "  ${C_DIM}project${C_NC}  ${PROJECT_NAME}"
    # Parse score components for formatted display
    echo -e "  ${C_DIM}score${C_NC}    ${C_BOLD}${TOTAL}/100${C_NC}  ${C_DIM}build ${BUILD} · struct ${STRUCT} · hygiene ${HYGIENE}${C_NC}"
else
    echo -e "  ${C_DIM}project${C_NC}  ${PROJECT_NAME}"
    echo -e "  ${C_DIM}score${C_NC}    ${C_DIM}none yet — run:${C_NC} rhino score ."
fi

# Plan
if [[ -n "$PLAN_FILE" && "$TASKS_REMAINING" -gt 0 ]]; then
    PLAN_LINE="  ${C_DIM}plan${C_NC}     ${TASKS_REMAINING} tasks remaining"
    [[ -n "$PLAN_STALE" ]] && PLAN_LINE="${PLAN_LINE}  ${C_YELLOW}${PLAN_STALE}${C_NC}"
    echo -e "$PLAN_LINE"
    [[ -n "$NEXT_TASK" ]] && echo -e "  ${C_DIM}next${C_NC}     ${C_GREEN}▸${C_NC} ${NEXT_TASK}"
fi

# Signals line (assertions + predictions)
SIGNALS=""
[[ -n "$ASSERT_DISPLAY" ]] && SIGNALS="${ASSERT_DISPLAY}"
[[ -n "$PRED_DISPLAY" ]] && SIGNALS="${SIGNALS:+$SIGNALS · }$PRED_DISPLAY"
[[ -n "$SIGNALS" ]] && echo -e "  ${C_DIM}signals${C_NC}  ${SIGNALS}"

echo ""

# Alerts (integrity, strategy, ungraded)
if [[ -n "$INTEGRITY_WARNINGS" ]]; then
    echo -e "  ${C_YELLOW}⚠${C_NC} ${C_YELLOW}$(echo "$INTEGRITY_WARNINGS" | head -1)${C_NC}"
fi
[[ -n "$STRATEGY_STALE" ]] && echo -e "  ${C_YELLOW}⚠${C_NC} ${STRATEGY_STALE}"
if (( UNGRADED_COUNT > 0 )); then
    echo -e "  ${C_RED}●${C_NC} ${UNGRADED_COUNT} ungraded prediction(s) — grade before starting new work"
fi
[[ -n "$AGENT_EXP_DISPLAY" ]] && echo -e "  ${C_YELLOW}⚙${C_NC} ${AGENT_EXP_DISPLAY}"

# --- Self-awareness recommendation (first match wins) ---
SELF_REC=""

# 1. Hooks broken?
HOOKS_BROKEN_COUNT=0
for hook in "$HOME/.claude/hooks/"*.sh; do
    [[ ! -f "$hook" ]] && continue
    if [[ -L "$hook" ]]; then
        target=$(readlink "$hook" 2>/dev/null)
        [[ ! -f "$target" ]] && HOOKS_BROKEN_COUNT=$((HOOKS_BROKEN_COUNT + 1))
    fi
done
if [[ "$HOOKS_BROKEN_COUNT" -gt 0 ]]; then
    SELF_REC="[self] $HOOKS_BROKEN_COUNT broken hook(s) — run \`rhino self\`"
fi

# 2. Mind files missing?
if [[ -z "$SELF_REC" ]]; then
    MIND_MISSING_COUNT=0
    for mf in identity.md thinking.md standards.md self.md; do
        if [[ ! -L "$HOME/.claude/rules/$mf" ]] || [[ ! -f "$HOME/.claude/rules/$mf" ]]; then
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

# --- Compaction recovery ---
if [[ "$SESSION_TYPE" == "compact" ]]; then
    echo ""
    echo -e "  ${C_YELLOW}↻${C_NC} ${C_BOLD}Context compacted.${C_NC} Re-read:"
    echo -e "    ${C_DIM}1.${C_NC} mind/thinking.md"
    echo -e "    ${C_DIM}2.${C_NC} ~/.claude/knowledge/experiment-learnings.md"
    echo -e "    ${C_DIM}3.${C_NC} .claude/plans/active-plan.md"
fi
