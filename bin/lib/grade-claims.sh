# grade-claims.sh — Claim parsing + single prediction grading engine
#
# Functions: parse_claim, grade_prediction
#
# Requires: CACHE_FILE, PRED_FILE (set by parent grade.sh)
# Depends on: grade-data.sh (get_feature_score, get_total_score, etc.)
#             grade-signals.sh (_is_feature_name)

# Extract claim components from prediction text.
# Returns: direction feature from_val to_val
# direction: raise|drop|improve|stable
parse_claim() {
    local text="$1"
    local direction="" feature="" from_val="" to_val=""

    # Pre-processing: strip "because Y" clause to prevent greedy interference.
    # Save the full text for causal fallback, but match patterns against the claim part only.
    local claim_text="$text"
    if [[ "$text" =~ ^(.+)[[:space:]]+because[[:space:]] ]]; then
        claim_text="${BASH_REMATCH[1]}"
    fi

    # --- TIER 1: Numeric patterns (most specific — "X from N to M") ---

    # Pattern: "X eval/feature from N to M" or "X eval/feature to N" (eval-cache lookup — BEFORE generic "from N to M")
    if [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(eval|feature)[[:space:]]+(from[[:space:]]+[0-9]+[[:space:]]+)?to[[:space:]]+([0-9]+) ]]; then
        direction="eval_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[4]}"
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?score[[:space:]]+([0-9]+) ]]; then
        direction="eval_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "raise X from N to M+"
    elif [[ "$claim_text" =~ raise[[:space:]]+([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "will raise X from N to M+"
    elif [[ "$claim_text" =~ will[[:space:]]+raise[[:space:]]+([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "X from N to M+"
    elif [[ "$claim_text" =~ ([a-zA-Z_-]+)[[:space:]]+from[[:space:]]+([0-9]+)[[:space:]]+to[[:space:]]+([0-9]+) ]]; then
        direction="raise"
        feature="${BASH_REMATCH[1]}"
        from_val="${BASH_REMATCH[2]}"
        to_val="${BASH_REMATCH[3]}"
    # Pattern: "X will reach/exceed/hit N" (numeric target)
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(reach|exceed|hit)[[:space:]]+([0-9]+) ]]; then
        direction="numeric_target"
        feature="${BASH_REMATCH[1]}"
        to_val="${BASH_REMATCH[4]}"
    elif [[ "$claim_text" =~ (reach|exceed|hit|get[[:space:]]+to)[[:space:]]+([0-9]+) ]]; then
        direction="numeric_target"
        to_val="${BASH_REMATCH[2]}"
        if [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(reach|exceed|hit|get[[:space:]]+to) ]]; then
            feature="${BASH_REMATCH[1]}"
        fi
    # Pattern: "N assertions will pass"
    elif [[ "$claim_text" =~ ([0-9]+)[[:space:]]+assertions?[[:space:]]+will[[:space:]]+pass ]]; then
        direction="assertion_count"
        to_val="${BASH_REMATCH[1]}"
    # Pattern: "score N" / "to score N" (overall score target)
    elif [[ "$claim_text" =~ (score|scoring)[[:space:]]+(stays?[[:space:]]+at[[:space:]]+|at[[:space:]]+|to[[:space:]]+)?([0-9]+) ]]; then
        direction="score_target"
        feature="score"
        to_val="${BASH_REMATCH[3]}"

    # --- TIER 2: Verb patterns with named subjects ("X will work/fail") ---

    # Pattern: "X will work" / "X will succeed"
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(work|succeed|pass) ]]; then
        direction="will_work"
        feature="${BASH_REMATCH[1]}"
    # Pattern: "X will fail" / "X will break"
    elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(fail|break|crash) ]]; then
        direction="will_fail"
        feature="${BASH_REMATCH[1]}"

    # --- TIER 3: Filesystem patterns ---

    # Pattern: "feature X exists" / "file X exists"
    elif [[ "$claim_text" =~ (feature|file)[[:space:]]+([a-zA-Z_./-]+)[[:space:]]+exists ]]; then
        direction="exists"
        feature="${BASH_REMATCH[2]}"
    # Pattern: "file X contains Y" / "X contains Y"
    elif [[ "$claim_text" =~ ([a-zA-Z_./-]+)[[:space:]]+contains ]]; then
        direction="contains"
        feature="${BASH_REMATCH[1]}"

    fi

    # --- TIER 4: Directional patterns (post-chain, since feature name validation can fail) ---
    if [[ -z "$direction" ]]; then
        # Try "X will improve/increase" with valid feature name
        if [[ "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(improve|increase|raise|grow|rise) ]]; then
            local _feat="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat"; then
                direction="directional_up"
                feature="$_feat"
            fi
        fi
        # Try "X improve/increase" (no "will")
        if [[ -z "$direction" && "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+(improve|increase|raise|grow|rise) ]]; then
            local _feat2="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat2"; then
                direction="directional_up"
                feature="$_feat2"
            fi
        fi
        # Try "X will decrease/drop"
        if [[ -z "$direction" && "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+will[[:space:]]+(decrease|drop|lower|decline|shrink|fall) ]]; then
            local _feat3="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat3"; then
                direction="directional_down"
                feature="$_feat3"
            fi
        fi
        # Try "X decrease/drop" (no "will")
        if [[ -z "$direction" && "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+(decrease|drop|lower|decline|shrink|fall) ]]; then
            local _feat4="${BASH_REMATCH[1]}"
            if _is_feature_name "$_feat4"; then
                direction="directional_down"
                feature="$_feat4"
            fi
        fi
        # No-subject fallback: "will drop" / "will decrease"
        if [[ -z "$direction" && "$claim_text" =~ will[[:space:]]+(drop|decrease|lower) ]]; then
            direction="drop"
        fi
        # No-subject fallback: "will improve" / "will increase"
        if [[ -z "$direction" && "$claim_text" =~ will[[:space:]]+(improve|increase) ]]; then
            direction="raise"
        fi

    # --- TIER 4.5: Qualitative patterns (adjective/verb/noun claims) ---

        # "will be [adjective]" — qualitative comparison claim
        # better, faster, simpler, cleaner, easier, more reliable, more accurate, higher, lower
        if [[ -z "$direction" && "$claim_text" =~ will[[:space:]]+be[[:space:]]+(better|faster|simpler|cleaner|easier|smoother|stronger|more[[:space:]]+reliable|more[[:space:]]+accurate|more[[:space:]]+stable|more[[:space:]]+honest|higher|lower) ]]; then
            local _adj="${BASH_REMATCH[1]}"
            # Try to extract subject before "will be"
            if [[ "$claim_text" =~ ([a-zA-Z_.-]{3,})[[:space:]]+will[[:space:]]+be[[:space:]]+ ]]; then
                feature="${BASH_REMATCH[1]}"
                _is_feature_name "$feature" || feature=""
            fi
            case "$_adj" in
                lower) direction="qualitative_down" ;;
                *)     direction="qualitative_up" ;;
            esac
        fi

        # "should [verb]" — expectation claim checked via assertions
        if [[ -z "$direction" && "$claim_text" =~ should[[:space:]]+(work|pass|succeed|improve|hold|transfer|apply|scale|run|compile|build) ]]; then
            direction="should_verb"
            local _verb="${BASH_REMATCH[1]}"
            # Try to extract subject before "should"
            if [[ "$claim_text" =~ ([a-zA-Z_.-]{3,})[[:space:]]+should ]]; then
                feature="${BASH_REMATCH[1]}"
                _is_feature_name "$feature" || feature=""
            fi
        fi

        # "expect [noun]" — expectation claim checked via score delta
        if [[ -z "$direction" && "$claim_text" =~ expect[[:space:]]+(improvement|regression|increase|decrease|drop|gain|decline|progress|growth|stability) ]]; then
            local _noun="${BASH_REMATCH[1]}"
            case "$_noun" in
                regression|decrease|drop|decline) direction="expect_down" ;;
                stability) direction="expect_stable" ;;
                *) direction="expect_up" ;;
            esac
            # Try to extract subject before "expect"
            if [[ "$claim_text" =~ ([a-zA-Z_.-]{3,})[[:space:]]+expect ]]; then
                feature="${BASH_REMATCH[1]}"
                _is_feature_name "$feature" || feature=""
            fi
        fi
        # Also handle "I expect" / "we expect" form
        if [[ -z "$direction" && "$claim_text" =~ (I|we)[[:space:]]+expect[[:space:]]+(improvement|regression|increase|decrease|drop|gain|decline|progress|growth|stability) ]]; then
            local _noun2="${BASH_REMATCH[2]}"
            case "$_noun2" in
                regression|decrease|drop|decline) direction="expect_down" ;;
                stability) direction="expect_stable" ;;
                *) direction="expect_up" ;;
            esac
        fi
    fi

    # --- TIER 5: Broad patterns (lowest priority) ---
    if [[ -z "$direction" ]]; then
        if [[ "$claim_text" =~ ([0-9]+)[[:space:]]+(sessions?|days?|weeks?|months?) ]]; then
            direction="time_based"
            to_val="${BASH_REMATCH[1]}"
            feature="${BASH_REMATCH[2]}"
        # Pattern: "X depends on Y" / "feature X depends on Y" / "X requires Y"
        elif [[ "$claim_text" =~ ([a-zA-Z_.-]+)[[:space:]]+(depends[[:space:]]+on|requires)[[:space:]]+([a-zA-Z_.-]+) ]]; then
            direction="dependency"
            feature="${BASH_REMATCH[1]}"
            to_val="${BASH_REMATCH[3]}"  # the dependency (Y)
        # Pattern: "users will [verb]" / "founders will [verb]" / "people will [verb]"
        elif [[ "$claim_text" =~ (users?|founders?|people|devs?|developers?|customers?)[[:space:]]+(will[[:space:]]+)?(adopt|install|use|try|ignore|skip|love|hate|churn|return|click|bounce|convert|upgrade|downgrade|complain|recommend|share|discover|find|prefer|avoid|switch|choose|leave|stay|sign[[:space:]]*up|drop[[:space:]]*off|pay|buy|subscribe) ]]; then
            direction="user_behavior"
            feature="${BASH_REMATCH[1]}"
            to_val="${BASH_REMATCH[3]}"
        elif [[ "$claim_text" =~ ([a-zA-Z_.-][a-zA-Z_.-][a-zA-Z_.-]+)[[:space:]]+(will[[:space:]]+)?(produce|generate|create|enable|reduce|eliminate) ]]; then
            direction="will_work"
            feature="${BASH_REMATCH[1]}"
        elif [[ "$claim_text" =~ will[[:space:]]+be[[:space:]]+the[[:space:]]+(highest|best|hardest|most|lowest|worst|easiest) ]]; then
            direction="superlative"
        # Causal fallback: if we stripped "because" earlier and nothing matched
        elif [[ "$claim_text" != "$text" ]]; then
            if [[ "$claim_text" =~ (will[[:space:]]+)?(work|succeed|pass|ship|land|hold|transfer|get) ]]; then
                direction="causal_bool"
                feature="causal"
            fi
        fi
    fi

    echo "$direction|$feature|$from_val|$to_val"
}

