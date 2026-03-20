---
name: rhino
description: "Project status dashboard + home screen. Shows where your product is, what to do next, and the one thing that matters right now. Use when the founder says 'where am I?', 'status', 'dashboard', 'what matters?'."
argument-hint: "[help|system|compare|health|progress]"
allowed-tools: Read, Bash, Grep, Glob
---

!cat .claude/cache/product-value.json 2>/dev/null | jq '.product_model' 2>/dev/null || true

# /rhino

The home screen. Everything the founder needs, nothing they don't.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/system-pulse.sh` — runs first, outputs full system status as structured text (score, assertions, predictions, plan, strategy, thesis, todos). Zero context cost.
- `scripts/skill-catalog.sh` — lists all installed skills with file counts and descriptions. Powers `/rhino help`.
- `templates/dashboard.md` — canonical rendering format for the default dashboard view: zone structure, bar math, conditional rules, anti-rationalization warnings.
- `references/dashboard-guide.md` — what each dashboard section means, how to read it, conditional rendering rules, snapshot protocol, opinion decision tree, pattern detection, anti-rationalization checks.
- `references/reading-guide.md` — what each number on the dashboard means and how to interpret the signals. For founders who ask "what does this mean?"
- `gotchas.md` — real failure modes. **Read before rendering any view.**

## Routing

Parse `$ARGUMENTS`:

| Argument | What happens |
|----------|-------------|
| (none) | Run `system-pulse.sh` → render dashboard → save snapshot → opinion |
| `help` | Run `skill-catalog.sh` → render "Start here" flows first, then skill catalog grouped by phase |
| `system` | Internals: version, hooks, agents, crown jewels, calibration |
| `compare` | Load last snapshot from `.claude/cache/rhino-snapshots.json` → diff against current |
| `health` | System health audit: hooks, agents, skills coverage, learning loop → letter grade |
| `progress` | The arc: score trajectory, feature maturity, prediction accuracy, assertions, velocity |

## Start Here (canonical flow)

When rendering `help`, show this FIRST before the skill catalog:

```
Start Here
  "is this good?"          → /score   (the oracle — unified quality number)
  "what should I work on?" → /plan    (the strategist — finds the bottleneck)
  "just build it"          → /go      (the builder — autonomous loop)

  The flow: /score → /plan → /go → /score (repeat)
```

This breaks the circular routing problem. /score is the entry point (assess), /plan is the decision (what), /go is the action (build).

## The protocol

### Step 0: First-run check

Run `bash skills/shared/first-run-detect.sh [project-dir]`. If result is "first_run", show a welcome screen instead of the full dashboard:
- "Welcome to rhino. Your project has no scores yet."
- "Start with: `/plan` to find what to work on, or `/score` to see where you are"
- Skip the full feature map, sub-score breakdown, history, coherence, and snapshot
- If `config/rhino.yml` is missing, suggest `/onboard` instead
- End here — do not continue to Step 1

### Step 1: Run system-pulse.sh (always first)

```bash
bash skills/rhino/scripts/system-pulse.sh
```

This scans score-cache, eval-cache, predictions, plan, strategy, roadmap, todos, beliefs, git log. Outputs structured key-value pairs.

Also read `config/product-spec.yml` if it exists — show spec completion alongside score. How much of what we said we'd build actually works?

### Step 2: Read gotchas.md

Read `gotchas.md` before rendering. Every gotcha is from a real session.

### Step 3: Read dashboard-guide.md

Read `references/dashboard-guide.md` for the full rendering spec — templates, conditional rules, snapshot protocol, opinion tree, pattern detection.

### Step 4: Render the view

Follow the templates and rules from the dashboard guide. For `/rhino help`, also run:

```bash
bash skills/rhino/scripts/skill-catalog.sh
```

### Step 5: Save snapshot (default view only)

After rendering `/rhino` (no arguments), save current state to `.claude/cache/rhino-snapshots.json`. Keep last 20 snapshots.

## State artifacts

| Artifact | Path | R/W |
|----------|------|-----|
| rhino-snapshots | `.claude/cache/rhino-snapshots.json` | R+W |
| eval-cache | `.claude/cache/eval-cache.json` | R |
| score-cache | `.claude/cache/score-cache.json` | R |
| rhino.yml | `config/rhino.yml` | R |
| product-spec | `config/product-spec.yml` | R |
| roadmap.yml | `.claude/plans/roadmap.yml` | R |
| predictions.tsv | `.claude/knowledge/predictions.tsv` | R |
| todos.yml | `.claude/plans/todos.yml` | R |
| beliefs.yml | `lens/product/eval/beliefs.yml` | R |

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

## System coherence (rendered from COHERENCE section of system-pulse.sh)

If `system-pulse.sh` outputs any `mismatch:` lines in the COHERENCE section, render them as warnings between signals and opinion:

```
  coherence   ⚠ strategy says [X] but eval says [Y] is the bottleneck
              ⚠ plan targets [X] but weakest feature is [Y]
              ⚠ [feature] is weakest but has 0 todos — nothing is working on it
```

If coherence is aligned, skip the section (no data = no zone). Mismatches mean the skills are pointing in different directions — the opinion should name this: "Skills are misaligned. Run /plan to re-diagnose."

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
