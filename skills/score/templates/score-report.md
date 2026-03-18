# Score Report Templates

## Full score output

```
▾ product score: [SCORE]/100  ●●●○○ (3/5 tiers)  [sparkline] [delta]

  health    [pass|fail]  (gate)
  ─────────────────────────────────────

  [feature_name]  [SCORE]/100  w:[weight]  ●●●○○
    delivery    ██████████████░░░░░░  [D]/100  (eval)
    craft       ████████████░░░░░░░░  [C]/100  (eval)
    visual      ████████████████░░░░  [V]/100  (taste)  [or "no data"]
    behavioral  ██████████████████░░  [B]/100  (flows)  [or "no data"]
    viability   ██████████░░░░░░░░░░  [Vi]/100 (source: agents|intelligence|capped)

  [repeat for each feature]

  ─────────────────────────────────────
  stale tiers: [list of stale tiers with ages]
  missing tiers: [list of unavailable tiers]
  weight redistribution: [if any tiers missing, show adjusted weights]

  ▸ [next command suggestion based on weakest tier/feature]
```

**Rules:**
- Always show tier fill badge (●●●○○) at product level and per feature
- Always show sparkline from `rhino score . --trend` if history exists
- Show viability source (agents/intelligence/capped) — never hide where the number comes from
- Show score delta vs previous unified score if available

## Quick mode output

```
▾ product score: [SCORE]/100  ●●○○○  (cached, [age])

  [feature]  [SCORE]  d:[D] c:[C] vi:[Vi]([source])  ●●○○○
  [feature]  [SCORE]  d:[D] c:[C] vi:[Vi]([source])  ●●○○○

  stale: [tier list]
  ▸ /score deep for fresh data
```

## Breakdown mode output

```
▾ score breakdown  ●●●●○ (4/5 tiers)

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
    source: [agents|intelligence|capped]
    cached: [age]  confidence: [level]
    [feature]: [score]  uvp:[N] gap:[N] demand:[N] position:[N]
    intelligence: market-context [age], customer-intel [age], strategy [age]
```

## Viability-only output

```
▾ viability assessment  confidence: [level]  source: [agents|intelligence|capped]

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
- Historical trend via `rhino score . --trend`
- Task suggestions from weakest tier
