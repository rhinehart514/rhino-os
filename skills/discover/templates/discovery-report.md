# Discovery Report Template

## Define mode (new product or existing product spec generation)

```
◆ discover — [scope]

  v[X.Y] · product: **[pct]%** · score: [N]
  spec quality: [N]/100 — [STRONG|DECENT|WEAK|SKELETON]

⎯⎯ who ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  person: [specific person in specific situation]
  pain: [current pain]
  evidence: [how we know this person exists]

⎯⎯ what changes ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  before: [what they do today]
  after: [what's different]
  in one sentence: [the pitch]

⎯⎯ core loop ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  trigger → action → reward
  frequency: [how often]

⎯⎯ wired ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ product-spec.yml — written to config/
  ✓ roadmap — thesis: "[thesis from spec]"
  ✓ features — N created (core-loop w:5, first-experience w:4, return-trigger w:4)
  ✓ assertions — M generated from signals + claims
  ✓ strategy — populated from competitors + why_now
  ✓ rhino.yml — value section written

⎯⎯ tasks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  · [task 1 — what needs doing]
  · [task 2 — what needs doing]
  · [task 3 — what needs doing]

/plan             start building from the spec
/go               autonomous build loop
/discover refine  pressure-test the spec
```

## Refine mode

```
◆ discover refine

  spec quality: [before] → [after]

⎯⎯ attacks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  who: [attack + result]
  change: [attack + result]
  core_loop: [attack + result]
  not_building: [attack + result]
  why_now: [attack + result]
  pricing: [attack + result]

⎯⎯ updated ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [N] sections strengthened
  [M] sections still weak

⎯⎯ tasks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  · [evidence to gather]
  · [claims to test]

/discover refine  attack again
/go               build with the refined spec
/research [gap]   dig into a weak section
```

## Pivot mode

```
◆ discover pivot

  spec quality: [N]/100
  evidence against current spec:
    · [wrong prediction or failing assertion]
    · [stale thesis evidence]

⎯⎯ proposed pivots ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  1. [specific pivot] — because [evidence]
     changes: [what fields in spec]
     wiring: [what features/assertions/roadmap change]
     lose: [what you give up]
     gain: [what you get]

  2. [specific pivot] — because [evidence]
     ...

⎯⎯ tasks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  · [pivot execution tasks]

/discover refine  refine after pivot
/plan             re-plan with new direction
/strategy         check strategic alignment
```

## Compare mode (vs)

```
◆ discover vs — [project name]

⎯⎯ competitive map ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  they have / we don't:
    · [capability] — [competitor] · [table stakes | differentiating]

  we have / they don't:
    · [capability] — [real advantage or just different?]

  nobody has:
    · [capability] — [novel opportunity]

  our differentiator: [one sentence]
  is it real? [yes/no — why]

⎯⎯ tasks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  · [gaps to close or document]

/go [feature]     build a competitive gap
/research market  deeper analysis
/strategy         update competitive positioning
```

## Systems mode

Uses the full systems map format from the original /discover — see references/discovery-guide.md for the systems decomposition approach.

## Formatting rules

- Header: `◆ discover — [scope]` with state bar
- Full dividers (`⎯⎯`) between major zones
- Spec quality score shown on every output
- Wiring status shown after define mode
- Tasks ALWAYS generated — every session produces work items
- Bottom: exactly 3 next commands, contextual to mode
- No ASCII tables in output body — use compact pulse format
