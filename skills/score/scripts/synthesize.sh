#!/usr/bin/env bash
# synthesize.sh — Compute unified score from all tier caches
# Usage: synthesize.sh [project-dir] [feature]
# Outputs JSON with per-feature unified scores and product total
#
# The unified score answers: "Does the user get value?"
# Every tier measures a different facet of user value delivery.
# This applies to any product surface — web, CLI, API, docs.
#
# Viability: reads viability-cache.json first (agent-backed).
# Falls back to scoring from accumulated intelligence files
# (market-context.json + customer-intel.json). No intelligence = capped at 30.

set -uo pipefail

PROJECT_DIR="${1:-.}"
TARGET_FEATURE=""
OUTPUT_MODE="json"

# Parse args: synthesize.sh [project-dir] [feature] [--text]
shift || true
for _arg in "$@"; do
    case "$_arg" in
        --text) OUTPUT_MODE="text" ;;
        *) TARGET_FEATURE="$_arg" ;;
    esac
done

EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
VIABILITY_CACHE="$PROJECT_DIR/.claude/cache/viability-cache.json"
MARKET_CONTEXT="$PROJECT_DIR/.claude/cache/market-context.json"
CUSTOMER_INTEL="$PROJECT_DIR/.claude/cache/customer-intel.json"
RHINO_YML="$PROJECT_DIR/config/rhino.yml"
TASTE_DIR="$PROJECT_DIR/.claude/evals/reports"

# --- Read feature weights from rhino.yml ---
get_feature_weight() {
    local feat="$1"
    local w
    w=$(grep -A 10 "^  ${feat}:" "$RHINO_YML" 2>/dev/null | grep "weight:" | head -1 | awk '{print $2}')
    echo "${w:-1}"
}

get_active_features() {
    awk '
        /^  [a-z][a-z_-]*:$/ { feat = $1; sub(/:$/, "", feat) }
        /status: active/ && feat { print feat; feat = "" }
        /status: killed/ && feat { feat = "" }
    ' "$RHINO_YML" 2>/dev/null
}

# --- Pre-validate eval cache (once, before per-feature reads) ---
_eval_cache_valid=false
if [[ -f "$EVAL_CACHE" ]]; then
    if jq empty "$EVAL_CACHE" 2>/dev/null; then
        _eval_cache_valid=true
    else
        echo "synthesize: eval cache corrupted — run /eval to rebuild." >&2
    fi
fi

# --- Read eval cache (tier 2: delivery + craft) ---
get_eval_scores() {
    local feat="$1"
    if [[ "$_eval_cache_valid" == true ]]; then
        local result
        result=$(jq -r --arg f "$feat" '.[$f] // {} | "\(.delivery_score // 0) \(.craft_score // 0)"' "$EVAL_CACHE" 2>/dev/null)
        if [[ -z "$result" || "$result" == "null null" ]]; then
            echo "0 0"
        else
            echo "$result"
        fi
    else
        echo "0 0"
    fi
}

