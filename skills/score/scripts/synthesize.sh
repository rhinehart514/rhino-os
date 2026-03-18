#!/usr/bin/env bash
# synthesize.sh — Compute unified score from all tier caches
# Usage: synthesize.sh [project-dir] [feature]
# Outputs JSON with per-feature unified scores and product total

set -uo pipefail

PROJECT_DIR="${1:-.}"
TARGET_FEATURE="${2:-}"

EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
VIABILITY_CACHE="$PROJECT_DIR/.claude/cache/viability-cache.json"
RHINO_YML="$PROJECT_DIR/config/rhino.yml"
TASTE_DIR="$PROJECT_DIR/.claude/evals/reports"

# --- Read feature weights from rhino.yml ---
get_feature_weight() {
    local feat="$1"
    # Extract weight from rhino.yml features section
    local w
    w=$(grep -A 10 "^  ${feat}:" "$RHINO_YML" 2>/dev/null | grep "weight:" | head -1 | awk '{print $2}')
    echo "${w:-1}"
}

get_active_features() {
    # Parse YAML: find feature names where status: active follows within 10 lines
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
        jq -r --arg f "$feat" '.[$f] // {} | "\(.delivery_score // 0) \(.craft_score // 0)"' "$EVAL_CACHE" 2>/dev/null
    else
        echo "0 0"
    fi
}

# --- Read latest taste report (tier 3: visual) ---
get_visual_score() {
    local latest
    latest=$(ls -t "$TASTE_DIR"/taste-*.json 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "-1"  # -1 = no data
        return
    fi
    # Average across all dimensions
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
        echo "-1"  # -1 = no data
        return
    fi
    # Convert issue list to score: 100 - blockers*25 - majors*10 - minors*3
    jq -r '
        def count_severity(s): [.issues[]? | select(.severity == s)] | length;
        100 - (count_severity("blocker") * 25) - (count_severity("major") * 10) - (count_severity("minor") * 3) |
        if . < 0 then 0 else . end
    ' "$latest" 2>/dev/null || echo "-1"
}

# --- Read viability cache (tier 5) ---
get_viability_score() {
    local feat="$1"
    if [[ -f "$VIABILITY_CACHE" ]]; then
        jq -r --arg f "$feat" '.features[$f].viability_score // -1' "$VIABILITY_CACHE" 2>/dev/null
    else
        echo "-1"
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

    local visual
    visual=$(get_visual_score)
    local behavioral
    behavioral=$(get_behavioral_score)
    local viability
    viability=$(get_viability_score "$feat")

    # Determine available tiers and weights
    local has_visual=true has_behavioral=true has_viability=true
    [[ "$visual" == "-1" ]] && has_visual=false
    [[ "$behavioral" == "-1" ]] && has_behavioral=false
    [[ "$viability" == "-1" ]] && has_viability=false

    local score
    if $has_visual && $has_behavioral && $has_viability; then
        # All tiers: d*40 + c*25 + v*15 + b*10 + vi*10
        score=$(( delivery * 40 / 100 + craft * 25 / 100 + visual * 15 / 100 + behavioral * 10 / 100 + viability * 10 / 100 ))
    elif $has_visual && $has_behavioral && ! $has_viability; then
        # No viability: cap viability at 30, use default weights
        viability=30
        score=$(( delivery * 40 / 100 + craft * 25 / 100 + visual * 15 / 100 + behavioral * 10 / 100 + viability * 10 / 100 ))
    elif ! $has_visual && ! $has_behavioral && $has_viability; then
        # Code + viability only: d*50 + c*30 + vi*20
        score=$(( delivery * 50 / 100 + craft * 30 / 100 + viability * 20 / 100 ))
    elif ! $has_visual && ! $has_behavioral && ! $has_viability; then
        # Code only: d*60 + c*40, viability capped at 30
        viability=30
        score=$(( delivery * 60 / 100 + craft * 40 / 100 ))
    else
        # Partial: just weighted average of what's available
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
        if $has_viability; then
            weighted_sum=$(( weighted_sum + viability * 10 ))
            total_weight=$(( total_weight + 10 ))
        fi
        score=$(( weighted_sum / total_weight ))
    fi

    # Clamp
    [[ $score -gt 100 ]] && score=100
    [[ $score -lt 0 ]] && score=0

    # Determine confidence
    local confidence="high"
    $has_visual || confidence="medium"
    $has_behavioral || confidence="medium"
    $has_viability || { [[ "$confidence" != "low" ]] && confidence="low"; }

    # Output JSON
    local vi_out
    $has_viability && vi_out="$viability" || vi_out="30"
    local vis_out
    $has_visual && vis_out="$visual" || vis_out="null"
    local beh_out
    $has_behavioral && beh_out="$behavioral" || beh_out="null"

    echo "{\"feature\":\"$feat\",\"score\":$score,\"delivery\":$delivery,\"craft\":$craft,\"visual\":$vis_out,\"behavioral\":$beh_out,\"viability\":$vi_out,\"confidence\":\"$confidence\",\"weight\":$(get_feature_weight "$feat")}"
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

while IFS= read -r feat; do
    [[ -z "$feat" ]] && continue
    $first || echo ","
    first=false

    result=$(compute_feature_score "$feat")
    feat_score=$(echo "$result" | jq -r '.score')
    feat_weight=$(echo "$result" | jq -r '.weight')

    product_weighted_sum=$(( product_weighted_sum + feat_score * feat_weight ))
    product_total_weight=$(( product_total_weight + feat_weight ))

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

echo "  \"product_score\": $product_score,"
echo "  \"total_weight\": $product_total_weight"
echo "}"
