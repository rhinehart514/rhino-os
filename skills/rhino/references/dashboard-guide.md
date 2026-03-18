# Dashboard Guide

How to read and render every /rhino view. The source of truth for templates, conditional rendering, snapshot protocol, opinion logic, and pattern detection.

## Dashboard Zones (default view)

Four zones. Each dense, visual, earns its space.

### Zone 1: Header + Score

```
  ◆ [PROJECT NAME]  ·  v[X.Y]  ·  [N] skills  ·  [mode] mode

  "[value hypothesis]"
  for [specific user]

  score       **95**/100  ███████████████████░
              assertions 57/63  ·  health 85
              delivery 62  ·  craft 52  ·  viability 55
```

- Score = big number + bar + dimensions
- Value hypothesis from `config/rhino.yml` → `value.hypothesis`
- User from `config/rhino.yml` → `value.user`
- Version from `.claude-plugin/plugin.json` or roadmap.yml

### Zone 2: Thesis

```
  thesis      "[thesis text]"  **43%**
              ✓ proven-item  ◐ partial-item  · todo-item
```

- Thesis from roadmap.yml current version
- Evidence: ✓ = proven, ◐ = partial, · = todo
- Version completion = proven / total evidence

### Zone 3: Features

```
  features    product: **64%**

              scoring    ████████████████████  w:5  58  d:62 c:50 v:55  ↑4
              commands   ████████████░░░░░░░░  w:5  70  d:75 c:65 v:68  ↑2
              learning   ██████░░░░░░░░░░░░░░  w:4  48  d:55 c:40 v:48  ↓3  ←
```

- Bar width proportional to score (0-100 mapped to 20 chars)
- w: = weight from rhino.yml
- d/c/v = delivery/craft/viability sub-scores
- Delta: ↑N / ↓N / — (from eval-cache delta field)
- ← marks the bottleneck feature
- Sort by weight descending, then score ascending

### Zone 4: Signals + Opinion

```
  signals     predictions: 63% accurate (10/16)  ·  3 ungraded
              todos: 2 active · 5 backlog · 1 stale
              last session: 2.7 pts/move (3 moves, +8)
              last commit: [hash] [msg] · [time ago]

  ◆ **[feature]** is the bottleneck ([details])

  /go [feature]      build the bottleneck
  /strategy          honest diagnosis
  /help              everything you can do
```

- One bold opinion sentence
- Exactly 3 suggested commands at bottom

## Conditional Rendering

- No eval-cache → skip sub-scores, show pass rates only
- No sessions → skip "last session" line
- No roadmap → skip thesis zone
- No predictions → show "no predictions yet — /plan to start"
- No features → "no features — /onboard to start"
- Score zone always shows — it's the anchor
- No eval-cache but assertions exist → run `rhino eval . --score` inline
- Skip zones with no data entirely — don't show empty state

## Dashboard Snapshot Protocol

After every `/rhino` run (default view only), save current state to `.claude/cache/rhino-snapshots.json`:

```json
{
  "snapshots": [
    {
      "date": "2026-03-16T14:30:00",
      "score": 95,
      "product_completion": 64,
      "version_completion": 43,
      "feature_scores": {"scoring": 58, "commands": 70, "learning": 48},
      "prediction_accuracy": 63,
      "todo_counts": {"active": 2, "backlog": 5, "stale": 1},
      "bottleneck": "learning"
    }
  ]
}
```

Keep last 20 snapshots. Trim oldest on append.

---

## Compare View (`/rhino compare`)

Delta against last snapshot. Only show features that changed. Regressions marked `← regression`. Maturity transitions called out. Thesis evidence: show which items flipped.

```
  ◆ rhino compare  ·  vs [prev.date]

  score              95 → 97   +2
  product completion 64% → 68% +4
  version completion 43% → 48% +5

  ⎯⎯ features ⎯⎯

  scoring    58 → 62  +4   matured: building → working
  commands   70 → 70  —
  learning   48 → 45  -3   ← regression

  ⎯⎯ signals ⎯⎯

  predictions   63% → 65%  +2
  thesis        2/4 → 3/4  +1  (◐ reach-plan → ✓)
  bottleneck    learning (unchanged)

  ◆ [opinion based on deltas]
```

If no snapshots exist: "First snapshot — comparison available next run."

---

## Health View (`/rhino health`)

System health audit. Is rhino-os itself working?

**Check four subsystems:**
1. **Hooks** — hook definitions vs scripts on disk (25%)
2. **Agents** — which agents have produced todos (25%)
3. **Skills** — which skills have assertion coverage (25%)
4. **Learning loop** — last prediction, ungraded count, experiment-learnings freshness (25%)

Letter grade A-F from subsystem health.