# --- Read latest taste report (tier 3: visual) ---
get_visual_score() {
    local latest
    latest=$(ls -t "$TASTE_DIR"/taste-*.json 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "-1"
        return
    fi
    local _taste_err
    _taste_err=$(mktemp /tmp/rhino-taste-err.XXXXXX)
    local _taste_result
    _taste_result=$(jq -r '
        [.dimensions // {} | to_entries[] | .value.score // 0] |
        if length > 0 then (add / length | floor) else -1 end
    ' "$latest" 2>"$_taste_err")
    if [[ $? -ne 0 ]]; then
        echo "synthesize: taste report parse error in $(basename "$latest") — $(head -1 "$_taste_err"). Run /taste to regenerate." >&2
        rm -f "$_taste_err"
        echo "-1"
        return
    fi
    rm -f "$_taste_err"
    echo "$_taste_result"
}

# --- Read latest flows report (tier 4: behavioral) ---
get_behavioral_score() {
    local latest
    latest=$(ls -t "$TASTE_DIR"/flows-*.json 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "-1"
        return
    fi
    local _flows_err
    _flows_err=$(mktemp /tmp/rhino-flows-err.XXXXXX)
    local _flows_result
    _flows_result=$(jq -r '
        def count_severity(s): [.issues[]? | select(.severity == s)] | length;
        100 - (count_severity("blocker") * 25) - (count_severity("major") * 10) - (count_severity("minor") * 3) |
        if . < 0 then 0 else . end
    ' "$latest" 2>"$_flows_err")
    if [[ $? -ne 0 ]]; then
        echo "synthesize: flows report parse error in $(basename "$latest") — $(head -1 "$_flows_err"). Run /taste flows to regenerate." >&2
        rm -f "$_flows_err"
        echo "-1"
        return
    fi
    rm -f "$_flows_err"
    echo "$_flows_result"
}

# --- Read viability (tier 5) ---
# Priority: viability-cache.json (agent-backed) > intelligence-derived > cap at 30
get_viability_score() {
    local feat="$1"

    # 1. Agent-backed viability cache (authoritative)
    if [[ -f "$VIABILITY_CACHE" ]]; then
        local v _via_err
        _via_err=$(mktemp /tmp/rhino-via-err.XXXXXX)
        v=$(jq -r --arg f "$feat" '.features[$f].viability // -1' "$VIABILITY_CACHE" 2>"$_via_err")
        if [[ $? -ne 0 ]]; then
            echo "synthesize: viability cache parse error — $(head -1 "$_via_err"). Run /score viability to rebuild." >&2
            rm -f "$_via_err"
        else
            rm -f "$_via_err"
            if [[ "$v" != "-1" && "$v" != "null" ]]; then
                echo "$v"
                return
            fi
        fi
    fi

    # 2. Derive from accumulated intelligence files
    local has_market=false has_customer=false
    [[ -f "$MARKET_CONTEXT" ]] && has_market=true
    [[ -f "$CUSTOMER_INTEL" ]] && has_customer=true

    if $has_market && $has_customer; then
        # Both sources: score up to 60 (full range requires agent assessment)
        # Check if sources mention this feature's category
        local market_signals customer_signals
        market_signals=$(jq -r '.demand_signals | length' "$MARKET_CONTEXT" 2>/dev/null || echo "0")
        customer_signals=$(jq -r '.demand_signals | length' "$CUSTOMER_INTEL" 2>/dev/null || echo "0")
        local base=40
        [[ "$market_signals" -gt 3 ]] && base=$((base + 10))
        [[ "$customer_signals" -gt 3 ]] && base=$((base + 10))
        echo "$base"
    elif $has_market; then
        # Market only: capped at 45
        echo "45"
    elif $has_customer; then
        # Customer only: capped at 45
        echo "45"
    else
        # No intelligence: capped at 30
        echo "30"
    fi
}

# --- Viability source label ---
get_viability_source() {
    local feat="$1"
    if [[ -f "$VIABILITY_CACHE" ]]; then
        local v
        v=$(jq -r --arg f "$feat" '.features[$f].viability // -1' "$VIABILITY_CACHE" 2>/dev/null)
        if [[ "$v" != "-1" && "$v" != "null" ]]; then
            echo "agents"
            return
        fi
    fi
    local has_market=false has_customer=false
    [[ -f "$MARKET_CONTEXT" ]] && has_market=true
    [[ -f "$CUSTOMER_INTEL" ]] && has_customer=true
    if $has_market || $has_customer; then
        echo "intelligence"
    else
        echo "capped"
    fi
}

# --- Compute unified score for a feature ---
compute_feature_score() {
    local feat="$1"
    local eval_scores
    eval_scores=$(get_eval_scores "$feat")
    local delivery craft
    delivery=$(echo "$eval_scores" | awk '{print $1}')
    craft=$(echo "$eval_scores" | awk '{print $2}')

    local visual behavioral viability
    visual=$(get_visual_score)
    behavioral=$(get_behavioral_score)
    viability=$(get_viability_score "$feat")
    local viability_src
    viability_src=$(get_viability_source "$feat")

    # Determine available tiers
    local has_visual=true has_behavioral=true
    [[ "$visual" == "-1" ]] && has_visual=false
    [[ "$behavioral" == "-1" ]] && has_behavioral=false

    # Count filled tiers for confidence badge
    local tier_count=2  # health + eval always present
    $has_visual && tier_count=$((tier_count + 1))
    $has_behavioral && tier_count=$((tier_count + 1))
    [[ "$viability_src" == "agents" ]] && tier_count=$((tier_count + 1))

    local score
    if $has_visual && $has_behavioral; then
        # All tiers: d*40 + c*25 + v*15 + b*10 + vi*10
        score=$(( delivery * 40 / 100 + craft * 25 / 100 + visual * 15 / 100 + behavioral * 10 / 100 + viability * 10 / 100 ))
    elif ! $has_visual && ! $has_behavioral; then
        # Code + viability only: d*50 + c*30 + vi*20
        score=$(( delivery * 50 / 100 + craft * 30 / 100 + viability * 20 / 100 ))
    else
        # Partial: weighted average of what's available
        local total_weight=0 weighted_sum=0
        weighted_sum=$(( delivery * 40 + craft * 25 ))
        total_weight=65
        if $has_visual; then
            weighted_sum=$(( weighted_sum + visual * 15 ))
            total_weight=$(( total_weight + 15 ))
        fi
        if $has_behavioral; then
            weighted_sum=$(( weighted_sum + behavioral * 10 ))
            total_weight=$(( total_weight + 10 ))
        fi
        weighted_sum=$(( weighted_sum + viability * 10 ))
        total_weight=$(( total_weight + 10 ))
        score=$(( weighted_sum / total_weight ))
    fi

    # Clamp
    [[ $score -gt 100 ]] && score=100
    [[ $score -lt 0 ]] && score=0

    # Confidence from tier count
    local confidence
    if [[ $tier_count -ge 5 ]]; then
        confidence="high"
    elif [[ $tier_count -ge 4 ]]; then
        confidence="medium"
    else
        confidence="low"
    fi

    # Output JSON
    local vis_out beh_out
    $has_visual && vis_out="$visual" || vis_out="null"
    $has_behavioral && beh_out="$behavioral" || beh_out="null"

    echo "{\"feature\":\"$feat\",\"score\":$score,\"delivery\":$delivery,\"craft\":$craft,\"visual\":$vis_out,\"behavioral\":$beh_out,\"viability\":$viability,\"viability_source\":\"$viability_src\",\"confidence\":\"$confidence\",\"tiers\":$tier_count,\"weight\":$(get_feature_weight "$feat")}"
}

# --- Main ---
features=$(get_active_features)
if [[ -n "$TARGET_FEATURE" ]]; then
    features="$TARGET_FEATURE"
fi

# Collect results into arrays for both output modes
_feat_names=()
_feat_results=()
product_weighted_sum=0
product_total_weight=0
min_tiers=5

while IFS= read -r feat; do
    [[ -z "$feat" ]] && continue

    result=$(compute_feature_score "$feat")
    feat_score=$(echo "$result" | jq -r '.score')
    feat_weight=$(echo "$result" | jq -r '.weight')
    feat_tiers=$(echo "$result" | jq -r '.tiers')

    _feat_names+=("$feat")
    _feat_results+=("$result")

    product_weighted_sum=$(( product_weighted_sum + feat_score * feat_weight ))
    product_total_weight=$(( product_total_weight + feat_weight ))
    [[ $feat_tiers -lt $min_tiers ]] && min_tiers=$feat_tiers
done <<< "$features"

# Product total
if [[ $product_total_weight -gt 0 ]]; then
    product_score=$(( product_weighted_sum / product_total_weight ))
else
    product_score=0
fi

# Product confidence from minimum tier count
product_confidence="high"
[[ $min_tiers -lt 5 ]] && product_confidence="medium"
[[ $min_tiers -lt 4 ]] && product_confidence="low"

if [[ "$OUTPUT_MODE" == "text" ]]; then
    # --- Formatted text output ---
    _conf_label=""
    case "$product_confidence" in
        high)   _conf_label="high confidence (all tiers)" ;;
        medium) _conf_label="medium confidence (${min_tiers}/5 tiers)" ;;
        low)    _conf_label="low confidence (${min_tiers}/5 tiers — run /taste and /eval to fill)" ;;
    esac
    echo "Unified Score: ${product_score}/100  (${_conf_label})"
    echo ""

    # Per-feature breakdown
    _bottleneck_feat="" _bottleneck_score=101
    for ((_i=0; _i<${#_feat_names[@]}; _i++)); do
        _fn="${_feat_names[$_i]}"
        _fr="${_feat_results[$_i]}"
        _fs=$(echo "$_fr" | jq -r '.score')
        _fd=$(echo "$_fr" | jq -r '.delivery')
        _fc=$(echo "$_fr" | jq -r '.craft')
        _fv=$(echo "$_fr" | jq -r '.viability')
        _fvs=$(echo "$_fr" | jq -r '.viability_source')
        _fw=$(echo "$_fr" | jq -r '.weight')
        _ft=$(echo "$_fr" | jq -r '.tiers')

        # Track bottleneck
        if [[ "$_fs" -lt "$_bottleneck_score" ]]; then
            _bottleneck_score=$_fs
            _bottleneck_feat=$_fn
        fi

        # Direction hint based on weakest dimension
        _hint=""
        if [[ "$_fd" -lt "$_fc" && "$_fd" -lt "$_fv" ]]; then
            _hint="delivery is the gap — ship more of the feature"
        elif [[ "$_fc" -lt "$_fd" && "$_fc" -lt "$_fv" ]]; then
            _hint="craft is the gap — polish error handling and UX"
        elif [[ "$_fvs" == "capped" ]]; then
            _hint="viability capped at 30 — run /research or /strategy"
        fi

        printf "  %-16s %3d/100  (d:%d c:%d v:%d) w:%s  %d/5 tiers\n" "$_fn" "$_fs" "$_fd" "$_fc" "$_fv" "$_fw" "$_ft"
        [[ -n "$_hint" ]] && echo "                   → ${_hint}"
    done

    echo ""
    if [[ -n "$_bottleneck_feat" ]]; then
        echo "Bottleneck: ${_bottleneck_feat} (${_bottleneck_score}/100) — fix this first."
    fi
else
    # --- JSON output (default) ---
    echo "{"
    echo "  \"synthesized_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"features\": {"

    first=true
    for ((_i=0; _i<${#_feat_names[@]}; _i++)); do
        $first || echo ","
        first=false
        echo -n "    \"${_feat_names[$_i]}\": ${_feat_results[$_i]}"
    done

    echo ""
    echo "  },"
    echo "  \"product_score\": $product_score,"
    echo "  \"confidence\": \"$product_confidence\","
    echo "  \"tiers_filled\": $min_tiers,"
    echo "  \"total_weight\": $product_total_weight"
    echo "}"
fi
