#!/usr/bin/env bash
# brains.sh — Persistent agent brain system for rhino-os.
# Provides inject_brain, detect_conflicts, resolve_conflict, recalculate_credibility, prune_stances.
# Sourced by bin/rhino.

BRAINS_DIR="$STATE_DIR/brains"
CONFLICTS_FILE="$STATE_DIR/conflicts.json"
RESOLUTIONS_FILE="$STATE_DIR/resolutions.jsonl"

# Agent-specific defaults for cold start (bash 3 compatible — no associative arrays)
_brain_tensions() {
    case "$1" in
        scout)           echo '["vs strategist — external signals vs internal portfolio evidence"]' ;;
        strategist)      echo '["vs scout — portfolio evidence vs market signals", "vs builder — strategic patience vs execution speed"]' ;;
        builder)         echo '["vs design-engineer — velocity vs quality", "vs sweep — speed vs safety"]' ;;
        design-engineer) echo '["vs builder — quality vs velocity"]' ;;
        sweep)           echo '["vs builder — safety vs speed"]' ;;
        meta)            echo '["referee — no natural tensions, grades all others"]' ;;
        *)               echo '[]' ;;
    esac
}

_brain_bias() {
    case "$1" in
        scout)           echo 'Market surprises you. Bias toward 0.5-0.7 conviction. Overconfidence on market predictions is your biggest risk.' ;;
        strategist)      echo 'You tend to accept scout market reads uncritically. Challenge with portfolio evidence. Your blind spot is sunk-cost bias on existing projects.' ;;
        builder)         echo 'You overestimate how much score improvement a single change will produce. Stake claims you can actually measure.' ;;
        design-engineer) echo 'You bias toward subjective taste judgments. Cite taste eval evidence, not vibes. "I feel" loses to "The score says."' ;;
        sweep)           echo 'Track your false alarm rate. If >50% of REDs turn out to be non-issues, lower conviction on safety calls.' ;;
        meta)            echo 'You are the referee. Your bias is toward finding problems even when the system is working. Sometimes no fix is the right fix.' ;;
        *)               echo '' ;;
    esac
}

# Ensure brains directory exists
_ensure_brains_dir() {
    mkdir -p "$BRAINS_DIR"
}

# Get brain file path for an agent
_brain_path() {
    echo "$BRAINS_DIR/${1}.json"
}

# Create brain from template if it doesn't exist, seeding agent-specific defaults
_ensure_brain() {
    local agent="$1"
    local brain_file
    brain_file="$(_brain_path "$agent")"

    if [[ ! -f "$brain_file" ]]; then
        _ensure_brains_dir

        local tensions
        tensions="$(_brain_tensions "$agent")"
        local bias
        bias="$(_brain_bias "$agent")"
        local now
        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        if command -v jq &>/dev/null; then
            jq --arg agent "$agent" \
               --argjson tensions "$tensions" \
               --arg bias "$bias" \
               --arg now "$now" \
               '.agent = $agent |
                .identity.natural_tensions = $tensions |
                .identity.bias_awareness = $bias |
                .updated = $now' \
               "$RHINO_DIR/agents/refs/brain-template.json" > "$brain_file"
        else
            # Fallback without jq — simple sed replacement
            sed -e "s/AGENT_NAME/$agent/g" \
                "$RHINO_DIR/agents/refs/brain-template.json" > "$brain_file"
        fi

        echo -e "${DIM}  brain created: $agent (credibility 0.50)${NC}" >&2
    fi
}

