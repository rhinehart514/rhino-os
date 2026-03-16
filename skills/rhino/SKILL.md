---
name: rhino
description: "Project status dashboard + rhino-os system status. The home screen. Shows where your product is, what you can do, and the one thing that matters right now."
argument-hint: "[help|system]"
allowed-tools: Read, Bash, Grep, Glob
---

# /rhino

The home screen. This is what the founder sees when they want to know where they are and what to do next. It should feel like opening a well-designed app — everything you need, nothing you don't, beautiful enough to screenshot.

**Three views:**
- `/rhino` — the full dashboard (product + system + opinion)
- `/rhino help` — what can I do? Every skill with just enough to be excited.
- `/rhino system` — internals for power users

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
- Product completion % (weighted feature maturity)
- Version completion % (evidence + features + todos for current thesis)
- Bottleneck (lowest maturity × highest weight)
- Dimension health (avg value/quality/ux across features)

---

## Default Dashboard (`/rhino`)

The dashboard has four zones. Each is dense, visual, and earns its space.

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ [PROJECT NAME]  ·  v8.0.3  ·  stage: one  ·  build mode
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  "[value hypothesis]"
  for [specific user]

  score       **95**/100  ███████████████████░
              assertions 57/63  ·  health 85
              value 62  ·  quality 52  ·  ux 59

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  thesis      "Someone who isn't us can complete a loop"  **43%**
              ✓ install-clean  ◐ reach-plan  · first-go  · return

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  features    product: **64%**

              scoring    ████████████████████  w:5  58  v:62 q:50 u:60  ↑4
              commands   ████████████░░░░░░░░  w:5  70  v:75 q:65 u:68  ↑2
              learning   ██████░░░░░░░░░░░░░░  w:4  48  v:55 q:40 u:48  ↓3  ←
              install    ████████████████████  w:3  68  v:70 q:60 u:72  —
              docs       ████████████░░░░░░░░  w:3

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  signals     predictions: 63% accurate (10/16)  ·  3 ungraded
              todos: 2 active · 5 backlog · 1 stale
              last session: 2.7 pts/move (3 moves, +8)
              last commit: [hash] [msg] · [time ago]

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ◆ **learning** is the bottleneck (quality_score 40, building, w:4)

  /go learning      build the bottleneck
  /strategy         honest diagnosis
  /help             see everything you can do
