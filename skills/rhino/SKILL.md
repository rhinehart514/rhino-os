---
name: rhino
description: "Project status dashboard + rhino-os system status. The home screen. Shows where your product is, what you can do, and the one thing that matters right now."
argument-hint: "[help|system|compare|health|progress]"
allowed-tools: Read, Bash, Grep, Glob
---

# /rhino

The home screen. This is what the founder sees when they want to know where they are and what to do next. It should feel like opening a well-designed app — everything you need, nothing you don't, beautiful enough to screenshot.

**Six views:**
- `/rhino` — the full dashboard (product + system + opinion)
- `/rhino help` — what can I do? Every skill with just enough to be excited.
- `/rhino system` — internals for power users
- `/rhino compare` — delta against last run. What changed since you last looked.
- `/rhino health` — system health audit. Is rhino-os itself working properly?
- `/rhino progress` — the arc. Score trajectory, feature maturity timeline, prediction accuracy trend, assertion pass rate over time.

## Steps (run in parallel)

### 1. Read product state
1. `rhino score . --quiet` — current score
2. `.claude/cache/eval-cache.json` — per-feature sub-scores + deltas
3. `config/rhino.yml` — stage, mode, value hypothesis, features
4. `.claude/plans/roadmap.yml` — thesis + evidence progress
5. `.claude/knowledge/predictions.tsv` — accuracy
6. `.claude/plans/todos.yml` — active/stale counts
7. `.claude/sessions/*.yml` — most recent session ROI
8. `git log --oneline -3` — last 3 commits

### 2. Read system state
1. Glob `skills/*/SKILL.md` — installed skills
2. Read `agents/*.md` — agents
3. Read `.claude-plugin/plugin.json` — version

### 3. Compute
- Product completion % = sum(eval_score × weight) / sum(weight × 100) — from eval-cache
- Version completion % (evidence_needed items from roadmap.yml)
- Bottleneck = lowest eval score among highest-weight active features
- Dimension health (avg delivery/craft/viability across features)

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| rhino-snapshots | `.claude/cache/rhino-snapshots.json` | R+W | Dashboard history |
| eval-cache | `.claude/cache/eval-cache.json` | R | Feature sub-scores |
| score-cache | `.claude/cache/score-cache.json` | R | Current score |
| rhino.yml | `config/rhino.yml` | R | Features, stage, mode |
| roadmap.yml | `.claude/plans/roadmap.yml` | R | Thesis, evidence |
| predictions.tsv | `.claude/knowledge/predictions.tsv` | R | Accuracy |
| todos.yml | `.claude/plans/todos.yml` | R | Backlog health |
| sessions | `.claude/sessions/*.yml` | R | Session ROI |
| beliefs.yml | `lens/product/eval/beliefs.yml` | R | Assertion coverage |
| skill-health | `.claude/cache/skill-health.json` | R | Skill measurement status |

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

## Default Dashboard (`/rhino`)

The dashboard has four zones. Each is dense, visual, and earns its space.

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ [PROJECT NAME]  ·  v8.0.3  ·  20 commands  ·  build mode
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  "[value hypothesis]"
  for [specific user]

  score       **95**/100  ███████████████████░
              assertions 57/63  ·  health 85
              delivery 62  ·  craft 52  ·  viability 55

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  thesis      "Someone who isn't us can complete a loop"  **43%**
              ✓ install-clean  ◐ reach-plan  · first-go  · return

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  features    product: **64%**

              scoring    ████████████████████  w:5  58  d:62 c:50 v:55  ↑4
              commands   ████████████░░░░░░░░  w:5  70  d:75 c:65 v:68  ↑2
              learning   ██████░░░░░░░░░░░░░░  w:4  48  d:55 c:40 v:48  ↓3  ←
              install    ████████████████████  w:3  68  d:70 c:60 v:72  —
              docs       ████████████░░░░░░░░  w:3

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  signals     predictions: 63% accurate (10/16)  ·  3 ungraded
              todos: 2 active · 5 backlog · 1 stale
              last session: 2.7 pts/move (3 moves, +8)
              last commit: [hash] [msg] · [time ago]

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ◆ **learning** is the bottleneck (craft_score 40, building, w:4)

  /go learning      build the bottleneck
  /strategy         honest diagnosis
  /help             see everything you can do
