# grade-consolidation.sh — Knowledge consolidation + staleness detection
#
# Functions: consolidate_knowledge, detect_stale_entries
#
# Requires: PROJECT_DIR, PRED_FILE, QUIET (set by parent grade.sh)

# --- Consolidate knowledge: append model_updates to experiment-learnings.md ---
consolidate_knowledge() {
    local learnings_file="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && learnings_file="$HOME/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && return 0

    # Collect new updates by zone: known, uncertain, dead_end
    local known_entries="" uncertain_entries="" dead_entries=""
    local consolidated=0

    while IFS=$'\t' read -r _date _agent _prediction _evidence _result _correct model_update; do
        [[ -z "$model_update" ]] && continue
        [[ -z "$_correct" ]] && continue

        # Deduplicate: skip if first 60 chars already present (normalized)
        local dedup_key="${model_update:0:60}"
        dedup_key=$(echo "$dedup_key" | tr -s ' ')  # normalize whitespace
        if grep -qF "$dedup_key" "$learnings_file" 2>/dev/null; then
            continue
        fi

        local entry="- **Auto-graded** (${_date}): ${model_update}"

        # Route to correct zone based on grading result
        case "$_correct" in
            yes)
                # Count how many similar entries already exist in Known Patterns
                local known_count=0
                # Extract a keyword from the prediction for matching (first 3+ char word)
                local keyword=""
                if [[ "$_prediction" =~ ([a-zA-Z_-]{4,}) ]]; then
                    keyword="${BASH_REMATCH[1]}"
                fi
                if [[ -n "$keyword" ]]; then
                    # Count entries in Known Patterns section that reference this keyword
                    known_count=$(awk '/^## Known Patterns/,/^## [A-Z]/' "$learnings_file" | grep -ciF "$keyword" 2>/dev/null || echo "0")
                fi
                if [[ "$known_count" -ge 2 ]]; then
                    # 2+ existing matches + this new one = 3+ → Known Patterns
                    known_entries="${known_entries}\n${entry}"
                else
                    # <3 matching entries → Uncertain Patterns
                    uncertain_entries="${uncertain_entries}\n${entry}"
                fi
                ;;
            no)
                # Check if this is a repeated failure (dead end candidate)
                local fail_count=0
                local fail_keyword=""
                if [[ "$_prediction" =~ ([a-zA-Z_-]{4,}) ]]; then
                    fail_keyword="${BASH_REMATCH[1]}"
                fi
                if [[ -n "$fail_keyword" ]]; then
                    fail_count=$(awk '/^## Dead Ends/,0' "$learnings_file" | grep -ciF "$fail_keyword" 2>/dev/null || echo "0")
                fi
                if [[ "$fail_count" -ge 1 ]]; then
                    # Already a dead end entry → add to Dead Ends
                    dead_entries="${dead_entries}\n${entry}"
                else
                    # First failure → Uncertain Patterns (might be noise)
                    uncertain_entries="${uncertain_entries}\n${entry}"
                fi
                ;;
            partial)
                # Partial results always go to Uncertain Patterns
                uncertain_entries="${uncertain_entries}\n${entry}"
                ;;
        esac
        consolidated=$((consolidated + 1))
    done < <(tail -n +2 "$PRED_FILE")

    [[ "$consolidated" -eq 0 ]] && return 0

    # Insert entries into their correct zones
    local temp_learnings
    temp_learnings=$(mktemp)
    local inserted_known=false inserted_uncertain=false inserted_dead=false

    while IFS= read -r line; do
        # Insert known entries before "## Uncertain Patterns"
        if [[ "$line" == "## Uncertain Patterns"* ]] && ! $inserted_known && [[ -n "$known_entries" ]]; then
            printf "%b\n\n" "$known_entries" >> "$temp_learnings"
            inserted_known=true
        fi
        # Insert uncertain entries before "## Unknown Territory"
        if [[ "$line" == "## Unknown Territory"* ]] && ! $inserted_uncertain && [[ -n "$uncertain_entries" ]]; then
            printf "%b\n\n" "$uncertain_entries" >> "$temp_learnings"
            inserted_uncertain=true
        fi
        # Insert dead end entries before end-of-file (after "## Dead Ends" section heading)
        if [[ "$line" == "## Dead Ends"* ]] && ! $inserted_dead && [[ -n "$dead_entries" ]]; then
            printf "%s\n" "$line" >> "$temp_learnings"
            # Read next line (usually blank or first entry) then insert
            printf "%b\n" "$dead_entries" >> "$temp_learnings"
            inserted_dead=true
            continue
        fi
        printf "%s\n" "$line" >> "$temp_learnings"
    done < "$learnings_file"

    # Fallback: if sections weren't found, append at end
    if [[ -n "$known_entries" ]] && ! $inserted_known; then
        printf "\n%b\n" "$known_entries" >> "$temp_learnings"
    fi
    if [[ -n "$uncertain_entries" ]] && ! $inserted_uncertain; then
        printf "\n%b\n" "$uncertain_entries" >> "$temp_learnings"
    fi
    if [[ -n "$dead_entries" ]] && ! $inserted_dead; then
        printf "\n%b\n" "$dead_entries" >> "$temp_learnings"
    fi

    mv "$temp_learnings" "$learnings_file"
    $QUIET || echo "Consolidated $consolidated learning(s) into experiment-learnings.md"
}

