#!/usr/bin/env bash
# opportunity-scan.sh — Surfaces opportunities the founder isn't seeing.
# Runs as part of /plan and session_start. Cross-references multiple sources.
# Output: structured opportunities, ranked by information value.
set -uo pipefail

PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
NOW=$(date +%s)

# Check dependencies
source "$RHINO_DIR/bin/lib/check-deps.sh"
require_cmd python3 "brew install python3"

echo "=== OPPORTUNITIES ==="
echo ""

# --- 1. Unknown Territory (highest information value) ---
LEARNINGS="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
[[ ! -f "$LEARNINGS" ]] && LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]]; then
    UNKNOWNS=$(awk '/^## Unknown Territory/,/^## /{if(/^## / && !/Unknown/) exit; if(/^\s*-/) print}' "$LEARNINGS" 2>/dev/null | head -5)
    if [[ -n "$UNKNOWNS" ]]; then
        UNKNOWN_CT=$(echo "$UNKNOWNS" | wc -l | tr -d ' ')
        echo "▸ UNEXPLORED: $UNKNOWN_CT unknowns — one experiment here teaches more than 10 in known territory"
        echo "$UNKNOWNS" | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
    fi
fi

# --- 2. Wrong predictions (model is broken here) ---
PRED_FILE="$PROJECT_DIR/.claude/knowledge/predictions.tsv"
[[ ! -f "$PRED_FILE" ]] && PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    WRONG=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "no"' | tail -5)
    if [[ -n "$WRONG" ]]; then
        WRONG_CT=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 == "no"' | wc -l | tr -d ' ')
        echo "▸ BLIND SPOTS: $WRONG_CT wrong predictions — your model is broken in these areas:"
        echo "$WRONG" | while IFS=$'\t' read -r date pred evidence result correct update; do
            echo "  · $pred"
            [[ -n "$update" ]] && echo "    → $update"
        done
        echo ""
    fi
fi

# --- 3. Dead ends worth retrying (conditions may have changed) ---
if [[ -f "$LEARNINGS" ]]; then
    DEAD_ENDS=$(awk '/^## Dead Ends/,/^## /{if(/^## / && !/Dead/) exit; if(/^\s*-\s*\*\*/) print}' "$LEARNINGS" 2>/dev/null)
    if [[ -n "$DEAD_ENDS" ]]; then
        # Check if any dead end is >30 days old (conditions may have changed)
        echo "▸ WORTH RETRYING? Dead ends that may have changed:"
        echo "$DEAD_ENDS" | head -3 | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
    fi
fi

# --- 4. Market signals (if market-context.json exists and is fresh) ---
MARKET="$PROJECT_DIR/.claude/cache/market-context.json"
if [[ -f "$MARKET" ]] && command -v jq &>/dev/null; then
    # Check freshness
    if [[ "$(uname)" == "Darwin" ]]; then
        MARKET_MTIME=$(stat -f %m "$MARKET" 2>/dev/null || echo 0)
    else
        MARKET_MTIME=$(stat -c %Y "$MARKET" 2>/dev/null || echo 0)
    fi
    MARKET_AGE=$(( (NOW - MARKET_MTIME) / 86400 ))
    if [[ "$MARKET_AGE" -lt 7 ]]; then
        SIGNALS=$(jq -r '.signals[]? // empty' "$MARKET" 2>/dev/null | head -3)
        if [[ -n "$SIGNALS" ]]; then
            echo "▸ MARKET SIGNALS (${MARKET_AGE}d fresh):"
            echo "$SIGNALS" | while IFS= read -r sig; do
                echo "  · $sig"
            done
            echo ""
        fi
    else
        echo "▸ STALE MARKET DATA: market-context.json is ${MARKET_AGE}d old. Run /research market to refresh."
        echo ""
    fi
else
    echo "▸ NO MARKET DATA: run /research market to discover opportunities you can't see from inside the codebase."
    echo ""
fi

