---
name: rhino
description: "Use when the user asks for project status, dashboard, or 'where am I?' — the home screen showing product state, signals, and the one thing that matters right now"
argument-hint: "[help|system|compare|health|progress]"
allowed-tools: Read, Bash, Grep, Glob
internal: true
---

<!-- INTERNAL: This skill is for rhino-os self-management, not marketplace distribution. -->

!cat .claude/cache/product-value.json 2>/dev/null | jq '.product_model' 2>/dev/null || true

# /rhino

The home screen. Everything the founder needs, nothing they don't.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `templates/dashboard.md` — canonical rendering format: zone structure, bar math, conditional rules
- `references/dashboard-guide.md` — section meanings, conditional rendering, snapshot protocol, opinion decision tree, pattern detection
- `references/reading-guide.md` — what each number means. For founders who ask "what does this mean?"
- `gotchas.md` — real failure modes. **Read before rendering any view.**

Scripts (`system-pulse.sh`, `skill-catalog.sh`) exist as verification — run to cross-check your synthesis, not as the primary path.

## State

Read these directly — you are the synthesizer, not scripts:

| File | What it tells you |
|------|-------------------|
| `.claude/cache/score-cache.json` | Health score, structure, hygiene. The cached `rhino score .` result |
| `.claude/cache/eval-cache.json` | Per-feature scores: delivery/craft/viability sub-scores, deltas, timestamps, weights |
| `config/rhino.yml` | Feature definitions, value hypothesis, user, mode, weights, dependencies |
| `config/product-spec.yml` | What the product claims to do — show spec completion alongside score |
| `.claude/plans/roadmap.yml` | Current version thesis, evidence items (proven/partial/todo/disproven) |
| `.claude/plans/strategy.yml` | Strategic diagnosis, bottleneck. Check freshness (>7d = stale) |
| `.claude/plans/plan.yml` | Active plan: tasks, bottleneck_feature. Check freshness (>24h = defer to own heuristic) |
| `.claude/knowledge/predictions.tsv` | Prediction log: accuracy, graded/ungraded counts (fall back to `~/.claude/knowledge/`) |
| `.claude/plans/todos.yml` | Backlog: active/backlog/stale/done counts |
| `lens/product/eval/beliefs.yml` | Assertions: total count, pass rates |
| `.claude/cache/rhino-snapshots.json` | Dashboard history — last 20 snapshots for compare/pattern detection (R+W) |

**Bottleneck**: compute from eval-cache + rhino.yml weights. Lowest `score * weight` among active features. If `plan.yml` exists and is <24h old, use its `bottleneck_feature` instead.

**Product completion**: `sum(eval_score * weight) / sum(weight * 100)` across active features.

**Version completion**: `proven / total` from roadmap.yml evidence items.

## Routing

Parse `$ARGUMENTS`:

| Argument | Action |
|----------|--------|
| (none) | Read all state → render dashboard (see `templates/dashboard.md`) → save snapshot → state one opinion |
| `help` | Show "Start Here" flow first, then skill catalog grouped by phase. Run `skill-catalog.sh` for raw list |
| `system` | Internals: version, hooks, agents, crown jewels, calibration |
| `compare` | Load last snapshot from `.claude/cache/rhino-snapshots.json` → diff against current state |
| `health` | System health audit: hooks, agents, skills coverage, learning loop → letter grade |
| `progress` | The arc: score trajectory, feature maturity, prediction accuracy, assertions, velocity |

## First-run gate

If `config/rhino.yml` is missing or `.claude/cache/eval-cache.json` doesn't exist:
- Show: "Welcome to rhino. Your project has no scores yet."
- Suggest `/onboard` (no rhino.yml) or `/score` (no cache yet)
- Skip the full dashboard — stop here

## Rendering

Read `gotchas.md` before rendering any view. Read `references/dashboard-guide.md` for the full rendering spec — templates, conditional rules, opinion decision tree, pattern detection, anti-rationalization checks.

**Help view** — show this FIRST before the skill catalog:

```
Start Here
  "is this good?"          → /score   (the oracle — unified quality number)
  "what should I work on?" → /plan    (the strategist — finds the bottleneck)
  "just build it"          → /go      (the builder — autonomous loop)

  The flow: /score → /plan → /go → /score (repeat)
```

**Default view** — after rendering, save current state to `.claude/cache/rhino-snapshots.json`. Keep last 20 snapshots, trim oldest on append.

## Task generation — dashboard alerts become tasks