```

**Design:** Thin dividers between zones. Score = big number + dimensions. Thesis = one line + evidence dots. Features = bars + weights + sub-scores + deltas, bottleneck marked `←`. Signals = system health numbers. Opinion = ONE bold sentence. Bottom = exactly 3 commands.

**Conditional rendering:**
- No eval-cache → skip sub-scores, show pass rates only
- No sessions → skip "last session" line
- No roadmap → skip thesis zone
- No predictions → show "no predictions yet — /plan to start"
- Score zone always shows — it's the anchor

After rendering the dashboard, execute the **Dashboard Snapshot Protocol** — save current computed state to `.claude/cache/rhino-snapshots.json`.

---

## Compare (`/rhino compare`)

Delta view. What changed since the last `/rhino` run.

### Steps
1. Read `.claude/cache/rhino-snapshots.json`
2. If no snapshots exist or file missing → output "First snapshot — comparison available next run." and stop.
3. Take the most recent snapshot as `prev`. Compute current state (same as default dashboard steps 1-3).
4. Diff every dimension.

### Template
```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ rhino compare  ·  vs [prev.date]
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  score              95 → 97   +2
  product completion 64% → 68% +4
  version completion 43% → 48% +5

  ⎯⎯ features ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  scoring    58 → 62  +4   matured: building → working
  commands   70 → 70  —
  learning   48 → 45  -3   ← regression

  ⎯⎯ signals ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  predictions   63% → 65%  +2
  thesis        2/4 → 3/4  +1  (◐ reach-plan → ✓)
  todos         +3 new  ·  2 closed  ·  1 decayed
  bottleneck    learning (unchanged)

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ◆ [opinion based on deltas — see pattern detection]

  /go [feature]     act on what moved
  /rhino            full dashboard
