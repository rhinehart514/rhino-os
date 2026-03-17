#!/usr/bin/env bash
# user_prompt_submit.sh — UserPromptSubmit hook (BLOCKING, always allows)
# Deterministic intent routing. Pattern matches user prompt against the intent table.
# Target: <10ms (pure string matching, no file I/O).

set -euo pipefail

INPUT=$(cat)

# --- Parse prompt from input JSON ---
PROMPT=""
if command -v jq &>/dev/null; then
    PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
else
    PROMPT=$(echo "$INPUT" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"prompt"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || echo "")
fi

# Skip if already a slash command
if [[ "$PROMPT" == /* ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Skip if too long (not a natural language intent)
if [[ ${#PROMPT} -gt 200 ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Lowercase for matching
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

SUGGESTION=""
case "$LOWER" in
    *"is this good"*|*"evaluate"*|*"how's the product"*|*"how is the product"*|*"run assertions"*|*"check quality"*)
        SUGGESTION="/eval" ;;
    *"what does it look like"*|*"visual eval"*|*"design quality"*|*"how's the ui"*|*"how is the ui"*)
        SUGGESTION="/taste" ;;
    *"what should i work on"*|*"what should we work on"*|*"start a session"*|*"what's the bottleneck"*|*"what is the bottleneck"*)
        SUGGESTION="/plan" ;;
    *"just build it"*|*"autonomous"*)
        SUGGESTION="/go" ;;
    *"set this up"*|*"bootstrap"*|*"initialize"*|*"onboard"*|*"new here"*|*"what is this project"*)
        SUGGESTION="/onboard" ;;
    *"what features"*|*"list features"*|*"how's auth"*|*"how is auth"*)
        SUGGESTION="/feature" ;;
    *"brainstorm"*|*"feature ideas"*)
        SUGGESTION="/ideate" ;;
    *"what don't we know"*|*"what do we not know"*|*"explore"*|*"gather data"*)
        SUGGESTION="/research" ;;
    *"where are we"*|*"dashboard"*)
        SUGGESTION="/rhino" ;;
    *"what's the roadmap"*|*"what is the roadmap"*|*"versions"*|*"what's next for the project"*)
        SUGGESTION="/roadmap" ;;
    *"deploy"*|*"ship it"*|*"push"*)
        SUGGESTION="/ship" ;;
    *"what did we learn"*|*"retro"*|*"grade predictions"*)
        SUGGESTION="/retro" ;;
    *"add a test"*|*"assert"*|*"this should be true"*)
        SUGGESTION="/assert" ;;
    *"what's the strategy"*|*"what is the strategy"*|*"what stage"*)
        SUGGESTION="/strategy" ;;
    *"backlog"*|*"todo"*|*"capture this"*|*"add to backlog"*)
        SUGGESTION="/todo" ;;
    *"clone this"*|*"screenshot"*|*"make it look like"*)
        SUGGESTION="/clone" ;;
    *"create a skill"*|*"new lens"*|*"manage lenses"*)
        SUGGESTION="/skill" ;;
    *"is this the right thing"*|*"product thinking"*|*"who cares"*|*"assumptions"*|*"should we build this"*)
        SUGGESTION="/product" ;;
esac

if [[ -n "$SUGGESTION" ]]; then
    echo "{\"decision\": \"allow\", \"additionalContext\": \"The user likely wants ${SUGGESTION}. Run it.\"}"
else
    echo '{"decision": "allow"}'
fi