See `../shared/task-generation.md` for the task generation protocol. /rhino generates tasks for:

**For EVERY alert or stale signal on the dashboard, generate a task:**

### Staleness tasks
- Strategy >7d old → task: "Strategy [N]d stale — run /strategy honest"
- Eval-cache >7d old → task: "Eval data [N]d stale — run /eval"
- Market-context >14d old → task: "Market data [N]d stale — run /strategy market"
- Predictions.tsv no entries in 7d → task: "No predictions in [N]d — learning loop starved"
- Roadmap evidence no movement in 14d → task: "Thesis stalled [N]d — run /roadmap next"

### Score alert tasks
- Score dropped since last snapshot → task: "Score dropped from [X] to [Y] — diagnose via /eval"
- Assertion pass rate dropped → task: "Assertions regressed: [N] newly failing — fix via /go"
- Feature score dropped → task: "Feature [X] regressed from [old] to [new] — investigate"

### Prediction health tasks
- Ungraded predictions exist → task: "Grade [N] ungraded predictions — run /retro"
- Prediction accuracy outside 50-70% → task: "Prediction accuracy at [N]% — recalibrate via /retro"
- No predictions in 7d → task: "No predictions logged — enforce on next /go session"

### Backlog health tasks
- >10 stale todos (>14d) → task: "Backlog has [N] stale items — run /todo decay"
- 0 active todos → task: "No active work — run /plan to pick next move"
- Todos with no feature tag → task: "Orphan todos — run /todo to tag them"

### System health tasks (for /rhino health mode)
- Missing state files (no strategy.yml, no roadmap.yml) → task per missing file
- Hooks not installed → task: "Install hooks via /configure"
- Skills without assertions → task: "Skill [X] unmeasured — run /skill health"

Tag with `source: /rhino` and alert type (stale/score/prediction/backlog/system). Priority: score regressions first, then staleness.

## System coherence

Cross-check alignment between strategy, eval, and plan yourself. Render warnings between signals and opinion when mismatched:

```
  coherence   ⚠ strategy says [X] but eval says [Y] is the bottleneck
              ⚠ plan targets [X] but weakest feature is [Y]
              ⚠ [feature] is weakest but has 0 todos — nothing is working on it
```

If coherence is aligned, skip the section (no data = no zone). Mismatches mean the skills are pointing in different directions — the opinion should name this: "Skills are misaligned. Run /plan to re-diagnose."

## System integration

/rhino is the home screen — the hub that routes to everything else.

- **/score** wrote `score-cache.json` and `eval-cache.json` — /rhino reads both
- **/plan** wrote `plan.yml` with `bottleneck_feature` — /rhino defers to it when fresh (<24h)
- **/strategy** wrote `strategy.yml` — /rhino checks freshness and coherence against eval
- **/roadmap** wrote `roadmap.yml` — /rhino renders thesis + evidence completion
- **/todo** wrote `todos.yml` — /rhino counts active/backlog/stale
- **/retro** graded `predictions.tsv` — /rhino reports accuracy and ungraded count
- **/eval** wrote `eval-cache.json` feature scores — /rhino computes product completion and bottleneck from these
- **/rhino** writes `rhino-snapshots.json` — consumed by `/rhino compare` and pattern detection

The opinion defers to /plan for bottleneck diagnosis when plan.yml is fresh. Otherwise, /rhino computes its own from eval data and flags the opinion as heuristic-based.

## Self-evaluation

The skill worked if:
- **Default**: dashboard rendered with all non-empty zones, snapshot was saved, opinion was stated
- **Help**: "Start Here" flow was shown BEFORE skill catalog, not after
- **Compare**: delta against previous snapshot was computed and rendered
- **Health**: letter grade was assigned with justification
- **All modes**: tasks were generated for every stale signal or alert

## What you never do
- Turn this into a long report — density is the design
- Recommend more than one next action
- Skip the opinion
- Show zones with no data — skip them
- Make up numbers

## If something breaks

- system-pulse.sh returns mostly empty: the project is not onboarded — run `/onboard` to generate config, features, and assertions
- Snapshot comparison shows no previous snapshot: `.claude/cache/rhino-snapshots.json` is missing or empty — run `/rhino` once to create the first snapshot
- skill-catalog.sh lists zero skills: the plugin may not be installed correctly — check that `CLAUDE_PLUGIN_ROOT` is set or skills are symlinked
- Dashboard shows stale data everywhere: score-cache and eval-cache are old — run `rhino score .` and `/eval` to refresh

$ARGUMENTS
