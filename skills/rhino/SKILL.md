---
name: rhino
description: "Project status dashboard + home screen. Shows where your product is, what to do next, and the one thing that matters right now. Use when the founder says 'where am I?', 'status', 'dashboard', 'what matters?'."
argument-hint: "[help|system|compare|health|progress]"
allowed-tools: Read, Bash, Grep, Glob
---

# /rhino

The home screen. Everything the founder needs, nothing they don't.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/system-pulse.sh` — runs first, outputs full system status as structured text (score, assertions, predictions, plan, strategy, thesis, todos). Zero context cost.
- `scripts/skill-catalog.sh` — lists all installed skills with file counts and descriptions. Powers `/rhino help`.
- `references/dashboard-guide.md` — what each dashboard section means, how to read it, conditional rendering rules, snapshot protocol, opinion decision tree, pattern detection, anti-rationalization checks.
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

## The protocol

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

**/rhino's job is not just showing status. It's generating tasks for every alert, every stale metric, every system that needs attention.** The dashboard is a health check — and health problems need treatment. If /rhino shows a yellow or red signal, that's a task.

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

**Write ALL tasks to /todo.** Tag with `source: /rhino` and alert type (stale/score/prediction/backlog/system). Priority: score regressions first, then staleness.

**There is no cap on task count.** A dashboard with 8 alerts generates 8 tasks.

After the dashboard, show: "Dashboard surfaced N alerts → N tasks added to backlog."

## What you never do
- Turn this into a long report — density is the design
- Recommend more than one next action
- Skip the opinion
- Show zones with no data — skip them
- Make up numbers

$ARGUMENTS
