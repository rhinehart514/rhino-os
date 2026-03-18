#!/usr/bin/env bash
# synthesize.sh — Compute unified score from all tier caches
# Usage: synthesize.sh [project-dir] [feature]
# Outputs JSON with per-feature unified scores and product total
#
# Viability: reads viability-cache.json first (agent-backed).
# Falls back to scoring from accumulated intelligence files
# (market-context.json + customer-intel.json). No intelligence = capped at 30.

set -uo pipefail

PROJECT_DIR="${1:-.}"
TARGET_FEATURE="${2:-}"

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

# --- Read eval cache (tier 2: delivery + craft) ---
get_eval_scores() {
    local feat="$1"
    if [[ -f "$EVAL_CACHE" ]]; then
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
    jq -r '
        [.dimensions // {} | to_entries[] | .value.score // 0] |
        if length > 0 then (add / length | floor) else -1 end
    ' "$latest" 2>/dev/null || echo "-1"
}

# --- Read latest flows report (tier 4: behavioral) ---
get_behavioral_score() {
    local latest
    latest=$(ls -t "$TASTE_DIR"/flows-*.json 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "-1"
        return
    fi
    jq -r '
        def count_severity(s): [.issues[]? | select(.severity == s)] | length;
        100 - (count_severity("blocker") * 25) - (count_severity("major") * 10) - (count_severity("minor") * 3) |
        if . < 0 then 0 else . end
    ' "$latest" 2>/dev/null || echo "-1"
}

# --- Read viability (tier 5) ---
# Priority: viability-cache.json (agent-backed) > intelligence-derived > cap at 30
get_viability_score() {
    local feat="$1"

    # 1. Agent-backed viability cache (authoritative)
    if [[ -f "$VIABILITY_CACHE" ]]; then
        local v
        v=$(jq -r --arg f "$feat" '.features[$f].viability // -1' "$VIABILITY_CACHE" 2>/dev/null)
        if [[ "$v" != "-1" && "$v" != "null" ]]; then
            echo "$v"
            return
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
echo "{"
echo "  \"synthesized_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
echo "  \"features\": {"

features=$(get_active_features)
if [[ -n "$TARGET_FEATURE" ]]; then
    features="$TARGET_FEATURE"
fi

first=true
product_weighted_sum=0
product_total_weight=0
min_tiers=5

while IFS= read -r feat; do
    [[ -z "$feat" ]] && continue
    $first || echo ","
    first=false

    result=$(compute_feature_score "$feat")
    feat_score=$(echo "$result" | jq -r '.score')
    feat_weight=$(echo "$result" | jq -r '.weight')
    feat_tiers=$(echo "$result" | jq -r '.tiers')

    product_weighted_sum=$(( product_weighted_sum + feat_score * feat_weight ))
    product_total_weight=$(( product_total_weight + feat_weight ))
    [[ $feat_tiers -lt $min_tiers ]] && min_tiers=$feat_tiers

    echo -n "    \"$feat\": $result"
done <<< "$features"

echo ""
echo "  },"

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

echo "  \"product_score\": $product_score,"
echo "  \"confidence\": \"$product_confidence\","
echo "  \"tiers_filled\": $min_tiers,"
echo "  \"total_weight\": $product_total_weight"
echo "}"
