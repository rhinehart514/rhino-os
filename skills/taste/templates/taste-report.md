# Taste Output Templates

Use these templates for all taste output modes. Copy the structure exactly — the formatting is the product surface.

---

## Full evaluation

```
◆ taste — <url>                              <category>
  calibrated against: <refs or "uncalibrated">

  overall   **<score>**/100  ████████████████░░░░  [+/-delta]

  ▸ gates
    layout_coherence         <score>/100  [+/-delta]  <evidence>
    information_architecture <score>/100  [+/-delta]  <evidence>
    [CAPPED AT 30 — fix the skeleton before decorating]

  ▸ dimensions (weakest first)
    <dim>   <score>/100  [+/-delta]  <evidence>
                          rx: <prescription>
    <dim>   <score>/100  [+/-delta]  <evidence>
                          rx: <prescription>

  ▸ slop check
    <page>: <verdict>

  ▸ top 3 fixes
    1. <element> → <change> → <dim> +<N>pts
    2. <element> → <change> → <dim> +<N>pts
    3. <element> → <change> → <dim> +<N>pts

  ▸ trend (if past data exists)
    improving: <dims going up>
    stuck: <dims unchanged 3+ evals>
    regressing: <dims going down>

  ▸ past prescriptions (if past data exists)
    followed: <what was fixed>
    ignored: <what wasn't — and the cost>

  verdict: <would_return + one_thing>

/taste <url>          re-evaluate after changes
/todo                 capture the fixes
/go [feature]         build the top fix
```

## Report JSON structure

Write to `.claude/evals/reports/taste-{YYYY-MM-DD}.json`:

```json
{
  "url": "<URL>",
  "timestamp": "<ISO>",
  "overall": 0,
  "dimensions": {
    "<name>": {
      "score": 0,
      "previous": null,
      "delta": null,
      "evidence": "<first-person>",
      "prescription": "<fix or null>"
    }
  },
  "gates": { "layout_coherence": 0, "information_architecture": 0, "capped": false },
  "slop": { "detected": false, "pages": [], "anti_slop": [] },
  "strongest": "<dimension + why>",
  "weakest": "<dimension + why>",
  "would_return": "<yes/no + reason>",
  "one_thing": "<highest-impact change>",
  "top_3_fixes": [{ "element": "", "change": "", "impact": "" }],
  "routes_evaluated": 0,
  "meta": { "mode": "standard", "market_research": "cached|none", "has_past_eval": false }
}
```

## TSV append format

Append to `.claude/evals/taste-history.tsv` (create with header if missing):

```
date	url	overall	hierarchy	breathing_room	contrast	polish	emotional_tone	information_density	wayfinding	distinctiveness	scroll_experience	layout_coherence	information_architecture
```

---

## Trend

```
◆ taste trend

  overall: 42 → 48 → 55 ████████████░░░░░░░░ **improving**
  evals: [N] total · last: [date]

  ▸ improving
    hierarchy          32 → 45 → 58  ↑26
    contrast           40 → 52 → 55  ↑15

  ▸ stuck (3+ evals, <5pt change)
    breathing_room     38 → 40 → 41  — current approach exhausted

  ▸ regressing
    polish             55 → 52 → 48  ↓7

  ▸ prescription effectiveness
    followed: 4 of 6 prescriptions · avg impact: +8pts
    ignored: 2 prescriptions · cost: stuck dimensions

/taste <url>          re-evaluate
/go [feature]         fix stuck dimensions
/research [dim]       new approach for stuck
```

---

## Comparative (`/taste vs`)

```
◆ taste vs — <url1> vs <url2>

  dimension                 [site1]   [site2]   delta
  layout_coherence             62        78     -16  ↓
  hierarchy                    55        60      -5  ↓
  breathing_room               48        72     -24  ↓
  contrast                     70        65      +5  ↑
  polish                       42        88     -46  ↓

  ▸ steal list
    from [site2]: [specific element/pattern] → [dimension] +[N]pts
    from [site1]: [specific element/pattern] → [dimension] +[N]pts

  verdict: [site2] wins on craft, [site1] wins on [specific thing].
  Biggest gap: **polish** (-46pts) — [what to steal].

/taste <url>          re-evaluate after stealing
/clone <url>          clone the winning patterns
/go [feature]         build the improvements
```

---

## Calibrate

```
◆ taste calibrate

  --- founder profile ---

  ✓ written to ~/.claude/knowledge/founder-taste.md
    preferences: 3 loves, 2 anti-patterns
    pain: [current pain point]

  --- design system ---

  ✓ written to .claude/design-system.md
    tokens:      5 color, 4 spacing, 3 radius, 2 shadow, 3 typography
    components:  card, button, input, nav (4 patterns)
    rules:       6 anti-slop rules

  --- dimension knowledge ---

  calibrated: ████████░░░░  4/11
    hierarchy          ✓ researched
    breathing_room     ✓ researched
    ...

  ✓ calibration logged to .claude/cache/calibration-history.json

/taste <url>                  run with calibrated knowledge
/taste calibrate verify       check if calibration is working
/taste calibrate drift        check for score drift over time
```

---

## Verify (`/taste calibrate verify`)

```
◆ taste calibrate verify

  dimension              expected   actual   gap    status
  hierarchy              high       58       -12    ⚠ miscalibrated
  breathing_room         medium     41        +1    ✓ aligned
  contrast               high       70        +0    ✓ aligned
  polish                 high       48       -22    ✗ miscalibrated

  calibrated: 4/11 · aligned: 2/4 · miscalibrated: 2/4

/taste calibrate profile    update preferences
/taste <url>                re-evaluate
/taste calibrate drift      check for shifts over time
```

---

## Formatting rules

- Header: `◆ taste — <url>` with category suffix
- Gate dimensions shown first — if either <30, cap message shown
- Dimensions sorted weakest-first, each with evidence + prescription
- Prescriptions: `rx:` prefix, specific and actionable
- Top 3 fixes: numbered, element → change → dimension impact
- Trend: grouped by improving/stuck/regressing
- Comparative: column-aligned comparison table with deltas
- Calibrate: labeled dividers for profile, design system, dimensions
- Verify: alignment table with expected/actual/gap/status
- Verdict: one-sentence, would the user return + one thing to fix
- Bottom: exactly 3 next commands
