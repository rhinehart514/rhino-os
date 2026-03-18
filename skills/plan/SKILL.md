---
name: plan
description: "Use when starting a work session, finding the bottleneck, or capturing a task"
argument-hint: "[feature...|brainstorm|critique|task text]"
allowed-tools: Read, Bash, Grep, Glob, EnterPlanMode, ExitPlanMode, AskUserQuestion, TaskCreate, TaskList
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, d: .value.delivery_score, c: .value.craft_score, v: .value.viability_score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"
!cat .claude/plans/plan.yml 2>/dev/null | head -20 || echo "no plan"

# /plan

A cofounder planning the next move. Not a task manager — a strategist with opinions.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/session-context.sh` — runs first, scans ALL state (scores, eval, predictions, todos, strategy, roadmap, git). Zero context cost.
- `scripts/opportunity-scan.sh` — surfaces opportunities the founder isn't seeing: unknowns, wrong predictions, market signals, customer demand, unused capabilities, stale strategy. Run AFTER session-context.
- `scripts/bottleneck-report.sh` — eval-grounded bottleneck with sub-score breakdown and completion metrics
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

## The protocol

### Step 1: Gather state (parallel)

Run these via Bash (parallel where possible):
1. `scripts/session-context.sh` — where are we?
2. `scripts/opportunity-scan.sh` — what are we not seeing?
3. `scripts/plan-progress.sh` — what did we plan last time?
4. `scripts/startup-check.sh` — any failure modes triggered?

Also read `config/product-spec.yml` if it exists — prioritize tasks that advance the spec's signals. Core loop tasks > polish tasks.

The opportunity scan is critical — it surfaces unknowns, wrong predictions, market signals, customer demand, dead ends worth retrying, stale strategy, and unused capabilities. Present the top 2-3 opportunities alongside the bottleneck.

Call EnterPlanMode. All reads, no writes until plan is approved.

### Step 2: Read gotchas

Read `gotchas.md` before generating moves.

### Step 3: Diagnose

Read `references/prioritization-guide.md` for ranking logic.

The bottleneck is NOT "the lowest scoring feature" — it's the lowest sub-score of the highest-weight feature blocking the current thesis. Read `scripts/bottleneck-report.sh` output for this.

If startup-check flagged anything, include it in the diagnosis.

### Step 4: Generate moves (1-2, not 3-5)

Each move uses the structure from `templates/move-brief.md`. Moves must:
- Target the weakest sub-score dimension specifically
- Connect to a roadmap evidence item (or declare maintenance)
- Include a falsifiable prediction with numbers
- Cite evidence from experiment-learnings or declare exploration

Read `references/prioritization-guide.md` for tiebreaking rules.

### Step 5: Align (AskUserQuestion)

Present diagnosis + moves with options. Include "Looks right — proceed" as first option.

### Step 6: Write

- TaskCreate for each move (source of truth)
- Write `.claude/plans/plan.yml` as snapshot (use `templates/plan-template.yml` structure)
- Promote matching todos (`rhino todo promote <id>`) instead of duplicating
- ExitPlanMode with summary

## Output format

See `reference.md` for templates. Dense, scannable, opinionated.
Also see `../OUTPUT_FORMAT.md` and `../STATE_MANIFEST.md`.

## Task generation — opportunities become tasks

See `../shared/task-generation.md` for the task generation protocol. /plan generates tasks for:

**For EVERY opportunity surfaced by opportunity-scan.sh, generate a task:**

### Unknown territory tasks
- Each unknown in experiment-learnings.md that's relevant to the bottleneck → task: "Unknown: [X] — run /research [topic] to build model"
- Each feature with no eval data → task: "Feature [X] never evaluated — run /eval [feature]"
- Each dimension with no predictions → task: "No predictions about [dimension] — blind spot to address"

### Wrong prediction tasks
- Each ungraded prediction → task: "Grade prediction: '[X]' — run /retro"
- Each wrong prediction that implies a model fix → task: "Model wrong about [X] — update experiment-learnings.md"

### Market signal tasks
- Market-context.json >14d stale → task: "Market data stale — run /strategy market"
- No customer-intel.json → task: "No customer signal — run /discover or /product user"
- Competitor moved → task: "Competitor [X] changed — evaluate via /strategy compete"

### Stale state tasks
- Strategy >14d old → task: "Strategy stale — run /strategy honest"
- No predictions in 7d → task: "Learning loop starving — enforce predictions"
- Plan tasks all complete but score didn't improve → task: "Completed tasks didn't move score — diagnose via /retro"

### Capability gap tasks
- Unused capabilities that could help → task: "Capability [X] available but unused — evaluate adoption"
- Dead ends worth retrying → task: "Dead end [X] may be worth retrying — conditions changed since [date]"

### Startup pattern tasks
- Each triggered failure mode from startup-check.sh → task with intervention from startup-patterns.md
- Each warning-to-critical escalation → urgent task

Tag with `source: /plan` and opportunity type. Priority: bottleneck-related opportunities first, then highest information value.

## Agent usage

- **Agent (rhino-os:grader)** — grade ungraded predictions before planning
- **Agent (rhino-os:explorer)** — if bottleneck is in Unknown Territory

## What you never do

- Plan for more than 10 minutes — if the bottleneck is clear, propose and move
- Propose the same approach that stalled last session with different words
- Skip the prediction — every move needs "I predict X because Y"
- Generate 3-5 tasks when 1-2 moves would cover it
- Ignore startup pattern warnings without naming the tradeoff

$ARGUMENTS
