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
# Outputs brain JSON block to stdout (caller appends to prompt)
inject_brain() {
    local agent="$1"
    _ensure_brain "$agent"

    local brain_file
    brain_file="$(_brain_path "$agent")"

    # Prune stances before injection
    prune_stances "$agent"

    local brain_content
    brain_content="$(cat "$brain_file")"

    cat <<BRAIN_EOF

--- Your Brain (persistent memory) ---
This is YOUR persistent identity. It survives across runs. You MUST:
1. Read your track record and active stances
2. Review and confirm/revise/withdraw existing stances
3. Stake at least ONE new falsifiable claim
4. Update beliefs, lessons, and next_move
5. Write updated brain to $brain_file

$brain_content
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
            target_agent=$(echo "$stance" | jq -r '.conflicts_with' 2>/dev/null)
            local domain
            domain=$(echo "$stance" | jq -r '.domain' 2>/dev/null)

            # Check if this conflict already exists
            local already_exists
            already_exists=$(echo "$existing_conflicts" | jq --arg a "$agent" --arg b "$target_agent" --arg d "$domain" '
                [.[] | select(
                    (.side_a.agent == $a and .side_b.agent == $b and .domain == $d) or
                    (.side_a.agent == $b and .side_b.agent == $a and .domain == $d)
                )] | length
            ' 2>/dev/null || echo "0")

            if [[ "$already_exists" == "0" ]]; then
                # Find the target agent's stance in same domain
                local target_brain="$BRAINS_DIR/${target_agent}.json"
                if [[ -f "$target_brain" ]]; then
                    local target_stance
                    target_stance=$(jq -c --arg d "$domain" '.active_stances[]? | select(.domain == $d) | {claim, conviction}' "$target_brain" 2>/dev/null | head -1)

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
    local winner_brain="$(_brain_path "$winner")"
    jq --arg domain "$domain" --arg now "$now" '
        .track_record.won += 1 |
        .track_record.resolved += 1 |
        .active_stances = [.active_stances[] | if .domain == $domain then .status = "won" | .resolved = $now else . end] |
        .updated = $now
    ' "$winner_brain" > "${winner_brain}.tmp" && mv "${winner_brain}.tmp" "$winner_brain"

    # Update loser brain — stance → lost
    local loser_brain="$(_brain_path "$loser")"
    jq --arg domain "$domain" --arg now "$now" '
        .track_record.lost += 1 |
        .track_record.resolved += 1 |
        .active_stances = [.active_stances[] | if .domain == $domain then .status = "lost" | .resolved = $now else . end] |
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
}
