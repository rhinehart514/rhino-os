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
    # Get last session entry (last ## block) — no tac on macOS
    LAST_SESSION=$(tail -30 "$SESSION_FILE" | awk '/^## /{buf=""} {buf=buf"\n"$0} END{print buf}')
    if [[ -n "$LAST_SESSION" ]]; then
        CONTEXT+="## Last Session ($PROJECT_NAME)
$LAST_SESSION
"
    fi
fi

# 2. Active plan (check project-local first, then global)
PLAN_FILE=""
for plan_path in \
    "$PROJECT_DIR/.claude/plans/active-plan.md" \
    "$CLAUDE_DIR/plans/active-plan.md"; do
    if [[ -f "$plan_path" ]]; then
        PLAN_FILE="$plan_path"
        break
    fi
done
if [[ -n "$PLAN_FILE" ]]; then
    # First 5 lines of the plan for quick context
    PLAN_HEADER=$(head -5 "$PLAN_FILE")
    CONTEXT+="
## Active Plan
$PLAN_HEADER
(full plan at $PLAN_FILE)
"
fi

# 2b. Latest taste eval (visual product quality — feeds into builder)
TASTE_REPORT=""
for taste_dir in "$PROJECT_DIR/.claude/evals/reports" "$PROJECT_DIR/docs/evals/reports"; do
    if [[ -d "$taste_dir" ]]; then
        TASTE_REPORT=$(ls -t "$taste_dir"/taste-*.json 2>/dev/null | head -1)
        [[ -n "$TASTE_REPORT" ]] && break
    fi
