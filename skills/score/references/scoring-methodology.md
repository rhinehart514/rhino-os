# Scoring Methodology

## Tier Weights

Default weights (all tiers available):

| Tier | Weight | Source | What it measures |
|------|--------|--------|-----------------|
| Health | gate | `rhino score .` | Build passes, structure, hygiene. < 20 = score 0. |
| Delivery | 40% | `/eval` | Does the code deliver real value? |
| Craft | 25% | `/eval` | Is the code well-made? |
| Visual | 15% | `/taste` | Does the rendered product look good? |
| Behavioral | 10% | `/taste flows` | Does the frontend actually work? |
| Viability | 10% | agents/intelligence | Would this survive the market? |

**Formula:** `delivery*0.40 + craft*0.25 + visual*0.15 + behavioral*0.10 + viability*0.10`

## Weight Redistribution

When tiers are unavailable (no URL, no Playwright, no agent data), redistribute:

| Missing | Redistribution |
|---------|---------------|
| Visual only | delivery 45%, craft 30%, behavioral 10%, viability 15% |
| Behavioral only | delivery 45%, craft 25%, visual 15%, viability 15% |
| Visual + Behavioral | delivery 50%, craft 30%, viability 20% |
| Viability only | delivery 45%, craft 30%, visual 15%, behavioral 10% |

Always flag redistributed tiers in output.

## Staleness Thresholds

| Tier | Fresh | Acceptable | Stale |
|------|-------|-----------|-------|
| Health | < 5min | < 30min | > 30min |
| Code eval | < 24h | < 48h | > 48h |
| Visual | < 48h | < 96h | > 96h |
| Behavioral | < 48h | < 96h | > 96h |
| Viability | < 72h | < 144h | > 144h |

Fresh = high confidence. Acceptable = medium confidence. Stale = low confidence.

## Confidence Computation

Per-tier confidence: high/medium/low based on staleness table above.
Product confidence: minimum across all available tiers.
Missing tier: always counts as low confidence.

## Behavioral Score Conversion

Flows reports produce issue lists, not scores. Convert:

```
behavioral_score = 100 - (blockers * 25) - (majors * 10) - (minors * 3)
```

Floor at 0. A single blocker drops behavioral to 75. Two blockers = 50.

## Viability Score Components

Four sub-dimensions, 25 points each:

| Component | What it measures | Evidence source |
|-----------|-----------------|----------------|
| UVP clarity | Can you state what's unique in one sentence? | product-spec.yml |
| Competitive gap | Something no competitor has? | market-context.json |
| Demand signal | People actually want this? | customer-intel.json |
| Positioning | Clear stage-appropriate position? | strategy.yml |

**Viability source hierarchy:**
1. **Agent-backed** (viability-cache.json): full range 0-100. Authoritative.
2. **Both intelligence files** (market-context.json + customer-intel.json): capped at 60.
3. **One intelligence file**: capped at 45.
4. **No data**: capped at 30.

Agents are the refresh mechanism, not the only path. `synthesize.sh` reads intelligence files directly. Only spawn agents when viability-cache.json is stale (>72h) AND intelligence files are missing or stale (>7d).

## Per-Feature vs Product Score

Each feature gets its own unified score across all tiers.
Product score = weighted average of feature scores (using `weight:` from rhino.yml).

```
product_score = sum(feature_score * feature_weight) / sum(feature_weight)
```

Only active features are included.

## Stage Ceilings

From rhino.yml integrity settings:

| Stage | Score ceiling | Justification required above |
|-------|--------------|----------------------------|
| mvp | 65 | Any score above needs external validation |
| early | 80 | Scores 75+ need named evidence |
| growth | 90 | Near-perfect needs user data |
| mature | 95 | Only external proof breaks 90 |