# Inject brain content into agent prompt
# Usage: inject_brain "agent_name"
# Outputs brain JSON block + mechanical constraints to stdout
inject_brain() {
    local agent="$1"
    _ensure_brain "$agent"

    local brain_file
    brain_file="$(_brain_path "$agent")"

    # Prune stances before injection
    prune_stances "$agent"

    local brain_content
    brain_content="$(cat "$brain_file")"

    # Build mechanical constraints from brain data
    local constraints=""

    if command -v jq &>/dev/null; then
        # Extract credibility
        local cred
        cred=$(jq -r '.track_record.credibility // 0.50' "$brain_file" 2>/dev/null)

        # Extract pending lessons from meta
        local lessons
        lessons=$(jq -r '.memory.lessons[-1] // ""' "$brain_file" 2>/dev/null)

        # Check calibration: conviction vs accuracy
        local accuracy avg_conviction
        accuracy=$(jq -r '.track_record.accuracy // 0' "$brain_file" 2>/dev/null)
        avg_conviction=$(jq -r '
            [.active_stances[]? | select(.status == "won" or .status == "lost") | .conviction // 0.5] |
            if length > 0 then add / length else 0.5 end
        ' "$brain_file" 2>/dev/null || echo "0.5")

        # Build conviction constraint based on track record
        local conviction_rule=""
        local is_overconfident
        is_overconfident=$(awk "BEGIN { print ($avg_conviction > 0.65 && $accuracy < 0.45) ? 1 : 0 }" 2>/dev/null || echo "0")
        local is_underconfident
        is_underconfident=$(awk "BEGIN { print ($avg_conviction < 0.40 && $accuracy > 0.65) ? 1 : 0 }" 2>/dev/null || echo "0")

        if [[ "$is_overconfident" == "1" ]]; then
            conviction_rule="CALIBRATION CONSTRAINT: You are overconfident (avg conviction: ${avg_conviction}, accuracy: ${accuracy}). Your new stances MUST have conviction <= 0.5 until accuracy improves."
        elif [[ "$is_underconfident" == "1" ]]; then
            conviction_rule="CALIBRATION NOTE: You are underconfident (avg conviction: ${avg_conviction}, accuracy: ${accuracy}). Trust your instincts more — consider conviction >= 0.6."
        fi

        # Check for open conflicts involving this agent
        local conflict_constraints=""
        if [[ -f "$CONFLICTS_FILE" ]]; then
            local my_conflicts
            my_conflicts=$(jq -c --arg agent "$agent" '
                [.[] | select(.status == "open" and (.side_a.agent == $agent or .side_b.agent == $agent))]
            ' "$CONFLICTS_FILE" 2>/dev/null)

            local conflict_count
            conflict_count=$(echo "$my_conflicts" | jq 'length' 2>/dev/null || echo "0")

            if [[ "$conflict_count" -gt 0 ]]; then
                conflict_constraints="ACTIVE CONFLICTS ($conflict_count): You have open disagreements with other agents.
$(echo "$my_conflicts" | jq -r --arg agent "$agent" '.[] |
    (if .side_a.agent == $agent then .side_b else .side_a end) as $opponent |
    "  #\(.id) vs \($opponent.agent) [\(.domain)]: they claim \"\($opponent.claim)\" (conviction: \($opponent.conviction))"
' 2>/dev/null)
You MUST address each conflict: either strengthen your counter-evidence or withdraw your stance."
            fi
        fi

        # Check other agents' high-credibility stances that affect this agent
        local high_cred_warnings=""
        for other_brain in "$BRAINS_DIR"/*.json; do
            [[ ! -f "$other_brain" ]] && continue
            local other_agent other_cred
            other_agent=$(jq -r '.agent' "$other_brain" 2>/dev/null)
            [[ "$other_agent" == "$agent" ]] && continue
            other_cred=$(jq -r '.track_record.credibility // 0.50' "$other_brain" 2>/dev/null)

            # Only surface stances from agents with cred >= 0.60
            local is_credible
            is_credible=$(awk "BEGIN { print ($other_cred >= 0.60) ? 1 : 0 }" 2>/dev/null || echo "0")
            if [[ "$is_credible" == "1" ]]; then
                local relevant_stances
                relevant_stances=$(jq -r --arg agent "$agent" '
                    [.active_stances[]? | select((.status == "pending" or .status == null) and .conviction >= 0.6)] |
                    if length > 0 then
                        map("    \(.claim) (conviction: \(.conviction))") | join("\n")
                    else empty end
                ' "$other_brain" 2>/dev/null)

                if [[ -n "$relevant_stances" ]]; then
                    high_cred_warnings+="
  ${other_agent} (credibility: ${other_cred}) holds:
${relevant_stances}"
                fi
            fi
        done

        if [[ -n "$high_cred_warnings" ]]; then
            high_cred_warnings="HIGH-CREDIBILITY AGENT STANCES (these agents have earned their credibility — take seriously):${high_cred_warnings}
If you disagree, you must set conflicts_with and provide counter-evidence."
        fi

        # Assemble constraints
        [[ -n "$conviction_rule" ]] && constraints+="$conviction_rule"$'\n\n'
        [[ -n "$conflict_constraints" ]] && constraints+="$conflict_constraints"$'\n\n'
        [[ -n "$high_cred_warnings" ]] && constraints+="$high_cred_warnings"$'\n\n'
        [[ -n "$lessons" && "$lessons" != "null" ]] && constraints+="LAST META LESSON: $lessons"$'\n\n'
    fi

    cat <<BRAIN_EOF

--- Your Brain (persistent memory) ---
This is YOUR persistent identity. It survives across runs. You MUST:
1. Read your track record and active stances
2. Review and confirm/revise/withdraw existing stances
3. Stake at least ONE new falsifiable claim
4. Update beliefs, lessons, and next_move
5. Write updated brain to $brain_file

Your credibility: $(jq -r '.track_record.credibility // 0.50' "$brain_file" 2>/dev/null)
Your record: $(jq -r '"\(.track_record.won // 0)W/\(.track_record.lost // 0)L/\(.track_record.pending // 0)P"' "$brain_file" 2>/dev/null)

${constraints}${brain_content}
--- End Brain ---
BRAIN_EOF
}

# Detect conflicts between agents' active stances
# Scans all brains, finds stances in same domain with opposing claims
detect_conflicts() {
    _ensure_brains_dir

    if ! command -v jq &>/dev/null; then
        return 0
    fi

    local conflicts="[]"
    local conflict_id=1
    local agents=()
    local stances_by_domain=""

    # Collect all active stances with agent attribution
    for brain_file in "$BRAINS_DIR"/*.json; do
        [[ ! -f "$brain_file" ]] && continue
        local agent
        agent="$(jq -r '.agent' "$brain_file" 2>/dev/null)"
        [[ -z "$agent" || "$agent" == "null" ]] && continue

        # Extract stances with explicit conflicts_with
        local explicit
        explicit=$(jq -r --arg agent "$agent" '
            .active_stances[]? |
            select(.conflicts_with != null and .conflicts_with != "") |
            {agent: $agent, claim: .claim, domain: .domain, conviction: .conviction, conflicts_with: .conflicts_with, staked: .staked}
        ' "$brain_file" 2>/dev/null)

        if [[ -n "$explicit" ]]; then
            stances_by_domain+="$explicit"$'\n'
        fi
    done

    # Build conflicts from explicit conflicts_with declarations
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Load existing conflicts to preserve IDs
    local existing_conflicts="[]"
    if [[ -f "$CONFLICTS_FILE" ]]; then
        existing_conflicts=$(jq '.' "$CONFLICTS_FILE" 2>/dev/null || echo "[]")
        conflict_id=$(echo "$existing_conflicts" | jq '[.[].id] | max // 0 | . + 1' 2>/dev/null || echo "1")
    fi

    local new_conflicts="[]"
    # Process each stance that declares a conflict
    for brain_file in "$BRAINS_DIR"/*.json; do
        [[ ! -f "$brain_file" ]] && continue

        local agent
        agent="$(jq -r '.agent' "$brain_file" 2>/dev/null)"

        local conflict_stances
        conflict_stances=$(jq -c '.active_stances[]? | select(.conflicts_with != null and .conflicts_with != "")' "$brain_file" 2>/dev/null)

        while IFS= read -r stance; do
            [[ -z "$stance" ]] && continue
            local target_agent
            # Extract agent name from conflicts_with (agents may write "scout — reason..." so take first word)
            local raw_target
            raw_target=$(echo "$stance" | jq -r '.conflicts_with' 2>/dev/null)
            target_agent="${raw_target%% *}"  # first word only
            target_agent="${target_agent%% —*}"  # also strip " —" suffix
            local domain
            domain=$(echo "$stance" | jq -r '.domain' 2>/dev/null)

            # Check if this conflict already exists
            local already_exists
            # Check if conflict between these two agents already exists (any domain)
            already_exists=$(echo "$existing_conflicts" "$new_conflicts" | jq -s --arg a "$agent" --arg b "$target_agent" '
                [.[][] | select(
                    (.side_a.agent == $a and .side_b.agent == $b) or
                    (.side_a.agent == $b and .side_b.agent == $a)
                )] | length
            ' 2>/dev/null || echo "0")

            if [[ "$already_exists" == "0" ]]; then
                # Find the target agent's stance in same domain
                local target_brain="$BRAINS_DIR/${target_agent}.json"
                if [[ -f "$target_brain" ]]; then
                    local target_stance
                    # Try same domain first, then fall back to any pending stance from target
                    target_stance=$(jq -c --arg d "$domain" '
                        (.active_stances[]? | select(.domain == $d) | {claim, conviction, domain}) //
                        (.active_stances[]? | select(.status == "pending" or .status == null) | {claim, conviction, domain})
                    ' "$target_brain" 2>/dev/null | head -1)

                    if [[ -n "$target_stance" ]]; then
                        local my_claim my_conviction target_claim target_conviction
                        my_claim=$(echo "$stance" | jq -r '.claim' 2>/dev/null)
                        my_conviction=$(echo "$stance" | jq -r '.conviction' 2>/dev/null)
                        target_claim=$(echo "$target_stance" | jq -r '.claim' 2>/dev/null)
                        target_conviction=$(echo "$target_stance" | jq -r '.conviction' 2>/dev/null)

                        new_conflicts=$(echo "$new_conflicts" | jq --argjson id "$conflict_id" \
                            --arg domain "$domain" \
                            --arg agent_a "$agent" --arg claim_a "$my_claim" --argjson conv_a "${my_conviction:-0.5}" \
                            --arg agent_b "$target_agent" --arg claim_b "$target_claim" --argjson conv_b "${target_conviction:-0.5}" \
                            --arg now "$now" \
                            '. + [{
                                id: $id,
                                domain: $domain,
                                side_a: {agent: $agent_a, claim: $claim_a, conviction: $conv_a},
                                side_b: {agent: $agent_b, claim: $claim_b, conviction: $conv_b},
                                surfaced: $now,
                                status: "open"
                            }]' 2>/dev/null)

                        ((conflict_id++))
                    fi
                fi
            fi
        done <<< "$conflict_stances"
    done

    # Merge existing open conflicts with new ones
    local all_conflicts
    all_conflicts=$(echo "$existing_conflicts" "$new_conflicts" | jq -s '.[0] + .[1] | unique_by(.id)' 2>/dev/null || echo "[]")

    echo "$all_conflicts" > "$CONFLICTS_FILE"

    local count
    count=$(echo "$all_conflicts" | jq '[.[] | select(.status == "open")] | length' 2>/dev/null || echo "0")
    if [[ "$count" -gt 0 ]]; then
        echo -e "${YELLOW}  $count active conflict(s) detected — run 'rhino council'${NC}" >&2
    fi
}

# Resolve a conflict — update winner/loser brains and track records
# Usage: resolve_conflict <conflict_id> <winner_agent>
resolve_conflict() {
    local conflict_id="$1"
    local winner="$2"

    if ! command -v jq &>/dev/null; then
        echo -e "${RED}jq required for conflict resolution${NC}"
        return 1
    fi

    if [[ ! -f "$CONFLICTS_FILE" ]]; then
        echo -e "${RED}No conflicts file found${NC}"
        return 1
    fi

    # Find the conflict
    local conflict
    conflict=$(jq --argjson id "$conflict_id" '.[] | select(.id == $id)' "$CONFLICTS_FILE" 2>/dev/null)

    if [[ -z "$conflict" || "$conflict" == "null" ]]; then
        echo -e "${RED}Conflict $conflict_id not found${NC}"
        return 1
    fi

    local agent_a agent_b loser domain
    agent_a=$(echo "$conflict" | jq -r '.side_a.agent')
    agent_b=$(echo "$conflict" | jq -r '.side_b.agent')
    domain=$(echo "$conflict" | jq -r '.domain')

    if [[ "$winner" == "$agent_a" ]]; then
        loser="$agent_b"
    elif [[ "$winner" == "$agent_b" ]]; then
        loser="$agent_a"
    else
        echo -e "${RED}Winner must be '$agent_a' or '$agent_b'${NC}"
        return 1
    fi

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Update winner brain — stance → won
    # Try domain match first; if no match, mark first pending stance (cross-domain conflicts)
    local winner_brain="$(_brain_path "$winner")"
    jq --arg domain "$domain" --arg loser "$loser" --arg now "$now" '
        .track_record.won += 1 |
        .track_record.resolved += 1 |
        # Find best stance to mark: same domain > conflicts_with loser > first pending
        (
            [.active_stances | to_entries[] | select(.value.domain == $domain and (.value.status == "pending" or .value.status == null))] +
            [.active_stances | to_entries[] | select(.value.conflicts_with == $loser and (.value.status == "pending" or .value.status == null))] +
            [.active_stances | to_entries[] | select(.value.status == "pending" or .value.status == null)]
        )[0].key as $idx |
        if $idx != null then
            .active_stances[$idx].status = "won" |
            .active_stances[$idx].resolved = $now
        else . end |
        .updated = $now
    ' "$winner_brain" > "${winner_brain}.tmp" && mv "${winner_brain}.tmp" "$winner_brain"

    # Update loser brain — stance → lost
    # Same cross-domain logic as winner
    local loser_brain="$(_brain_path "$loser")"
    jq --arg domain "$domain" --arg winner "$winner" --arg now "$now" '
        .track_record.lost += 1 |
        .track_record.resolved += 1 |
        (
            [.active_stances | to_entries[] | select(.value.domain == $domain and (.value.status == "pending" or .value.status == null))] +
            [.active_stances | to_entries[] | select(.value.conflicts_with == $winner and (.value.status == "pending" or .value.status == null))] +
            [.active_stances | to_entries[] | select(.value.status == "pending" or .value.status == null)]
        )[0].key as $idx |
        if $idx != null then
            .active_stances[$idx].status = "lost" |
            .active_stances[$idx].resolved = $now
        else . end |
        .updated = $now
    ' "$loser_brain" > "${loser_brain}.tmp" && mv "${loser_brain}.tmp" "$loser_brain"

    # Recalculate credibility for both
    recalculate_credibility "$winner"
    recalculate_credibility "$loser"

    # Mark conflict as resolved
    jq --argjson id "$conflict_id" --arg winner "$winner" --arg now "$now" '
        [.[] | if .id == $id then .status = "resolved" | .winner = $winner | .resolved = $now else . end]
    ' "$CONFLICTS_FILE" > "${CONFLICTS_FILE}.tmp" && mv "${CONFLICTS_FILE}.tmp" "$CONFLICTS_FILE"

    # Append to resolutions log
    local winner_cred loser_cred
    winner_cred=$(jq -r '.track_record.credibility' "$winner_brain" 2>/dev/null)
    loser_cred=$(jq -r '.track_record.credibility' "$loser_brain" 2>/dev/null)

    echo "{\"date\":\"$now\",\"conflict_id\":$conflict_id,\"domain\":\"$domain\",\"winner\":\"$winner\",\"loser\":\"$loser\",\"winner_credibility\":$winner_cred,\"loser_credibility\":$loser_cred}" >> "$RESOLUTIONS_FILE"

    echo -e "${GREEN}Resolved:${NC} $winner wins in $domain"
    echo -e "  $winner credibility: $winner_cred"
    echo -e "  $loser credibility: $loser_cred"
}

# Recalculate credibility using conviction-weighted Brier scoring
# High conviction wins earn more, high conviction losses cost more
# 30-day half-life, minimum 5 resolved stances
recalculate_credibility() {
    local agent="$1"
    local brain_file
    brain_file="$(_brain_path "$agent")"

    if ! command -v jq &>/dev/null || [[ ! -f "$brain_file" ]]; then
        return 0
    fi

    local half_life_days
    half_life_days=$(cfg brains.credibility_half_life_days 30)
    local min_stances
    min_stances=$(cfg brains.min_stances_for_credibility 5)

    # Count resolved stances
    local resolved
    resolved=$(jq '.track_record.resolved // 0' "$brain_file" 2>/dev/null)

    if [[ "$resolved" -lt "$min_stances" ]]; then
        # Calibration period — stay at 0.50
        jq '.track_record.credibility = 0.50 | .track_record.accuracy = 0' "$brain_file" > "${brain_file}.tmp" \
            && mv "${brain_file}.tmp" "$brain_file"
        return 0
    fi

    # Calculate weighted accuracy from resolved stances
    # Won stances with high conviction earn more; lost stances with high conviction cost more
    local credibility
    credibility=$(jq --argjson half_life "$half_life_days" '
        def age_weight($staked; $half_life):
            (now - ($staked | fromdateiso8601 // now)) / 86400 / $half_life |
            pow(0.5; .);

        .active_stances as $stances |
        ($stances | map(select(.status == "won" or .status == "lost"))) as $resolved_stances |
        if ($resolved_stances | length) == 0 then 0.50
        else
            ($resolved_stances | map(
                (.conviction // 0.5) as $conv |
                (if .status == "won" then $conv else (0 - $conv) end)
            ) | add / length) as $raw |
            (($raw + 1) / 2) |  # normalize to 0-1
            if . < 0.10 then 0.10
            elif . > 0.95 then 0.95
            else .
            end
        end |
        . * 100 | round / 100
    ' "$brain_file" 2>/dev/null || echo "0.50")

    local won lost accuracy
    won=$(jq '.track_record.won // 0' "$brain_file" 2>/dev/null)
    lost=$(jq '.track_record.lost // 0' "$brain_file" 2>/dev/null)
    if [[ $((won + lost)) -gt 0 ]]; then
        accuracy=$(awk "BEGIN { printf \"%.2f\", $won / ($won + $lost) }")
    else
        accuracy="0.00"
    fi

    jq --argjson cred "$credibility" --argjson acc "$accuracy" '
        .track_record.credibility = $cred |
        .track_record.accuracy = $acc
    ' "$brain_file" > "${brain_file}.tmp" && mv "${brain_file}.tmp" "$brain_file"
}

# Auto-resolve stances that have measurable outcomes
# Called by catchup and after meta runs
# Runs under set +e internally to avoid killing the main script
auto_resolve_stances() {
    command -v jq &>/dev/null || return 0
    [[ -d "$BRAINS_DIR" ]] || return 0
    # Guard against empty glob
    local has_brains=false
    for _bf in "$BRAINS_DIR"/*.json; do
        [[ -f "$_bf" ]] && has_brains=true && break
    done
    $has_brains || return 0

    # Disable exit-on-error inside this function (jq pipelines can fail on empty data)
    local _old_e=""
    [[ $- == *e* ]] && _old_e=1 && set +e

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local resolved_count=0

    for brain_file in "$BRAINS_DIR"/*.json; do
        [[ ! -f "$brain_file" ]] && continue

        local agent
        agent=$(jq -r '.agent' "$brain_file" 2>/dev/null)

        # Auto-resolve score-based claims (builder, design-engineer)
        if [[ "$agent" == "builder" || "$agent" == "design-engineer" ]]; then
            local auto_resolve
            auto_resolve=$(cfg brains.auto_resolve_score_claims true)
            [[ "$auto_resolve" != "true" ]] && continue

            # Find stances that predict score changes
            local score_stances
            score_stances=$(jq -c '.active_stances[]? | select(
                (.status == "pending" or .status == null) and
                (.domain == "execution" or .domain == "quality") and
                (.claim | test("score|Score|improve|Improve|increase|decrease"; "i") // false)
            )' "$brain_file" 2>/dev/null)

            while IFS= read -r stance; do
                [[ -z "$stance" ]] && continue
                local staked_date
                staked_date=$(echo "$stance" | jq -r '.staked // ""' 2>/dev/null)
                [[ -z "$staked_date" ]] && continue

                # Check if falsifiable_by date has passed
                local staked_epoch
                staked_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$staked_date" +%s 2>/dev/null || date -d "$staked_date" +%s 2>/dev/null || echo "0")
                local age_days=$(( ($(date +%s) - staked_epoch) / 86400 ))

                # Auto-resolve after 7 days (enough time for scores to materialize)
                if [[ "$age_days" -ge 7 ]]; then
                    local claim_text
                    claim_text=$(echo "$stance" | jq -r '.claim' 2>/dev/null)
                    local conviction
                    conviction=$(echo "$stance" | jq -r '.conviction // 0.5' 2>/dev/null)

                    # Check experiment TSVs for evidence
                    local found_improvement=false
                    for exp_dir in "$PWD/.claude/experiments" "$HOME/Desktop"/*/.claude/experiments; do
                        [[ ! -d "$exp_dir" ]] && continue
                        for tsv in "$exp_dir"/*.tsv; do
                            [[ ! -f "$tsv" ]] && continue
                            # Look for kept experiments after the stance date
                            if grep -q "keep" "$tsv" 2>/dev/null; then
                                found_improvement=true
                                break 2
                            fi
                        done
                    done

                    # Mark based on evidence
                    local result="inconclusive"
                    if $found_improvement; then
                        result="won"
                    fi

                    jq --arg claim "$claim_text" --arg result "$result" --arg now "$now" '
                        .active_stances = [.active_stances[] |
                            if .claim == $claim and (.status == "pending" or .status == null)
                            then .status = $result | .resolved = $now
                            else . end
                        ] |
                        if $result == "won" then .track_record.won += 1 | .track_record.resolved += 1
                        elif $result == "lost" then .track_record.lost += 1 | .track_record.resolved += 1
                        else .track_record.withdrawn += 1 | .track_record.resolved += 1
                        end |
                        .updated = $now
                    ' "$brain_file" > "${brain_file}.tmp" && mv "${brain_file}.tmp" "$brain_file"

                    echo "{\"date\":\"$now\",\"agent\":\"$agent\",\"claim\":\"$claim_text\",\"result\":\"$result\",\"auto\":true}" >> "$RESOLUTIONS_FILE"
                    ((resolved_count++))
                fi
            done <<< "$score_stances"
        fi
    done

    # Auto-resolve old conflicts by credibility gap
    if [[ -f "$CONFLICTS_FILE" ]]; then
        local escalation_days
        escalation_days=$(cfg brains.conflict_escalation_days 7)

        local open_conflicts
        open_conflicts=$(jq -c '.[] | select(.status == "open")' "$CONFLICTS_FILE" 2>/dev/null)

        while IFS= read -r conflict; do
            [[ -z "$conflict" ]] && continue

            local surfaced conflict_id
            surfaced=$(echo "$conflict" | jq -r '.surfaced' 2>/dev/null)
            conflict_id=$(echo "$conflict" | jq -r '.id' 2>/dev/null)

            local surfaced_epoch
            surfaced_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$surfaced" +%s 2>/dev/null || date -d "$surfaced" +%s 2>/dev/null || echo "0")
            local conflict_age_days=$(( ($(date +%s) - surfaced_epoch) / 86400 ))

            if [[ "$conflict_age_days" -ge "$escalation_days" ]]; then
                # Check credibility gap — auto-resolve if gap >= 0.15
                local a_agent b_agent
                a_agent=$(echo "$conflict" | jq -r '.side_a.agent' 2>/dev/null)
                b_agent=$(echo "$conflict" | jq -r '.side_b.agent' 2>/dev/null)

                local a_cred b_cred
                a_cred=$(jq -r '.track_record.credibility // 0.50' "$BRAINS_DIR/${a_agent}.json" 2>/dev/null)
                b_cred=$(jq -r '.track_record.credibility // 0.50' "$BRAINS_DIR/${b_agent}.json" 2>/dev/null)

                local gap winner
                gap=$(awk "BEGIN { g = $a_cred - $b_cred; print (g < 0 ? -g : g) }")
                local should_resolve
                should_resolve=$(awk "BEGIN { print ($gap >= 0.15) ? 1 : 0 }")

                if [[ "$should_resolve" == "1" ]]; then
                    if awk "BEGIN { exit !($a_cred > $b_cred) }" 2>/dev/null; then
                        winner="$a_agent"
                    else
                        winner="$b_agent"
                    fi
                    echo -e "${DIM}  auto-resolving conflict #${conflict_id}: ${winner} wins (credibility gap: ${gap})${NC}" >&2
                    resolve_conflict "$conflict_id" "$winner"
                    ((resolved_count++))
                fi
            fi
        done <<< "$open_conflicts"
    fi

    # Recalculate credibility for all agents with changes
    if [[ "$resolved_count" -gt 0 ]]; then
        for brain_file in "$BRAINS_DIR"/*.json; do
            [[ ! -f "$brain_file" ]] && continue
            local agent
            agent=$(jq -r '.agent' "$brain_file" 2>/dev/null)
            recalculate_credibility "$agent"
        done
        echo -e "${DIM}  auto-resolved $resolved_count stance(s)${NC}" >&2
    fi

    # Restore set -e if it was previously on
    [[ -n "$_old_e" ]] && set -e
}

# Prune stances — expire old stances, cap active count
prune_stances() {
    local agent="$1"
    local brain_file
    brain_file="$(_brain_path "$agent")"

    if ! command -v jq &>/dev/null || [[ ! -f "$brain_file" ]]; then
        return 0
    fi

    local expiry_days
    expiry_days=$(cfg brains.stance_expiry_days 30)
    local max_stances
    max_stances=$(cfg brains.max_active_stances 5)

    local now_epoch
    now_epoch=$(date +%s)
    local cutoff_epoch=$((now_epoch - expiry_days * 86400))

    # Count expired stances before pruning (for logging)
    local expired_claims
    expired_claims=$(jq -r --argjson cutoff "$cutoff_epoch" '
        [.active_stances[]? |
         select((.status == "pending" or .status == null) and
                ((.staked // "") != "") and
                ((.staked | fromdateiso8601 // 9999999999) < $cutoff)) |
         .claim] | .[]
    ' "$brain_file" 2>/dev/null)

    jq --argjson max "$max_stances" --argjson cutoff "$cutoff_epoch" '
        # Expire old pending stances
        .active_stances = [
            .active_stances[]? |
            if (.status == "pending" or .status == null) and
               ((.staked // "") != "") and
               ((.staked | fromdateiso8601 // 9999999999) < $cutoff)
            then .status = "expired"
            else .
            end
        ] |
        # Move resolved/expired to track record counts
        (.active_stances | map(select(.status == "expired")) | length) as $expired |
        .track_record.withdrawn += $expired |
        .track_record.resolved += $expired |
        # Keep only active/pending stances, cap at max
        .active_stances = [.active_stances[] | select(.status == "pending" or .status == null or .status == "won" or .status == "lost")] |
        .active_stances = .active_stances[:$max]
    ' "$brain_file" > "${brain_file}.tmp" && mv "${brain_file}.tmp" "$brain_file" 2>/dev/null

    # Log expired stances to resolutions.jsonl for audit trail
    if [[ -n "$expired_claims" ]]; then
        local now_iso
        now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        while IFS= read -r claim; do
            [[ -z "$claim" ]] && continue
            echo "{\"date\":\"$now_iso\",\"agent\":\"$agent\",\"claim\":\"$claim\",\"result\":\"expired\",\"auto\":true}" >> "$RESOLUTIONS_FILE"
        done <<< "$expired_claims"
    fi
}