```

**Compare design:** Only show features that changed (unchanged get `—`). Regressions marked `← regression`. Maturity transitions called out. Thesis evidence: show which items flipped. Opinion is delta-aware.

---

## Health (`/rhino health`)

System health audit. Is rhino-os itself working?

### Steps
1. **Hooks**: Check for hook output artifacts. Glob `.claude/cache/hook-*.json` or similar evidence that hooks fired. Check `settings.json` or `.claude-plugin/plugin.json` for hook definitions vs actual hook scripts existing on disk.
2. **Agents**: Read `.claude/plans/todos.yml` — count items with `source:` containing agent names (builder, explorer, measurer, reviewer, evaluator, market-analyst). Agents that never produce todos may not be firing.
3. **Skills**: Glob `skills/*/SKILL.md` to list skills. Cross-reference with `lens/product/eval/beliefs.yml` — which skills have assertions covering them? Which have feature entries in `config/rhino.yml`?
4. **Learning loop**: Read `.claude/knowledge/predictions.tsv` — when was the last prediction? How many ungraded? Read `.claude/knowledge/experiment-learnings.md` — when was it last updated? Count known/uncertain/unknown/dead-end entries.
5. **Grade**: Compute a letter grade (A-F) based on: hooks defined and present (25%), agents producing output (25%), skills measured (25%), learning loop active (25%).

### Template
```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ rhino health  ·  grade: **B**
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  hooks        8/8 scripts present  ✓
  agents       4/6 producing todos  · silent: reviewer, market-analyst
  skills       12/18 with assertions  · unmeasured: clone, calibrate, skill, onboard, research, ship
  learning     last prediction 1d ago  ·  3 ungraded  ·  latency 2.1d avg
               8 known · 4 uncertain · 3 unknown · 2 dead ends

  ⎯⎯ recommendations ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▸ reviewer + market-analyst silent — check agent configs
  ▸ 6 skills unmeasured — `/assert` to add coverage
  ▸ 3 ungraded predictions — `/retro` to close the loop

  /retro            grade predictions
  /assert           add missing coverage
  /rhino            back to dashboard
```

**Health design principles:**
- Compact summary per subsystem — expand details only where problems exist.
- Silent agents and unmeasured skills called out by name — no hiding.
- Recommendations are specific and actionable, not generic advice.
- Letter grade gives an instant read before diving into details.

---

## Progress (`/rhino progress`)

The arc — where you were, where you are, where you're headed. This is the view that makes a founder feel the compound effect.

### Steps
1. Read `.claude/scores/history.tsv` — parse all rows, group by day, compute daily averages for score
2. Read `~/.claude/knowledge/predictions.tsv` — compute weekly accuracy (rolling 7-day windows)
3. Read `config/rhino.yml` — get features and their current maturity
4. Read `git log --oneline --format="%H %ai %s" -50` via Bash — commit frequency and types
5. Read `.claude/cache/eval-cache.json` — current feature scores for endpoint
6. Read `.claude/plans/roadmap.yml` — version history with dates

### Render

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ progress — 7 days
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⎯⎯ score trajectory ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  100 ┤
   90 ┤                          ●━━━●━━━● 95
   80 ┤              ●━━━●━━━●
   70 ┤    ●━━━●━━━●
   60 ┤
      └──────────────────────────────────────
       Mar 9  10   11   12   13   14   15  16

  +30 pts in 7 days  ·  avg +4.3/day

  ⎯⎯ feature maturity ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  scoring     ░░░░▓▓▓▓████████████████████  planned → working   Mar 9-15
  commands    ░░░░░░▓▓▓▓▓▓████████████████  planned → working   Mar 10-14
  learning    ░░░░░░░░░░▓▓▓▓▓▓▓▓██████████  planned → working   Mar 11-16
  install     ░░░░░░░░▓▓▓▓████████████████  planned → polished  Mar 10-15
  docs        ░░░░░░░░░░░░▓▓▓▓▓▓██████████  planned → working   Mar 12-16

  legend: ░ planned  ▓ building  █ working  ● polished

  ⎯⎯ prediction accuracy ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  100% ┤
   75% ┤    ●━━━━━━━━●              ●━━━● 63%
   50% ┤                 ●━━━●━━━●
   25% ┤
      └──────────────────────────────────────
       Mar 9  10   11   12   13   14   15  16

  28 predictions  ·  22 graded  ·  63% accurate  ·  well-calibrated

  ⎯⎯ assertions ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  total: 8 → 25 → 48 → 63   (+55 in 7 days)
  pass rate: ░░░░▓▓▓▓████████████████  40% → 89%

  ⎯⎯ velocity ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  commits: 47 in 7 days  ·  6.7/day
  versions: v6.0 → v7.0 → v7.1 → v7.2 → v8.0 → v8.1 → v8.2
  theses proven: 6/7

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ◆ 7 days: score **+30**, features **5 matured**, theses **6 proven**

  /rhino             current snapshot
  /retro             grade ungraded predictions
  /roadmap           version history
```

### Design principles
- ASCII line charts for score and prediction accuracy — use `●` for data points, `━` for connections, `┤` and `└──` for axes
- Feature maturity timeline uses gradient blocks: `░` planned, `▓` building, `█` working, `●` polished — a visual timeline of each feature's journey
- Assertion growth shown as a ramp: total count over time + pass rate bar
- Velocity zone: raw commit frequency + version progression + thesis success rate
- One bold summary sentence at the bottom: the compound effect in one line
- Time range: default 7 days, accepts argument `/rhino progress 30` for 30 days

### Data sources for the charts
- Score trajectory: parse `.claude/scores/history.tsv`, group by day, take daily max (score column varies — use the `product` column or first numeric after timestamp)
- Feature maturity: no explicit history file — reconstruct from git log (when files in feature's code paths first appeared, when assertions started passing). This is approximate but useful.
- Prediction accuracy: parse predictions.tsv, group by week, compute rolling accuracy
- Assertions: count beliefs in beliefs.yml is current state. For growth, use git log on beliefs.yml to count entries per commit.
- Velocity: git log with dates

### Conditional rendering
- No history.tsv → skip score trajectory, note "run `rhino score .` a few times to build history"
- <3 days of data → show the data but note "building trend — more data in a few days"
- No predictions → skip prediction accuracy zone
- No beliefs.yml → skip assertions zone

---

## Help (`/rhino help`)

This is the skill catalog that makes someone want to try everything. Not a reference manual — a menu of superpowers. Each skill gets one line that makes the founder think "I need that."

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ rhino-os  ·  20 commands  ·  22 skills  ·  6 agents
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  Just type what you want. rhino-os routes your intent.

  ⎯⎯ measure ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /eval                    Is my product actually good?
                           Sub-scores per feature. Rubrics. Multi-sample median.
                           deep · slop · blind · coverage · trend · diff · vs

  /taste                   Visual product intelligence. 0-100 scale.
                           Market-calibrated. Persistent memory. Auto-creates todos.
                           url · mobile · vs · deep · trend

  /calibrate               Ground the taste eval in YOUR preferences.
                           Founder interview + design system + dimension research.
                           profile · design-system · dimensions · verify · refresh · drift

  ⎯⎯ think ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /product                 Should this exist? Who cares?
                           7 lenses. Pressure-tests new ideas AND existing products.
                           "I want to build..." · user · assumptions · pitch · coherence

  /strategy                The honest take on where you are.
                           Anti-sycophantic. Names what you're avoiding. Full strategy suite.
                           bet · market · position · price · gtm · compete · honest · coherence · user · research · docs · site

  /ideate                  What should we build next?
                           Evidence-weighted. Steals from market. Mandatory kill list.
                           feature · wild · kill

  /research                What do we need to know before deciding?
                           Multi-source. Spawns explorer + market-analyst agents.
                           feature · docs · site · market · competitor · history · gaps

  ⎯⎯ build ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /plan                    Find the bottleneck, propose what to work on.
                           Reads 14 state sources. Sub-score aware. Thesis-informed.
                           feature · brainstorm · critique

  /go                      Autonomous build loop.
                           Speculative branching. Adversarial review. Prediction grading.
                           feature · --safe · --speculate N

  /clone                   Screenshot any URL, generate components.
                           Your framework + your design tokens + your conventions.
                           url · verify · mobile · section · history

  /ship                    Get it out the door.
                           Pre-flight, commit, push, GitHub release, deploy, verify.
                           release · pr · hotfix · dry · verify · rollback · history

  ⎯⎯ track ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /feature                 Define, manage, detect features.
                           Sub-score breakdown. Maturity tracking. Dependency graph.
                           name · new · detect · ideate · status

  /assert                  Make a belief permanent.
                           Todo graduation. Chat-native assertion management.
                           feature: belief · list · check · remove · graduate · health · coverage · suggest · flapping

  /todo                    Living backlog — never stale.
                           Decay. Graduation. Smart promote. Agent-fed.
                           add · done · promote · health · decay

  /roadmap                 Version theses + the external story.
                           Proves/disproves questions. Generates narrative + changelog.
                           next · bump · narrative · changelog · positioning

  ⎯⎯ learn ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /retro                   Close the learning loop.
                           Grade predictions. Prune stale knowledge. Audit beta features.
                           session · accuracy · stale · health · dimensions · auto

  ⎯⎯ setup ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /onboard                 Onboard any repo in under 2 minutes.
                           Detects project. Generates features. Runs first eval.
                           --force

  /skill                   Manage skills.
                           Create, install, audit, measure overlap.
                           list · create · install · remove · info · health · overlap · audit

  /rhino                   Where am I? What matters?
                           Product state, system health, one opinion.
                           help · system · compare · health · progress

  ⎯⎯ connect ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /openclaw                Chat-optimized interface.
                           Formats rhino-os output for messaging delivery.
                           pulse · ask · nudge · bet · grunt

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  6 agents work behind the scenes:
  builder · explorer · measurer · reviewer · evaluator · market-analyst
  All produce todos as exhaust — the backlog is the aggregate signal.

  /rhino          back to the dashboard
  /rhino system   hooks, calibration, internals
```

**Help design:** Name line (hook) + detail line (what's special) + routes line (dimmed). Grouped by phase: measure → think → build → track → learn → setup → connect. Sell the value, not the functionality. 3 lines per skill max.

---

## System (`/rhino system`)

For power users who want to see the internals.

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ rhino system  ·  v8.0.3  ·  plugin mode
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  commands     20 installed
  skills       22 total (20 commands + 2 context)
  agents       6 (builder, explorer, measurer, reviewer, evaluator, market-analyst)
  hooks        8 active

  ⎯⎯ calibration ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  taste profile    ✓ documented           · not set up → /calibrate profile
  design system    ✓ 5 tokens, 4 comps    · not documented → /calibrate design-system
  taste knowledge  4/11 dimensions        → /calibrate dimensions
  predictions      16 total · 3 ungraded  → /retro
  learnings        8 known · 4 uncertain · 3 unknown · 2 dead ends

  ⎯⎯ agents ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  builder        sonnet   writes code, auto-closes todos, captures regression guards
  explorer       sonnet   multi-source research, converts findings to todos
  measurer       sonnet   runs eval, captures regressions + stuck features
  reviewer       haiku    quality gate, captures unfixed warnings
  evaluator      sonnet   deep eval, rubrics, slop detection
  market-analyst sonnet   competitive landscape via playwright

  ⎯⎯ hooks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  session_start   boot card on conversation start
  pre_compact     context recovery before compaction
  post_edit       quality checks after file edits
  post_skill      YAML validation after skill use
  post_commit     score update after commits
  pre_commit      pre-commit integrity check
  stop            session cleanup
  subagent_stop   agent completion handler

  ⎯⎯ crown jewels (immutable) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  bin/score.sh              value scoring with health gate
  bin/eval.sh               generative feature eval (sub-scores, rubrics, median)
  skills/taste/SKILL.md     visual product intelligence (0-100, market-calibrated)
  lens/product/eval/taste.mjs   legacy CLI taste eval (backward compat)
  bin/self.sh               4-system self-diagnostic

  /rhino          back to the dashboard
  /rhino help     skill catalog
```

---

## One opinion (decision tree)

After the dashboard, ONE bold recommendation.

### Deference to /plan

The bottleneck diagnosis in /plan is authoritative (14 sources). /rhino's opinion is a quick heuristic (8 sources). When they conflict, /plan wins.

- If `plan.yml` exists and was updated within the last 24 hours, use its `bottleneck_feature` as the basis for the opinion instead of computing independently.
- If `plan.yml` is stale (>24h) or missing, compute the opinion independently but note: "Opinion based on /rhino heuristic — run /plan for authoritative diagnosis."

### Decision tree

Check in order:

1. Version completion >= 80% → "**v[X.Y] is ready.** `/roadmap bump` to graduate."
2. Bottleneck eval < 30 → "**Define [feature].** `/feature new [name]`"
3. Bottleneck eval 30-49 → "**[feature]** needs work. `/go [feature]`"
4. Bottleneck eval 50-69 + assertions failing → "**Fix [feature].** `/go [feature]`"
5. All features eval 50+ → "**Polish or expand.** `/ideate`"
6. Plan exists, tasks incomplete → "**Resume the plan.** `/go [feature]`"
7. Predictions ungraded >5 → "**Learning loop is leaking.** `/retro`"
8. Todos stale >3 → "**Backlog is rotting.** `/todo decay`"
9. No predictions in 7+ days → "**Knowledge is stale.** `/research`"
10. Everything green → "**Raise the bar.** `/ideate wild`"

### Pattern Detection

After computing the opinion, check for meta-patterns across snapshots (requires 3+ entries in `rhino-snapshots.json`):

- **Bottleneck stagnation**: same feature has been bottleneck for 3+ consecutive snapshots → "**[feature] has been the bottleneck for [N] sessions.** Current approach may be exhausted. `/strategy honest`"
- **Score-product divergence**: score went up but product completion didn't move → "**Score improved but no feature eval score moved** — are you optimizing the thermometer? `/eval coverage`"
- **Thesis stall**: thesis evidence hasn't progressed in 3+ snapshots → "**Thesis is stalling.** Evidence hasn't moved. Either `/research` the blockers or `/roadmap bump` to a new thesis."
- **Learning decay**: prediction accuracy dropped below 40% → "**Model is degrading.** `/retro` before building more."
- **All working, nothing proven**: all features at "working" but thesis evidence still unproven → "**Features work but thesis isn't proven.** Ship or pivot? `/strategy honest`"

When a meta-pattern fires, it REPLACES the standard opinion from the decision tree above. Meta-patterns are higher-signal — they represent systemic issues, not just the current bottleneck.

---

## Anti-rationalization checks

The dashboard is the most-seen surface. It must be honest:

- **Score inflation**: if score jumps >15 points between snapshots without a feature maturing, flag: "Warning: Score jumped **+[N]** without feature improvement — investigate"
- **Perpetual building**: if >3 features have eval 30-49 for 3+ snapshots, flag: "Warning: Feature sprawl — too many things in flight. `/strategy focus`"
- **Prediction avoidance**: if no predictions logged in 7+ days, the learning loop is dead — make this a prominent warning in the signals zone, not a minor signal line. Use: "**No predictions in [N] days — learning loop is dead.** `/plan` to restart."
- **Todo graveyard**: if >10 backlog items and <20% completion rate, flag: "Warning: Backlog is a graveyard. `/todo decay`"

These checks run on every default dashboard render. Warnings appear between the signals zone and the opinion, in their own `warnings` zone (only rendered when at least one warning fires). Each warning is one line — dense, specific, actionable.

---

## What you never do
- Turn this into a long report — density is the design
- Recommend more than one next action
- Skip the opinion
- Show zones with no data — skip them, don't show empty state
- Make up numbers
- Use color descriptions in the template — the terminal handles ANSI, you render the structure

## Degraded modes
- `rhino score .` fails → show "score: --"
- No eval-cache → skip sub-scores, show pass rates only
- No roadmap → skip thesis zone
- No predictions → "no predictions yet — /plan to start"
- No features → "no features — /onboard to start"
- No sessions → skip session ROI line
- No rhino-snapshots.json → create empty file, note "First snapshot — comparison available next run" (for compare view, skip pattern detection and anti-rationalization snapshot checks)
- No eval-cache but assertions exist → run `rhino eval . --score` inline to generate
- No skill-health.json → generate inline by globbing `skills/*/SKILL.md` and checking `lens/product/eval/beliefs.yml` for matching feature entries
- No beliefs.yml → skip assertion coverage in health view

$ARGUMENTS