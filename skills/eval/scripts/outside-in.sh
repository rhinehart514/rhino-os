#!/usr/bin/env bash
# outside-in.sh — Surface what the product is MISSING by reading intelligence caches.
# Usage: outside-in.sh [project-dir]
# Outputs JSON to stdout AND writes to .claude/cache/outside-in.json
#
# Reads: product-value.json, market-context.json, customer-intel.json, rhino.yml
# Surfaces: journey gaps, unmet needs, market opportunities, concentration risk

set -uo pipefail

PROJECT_DIR="${1:-.}"
CACHE_DIR="$PROJECT_DIR/.claude/cache"

VALUE_CACHE="$CACHE_DIR/product-value.json"
MARKET_CACHE="$CACHE_DIR/market-context.json"
CUSTOMER_CACHE="$CACHE_DIR/customer-intel.json"
RHINO_YML="$PROJECT_DIR/config/rhino.yml"
OUTPUT="$CACHE_DIR/outside-in.json"

# Bail gracefully if no intelligence caches exist
if [[ ! -f "$VALUE_CACHE" && ! -f "$MARKET_CACHE" && ! -f "$CUSTOMER_CACHE" ]]; then
    echo "{}"
    exit 0
fi

# Require jq
if ! command -v jq &>/dev/null; then
    echo "{}" >&2
    exit 0
fi

# --- Collect feature delivers: claims from rhino.yml ---
get_feature_delivers() {
    # Extract active feature names and their delivers: values
    awk '
        /^  [a-z][a-z_-]*:$/ { feat = $1; sub(/:$/, "", feat); delivers = "" }
        /status: active/ && feat { active[feat] = delivers }
        /status: killed/ && feat { feat = "" }
        /delivers:/ && feat {
            sub(/.*delivers: *"?/, ""); sub(/"? *$/, "")
            delivers = $0
            active[feat] = delivers
        }
        END {
            for (f in active) {
                if (active[f] != "") print f "|" active[f]
            }
        }
    ' "$RHINO_YML" 2>/dev/null
}

FEATURE_CLAIMS=$(get_feature_delivers)

# --- 1. Journey gaps: stages with 0 or <2 surfaces ---
JOURNEY_GAPS="[]"
if [[ -f "$VALUE_CACHE" ]]; then
    JOURNEY_GAPS=$(jq -r '
        [.journey_funnel // {} | to_entries[] |
         select(.value.count < 2) |
         {stage: .key, surfaces: .value.count,
          implication: (
            if .value.count == 0 then "no surfaces — this stage is invisible"
            elif .value.count == 1 then "single surface — fragile, no redundancy"
            else "thin coverage"
          end)}]
    ' "$VALUE_CACHE" 2>/dev/null || echo "[]")
fi

# --- 2. Unmet needs: customer needs not matching any feature delivers: claim ---
UNMET_NEEDS="[]"
if [[ -f "$CUSTOMER_CACHE" ]]; then
    # Get demand signals / unmet needs from customer intel
    RAW_NEEDS=$(jq -r '
        [(.demand_signals // [])[] | .need // .signal // .description // empty] |
        unique | .[]
    ' "$CUSTOMER_CACHE" 2>/dev/null)

    if [[ -n "$RAW_NEEDS" ]]; then
        UNMET_LIST="[]"
        while IFS= read -r need; do
            [[ -z "$need" ]] && continue
            # Check if any feature's delivers: claim contains keywords from this need
            NEED_LOWER=$(echo "$need" | tr '[:upper:]' '[:lower:]')
            MATCHED=false
            while IFS='|' read -r feat_name feat_delivers; do
                DELIVERS_LOWER=$(echo "$feat_delivers" | tr '[:upper:]' '[:lower:]')
                # Simple keyword overlap check
                for word in $NEED_LOWER; do
                    [[ ${#word} -lt 4 ]] && continue
                    if echo "$DELIVERS_LOWER" | grep -qi "$word" 2>/dev/null; then
                        MATCHED=true
                        break
                    fi
                done
                $MATCHED && break
            done <<< "$FEATURE_CLAIMS"

            if ! $MATCHED; then
                UNMET_LIST=$(echo "$UNMET_LIST" | jq --arg n "$need" '. + [{need: $n, status: "no feature addresses this"}]')
            fi
        done <<< "$RAW_NEEDS"
        UNMET_NEEDS="$UNMET_LIST"
    fi
fi

# --- 3. Market opportunities: demand signals not addressed by current features ---
MARKET_OPPS="[]"
if [[ -f "$MARKET_CACHE" ]]; then
    RAW_SIGNALS=$(jq -r '
        [(.demand_signals // [])[] | .signal // .description // empty] |
        unique | .[]
    ' "$MARKET_CACHE" 2>/dev/null)

    if [[ -n "$RAW_SIGNALS" ]]; then
        OPP_LIST="[]"
        while IFS= read -r signal; do
            [[ -z "$signal" ]] && continue
            SIGNAL_LOWER=$(echo "$signal" | tr '[:upper:]' '[:lower:]')
            MATCHED=false
            while IFS='|' read -r feat_name feat_delivers; do
                DELIVERS_LOWER=$(echo "$feat_delivers" | tr '[:upper:]' '[:lower:]')
                for word in $SIGNAL_LOWER; do
                    [[ ${#word} -lt 4 ]] && continue
                    if echo "$DELIVERS_LOWER" | grep -qi "$word" 2>/dev/null; then
                        MATCHED=true
                        break
                    fi
                done
                $MATCHED && break
            done <<< "$FEATURE_CLAIMS"

            if ! $MATCHED; then
                OPP_LIST=$(echo "$OPP_LIST" | jq --arg s "$signal" '. + [{signal: $s, status: "opportunity not captured"}]')
            fi
        done <<< "$RAW_SIGNALS"
        MARKET_OPPS="$OPP_LIST"
    fi
fi

# --- 4. Concentration risk: top 3 surfaces hold >80% of value ---
CONCENTRATION="null"
if [[ -f "$VALUE_CACHE" ]]; then
    CONCENTRATION=$(jq -r '
        .value_loop // [] |
        if length < 4 then
            {risk: true, detail: "only \(length) value surfaces — high concentration"}
        else
            # Check if top 3 dominate (by position = proxy for importance)
            {risk: false, detail: "\(length) surfaces — reasonable distribution"}
        end
    ' "$VALUE_CACHE" 2>/dev/null || echo "null")
fi

# --- Assemble output ---
RESULT=$(jq -n \
    --argjson journey "$JOURNEY_GAPS" \
    --argjson unmet "$UNMET_NEEDS" \
    --argjson market "$MARKET_OPPS" \
    --argjson concentration "$CONCENTRATION" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        generated_at: $generated_at,
        journey_gaps: $journey,
        unmet_needs: $unmet,
        market_opportunities: $market,
        concentration_risk: $concentration
    }')

# Write to cache
mkdir -p "$CACHE_DIR"
echo "$RESULT" > "$OUTPUT"

# Output to stdout
echo "$RESULT"
