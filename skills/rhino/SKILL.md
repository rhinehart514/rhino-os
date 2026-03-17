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
| `help` | Run `skill-catalog.sh` → render skill catalog grouped by phase |
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
| roadmap.yml | `.claude/plans/roadmap.yml` | R |
| predictions.tsv | `.claude/knowledge/predictions.tsv` | R |
| todos.yml | `.claude/plans/todos.yml` | R |
| beliefs.yml | `lens/product/eval/beliefs.yml` | R |

## What you never do
- Turn this into a long report — density is the design
- Recommend more than one next action
- Skip the opinion
- Show zones with no data — skip them
- Make up numbers

$ARGUMENTS