```
  ◆ rhino health  ·  grade: **B**

  hooks        8/8 scripts present  ✓
  agents       4/6 producing todos  · silent: reviewer, market-analyst
  skills       12/18 with assertions  · unmeasured: clone, calibrate, skill, onboard, research, ship
  learning     last prediction 1d ago  ·  3 ungraded  ·  latency 2.1d avg
               8 known · 4 uncertain · 3 unknown · 2 dead ends

  ⎯⎯ recommendations ⎯⎯

  ▸ reviewer + market-analyst silent — check agent configs
  ▸ 6 skills unmeasured — /assert to add coverage
  ▸ 3 ungraded predictions — /retro to close the loop
```

---

## Progress View (`/rhino progress`)

The arc — score trajectory, feature maturity, prediction accuracy, assertions, velocity.

**Data sources:**
- Score trajectory: `.claude/scores/history.tsv`
- Feature maturity: reconstructed from git log + eval-cache
- Prediction accuracy: predictions.tsv grouped by week
- Assertions: beliefs.yml + git history
- Velocity: git log with dates

Default: 7 days. Accepts argument: `/rhino progress 30` for 30 days.

ASCII line charts with `●` data points, `━` connections, `┤└──` axes. Feature maturity uses `░` planned `▓` building `█` working `●` polished.

---

## Help View (`/rhino help`)

Run `scripts/skill-catalog.sh` for raw data. Render grouped by phase:

1. **measure** — /eval, /taste
2. **think** — /product, /strategy, /ideate, /research
3. **build** — /plan, /go, /clone, /ship
4. **track** — /feature, /assert, /todo, /roadmap
5. **learn** — /retro
6. **setup** — /onboard, /skill, /configure, /rhino

Each skill: name line (hook) + detail line (what's special) + sub-commands line (dimmed). 3 lines max per skill. Sell the value, not the functionality.

---

## System View (`/rhino system`)

Internals: version, mode, counts, calibration status, agents with models, hooks with events, crown jewels.

---

## Opinion (Decision Tree)

### Deference to /plan

If `plan.yml` exists and was updated within 24 hours, use its `bottleneck_feature`. Otherwise compute independently but note: "Opinion based on /rhino heuristic — run /plan for authoritative diagnosis."

### Decision tree (check in order)

1. Version completion >= 80% → "**v[X.Y] is ready.** `/roadmap bump`"
2. Bottleneck eval < 30 → "**Define [feature].** `/feature new [name]`"
3. Bottleneck eval 30-49 → "**[feature]** needs work. `/go [feature]`"
4. Bottleneck eval 50-69 + assertions failing → "**Fix [feature].** `/go [feature]`"
5. All features eval 50+ → "**Polish or expand.** `/ideate`"
6. Plan exists, tasks incomplete → "**Resume the plan.** `/go [feature]`"
7. Predictions ungraded >5 → "**Learning loop is leaking.** `/retro`"
8. Todos stale >3 → "**Backlog is rotting.** `/todo decay`"
9. No predictions in 7+ days → "**Knowledge is stale.** `/research`"
10. Everything green → "**Raise the bar.** `/ideate wild`"

---

## Pattern Detection

Requires 3+ snapshots. When a meta-pattern fires, it **replaces** the standard opinion.

- **Bottleneck stagnation**: same feature bottleneck 3+ consecutive snapshots → "Current approach may be exhausted. `/strategy honest`"
- **Score-product divergence**: score up but product completion flat → "Optimizing the thermometer? `/eval coverage`"
- **Thesis stall**: evidence hasn't progressed 3+ snapshots → "Thesis is stalling. `/research` or `/roadmap bump`"
- **Learning decay**: prediction accuracy below 40% → "Model is degrading. `/retro` before building more."
- **All working, nothing proven**: features at "working" but thesis unproven → "Features work but thesis isn't proven. `/strategy honest`"

---

## System Coherence Check

Rendered from the `=== COHERENCE ===` section of system-pulse.sh. Shows whether strategy, eval, and plan agree on what matters.

Three checks:
1. **Strategy vs eval bottleneck** — does the strategy diagnosis match the eval-measured weakest feature?
2. **Plan vs eval bottleneck** — is the plan targeting the actual weakest feature?
3. **Weakest feature has work** — does the bottleneck feature have any todos assigned?

Render as warnings between signals and opinion (only when mismatches exist). If aligned, skip the zone entirely.

When mismatches exist, the opinion should prioritize realignment: "Skills are misaligned. Run /plan to re-diagnose."

---

## Anti-Rationalization Checks

Run on every default dashboard render. Warnings appear between signals and opinion zones (only when triggered).

- **Score inflation**: score +15 between snapshots without feature maturity change → flag
- **Perpetual building**: >3 features at eval 30-49 for 3+ snapshots → "Feature sprawl"
- **Prediction avoidance**: no predictions in 7+ days → prominent warning
- **Todo graveyard**: >10 backlog items, <20% completion → "Backlog is a graveyard"