# --- Staleness detection: flag entries not referenced by predictions in 30+ days ---
detect_stale_entries() {
    local learnings_file="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && learnings_file="$HOME/.claude/knowledge/experiment-learnings.md"
    [[ ! -f "$learnings_file" ]] && return 0

    local stale_days=30
    local cutoff_date
    cutoff_date=$(date -v-${stale_days}d '+%Y-%m-%d' 2>/dev/null || date -d "${stale_days} days ago" '+%Y-%m-%d' 2>/dev/null || echo "")
    [[ -z "$cutoff_date" ]] && return 0

    # Extract dated entries and check which are stale
    local stale_entries=0
    local total_dated=0
    local stale_list=""

    while IFS= read -r entry_line; do
        local entry_date=""
        if [[ "$entry_line" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            entry_date="${BASH_REMATCH[1]}"
        else
            continue
        fi
        total_dated=$((total_dated + 1))

        if [[ "$entry_date" < "$cutoff_date" ]]; then
            # Check if any recent prediction references this entry
            local entry_snippet="${entry_line:0:60}"
            entry_snippet="${entry_snippet//\"/}"
            local referenced=false
            if [[ -f "$PRED_FILE" ]]; then
                if tail -n +2 "$PRED_FILE" | awk -F'\t' -v cutoff="$cutoff_date" '$1 >= cutoff' | grep -qiF "${entry_snippet:0:25}" 2>/dev/null; then
                    referenced=true
                fi
            fi
            if [[ "$referenced" == "false" ]]; then
                stale_entries=$((stale_entries + 1))
                local display="${entry_line:0:80}"
                stale_list="${stale_list}\n    ${display}..."
            fi
        fi
    done < <(grep '^\s*-\s.*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$learnings_file" 2>/dev/null)

    if [[ "$stale_entries" -gt 0 ]]; then
        $QUIET || echo ""
        $QUIET || echo "Stale knowledge: ${stale_entries} entries not referenced in ${stale_days}d"
        if [[ "$QUIET" == false && -n "$stale_list" ]]; then
            echo -e "$stale_list" | head -5
            [[ "$stale_entries" -gt 5 ]] && echo "    ... and $((stale_entries - 5)) more. Run /retro to prune."
        fi

        # Demote stale Known Patterns → Uncertain Patterns
        # Only demote entries in Known Patterns section that are stale
        local known_section=""
        known_section=$(awk '/^## Known Patterns/,/^## [A-Z]/' "$learnings_file" 2>/dev/null)
        local demoted=0
        while IFS= read -r stale_line; do
            stale_line="${stale_line#    }"  # strip leading spaces from stale_list
            [[ -z "$stale_line" ]] && continue
            # Check if this stale entry is in Known Patterns
            local snippet="${stale_line:0:40}"
            if echo "$known_section" | grep -qF "$snippet" 2>/dev/null; then
                # Mark as stale in-place (non-destructive — /retro can fully prune)
                if [[ "$stale_line" != *"(stale)"* ]]; then
                    local escaped_snippet
                    escaped_snippet=$(printf '%s\n' "$snippet" | sed 's/[[\.*^$()+?{|]/\\&/g')
                    sed -i '' "s|${escaped_snippet}|${snippet} (stale)|" "$learnings_file" 2>/dev/null && demoted=$((demoted + 1))
                fi
            fi
        done <<< "$(echo -e "$stale_list")"
        [[ "$demoted" -gt 0 ]] && $QUIET || true
    fi
}