# --- 5. Customer signals (if customer-intel.json exists) ---
CUST="$PROJECT_DIR/.claude/cache/customer-intel.json"
if [[ -f "$CUST" ]] && command -v jq &>/dev/null; then
    DEMANDS=$(jq -r '.demand_signals[]? // empty' "$CUST" 2>/dev/null | head -3)
    UNMET=$(jq -r '.unmet_needs[]? // empty' "$CUST" 2>/dev/null | head -3)
    if [[ -n "$DEMANDS" || -n "$UNMET" ]]; then
        echo "▸ CUSTOMER SIGNALS:"
        [[ -n "$DEMANDS" ]] && echo "$DEMANDS" | while IFS= read -r d; do echo "  demand: $d"; done
        [[ -n "$UNMET" ]] && echo "$UNMET" | while IFS= read -r u; do echo "  unmet: $u"; done
        echo ""
    fi
else
    echo "▸ NO CUSTOMER DATA: run /research or spawn customer agent to discover demand signals."
    echo ""
fi

# --- 6. Unproven roadmap evidence (what you're avoiding) ---
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"
if [[ -f "$ROADMAP" ]]; then
    # Find current version's todo evidence
    CURRENT=$(grep '^current:' "$ROADMAP" | sed 's/current: *//')
    if [[ -n "$CURRENT" ]]; then
        TODO_EVIDENCE=$(awk "/^  ${CURRENT}:/,/^  v[0-9]/" "$ROADMAP" 2>/dev/null | grep 'status: todo' -B1 | grep 'question:' | sed 's/.*question: *"/  · /' | sed 's/"//' | head -3)
        if [[ -n "$TODO_EVIDENCE" ]]; then
            TODO_CT=$(echo "$TODO_EVIDENCE" | wc -l | tr -d ' ')
            echo "▸ THESIS EVIDENCE UNPROVEN ($TODO_CT items in $CURRENT):"
            echo "$TODO_EVIDENCE"
            echo ""
        fi
    fi
fi

# --- 7. Features scoring 50+ but unused externally ---
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
if [[ -f "$EVAL_CACHE" ]] && command -v jq &>/dev/null; then
    WORKING=$(jq -r 'to_entries[] | select(.value.score >= 50 and .value.score != null) | "\(.key): \(.value.score)"' "$EVAL_CACHE" 2>/dev/null)
    if [[ -n "$WORKING" ]]; then
        WORKING_CT=$(echo "$WORKING" | wc -l | tr -d ' ')
        echo "▸ WORKING FEATURES ($WORKING_CT scoring 50+) — are real users benefiting from these?"
        echo "$WORKING" | while IFS= read -r f; do echo "  · $f"; done
        echo ""
    fi
fi

# --- 8. Skills/capabilities never used ---
LOG_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/data/rhino-os}"
if [[ -d "$LOG_DIR" ]]; then
    # Check which logs exist (indicates which skills have been used)
    USED=""
    [[ -f "$LOG_DIR/ideation-log.jsonl" ]] && USED="$USED ideate"
    [[ -f "$LOG_DIR/build-log.jsonl" ]] && USED="$USED go"
    [[ -f "$LOG_DIR/ship-log.jsonl" ]] && USED="$USED ship"
    [[ -f "$LOG_DIR/retro-log.jsonl" ]] && USED="$USED retro"
    [[ -f "$LOG_DIR/research-log.jsonl" ]] && USED="$USED research"
    [[ -f "$LOG_DIR/copy-log.jsonl" ]] && USED="$USED copy"

    NEVER_USED=""
    for skill in ideate go ship retro research copy; do
        echo "$USED" | grep -q "$skill" || NEVER_USED="$NEVER_USED $skill"
    done
    if [[ -n "$NEVER_USED" ]]; then
        echo "▸ UNUSED CAPABILITIES: these skills have persistent logs but you've never used them:"
        echo " $NEVER_USED"
        echo ""
    fi
fi

# --- 9. Stale strategy ---
STRATEGY="$PROJECT_DIR/.claude/plans/strategy.yml"
if [[ -f "$STRATEGY" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        STRAT_MTIME=$(stat -f %m "$STRATEGY" 2>/dev/null || echo 0)
    else
        STRAT_MTIME=$(stat -c %Y "$STRATEGY" 2>/dev/null || echo 0)
    fi
    STRAT_AGE=$(( (NOW - STRAT_MTIME) / 86400 ))
    if [[ "$STRAT_AGE" -gt 3 ]]; then
        echo "▸ STALE STRATEGY: ${STRAT_AGE}d since last /strategy. The market moved. Your assumptions may be wrong."
        echo ""
    fi
fi

echo "=== END OPPORTUNITIES ==="