# Grade a single prediction
grade_prediction() {
    local prediction="$1"
    local pred_date="${2:-}"
    local claim
    claim=$(parse_claim "$prediction")

    local direction feature from_val to_val
    IFS='|' read -r direction feature from_val to_val <<< "$claim"

    # Can't extract a directional claim — skip for manual grading
    if [[ -z "$direction" ]]; then
        echo "SKIP"
        return
    fi

    # Some patterns don't need a feature name — only skip if the specific pattern requires one
    if [[ -z "$feature" && "$direction" != "assertion_count" && "$direction" != "score_target" \
        && "$direction" != "causal_bool" && "$direction" != "time_based" \
        && "$direction" != "superlative" && "$direction" != "numeric_target" \
        && "$direction" != "qualitative_up" && "$direction" != "qualitative_down" \
        && "$direction" != "should_verb" \
        && "$direction" != "expect_up" && "$direction" != "expect_down" && "$direction" != "expect_stable" \
        && "$direction" != "user_behavior" ]]; then
        echo "SKIP"
        return
    fi

    # --- Patterns that don't need a score (git-based, filesystem-based) ---

    # "X will work" — check git log for reverts (failure) or success
    if [[ "$direction" == "will_work" ]]; then
        # Check if feature was reverted recently
        REVERTED=$(git log --oneline -20 2>/dev/null | grep -i "revert.*${feature}" | head -1 || true)
        if [[ -n "$REVERTED" ]]; then
            echo "NO|Reverted: ${REVERTED}"
        else
            # Check if feature appears in recent successful commits
            COMMITTED=$(git log --oneline -20 2>/dev/null | grep -i "${feature}" | head -1 || true)
            if [[ -n "$COMMITTED" ]]; then
                echo "YES|Committed: ${COMMITTED}"
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "X will fail" — inverse of will_work
    if [[ "$direction" == "will_fail" ]]; then
        REVERTED=$(git log --oneline -20 2>/dev/null | grep -i "revert.*${feature}" | head -1 || true)
        if [[ -n "$REVERTED" ]]; then
            echo "YES|Failed and reverted: ${REVERTED}"
        else
            COMMITTED=$(git log --oneline -20 2>/dev/null | grep -i "${feature}" | head -1 || true)
            if [[ -n "$COMMITTED" ]]; then
                echo "NO|Succeeded: ${COMMITTED}"
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "N assertions will pass" — check score-cache.json assertion counts
    if [[ "$direction" == "assertion_count" && -n "$to_val" ]]; then
        if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
            ACTUAL_PASS=$(jq -r '.assertion_pass_count // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
            if [[ "$ACTUAL_PASS" -ge "$to_val" ]]; then
                echo "YES|${ACTUAL_PASS} assertions passing (target was ${to_val})"
            elif [[ "$ACTUAL_PASS" -gt 0 ]]; then
                echo "PARTIAL|${ACTUAL_PASS} assertions passing (target was ${to_val})"
            else
                echo "NO|${ACTUAL_PASS} assertions passing (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "feature/file X exists" — check filesystem
    if [[ "$direction" == "exists" ]]; then
        if [[ -f "$feature" || -d "$feature" ]]; then
            echo "YES|${feature} exists"
        else
            # Try finding it in common locations
            FOUND=$(find . -name "$(basename "$feature")" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 || true)
            if [[ -n "$FOUND" ]]; then
                echo "YES|Found at ${FOUND}"
            else
                echo "NO|${feature} not found"
            fi
        fi
        return
    fi

    # "X contains Y" — check file contents
    if [[ "$direction" == "contains" && -f "$feature" ]]; then
        echo "SKIP"  # Would need the Y part — too complex for pattern matching
        return
    fi

    # --- Score-based patterns (need current_score) ---
    local current_score
    current_score=$(get_feature_score "$feature")

    # If feature not found by exact name, fall back to total score
    if [[ -z "$current_score" ]]; then
        current_score=$(get_total_score)
    fi

    # --- NEW GRADING LOGIC (v9.0.1) ---

    # "directional_up" — check if feature score went up vs baseline at prediction time
    if [[ "$direction" == "directional_up" ]]; then
        if [[ -n "$current_score" && "$current_score" -gt 0 ]]; then
            local baseline
            baseline=$(find_score_at_date "$pred_date")
            if [[ -n "$baseline" && "$baseline" =~ ^[0-9]+$ ]]; then
                if [[ "$current_score" -gt "$baseline" ]]; then
                    echo "YES|Improved: ${baseline}→${current_score}"
                elif [[ "$current_score" -eq "$baseline" ]]; then
                    echo "NO|Unchanged at ${current_score}"
                else
                    echo "NO|Decreased: ${baseline}→${current_score}"
                fi
            else
                echo "SKIP"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "directional_down" — check if feature score went down vs baseline at prediction time
    if [[ "$direction" == "directional_down" ]]; then
        if [[ -n "$current_score" ]]; then
            local baseline
            baseline=$(find_score_at_date "$pred_date")
            if [[ -n "$baseline" && "$baseline" =~ ^[0-9]+$ ]]; then
                if [[ "$current_score" -lt "$baseline" ]]; then
                    echo "YES|Decreased: ${baseline}→${current_score}"
                else
                    echo "NO|Did not decrease: ${baseline}→${current_score}"
                fi
            else
                echo "SKIP"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "numeric_target" — check if a feature/total score reached the target
    if [[ "$direction" == "numeric_target" && -n "$to_val" ]]; then
        local check_score="${current_score}"
        [[ -z "$check_score" ]] && check_score=$(get_total_score)
        if [[ -n "$check_score" && "$check_score" =~ ^[0-9]+$ ]]; then
            if [[ "$check_score" -ge "$to_val" ]]; then
                echo "YES|Reached ${check_score} (target was ${to_val})"
            elif [[ "$check_score" -ge "$((to_val * 80 / 100))" ]]; then
                echo "PARTIAL|At ${check_score} (target was ${to_val}, within 80%)"
            else
                echo "NO|At ${check_score} (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "eval_target" — check eval-cache for feature score
    if [[ "$direction" == "eval_target" && -n "$to_val" ]]; then
        local eval_score=""
        eval_score=$(get_feature_score "$feature")
        [[ -z "$eval_score" ]] && eval_score=$(get_total_score)
        if [[ -n "$eval_score" && "$eval_score" =~ ^[0-9]+$ ]]; then
            if [[ "$eval_score" -ge "$to_val" ]]; then
                echo "YES|Eval score ${eval_score} (target was ${to_val})"
            elif [[ "$eval_score" -ge "$((to_val * 75 / 100))" ]]; then
                echo "PARTIAL|Eval score ${eval_score} (target was ${to_val})"
            else
                echo "NO|Eval score ${eval_score} (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "score_target" — check total score against target
    if [[ "$direction" == "score_target" && -n "$to_val" ]]; then
        local total
        total=$(get_total_score)
        if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
            local diff=$(( total - to_val ))
            [[ $diff -lt 0 ]] && diff=$(( -diff ))
            if [[ "$diff" -le 5 ]]; then
                echo "YES|Score ${total} (target was ${to_val}, within 5pt margin)"
            elif [[ "$total" -ge "$to_val" ]]; then
                echo "PARTIAL|Score ${total} exceeded target ${to_val}"
            else
                echo "NO|Score ${total} (target was ${to_val})"
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # --- NEW QUALITATIVE GRADING (v9.4.1) ---

    # "will be [adjective]" — grade by checking if related eval sub-scores improved
    if [[ "$direction" == "qualitative_up" || "$direction" == "qualitative_down" ]]; then
        # Strategy: check if feature's eval sub-scores improved vs baseline at prediction date
        # If no feature, check total score delta
        local delta
        delta=$(get_score_delta "$pred_date")
        if [[ -n "$delta" ]]; then
            if [[ "$direction" == "qualitative_up" ]]; then
                if [[ "$delta" -gt 5 ]]; then
                    echo "YES|Score improved by ${delta} points"
                elif [[ "$delta" -ge 0 ]]; then
                    echo "PARTIAL|Score delta ${delta} (marginal improvement)"
                else
                    echo "NO|Score decreased by ${delta#-} points"
                fi
            else  # qualitative_down
                if [[ "$delta" -lt -5 ]]; then
                    echo "YES|Score decreased by ${delta#-} points"
                elif [[ "$delta" -le 0 ]]; then
                    echo "PARTIAL|Score delta ${delta} (marginal decrease)"
                else
                    echo "NO|Score increased by ${delta} points"
                fi
            fi
        else
            # Fallback: check feature-specific eval sub-scores if feature is set
            if [[ -n "$feature" ]]; then
                local feat_score
                feat_score=$(get_feature_score "$feature")
                if [[ -n "$feat_score" && "$feat_score" =~ ^[0-9]+$ ]]; then
                    if [[ "$direction" == "qualitative_up" && "$feat_score" -ge 60 ]]; then
                        echo "YES|Feature ${feature} at ${feat_score} (above threshold)"
                    elif [[ "$direction" == "qualitative_up" && "$feat_score" -ge 40 ]]; then
                        echo "PARTIAL|Feature ${feature} at ${feat_score}"
                    else
                        echo "NO|Feature ${feature} at ${feat_score}"
                    fi
                else
                    echo "SKIP"
                fi
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "should [verb]" — grade by checking assertion pass rates
    if [[ "$direction" == "should_verb" ]]; then
        local pass_rate
        pass_rate=$(get_assertion_pass_rate)
        if [[ -n "$pass_rate" && "$pass_rate" =~ ^[0-9]+$ ]]; then
            if [[ "$pass_rate" -ge 85 ]]; then
                echo "YES|Assertion pass rate ${pass_rate}%"
            elif [[ "$pass_rate" -ge 60 ]]; then
                echo "PARTIAL|Assertion pass rate ${pass_rate}%"
            else
                echo "NO|Assertion pass rate ${pass_rate}%"
            fi
        else
            # Fallback: check git log for evidence of the verb's subject
            if [[ -n "$feature" ]]; then
                COMMITTED=$(git log --oneline -20 2>/dev/null | grep -i "${feature}" | head -1 || true)
                REVERTED=$(git log --oneline -20 2>/dev/null | grep -i "revert.*${feature}" | head -1 || true)
                if [[ -n "$REVERTED" ]]; then
                    echo "NO|Reverted: ${REVERTED}"
                elif [[ -n "$COMMITTED" ]]; then
                    echo "YES|Committed: ${COMMITTED}"
                else
                    echo "SKIP"
                fi
            else
                echo "SKIP"
            fi
        fi
        return
    fi

    # "expect [noun]" — grade by checking score delta
    if [[ "$direction" == "expect_up" || "$direction" == "expect_down" || "$direction" == "expect_stable" ]]; then
        local delta
        delta=$(get_score_delta "$pred_date")
        if [[ -n "$delta" ]]; then
            case "$direction" in
                expect_up)
                    if [[ "$delta" -gt 5 ]]; then
                        echo "YES|Score improved by ${delta} points"
                    elif [[ "$delta" -ge 0 ]]; then
                        echo "PARTIAL|Score delta +${delta} (marginal)"
                    else
                        echo "NO|Score decreased by ${delta#-} points"
                    fi
                    ;;
                expect_down)
                    if [[ "$delta" -lt -5 ]]; then
                        echo "YES|Score decreased by ${delta#-} points"
                    elif [[ "$delta" -le 0 ]]; then
                        echo "PARTIAL|Score delta ${delta} (marginal)"
                    else
                        echo "NO|Score increased by ${delta} points"
                    fi
                    ;;
                expect_stable)
                    local abs_delta="${delta#-}"
                    if [[ "$abs_delta" -le 3 ]]; then
                        echo "YES|Score stable (delta ${delta})"
                    elif [[ "$abs_delta" -le 8 ]]; then
                        echo "PARTIAL|Score delta ${delta} (slightly unstable)"
                    else
                        echo "NO|Score delta ${delta} (not stable)"
                    fi
                    ;;
            esac
        else
            echo "SKIP"
        fi
        return
    fi

    # "time_based" — grade "X will take N sessions/days" by checking date diff or git log session count
    if [[ "$direction" == "time_based" ]]; then
        local predicted_count="$to_val"
        local unit="$feature"  # feature field holds the time unit for time_based
        if [[ -z "$pred_date" || -z "$predicted_count" ]]; then
            echo "SKIP"
            return
        fi
        local today
        today=$(date '+%Y-%m-%d' 2>/dev/null || echo "")
        [[ -z "$today" ]] && { echo "SKIP"; return; }

        case "$unit" in
            session|sessions)
                # Count distinct build sessions (days with commits) since prediction
                local actual_sessions
                actual_sessions=$(git log --format='%ad' --date=short --after="$pred_date" 2>/dev/null | sort -u | wc -l | tr -d ' ')
                if [[ "$actual_sessions" -le "$predicted_count" ]]; then
                    echo "YES|Completed in ${actual_sessions} sessions (predicted ${predicted_count})"
                elif [[ "$actual_sessions" -le "$((predicted_count * 2))" ]]; then
                    echo "PARTIAL|Took ${actual_sessions} sessions (predicted ${predicted_count})"
                else
                    echo "NO|Took ${actual_sessions} sessions (predicted ${predicted_count})"
                fi
                ;;
            day|days)
                # Calculate actual days elapsed
                local pred_epoch today_epoch
                if date -v+0d &>/dev/null 2>&1; then
                    # macOS
                    pred_epoch=$(date -j -f '%Y-%m-%d' "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                else
                    # GNU
                    pred_epoch=$(date -d "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                fi
                if [[ -n "$pred_epoch" ]]; then
                    local actual_days=$(( (today_epoch - pred_epoch) / 86400 ))
                    if [[ "$actual_days" -le "$predicted_count" ]]; then
                        echo "YES|Completed in ${actual_days} days (predicted ${predicted_count})"
                    elif [[ "$actual_days" -le "$((predicted_count * 2))" ]]; then
                        echo "PARTIAL|Took ${actual_days} days (predicted ${predicted_count})"
                    else
                        echo "NO|Took ${actual_days} days (predicted ${predicted_count})"
                    fi
                else
                    echo "SKIP"
                fi
                ;;
            week|weeks)
                local pred_epoch today_epoch
                if date -v+0d &>/dev/null 2>&1; then
                    pred_epoch=$(date -j -f '%Y-%m-%d' "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                else
                    pred_epoch=$(date -d "$pred_date" '+%s' 2>/dev/null || echo "")
                    today_epoch=$(date '+%s')
                fi
                if [[ -n "$pred_epoch" ]]; then
                    local actual_weeks=$(( (today_epoch - pred_epoch) / 604800 ))
                    if [[ "$actual_weeks" -le "$predicted_count" ]]; then
                        echo "YES|Completed in ${actual_weeks} weeks (predicted ${predicted_count})"
                    elif [[ "$actual_weeks" -le "$((predicted_count * 2))" ]]; then
                        echo "PARTIAL|Took ${actual_weeks} weeks (predicted ${predicted_count})"
                    else
                        echo "NO|Took ${actual_weeks} weeks (predicted ${predicted_count})"
                    fi
                else
                    echo "SKIP"
                fi
                ;;
            *)
                echo "SKIP"
                ;;
        esac
        return
    fi

    # "dependency" — grade "feature X depends on Y" by checking if Y's score improved before X was attempted
    if [[ "$direction" == "dependency" ]]; then
        local dep_feature="$to_val"  # Y — the dependency
        local dep_score
        dep_score=$(get_feature_score "$dep_feature")
        local main_score
        main_score=$(get_feature_score "$feature")
        if [[ -n "$dep_score" && "$dep_score" =~ ^[0-9]+$ ]]; then
            if [[ "$dep_score" -ge 50 ]]; then
                # Dependency is healthy — check if main feature benefited
                if [[ -n "$main_score" && "$main_score" =~ ^[0-9]+$ && "$main_score" -ge 40 ]]; then
                    echo "YES|${dep_feature} at ${dep_score}, ${feature} at ${main_score} — dependency held"
                else
                    echo "PARTIAL|${dep_feature} at ${dep_score} (healthy), but ${feature} at ${main_score:-unknown}"
                fi
            else
                # Dependency is weak — did main feature suffer?
                if [[ -n "$main_score" && "$main_score" =~ ^[0-9]+$ && "$main_score" -lt 40 ]]; then
                    echo "YES|${dep_feature} at ${dep_score} (weak), ${feature} at ${main_score} (blocked) — dependency confirmed"
                else
                    echo "NO|${dep_feature} at ${dep_score} (weak) but ${feature} at ${main_score:-unknown} (not blocked)"
                fi
            fi
        else
            echo "SKIP"
        fi
        return
    fi

    # "user_behavior" — check customer-intel.json first, fall back to manual
    if [[ "$direction" == "user_behavior" ]]; then
        local ci_result
        ci_result=$(grade_customer_signal "$prediction")
        if [[ "${ci_result%%|*}" != "SKIP" ]]; then
            echo "$ci_result"
        else
            echo "NEEDS_MANUAL|User behavior claim: \"${feature} will ${to_val}\" — check customer-intel.json, support tickets, or analytics. Grade manually in /retro."
        fi
        return
    fi

    # "superlative" — can't auto-grade subjective superlatives
    if [[ "$direction" == "superlative" ]]; then
        echo "SKIP"
        return
    fi

    # "causal_bool" — check git log for evidence of the causal claim
    if [[ "$direction" == "causal_bool" ]]; then
        # Look for commits mentioning the prediction text (first 30 chars)
        local search_term="${prediction:0:30}"
        FOUND=$(git log --oneline -30 2>/dev/null | grep -i "${search_term:0:15}" | head -1 || true)
        if [[ -n "$FOUND" ]]; then
            echo "YES|Evidence in commits: ${FOUND}"
        else
            echo "SKIP"
        fi
        return
    fi

    # Original directional grading
    if [[ "$direction" == "raise" && -n "$to_val" && -n "$from_val" ]]; then
        if [[ "$current_score" -ge "$to_val" ]]; then
            echo "YES|Score reached ${current_score} (target was ${to_val}+)"
        elif [[ "$current_score" -gt "$from_val" ]]; then
            echo "PARTIAL|Score at ${current_score} (up from ${from_val}, target was ${to_val}+)"
        else
            echo "NO|Score at ${current_score} (target was ${to_val}+, baseline was ${from_val})"
        fi
    elif [[ "$direction" == "drop" ]]; then
        if [[ -n "$from_val" && "$current_score" -lt "$from_val" ]]; then
            echo "YES|Score dropped to ${current_score}"
        else
            echo "PARTIAL|Score at ${current_score}"
        fi
    else
        echo "SKIP"
    fi
}
