# /feature Reference — Output Templates

Loaded on demand. Routing and core logic are in SKILL.md.

---

## Output format

### List all features:

Only show `active` and `proven` features by default. Suffix proven features with `(proven)`. Omit `killed` and `archived` unless the user explicitly requests them.

```
◆ features

v8.0: **43%** · product: **62%** · assertions: 57/63

▸ learning        ████░░░░░░  **48**/100  w:4  building   ← bottleneck
  (v:55 q:40 u:48) ↓3
  "a model that gets smarter every session"
  for: the system itself · depends on: scoring

▸ scoring         █████░░░░░  **58**/100  w:5  working
  (v:62 q:50 u:60) ↑4
  "honest number that tells a founder if their product improved"
  for: solo founder who just made changes

· self-diagnostic ██████░░░░  **68**/100  w:2  working  (proven)
  (v:70 q:65 u:68) —
  "system health check — measures calibration, staleness, learning loop"
  for: solo founder · depends on: scoring, learning

· install         ██████░░░░  **68**/100  w:3  polished
  (v:70 q:60 u:72) —
  "one-command setup — clone, run install.sh, everything works"
  for: new user trying rhino-os for the first time

· commands        ███████░░░  **70**/100  w:5  working
  (v:75 q:65 u:68) ↑2
  "slash commands that route founder intent to the right action"
  for: solo founder working in Claude Code

product completion: **62%**
bottleneck: **learning** (w:4, building) — quality_score 40 is weakest dimension

/feature [name]       deep dive into one
/feature new [name]   define a new feature
/feature detect       scan codebase for undeclared features
```

**Formatting rules:**
- Header includes version completion + product completion + assertion count
- Features sorted worst-to-best by total score
- Sub-scores shown on second line: `(v:N q:N u:N)` with delta arrow
- Bar graphs: █ for passing proportion, ░ for failing
- Bottleneck opinion names the weakest sub-score dimension, not just the total
- Bottom: exactly 3 next commands

### Single feature detail:

```
◆ feature — scoring

  **58**/100  █████░░░░░
  maturity: working  w:5
  depends on: (none)
  depended on by: learning, self-diagnostic

  delivers: "honest number that tells a founder if their product improved"
  for: solo founder who just made changes
  code: bin/score.sh, bin/eval.sh, bin/lib/config.sh

▾ sub-scores
  value     ██████████████░░░░░░  62/100  ↑4
  quality   ████████████░░░░░░░░  50/100  —
  ux        ████████████████░░░░  60/100  ↑2

▾ verdict
  DELIVERS: score.sh computes honest number with health gate
  DELIVERS: per-feature breakdown identifies real bottlenecks
  PARTIAL: trend visualization exists but not surfaced in output
  MISSING: onboarding guidance for new projects is generic

▾ rubric (if .claude/cache/rubrics/scoring.json exists)
  spec_alignment: check score formula matches docs
  integrity: 4 unhandled I/O paths
  ux: output clear but no next-step guidance
  anti_slop: 82% human-quality

/go scoring           fix the gaps
/eval deep scoring    full evaluation with rubric
/eval scoring         measure current state
```

### New feature created:

```
◆ feature new — [name]

  defined in config/rhino.yml
  delivers: "[what]"
  for: "[who]"
  code: [files]
  weight: [N]  maturity: planned
  depends on: [features or none]

  baseline:
  value     ░░░░░░░░░░░░░░░░░░░░  --/100
  quality   ░░░░░░░░░░░░░░░░░░░░  --/100
  ux        ░░░░░░░░░░░░░░░░░░░░  --/100
  verdict: **PARTIAL** — 2 delivers, 1 partial, 1 missing

/go [name]      build what's missing
/eval [name]    measure in detail
/plan [name]    plan the build
```

### Detect results:

```
◆ feature detect

  scanned: 12 modules · 3 already declared · 4 new

  ▸ auth (new)
    code: src/auth/, src/middleware/auth.ts
    delivers: "user authentication and session management"
    for: end users
    weight: 4 (supports core flow)

  ▸ api (new)
    code: src/api/, src/routes/
    delivers: "REST API for client consumption"
    for: frontend clients
    weight: 3 (supports core flow)

  · utils (new, low weight)
    code: src/utils/
    delivers: "shared utility functions"
    for: developers
    weight: 1 (peripheral)

  · logging (new)
    code: src/logger.ts, src/middleware/logger.ts
    delivers: "structured request logging"
    for: developers/ops
    weight: 2

  already declared: scoring, commands, learning (skipped)

Add all 4 / Pick specific ones / Skip?

/feature new [name]   define manually instead
/eval                 measure what exists
```

### Feature ideate:

```
◆ feature ideate — scoring

  current: **58**/100 (v:62 q:50 u:60)
  weakest dimension: **quality** at 50

  ▸ 1. error boundary hardening
    add try/catch around all file I/O in score.sh
    predicted impact: quality_score +15

  ▸ 2. guided first-run experience
    detect first run, show setup wizard
    predicted impact: ux_score +10, value_score +5

  ▸ 3. trend visualization
    add sparkline to score output showing last 10 runs
    predicted impact: value_score +8

  · 4. score explanation mode
    --explain flag shows why each penalty was applied
    predicted impact: ux_score +5

Which direction? (1-4 or skip)
```

### Feature status transition:

```
◆ feature — scoring → proven

  was: working
  now: proven
  criteria met: 3+ sessions without regression, external validation (commander.js)

/feature             see all features
/roadmap             check thesis progress
```

## Sub-score display rules

When eval-cache.json has sub-scores for a feature:
- Always show `(v:N q:N u:N)` after the total score
- Show delta arrow: `↑N` (improved), `↓N` (regressed), `—` (same, within ±3)
- In detail view, show sub-score bars with individual deltas
- Name the weakest sub-score in bottleneck opinion
- In ideate, focus ideas on the weakest sub-score dimension

When eval-cache.json has NO sub-scores (legacy cache):
- Show total score only, no parenthetical
- Note: "run `rhino eval . --fresh` for sub-score breakdown"

## Prediction auto-grading

After presenting feature status, check `.claude/knowledge/predictions.tsv` for ungraded predictions mentioning this feature. If found, grade them inline:

```
▾ predictions graded
  ✓ "scoring will reach 65+" → 58 (no, still below)
    model update: quality_score is the bottleneck, not value delivery
```
