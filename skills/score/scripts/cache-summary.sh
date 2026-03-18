#!/usr/bin/env bash
# cache-summary.sh — Quick view of all tier caches and staleness
# Zero context cost: run this to see what data is available before scoring

set -uo pipefail

PROJECT_DIR="${1:-.}"
NOW=$(date +%s)

staleness() {
    local file="$1"
    local field="${2:-cached_at}"
    if [[ ! -f "$file" ]]; then
        echo "missing"
        return
    fi
    local ts
    ts=$(jq -r ".$field // .assessed_at // .analyzed_at // empty" "$file" 2>/dev/null)
    if [[ -z "$ts" ]]; then
        # Fall back to file modification time
        ts=$(date -r "$file" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
    fi
    if [[ -z "$ts" ]]; then
        echo "unknown"
        return
    fi
    local epoch
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || date -d "$ts" +%s 2>/dev/null || echo "0")
    local age=$(( NOW - epoch ))
    [[ $age -lt 0 ]] && age=0
    if [[ $age -lt 3600 ]]; then
        echo "$((age / 60))m ago"
    elif [[ $age -lt 86400 ]]; then
        echo "$((age / 3600))h ago"
    else
        echo "$((age / 86400))d ago"
    fi
}

confidence() {
    local file="$1"
    local fresh_secs="$2"
    local acceptable_secs="$3"
    if [[ ! -f "$file" ]]; then
        echo "none"
        return
    fi
    local ts
    ts=$(jq -r ".cached_at // .assessed_at // .analyzed_at // empty" "$file" 2>/dev/null)
    if [[ -z "$ts" ]]; then
        echo "low"
        return
    fi
    local epoch
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || date -d "$ts" +%s 2>/dev/null || echo "0")
    local age=$(( NOW - epoch ))
    if [[ $age -lt $fresh_secs ]]; then
        echo "high"
    elif [[ $age -lt $acceptable_secs ]]; then
        echo "medium"
    else
        echo "low"
    fi
}

echo "score tier cache status"
echo "───────────────────────────────────"

# Tier 1: Health
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
echo -n "health      "
if [[ -f "$SCORE_CACHE" ]]; then
    score=$(jq -r '.score // "?"' "$SCORE_CACHE" 2>/dev/null)
    echo "$score  $(staleness "$SCORE_CACHE")  confidence:$(confidence "$SCORE_CACHE" 300 1800)"
else
    echo "no cache"
fi

# Tier 2: Code eval
EVAL_CACHE="$PROJECT_DIR/.claude/cache/eval-cache.json"
echo -n "code eval   "
if [[ -f "$EVAL_CACHE" ]]; then
    feat_count=$(jq 'length' "$EVAL_CACHE" 2>/dev/null || echo "0")
    # Use first feature's cached_at as proxy
    first_ts=$(jq -r 'to_entries[0].value.cached_at // empty' "$EVAL_CACHE" 2>/dev/null)
    if [[ -n "$first_ts" ]]; then
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$first_ts" +%s 2>/dev/null || echo "0")
        age=$(( NOW - epoch ))
        if [[ $age -lt 86400 ]]; then
            conf="high"
        elif [[ $age -lt 172800 ]]; then
            conf="medium"
        else
            conf="low"
        fi
        if [[ $age -lt 3600 ]]; then
            age_str="$((age / 60))m ago"
        elif [[ $age -lt 86400 ]]; then
            age_str="$((age / 3600))h ago"
        else
            age_str="$((age / 86400))d ago"
        fi
        echo "${feat_count} features  ${age_str}  confidence:${conf}"
    else
        echo "${feat_count} features  age unknown  confidence:low"
    fi
else
    echo "no cache"
fi

# Tier 3: Visual (taste)
TASTE_DIR="$PROJECT_DIR/.claude/evals/reports"
echo -n "visual      "
latest_taste=$(ls -t "$TASTE_DIR"/taste-*.json 2>/dev/null | head -1)
if [[ -n "$latest_taste" ]]; then
    echo "$(basename "$latest_taste")  $(staleness "$latest_taste")  confidence:$(confidence "$latest_taste" 172800 345600)"
else
    echo "no data"
fi

# Tier 4: Behavioral (flows)
echo -n "behavioral  "
latest_flows=$(ls -t "$TASTE_DIR"/flows-*.json 2>/dev/null | head -1)
if [[ -n "$latest_flows" ]]; then
    blockers=$(jq '[.issues[]? | select(.severity == "blocker")] | length' "$latest_flows" 2>/dev/null || echo "?")
    echo "$(basename "$latest_flows")  blockers:${blockers}  $(staleness "$latest_flows")  confidence:$(confidence "$latest_flows" 172800 345600)"
else
    echo "no data"
fi

# Tier 5: Viability
VIABILITY_CACHE="$PROJECT_DIR/.claude/cache/viability-cache.json"
echo -n "viability   "
if [[ -f "$VIABILITY_CACHE" ]]; then
    echo "$(staleness "$VIABILITY_CACHE")  confidence:$(confidence "$VIABILITY_CACHE" 259200 518400)"
else
    echo "no data (capped at 30 without agents)"
fi

# Market intelligence sources
echo ""
echo "intelligence sources"
echo "───────────────────────────────────"
for f in market-context.json customer-intel.json; do
    path="$PROJECT_DIR/.claude/cache/$f"
    echo -n "$(printf '%-20s' "$f")"
    if [[ -f "$path" ]]; then
        echo "$(staleness "$path")"
    else
        echo "missing"
    fi
done
for f in strategy.yml product-spec.yml; do
    path="$PROJECT_DIR/.claude/plans/$f"
    [[ "$f" == "product-spec.yml" ]] && path="$PROJECT_DIR/config/$f"
    echo -n "$(printf '%-20s' "$f")"
    if [[ -f "$path" ]]; then
        echo "present"
    else
        echo "missing"
    fi
done