done
if [[ -n "$TASTE_REPORT" ]] && command -v jq &>/dev/null; then
    taste_score=$(jq -r '.score_100 // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_weakest=$(jq -r '.weakest_dimension // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_one_thing=$(jq -r '.one_thing // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_return=$(jq -r '.would_return // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_recommend=$(jq -r '.would_recommend // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_date=$(jq -r '.meta.timestamp // empty' "$TASTE_REPORT" 2>/dev/null | head -c10)
    if [[ -n "$taste_score" ]]; then
        CONTEXT+="
## Taste Eval ($taste_date): ${taste_score}/100"
        [[ -n "$taste_weakest" ]] && CONTEXT+=" · weakest: $taste_weakest"
        [[ -n "$taste_return" ]] && CONTEXT+="
Return? $taste_return"
        [[ -n "$taste_recommend" ]] && CONTEXT+="
Recommend? $taste_recommend"
        [[ -n "$taste_one_thing" ]] && CONTEXT+="
One thing: $taste_one_thing"

        # Taste trend from taste-history.tsv
        TASTE_HISTORY=""
        for th_dir in "$PROJECT_DIR/.claude/evals" "$PROJECT_DIR/docs/evals"; do
            if [[ -f "$th_dir/taste-history.tsv" ]]; then
                TASTE_HISTORY="$th_dir/taste-history.tsv"
                break
            fi
        done
        if [[ -n "$TASTE_HISTORY" ]]; then
            taste_eval_count=$(tail -n +2 "$TASTE_HISTORY" | grep -cv '^$' 2>/dev/null || echo "0")
            if [[ "$taste_eval_count" -gt 1 ]]; then
                # Compare first and last overall scores to determine direction
                first_overall=$(tail -n +2 "$TASTE_HISTORY" | head -1 | cut -f2)
                last_overall=$(tail -1 "$TASTE_HISTORY" | cut -f2)
                if [[ -n "$first_overall" && -n "$last_overall" ]]; then
                    if awk "BEGIN { exit !($last_overall > $first_overall) }" 2>/dev/null; then
                        taste_direction="improving"
                    elif awk "BEGIN { exit !($last_overall < $first_overall) }" 2>/dev/null; then
                        taste_direction="declining"
                    else
                        taste_direction="flat"
                    fi
                    CONTEXT+="
Taste trend: $taste_direction ($taste_eval_count evals, $first_overall -> $last_overall)"
                fi
            fi

            # Show weakest feature if features.yml exists
            FEATURES_YML=""
            for fy in "$PROJECT_DIR/.claude/features.yml" "$PROJECT_DIR/.claude/features.yaml"; do
                [[ -f "$fy" ]] && FEATURES_YML="$fy" && break
            done
            if [[ -n "$FEATURES_YML" ]]; then
                # Get the most recent feature-specific eval (non-"all")
                weakest_feature=$(tail -n +2 "$TASTE_HISTORY" | awk -F'\t' '$5 != "all" && $5 != "" {print $5, $2}' | sort -k2 -n | head -1 | cut -d' ' -f1)
                if [[ -n "$weakest_feature" ]]; then
                    CONTEXT+="
Weakest feature: $weakest_feature"
                fi
            fi
        fi

        CONTEXT+="
"
    fi
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

# 5b. Agent Suggestions — show each agent's next_move
BRAINS_DIR="$STATE_DIR/brains"
if [[ -d "$BRAINS_DIR" ]] && command -v jq &>/dev/null; then
    SUGGESTIONS=""
    LATEST_TS="0"
    for brain_file in "$BRAINS_DIR"/*.json; do
        [[ ! -f "$brain_file" ]] && continue
        ba=$(jq -r '.agent // ""' "$brain_file" 2>/dev/null)
        baction=$(jq -r '.next_move // "" | if type == "object" then .action // "" else . end' "$brain_file" 2>/dev/null || true)
        bupdated=$(jq -r '.updated // ""' "$brain_file" 2>/dev/null || true)
        if [[ -n "$baction" && "$baction" != "null" && "$baction" != "" ]]; then
            SUGGESTIONS+="- ${ba}: ${baction}
"
        fi
    done
    if [[ -n "$SUGGESTIONS" ]]; then
        CONTEXT+="
## Agent Suggestions
${SUGGESTIONS}"
    fi
fi

# 6. Eval state — check project-local eval history first, then global
EVAL_HISTORY=""
for eval_path in \
    "$PROJECT_DIR/.claude/evals/reports/history.jsonl" \
    "$PROJECT_DIR/docs/evals/reports/history.jsonl" \
    "$CLAUDE_DIR/evals/reports/history.jsonl"; do
    if [[ -f "$eval_path" ]]; then
        EVAL_HISTORY="$eval_path"
        break
    fi
done

if [[ -n "$EVAL_HISTORY" ]] && command -v jq &>/dev/null; then
    # Get latest eval entry
    LATEST_EVAL=$(tail -1 "$EVAL_HISTORY")
    if [[ -n "$LATEST_EVAL" ]]; then
        eval_verdict=$(echo "$LATEST_EVAL" | jq -r '.verdict // empty' 2>/dev/null)
        eval_feature=$(echo "$LATEST_EVAL" | jq -r '.feature // empty' 2>/dev/null)
        eval_date=$(echo "$LATEST_EVAL" | jq -r '.date // empty' 2>/dev/null)
        eval_type=$(echo "$LATEST_EVAL" | jq -r '.type // "feature-eval"' 2>/dev/null)

        if [[ -n "$eval_verdict" ]]; then
            CONTEXT+="
## Latest Eval ($eval_date)
$eval_feature · $eval_verdict"

            # For product evals, show key scores dynamically
            if [[ "$eval_type" == "product-eval" ]]; then
                overall=$(echo "$LATEST_EVAL" | jq -r '.overall // empty' 2>/dev/null)
                CONTEXT+=" · overall: $overall"
                # Show lowest-scoring dimensions (the bottlenecks)
                lowest=$(echo "$LATEST_EVAL" | jq -r 'to_entries | map(select(.value | type == "number" and . <= 1 and . >= 0)) | map(select(.key | IN("date","overall","type","feature") | not)) | sort_by(.value) | .[0:3] | map("\(.key): \(.value)") | join(" · ")' 2>/dev/null)
                [[ -n "$lowest" ]] && CONTEXT+=" · $lowest"
            else
                ceiling=$(echo "$LATEST_EVAL" | jq -r '.ceiling // empty' 2>/dev/null)
                [[ -n "$ceiling" ]] && CONTEXT+=" · ceiling: $ceiling"
            fi

            # Show top gaps (the most important part — what to fix)
            top_gaps=$(echo "$LATEST_EVAL" | jq -r '(.top_gaps // .ceiling_gaps // [])[:3][]' 2>/dev/null)
            if [[ -n "$top_gaps" ]]; then
                CONTEXT+="
Gaps: $top_gaps"
            fi
            CONTEXT+="
"
        fi
    fi
fi

# 7. Active experiments — show branches and recent results
EXP_BRANCHES=$(git -C "$PROJECT_DIR" branch 2>/dev/null | grep 'exp/' | sed 's/^[* ]*//' | head -5)
if [[ -n "$EXP_BRANCHES" ]]; then
    CONTEXT+="
## Active Experiments"
    while read -r branch; do
        commit_count=$(git -C "$PROJECT_DIR" rev-list --count "main..$branch" 2>/dev/null || echo "?")
        CONTEXT+="
$branch ($commit_count commits)"
    done <<< "$EXP_BRANCHES"
    CONTEXT+="
"
fi

# Check for experiment TSVs
for exp_dir in "$PROJECT_DIR/.claude/experiments" "$PROJECT_DIR/docs/experiments"; do
    if [[ -d "$exp_dir" ]]; then
        for tsv in "$exp_dir"/*.tsv; do
            [[ -f "$tsv" ]] || continue
            ename=$(basename "$tsv" .tsv)
            ekept=$(grep -c 'keep' "$tsv" 2>/dev/null || echo "0")
            etotal=$(tail -n +2 "$tsv" | grep -cv '^---\|^$' 2>/dev/null || echo "0")
            elast=$(tail -1 "$tsv" | cut -f4-5 2>/dev/null)
            CONTEXT+="
## Experiment: $ename — $ekept/$etotal kept, last: $elast"
        done
        break
    fi
done

# 8. Score integrity warnings (from last score run)
for cache_path in "$PROJECT_DIR/.claude/cache/score-cache.json"; do
    if [[ -f "$cache_path" ]] && command -v jq &>/dev/null; then
        warnings=$(jq -r '.integrity_warnings // [] | .[]' "$cache_path" 2>/dev/null)
        if [[ -n "$warnings" ]]; then
            CONTEXT+="
## Score Integrity Warnings
$warnings
Scores are diagnostic instruments, not goals. Address warnings before chasing numbers.
"
        fi
    fi
done

# Only output if we have meaningful context
if [[ -n "$CONTEXT" ]]; then
    echo "--- rhino-os session context ---"
    echo "$CONTEXT"
    echo "--- end session context ---"
fi

exit 0
