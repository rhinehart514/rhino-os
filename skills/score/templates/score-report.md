# Score Report Templates

## Full score output

```
▾ product score: [SCORE]/100  confidence: [high|medium|low]

  health    [pass|fail]  (gate)
  ─────────────────────────────────────

  [feature_name]  [SCORE]/100  w:[weight]  confidence: [level]
    delivery    ██████████████░░░░░░  [D]/100  (eval)
    craft       ████████████░░░░░░░░  [C]/100  (eval)
    visual      ████████████████░░░░  [V]/100  (taste)  [or "no data"]
    behavioral  ██████████████████░░  [B]/100  (flows)  [or "no data"]
    viability   ██████████░░░░░░░░░░  [Vi]/100 (agents)
      uvp: [score]/25 — [evidence]
      gap: [score]/25 — [evidence]
      demand: [score]/25 — [evidence]
      position: [score]/25 — [evidence]

  [repeat for each feature]

  ─────────────────────────────────────
  stale tiers: [list of stale tiers with ages]
  missing tiers: [list of unavailable tiers]
  weight redistribution: [if any tiers missing, show adjusted weights]

  ▸ [next command suggestion based on weakest tier/feature]
```

## Quick mode output

```
▾ product score: [SCORE]/100  (cached, [age])

  [feature]  [SCORE]  d:[D] c:[C] v:[V] vi:[Vi]  confidence:[level]
  [feature]  [SCORE]  d:[D] c:[C] v:[V] vi:[Vi]  confidence:[level]

  stale: [tier list]
  ▸ /score deep for fresh data
```

## Breakdown mode output

```
▾ score breakdown

  tier 1: health
    score: [N]  cached: [age]  confidence: [level]
    structure: [N]  hygiene: [N]
    penalties: [list]

  tier 2: code eval
    cached: [age]  confidence: [level]
    [feature]: d:[D] c:[C]  gaps: [N]
    [feature]: d:[D] c:[C]  gaps: [N]

  tier 3: visual
    cached: [age]  confidence: [level]
    [dimension]: [score]  [dimension]: [score]  ...
    weakest: [dimension] at [score]

  tier 4: behavioral
    cached: [age]  confidence: [level]
    blockers: [N]  majors: [N]  minors: [N]
    converted score: [N]/100

  tier 5: viability
    cached: [age]  confidence: [level]
    [feature]: [score]  uvp:[N] gap:[N] demand:[N] position:[N]
    sources: market-context [age], customer-intel [age], strategy [age]
```

## Viability-only output

```
▾ viability assessment  confidence: [level]

  [feature]  [SCORE]/100
    uvp clarity:      [N]/25  [one-line evidence]
    competitive gap:  [N]/25  [one-line evidence]
    demand signal:    [N]/25  [one-line evidence]
    positioning:      [N]/25  [one-line evidence]

  sources:
    market-context.json  [fresh|stale|missing]  [age]
    customer-intel.json  [fresh|stale|missing]  [age]
    strategy.yml         [fresh|stale|missing]  [age]
    product-spec.yml     [fresh|stale|missing]  [age]

  ▸ [suggestion if sources missing or stale]
```

## Feature-scoped output

Same as full score but for one feature, with additional detail:
- All evidence citations expanded (not one-line)
- Cross-tier contradictions surfaced
- Historical trend if available (from eval-cache deltas)
- Task suggestions from weakest tier