```

**Design principles:**
- Each zone separated by thin dividers — scannable, not a wall of text
- Score zone: the big number + dimension averages (value/quality/ux)
- Thesis zone: one line with evidence dots (✓ ◐ ·)
- Features zone: bars + weights + sub-scores + deltas. Bottleneck marked with `←` (no text, just the arrow — it's obvious)
- Signals zone: the numbers that tell you if the system is working (predictions, todos, session ROI, last commit)
- Opinion: ONE bold sentence. The bottleneck and why.
- Bottom: exactly 3 commands

**Conditional rendering:**
- No eval-cache → skip sub-scores, show pass rates only
- No sessions → skip "last session" line
- No roadmap → skip thesis zone
- No predictions → show "no predictions yet — /plan to start"
- Score zone always shows — it's the anchor

---

## Help (`/rhino help`)

This is the skill catalog that makes someone want to try everything. Not a reference manual — a menu of superpowers. Each skill gets one line that makes the founder think "I need that."

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ rhino-os  ·  18 skills  ·  6 agents  ·  v8.0.3
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  Just type what you want. rhino-os routes your intent.

  ⎯⎯ measure ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /eval                    Is my product actually good?
                           Sub-scores per feature. Rubrics. Multi-sample median.
                           deep · slop · blind · coverage · trend · diff · vs

  /taste                   Visual product intelligence. 0-100 scale.
                           Market-calibrated. Persistent memory. Auto-creates todos.
                           <url> · mobile · vs · deep · trend

  /calibrate               Ground the taste eval in YOUR preferences
                           Founder interview + design system + dimension research.
                           profile · design-system · dimensions

  ⎯⎯ think ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /product                 Should this exist? Who cares?
                           7 lenses. Pressure-tests new ideas AND existing products.
                           "I want to build..." · user · assumptions · pitch · coherence

  /ideate                  What should we build next?
                           Evidence-weighted. Steals from market. Mandatory kill list.
                           feature · wild · kill

  /research                What do we need to know before deciding?
                           Multi-source. Spawns explorer + market-analyst agents.
                           feature · docs · site · market · competitor

  ⎯⎯ build ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /plan                    Find the bottleneck, propose what to work on
                           Reads 14 state sources. Sub-score aware. Thesis-informed.
                           feature · brainstorm · critique

  /go                      Autonomous build loop ⚡ BETA
                           Speculative branching. Adversarial review. Prediction grading.
                           feature · --safe · --speculate N

  /clone                   Screenshot any URL, generate components
                           Your framework + your design tokens + your conventions.
                           <url>

  /ship                    Get it out the door
                           Pre-flight → commit → push → GitHub release → deploy → verify.
                           release · pr · hotfix · dry

  ⎯⎯ track ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /feature                 Define, manage, detect features
                           Sub-score breakdown. Maturity tracking. Dependency graph.
                           name · new · detect · ideate · status

  /assert                  Make a belief permanent
                           Todo graduation. Chat-native assertion management.
                           feature: belief · list · check · graduate

  /todo                    Living backlog — never stale
                           Decay. Graduation. Smart promote. Agent-fed.
                           add · done · promote · health · decay

  /roadmap                 Version theses + the external story
                           Proves/disproves questions. Generates narrative + changelog.
                           next · bump · narrative · changelog · positioning

  ⎯⎯ learn ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /strategy                The honest take on where you are
                           Anti-sycophantic. Names what you're avoiding. One opinion.
                           refresh · honest

  /retro                   Close the learning loop
                           Grade predictions. Prune stale knowledge. Audit beta features.
                           session · accuracy · stale

  ⎯⎯ setup ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  /onboard                 Onboard any repo in under 2 minutes
                           Detects project. Generates features. Runs first eval.
                           --force

  /skill                   Manage skills
                           list · install · remove · create

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  6 agents work behind the scenes:
  builder · explorer · measurer · reviewer · evaluator · market-analyst
  All produce todos as exhaust — the backlog is the aggregate signal.

  /rhino          back to the dashboard
  /rhino system   hooks, calibration, internals
```

**Help design principles:**
- Each skill gets a name line (bold, one-sentence hook) and a detail line (what makes it special) and a routes line (available sub-commands, dimmed)
- The hook line should make someone think "I need to try this" — not describe functionality, sell the value
- Grouped by workflow phase: measure → think → build → track → learn → setup
- Thin dividers between groups with group name
- Agent section at bottom — brief, contextual ("produce todos as exhaust")
- No walls of text. If it takes more than 3 lines per skill, it's too much.

---

## System (`/rhino system`)

For power users who want to see the internals.

```
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ◆ rhino system  ·  v8.0.3  ·  plugin mode
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  skills       18 installed (16 commands + 2 context)
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

After the dashboard, ONE bold recommendation. Check in order:

1. Version completion ≥ 80% → "**v[X.Y] is ready.** `/roadmap bump` to graduate."
2. Bottleneck is `planned` → "**Define [feature].** `/feature new [name]`"
3. Bottleneck is `building` → "**[feature]** needs work. `/go [feature]`"
4. Bottleneck is `working` + assertions failing → "**Fix [feature].** `/go [feature]`"
5. All features `working`+ → "**Polish or expand.** `/ideate`"
6. Plan exists, tasks incomplete → "**Resume the plan.** `/go [feature]`"
7. Predictions ungraded >5 → "**Learning loop is leaking.** `/retro`"
8. Todos stale >3 → "**Backlog is rotting.** `/todo decay`"
9. No predictions in 7+ days → "**Knowledge is stale.** `/research`"
10. Everything green → "**Raise the bar.** `/ideate wild`"

## What you never do
- Turn this into a long report — density is the design
- Recommend more than one next action
- Skip the opinion
- Show zones with no data — skip them, don't show empty state
- Make up numbers
- Use color descriptions in the template — the terminal handles ANSI, you render the structure

## If something breaks
- `rhino score .` fails: show "score: --"
- No eval-cache: skip sub-scores
- No roadmap: skip thesis zone
- No predictions: "no predictions yet — /plan to start"
- No features: "no features — /onboard to start"
- No sessions: skip session ROI line

$ARGUMENTS
