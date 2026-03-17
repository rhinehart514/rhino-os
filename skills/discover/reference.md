# /discover Reference — Output Templates

Loaded on demand. Phases, modes, and routing are in SKILL.md.

---

## Full discovery output

```
◆ discover — [scope]

  v[X.Y] · product: **[pct]%** · score: [N]
  thesis: "[current thesis]"
  velocity: [N] commits/month

⎯⎯ product ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [one paragraph: what this product is, who it's for, what stage]

  journey: [user path through the product]
  value moment: [where value happens]
  dead ends: [where journey stops]

  ⚠ [the one contradiction, if any]

⎯⎯ systems ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▸ **[System Name]** — [type] · [exists/missing] · [market position] · [S/M/L]
    does: [what the user gets]
    eval: [score] (d:[N] c:[N] v:[N]) — or "no code"
    weakest: [which sub-score and why]
    depends on: [systems]
    enables: [what breaks without this]
    priority: [1-5]

  ▸ **[System Name]** — [type] · [exists/missing] · [market position] · [S/M/L]
    does: [what the user gets]
    eval: [score] (d:[N] c:[N] v:[N])
    depends on: [systems]
    priority: [N]

  critical path:
    1. [system] — [why first]
    2. [system] — [why second]
    3. [system] — [why third]

  kill:
    ✗ [feature/system] — [why] · frees [what]

⎯⎯ recommend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▸ **[Missing System]** — [type] · [S/M/L]
    why: [what the product can't do without it]
    user story: [walk through the interaction]
    changes: [what moves in the product map]
    second-order: [cascade]
    kills it: [failure mode]
    evidence: [cite]
    draft features:
      · [feature 1]
      · [feature 2]
    draft assertions:
      · [belief 1]
      · [belief 2]

  ▸ **[Ambitious]** — [type] · [S/M/L]
    why: [novel, high learning value]
    kills it: [failure mode]

  ▸ **[Practical]** — [type] · [S/M/L]
    why: [table stakes or level-up]
    kills it: [failure mode]

  bias: [clean | flagged — [what + counter-evidence]]

⎯⎯ validate ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  testing: "[riskiest assumption]"
  finding: [2-3 sentences]
  evidence: [HIGH/MEDIUM/LOW]
  verdict: [✓/✗/◐]

⎯⎯ discovery ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  recommend: **[system]**
  confidence: [level] — [why]
  size: [S/M/L] · ~[N] sessions
  critical path: [position]
  thesis: [advances or not]

  track record: [N] recommended → [N] built → [N] succeeded

/go [system]         build the recommendation
/research [topic]    dig deeper before building
/feature new [name]  register it as a feature
```

## New product mode output

```
◆ discover new — "[idea]"

  v0.1 · product: **0%** · no code yet

⎯⎯ idea ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  idea: "[founder's description]"
  for: [specific person]
  today: [what they do without this]
  hook: [why they'd try it]

⎯⎯ systems ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [5-8 systems with full format]

  mvp systems (minimum loveable):
    1. [system] — [why essential]
    2. [system] — [why essential]
    3. [system] — [why essential]

  defer to v2:
    · [system] — [why not yet]

  riskiest assumption: [the one that kills it]

⎯⎯ validate ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [validation of riskiest assumption]

/onboard             bootstrap with this hypothesis
/research [topic]    validate before building
/ideate              brainstorm features for the MVP
```

## Competitive mode output (`/discover vs`)

```
◆ discover vs — [project name]

  v[X.Y] · product: **[pct]%** · score: [N]

⎯⎯ competitive systems ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  they have / we don't:
    · [system] — [competitor] has this, table stakes
    · [system] — [competitor] has this, differentiating

  we have / they don't:
    · [system] — our advantage
    · [system] — our advantage

  nobody has:
    · [system idea] — novel opportunity

⎯⎯ recommend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  steal: **[system]** — adapt [competitor]'s approach
  leapfrog: **[system]** — build what nobody has

/go [system]         build the recommendation
/research market     deeper competitive analysis
/strategy            check if this changes the bottleneck
```

## Inversion mode output (`/discover invert`)

```
◆ discover invert — [project name]

  v[X.Y] · product: **[pct]%** · score: [N]

⎯⎯ failure modes ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ [failure mode 1] — likelihood: HIGH · defense: LOW
    prevents: [what system would prevent this]
  ⚠ [failure mode 2] — likelihood: MEDIUM · defense: MEDIUM
    prevents: [what system would prevent this]
  · [failure mode 3] — likelihood: LOW · defense: HIGH
    defense: [existing system that handles this]

  most vulnerable: **[failure mode]**

⎯⎯ recommend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▸ **[Defensive System]** — trust · [S/M/L]
    prevents: [the most vulnerable failure mode]
    evidence: [why this is the right defense]

/go [system]         build the defense
/strategy            check alignment
/discover systems    full systems audit
```

## Formatting rules

- Header: `◆ discover — [scope]` with state bar
- Full dividers (`⎯⎯`) between major zones: product, systems, recommend, validate, discovery
- Systems: `▸ **[Name]** — [type]` with eval sub-scores when available
- Critical path: numbered list with justification
- Kill list: `✗` prefix with reason and what it frees
- Recommendations: 1 primary + 2 alternatives, each with kills-it field
- Bias check: explicit — `clean` or `flagged` with counter-evidence
- Validation: predict/finding/evidence/verdict compact block
- Discovery synthesis: bold system name, confidence, size, path position
- Track record: shown when discovery-history.tsv has past data
- Bottom: exactly 3 next commands
