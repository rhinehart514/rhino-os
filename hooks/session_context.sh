#!/usr/bin/env bash
# session_context.sh — PreToolUse hook that injects last session context
# Fires once per session (30min cooldown), reads last session summary + active plan
# Outputs context to stdout so the model sees it as hook feedback

# MUST drain stdin first — hook protocol requires it
cat > /dev/null

CLAUDE_DIR="$HOME/.claude"
STATE_DIR="$CLAUDE_DIR/state"
KNOWLEDGE_DIR="$CLAUDE_DIR/knowledge"
MARKER="$STATE_DIR/.session-context-injected"

# Fast exit: if marker exists and is less than 30 minutes old, skip
if [[ -f "$MARKER" ]]; then
    MARKER_AGE=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || stat -c %Y "$MARKER" 2>/dev/null || echo "0") ))
    if (( MARKER_AGE < 1800 )); then
        exit 0
    fi
fi

# Create/update marker
mkdir -p "$STATE_DIR"
date +%s > "$MARKER"

# --- Detect current project ---
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# --- Assemble session context ---
CONTEXT=""

# 1. Last session summary for this project
SESSION_FILE="$KNOWLEDGE_DIR/sessions/${PROJECT_NAME}.md"
if [[ -f "$SESSION_FILE" ]]; then
    # Get last session entry (last ## block)
    LAST_SESSION=$(tail -30 "$SESSION_FILE" | tac | sed '/^## /q' | tac)
    if [[ -n "$LAST_SESSION" ]]; then
        CONTEXT+="## Last Session ($PROJECT_NAME)
$LAST_SESSION
"
    fi
fi

# 2. Active plan
PLAN_FILE="$CLAUDE_DIR/plans/active-plan.md"
if [[ -f "$PLAN_FILE" ]]; then
    # First 5 lines of the plan for quick context
    PLAN_HEADER=$(head -5 "$PLAN_FILE")
    CONTEXT+="
## Active Plan
$PLAN_HEADER
(full plan at .claude/plans/active-plan.md)
"
fi

# 3. Taste profile summary (top signals by strength)
TASTE_FILE="$KNOWLEDGE_DIR/taste.jsonl"
if [[ -f "$TASTE_FILE" ]] && command -v jq &>/dev/null; then
    STRONG_SIGNALS=$(grep '"strong"' "$TASTE_FILE" 2>/dev/null | jq -r '.signal' 2>/dev/null | head -5)
    if [[ -n "$STRONG_SIGNALS" ]]; then
        CONTEXT+="
## Founder Taste (strong signals)
$STRONG_SIGNALS
"
    fi
fi

# 4. Portfolio focus
PORTFOLIO_FILE="$KNOWLEDGE_DIR/portfolio.json"
if [[ -f "$PORTFOLIO_FILE" ]] && command -v jq &>/dev/null; then
    FOCUS=$(jq -r '.focus.primary // empty' "$PORTFOLIO_FILE" 2>/dev/null)
    if [[ -n "$FOCUS" ]]; then
        CONTEXT+="
## Portfolio Focus: $FOCUS
"
    fi
fi

# 5. Sweep state (if recent)
SWEEP_FILE="$STATE_DIR/sweep-latest.md"
if [[ -f "$SWEEP_FILE" ]]; then
    SWEEP_AGE=$(( ( $(date +%s) - $(stat -f %m "$SWEEP_FILE" 2>/dev/null || stat -c %Y "$SWEEP_FILE" 2>/dev/null || echo "0") ) / 3600 ))
    if (( SWEEP_AGE < 48 )); then
        SWEEP_HEADER=$(head -3 "$SWEEP_FILE")
        CONTEXT+="
## Recent Sweep (${SWEEP_AGE}h ago)
$SWEEP_HEADER
"
    fi
fi

# Only output if we have meaningful context
if [[ -n "$CONTEXT" ]]; then
    echo "--- rhino-os session context ---"
    echo "$CONTEXT"
    echo "--- end session context ---"
fi

exit 0
