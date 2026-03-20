---
name: plan
description: "Use when starting a work session, finding the bottleneck, or capturing a task"
argument-hint: "[feature...|brainstorm|critique|task text]"
allowed-tools: Read, Bash, Grep, Glob, Agent, EnterPlanMode, ExitPlanMode, AskUserQuestion, TaskCreate, TaskList
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, d: .value.delivery_score, c: .value.craft_score, v: .value.viability_score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"
!cat .claude/cache/product-value.json 2>/dev/null | jq '{model: .product_model, loop: .value_loop[:5], journey_balance: [.journey_funnel | to_entries[] | "\(.key):\(.value.count)"]}' 2>/dev/null || true
!cat .claude/plans/plan.yml 2>/dev/null | head -20 || echo "no plan"
!cat ~/.claude/knowledge/experiment-learnings.md 2>/dev/null | head -60 || echo "no knowledge model"

# /plan

A cofounder planning the next move. Not a task manager — a strategist with opinions.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/session-context.sh` — quick state scan. Use to VERIFY your diagnosis, not replace it.
- `scripts/opportunity-scan.sh` — surfaces opportunities the founder isn't seeing. Run AFTER reading state.
- `scripts/bottleneck-report.sh` — mechanical bottleneck computation. Use to VERIFY your reasoning.
- `scripts/plan-progress.sh` — reads plan.yml, shows task completion status
- `scripts/startup-check.sh` — runs the 8 startup failure mode checks mechanically
- `references/prioritization-guide.md` — how to rank moves (bottleneck-first, information value, stage-appropriate)
- `references/startup-patterns-quick.md` — condensed failure mode reference
- `templates/plan-template.yml` — valid plan.yml structure
- `templates/move-brief.md` — template for proposing a move
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read before generating moves.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Mode |
|----------|------|
| (none) | Full planning — bottleneck diagnosis, thesis-aware moves |
| `[feature]` | Scoped to one feature's assertions and files |
| `[feature] [feature]` | Cross-feature plan, grouped moves |
| `brainstorm` | Skip bottleneck, propose 5 high-information directions |
| `critique` | Product walkthrough (first contact -> core loop -> edge cases -> 3 worst things) |
| Any other text | Quick capture as task or assertion |

**Quick capture**: if `$ARGUMENTS` looks like a task (not a route keyword), capture it:
- Contains "must"/"should"/"always"/"never" -> assertion in beliefs.yml
- Otherwise -> TaskCreate tagged to a feature if mentioned
- Output: `Captured: [text]` — done. No full planning flow.

## How planning works

### Read state directly

Read these in parallel — form your own picture before running any scripts:

**Core state (always read):**
- `config/rhino.yml` — features, weights, depends_on, mode, stage
- `.claude/cache/eval-cache.json` — per-feature scores with sub-dimensions (delivery, craft, viability), deltas
- `.claude/plans/roadmap.yml` — current thesis, evidence items, version
- `.claude/plans/strategy.yml` — stage, bottleneck, loop health
- `~/.claude/knowledge/predictions.tsv` — recent predictions, accuracy
- `.claude/plans/plan.yml` — previous plan tasks and completion
- `.claude/plans/todos.yml` — backlog items

**Context state (read when relevant):**
- `~/.claude/knowledge/experiment-learnings.md` — known/uncertain/unknown patterns
- `.claude/cache/topology.json` — journey positions, data flows, orphan surfaces
- `.claude/cache/product-value.json` — value loop, surface categories
- `.claude/cache/customer-intel.json` — customer signals (if exists)
- `.claude/cache/market-context.json` — competitive landscape (if exists)
- `config/product-spec.yml` — prioritize tasks that advance the spec's signals
- `git log --oneline -10` — recent work direction

**Also read** `gotchas.md` before generating moves.

Call EnterPlanMode. All reads, no writes until plan is approved.

### First-run check

If no features defined in rhino.yml or no eval-cache exists:
- Skip tier-aware routing and opportunity scan
- Show simplified output: "This is a new project. Here's what to do first:" followed by 3 clear steps:
  1. Run `/score` to establish a baseline health score
  2. Define your product's features in `config/rhino.yml` (or run `/feature new [name]`)
  3. Run `/plan` again once features exist — it gets much smarter with data
- End with one next command, not a menu

### Diagnose the bottleneck

This is YOUR reasoning, not a script's output. Think through:

1. **Which feature matters most right now?** Highest weight with lowest score, adjusted by thesis relevance. A feature the thesis needs proven outranks a higher-weight feature that's stable.

2. **Which sub-score is weakest?** The bottleneck is the lowest sub-score (delivery/craft) on the highest-priority feature. Not the average — the weakest dimension specifically.

3. **What's the journey position?** An entry feature below 60 delivery blocks ALL users. A core feature below 60 gates dependents. A leaf feature below 60 only affects itself. Entry > core > leaf at equal scores.

4. **Did the last plan work?** Compare previous plan.yml `state.score` against current. Tasks completed but score flat = wrong diagnosis. Same approach stalling = change the angle.

5. **What patterns apply?** Check experiment-learnings.md for known/uncertain patterns relevant to this feature. Check unknown territory for high-information experiments.

6. **Any startup failure modes?** Run `bash scripts/startup-check.sh` to verify mechanically. Include triggered warnings in your diagnosis.

**Verify your diagnosis** by running `bash scripts/bottleneck-report.sh` — if it disagrees with your reasoning, reconcile the difference explicitly.

### Tier-aware routing

Determine the maturity tier from eval-cache scores (or run `bash ../../bin/maturity-tier.sh` to verify):

| Tier | Score range | /plan behavior |
|------|-------------|---------------|
| **fix** (<50) | Only propose fix tasks. No ideation, no research, no strategy. |
| **deepen** (50-70) | Propose tasks from eval gaps. Run /eval inline if stale. |
| **strengthen** (70-85) | Target weakest sub-scores on highest-weight features. Suggest /research for unknowns. |
| **expand** (85+ score, <70 eval avg) | Structure solid, features shallow. Deep eval tasks. Only /ideate if bottleneck needs new capabilities. |
| **mature** (85+ score, 70+ eval avg) | Shift from "fix" to "what's next." Suggest /ideate, /research, /strategy, /taste, /product. Building new code is secondary. |

At `expand`/`mature`: surface unknown territory as primary opportunities. Check if /ideate, /research, /strategy have been run recently — recommend them if not.

### Surface opportunities

Run `bash scripts/opportunity-scan.sh` to surface what you might be missing: unknowns, wrong predictions, market signals, customer demand, stale strategy, unused capabilities. Present top 2-3 alongside your bottleneck diagnosis.

### Generate moves (1-2, not 3-5)

Each move uses `templates/move-brief.md` structure. Moves must:
- Target the weakest sub-score dimension specifically
- Connect to a roadmap evidence item (or declare maintenance)
- Include a falsifiable prediction with numbers
- Cite evidence from experiment-learnings or declare exploration

Read `references/prioritization-guide.md` for tiebreaking rules.

### Align

Present diagnosis + moves with options via AskUserQuestion. Include "Looks right — proceed" as first option.

### Write

- TaskCreate for each move (source of truth)
- Write `.claude/plans/plan.yml` as snapshot (use `templates/plan-template.yml` structure)
- Promote matching todos (`rhino todo promote <id>`) instead of duplicating
- ExitPlanMode with summary

## Task generation — opportunities become tasks

See `../shared/task-generation.md` for the task generation protocol. Generate tasks for every opportunity surfaced:

- **Unknown territory**: each relevant unknown -> task to research or eval
- **Wrong predictions**: ungraded -> grade via /retro; wrong with model fix needed -> update task
- **Market signals**: stale market-context.json -> /strategy market; no customer-intel -> /discover
- **Stale state**: strategy >14d -> /strategy honest; no predictions in 7d -> enforce predictions
- **Capability gaps**: unused capabilities that could help; dead ends worth retrying
- **Startup patterns**: each triggered failure mode -> task with intervention

Tag with `source: /plan` and opportunity type. Priority: bottleneck-related first, then highest information value.

## Output format

See `reference.md` for templates. Dense, scannable, opinionated.
Also see `../OUTPUT_FORMAT.md` and `../STATE_MANIFEST.md`.

## Self-evaluation

This skill worked if: (1) plan.yml was written with 1-2 moves targeting the bottleneck, (2) each move has a falsifiable prediction, (3) the diagnosis cites eval data (not vibes), and (4) startup pattern warnings were addressed or explicitly deferred.

## Agent usage

- **Agent (rhino-os:grader)** — grade ungraded predictions before planning. Expect ~10s latency.
- **Agent (rhino-os:explorer)** — if bottleneck is in Unknown Territory. Expect ~30s latency, runs in background.

## What you never do

- Plan for more than 10 minutes — if the bottleneck is clear, propose and move
- Propose the same approach that stalled last session with different words
- Skip the prediction — every move needs "I predict X because Y"
- Generate 3-5 tasks when 1-2 moves would cover it
- Ignore startup pattern warnings without naming the tradeoff
- Delegate your diagnosis to a script — scripts verify, you reason

## System integration

Reads: config/rhino.yml, eval-cache.json, roadmap.yml, strategy.yml, predictions.tsv, plan.yml, todos.yml, experiment-learnings.md, topology.json, product-value.json, customer-intel.json, market-context.json, product-spec.yml
Writes: plan.yml, tasks (via TaskCreate)
Triggers: /go (build), /research (unknowns), /eval (stale scores)
Triggered by: session start, /rhino (dashboard), founder asking "what should I work on?"

## Next commands

After planning, run `/go` to start building. If the diagnosis reveals unknowns, run `/research` first. If startup patterns fired, address those before building.

## If something breaks

- No score cache: run `rhino score .` first — need score data to diagnose
- All zeros: the project may not be onboarded — run `/onboard`
- startup-check.sh fails with "no rhino.yml": config is missing — run `/onboard` to generate it
- maturity-tier.sh returns wrong tier: check that eval-cache.json and score-cache.json are fresh

$ARGUMENTS
