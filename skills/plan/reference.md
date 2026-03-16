# /plan Reference — Output Templates

Loaded on demand. Steps and routing are in SKILL.md.

---

## Output format

Always use this structure. Dense, scannable, opinionated.

```
◆ plan — [feature name or "full product"]

v8.0: **43%** · product: **64%** · score: 92 · predictions: 63%
thesis: "Someone who isn't us can complete a loop without help"
evidence: install-clean ◐ · reach-plan ◐ · first-go · · return ·

▾ product map
  scoring    ████████████████████  polished  w:5  58 (v:62 q:50 u:60) ↑4
  commands   ████████████░░░░░░░░  working   w:5  70 (v:75 q:65 u:68) ↑2
  learning   ██████░░░░░░░░░░░░░░  building  w:4  48 (v:55 q:40 u:48) ↓3  ← bottleneck
  install    ████████████████████  polished  w:3  68 (v:70 q:60 u:72) —
  docs       ████████████░░░░░░░░  working   w:3

▾ signals
  assertions 26/37  ·  todos 8/14 done  ·  plan 3/5 tasks
  previous plan: "Structured Plans + Todos" — all tasks done
  last 3 commits: [hash] [msg], [hash] [msg], [hash] [msg]

▾ graded predictions
  ✓ "trend_for() will raise scoring to 60+" → 58 (partial)
  ✗ "auto-grade will work without API" → not implemented (wrong)
    model update: auto-grading needs explicit build, not emergent

◆ bottleneck: **learning** · weakest: **quality_score 40** ↓3

  The learning feature claims "a model that gets smarter every session"
  but predictions.tsv has 16 entries with only 8 auto-graded. The knowledge
  model is append-only. No mechanism detects when learning stalls.
  quality_score is the weakest dimension — error handling and edge cases.

▸ move 1 — auto-grade predictions on session start
  feature: learning · dimension: quality
  advances: first-go (thesis evidence: does /go produce improvement?)
  informed_by: "Predictions log but never grade" (Known — self.md)
  predict: grading predictions mechanically will raise quality_score from 40 to 55
  accept: session_start hook grades predictions with filled result columns
  touch: hooks/session_start.sh, bin/self.sh

▸ move 2 — knowledge model pruning
  feature: learning · dimension: quality
  informed_by: "Knowledge model is append-only" (Known — self.md)
  predict: adding a staleness check will raise quality_score to 60
  accept: experiment-learnings.md entries older than 30 days get flagged

/go learning         start building (beta: speculative branching)
/go learning --safe  start building (proven sequential loop)
/research learning   explore unknowns first
```

## Formatting rules

- Header: `◆ plan — [scope]`
- State bar: `v[N]: **[pct]%**` version completion, product completion, score, prediction accuracy — one line
- Thesis line: current thesis quoted, then evidence items with status markers (● = proven, ◐ = partial, · = todo)
- Product map: maturity bars + weight + score with sub-scores `(v:N q:N u:N)` + delta arrow
- State section: collapsed, 4-5 lines max
- Graded predictions: ✓/✗ prefix, quoted prediction, outcome. Include `model update:` on wrong predictions.
- Bottleneck: `◆ bottleneck: **[name]** · weakest: **[dimension] [score]**` — names the weakest sub-score dimension, not just the total
- If version completion >80%: `◆ thesis nearly proven — recommend /roadmap bump` before moves
- Moves: `▸ move N — [title]` with feature/dimension/informed_by/predict/accept/touch fields
- `dimension:` names which sub-score (value/quality/ux) the move targets
- `advances:` on moves that target a thesis evidence item
- `informed_by:` cites the learning or declares "Exploring: [what this will teach us]"
- Bottom: 2-3 relevant next commands. Include both `/go [feature]` and `/go [feature] --safe`

## Sub-score bottleneck rules

When eval-cache has sub-scores:
- Bottleneck = lowest sub-score among highest-weight features
- If two features tie on weight, the one with a `worse` delta gets priority
- Moves should target the weakest dimension specifically:
  - Low value_score → "code doesn't deliver what the claim promises"
  - Low quality_score → "error handling, edge cases, robustness"
  - Low ux_score → "output clarity, user feedback, progressive disclosure"
- The `dimension:` field on moves maps to the sub-score being targeted

When no sub-scores exist (legacy eval-cache):
- Fall back to layer-first diagnosis
- Note: "run `rhino eval . --fresh` for sub-score breakdown"

## Research override format

When `~/.claude/cache/last-research.yml` exists and is <24h old:

```
▾ research — [topic] (N hours ago)
  [key findings, 2-3 lines]
  suggested: [task from research]
```

Insert between signals and bottleneck. Research-informed moves get `informed_by: research ([topic])` tag and priority.

## Quick capture format

When `$ARGUMENTS` is a task, not a route keyword:

```
◆ captured — "[task text]"

  feature: [auto-detected or unscoped]
  type: task (TaskCreate) | assertion (beliefs.yml)

/plan           full planning session
/todo           see backlog
```

## Special mode: brainstorm

```
◆ plan brainstorm

v8.0: **43%** · product: **64%**

▾ 5 high-information directions

  1. [direction] — Exploring: [what this teaches]
     feature: [name] · predicted impact: [sub-score] +N
     risk: [what could go wrong]

  2. ...

Which direction? (1-5 or "none — show me the bottleneck")
```

## Special mode: critique

```
◆ plan critique

▾ first contact
  What a stranger sees: [description]
  Time to value: [estimate]
  Friction: [specific problems]

▾ core loop
  What works: [specifics]
  What breaks: [specifics]

▾ edge cases
  [3-5 specific failure scenarios]

▾ 3 worst things
  1. [worst problem with evidence]
  2. [second worst]
  3. [third worst]

/go [feature]     fix the worst thing
/feature [name]   redefine what's broken
```
