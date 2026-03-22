---
name: retro
description: "Review what worked, what didn't, and what the system learned. Audit prediction accuracy and knowledge model health. Triggers on 'retro', 'what did we learn?', 'review', 'grade predictions', 'learning health'."
argument-hint: "[accuracy|stale|session|health|dimensions|auto]"
allowed-tools: Read, Bash, Grep, Edit, Agent, TaskCreate
---

# /retro

Grade predictions. Prune stale knowledge. Fix the learning model. `/go` grades predictions inline during builds — `/retro` is the periodic audit that catches everything `/go` missed and generates tasks to close learning gaps.

**`/go`** = grade predictions as you build (every move)
**`/retro`** = grade everything missed + audit the learning model (weekly)

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/retro-log.sh` — persistent retro session log (uses `${CLAUDE_PLUGIN_DATA}`)
- `references/grading-guide.md` — how to grade predictions, partial credit, model update quality. **Read before grading.**
- `references/knowledge-maintenance.md` — promotion rules, pruning rules, staleness thresholds
- `templates/retro-report.md` — output template for retro sessions
- `reference.md` — full output templates for all routes
- `gotchas.md` — real failure modes. **Read before grading.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Mode | What happens |
|----------|------|-------------|
| (none) | Full retro | Grade ungraded, staleness check, model updates, todos |
| `accuracy` | Just the number | Accuracy + calibration from predictions.tsv. One line. |
| `stale` | Staleness check | Scan experiment-learnings.md for stale entries |
| `session` | Last session retro | Grade session predictions, assess beta features |
| `health` | Health dashboard | Prediction frequency, grading latency, model freshness |
| `dimensions` | By-topic accuracy | Accuracy by feature and dimension. Blind spots. |
| `auto` | Auto-grade | Mechanical grading from score-cache + eval-cache + git |

## State to read

Read `gotchas.md` and `references/grading-guide.md` first. Then read these in parallel — you reason from state, not script output:

**Prediction stats** — compute directly from predictions.tsv:
- Read `.claude/knowledge/predictions.tsv` (fall back `~/.claude/knowledge/predictions.tsv`)
- TSV columns: `date`, `prediction`, `evidence`, `result`, `correct`, `model_update`
- Compute: total (skip header), graded (where `correct` != ""), ungraded, correct count, partial count, wrong count
- Accuracy: `(correct + partial * 0.5) / graded * 100` — target 50-70% = well-calibrated, >70% = too safe, <50% = model needs work
- Domain breakdown: classify predictions by keyword (score/craft/delivery/eval/commands/learning/docs/approach), compute accuracy per domain, flag domains with 3+ graded and <40% accuracy as overconfident
- Recent wrong predictions: filter where `correct` == "no", show last 5 — these are highest learning value
- Ungraded backlog: list ungraded entries, show oldest date and count

**Knowledge staleness** — compute directly from experiment-learnings.md:
- Read `.claude/knowledge/experiment-learnings.md` (fall back `~/.claude/knowledge/experiment-learnings.md`)
- File age: compare file modification time to now, >30d = stale
- Section sizes: count bullet points under each `##` heading (Known Patterns, Uncertain Patterns, Unknown Territory, Dead Ends)
- Zombie dead ends: for each bullet in Dead Ends section, check if any keyword appears in recent predictions — if so, it's a zombie that needs investigation
- Uncertain entries >14d old: candidates for promotion (if confirmed) or pruning (if abandoned)

**Learning velocity** — compute from git + predictions.tsv:
- Model updates: `git log --oneline --since="N weeks ago" --until="M weeks ago" -- [learnings path]` for last 4 weeks
- Prediction frequency: count predictions per week from TSV date column for last 4 weeks
- Accuracy trend: compute rolling 5-prediction window accuracy, compare first half vs second half of graded predictions (>10% diff = improving/declining)
- Model freshness: file age of experiment-learnings.md — <=3d fresh, <=7d aging, >7d stale

**Additional state:** `.claude/cache/eval-cache.json`, `.claude/cache/score-cache.json`, `.claude/plans/strategy.yml`, `config/rhino.yml`, `config/product-spec.yml`, `.claude/plans/todos.yml`, `git log --oneline -20`

**Cost tier** from `~/.claude/preferences.yml` -> `agents.cost` (economy/balanced/premium)

## How to retro

Read `gotchas.md` and `references/grading-guide.md` first. Then execute based on the routed mode:

### Mode: (none) — Full retro

The complete audit. Runs all phases sequentially:

1. **Grade** — run `bash bin/grade.sh` for mechanical first pass, then spawn grader for remaining ungraded:
   ```
   Agent(subagent_type: "rhino-os:grader", prompt: "Batch grade all ungraded predictions in predictions.tsv. Check git log, eval-cache, experiment-learnings for evidence.")
   ```
2. **Anti-rationalization** — check grades per `references/grading-guide.md`
3. **Model update** — for each wrong prediction, identify WHY and update experiment-learnings.md. Then spawn consolidator:
   ```
   Agent(subagent_type: "rhino-os:consolidator", prompt: "Consolidate experiment-learnings.md. [N] predictions graded. Merge duplicates, promote uncertain→known where 3+ confirm, flag stale, revive zombie dead ends.")
   ```
4. **Staleness scan** — run `bash scripts/stale-knowledge.sh`, flag entries per `references/knowledge-maintenance.md`
5. **Task generation** — generate tasks for every gap found (see Task generation section below)
6. **Log** — append to retro log via `bash scripts/retro-log.sh`. Write `~/.claude/cache/last-retro.yml`. Format per `templates/retro-report.md`.

### Mode: accuracy

One-line output. Compute from predictions.tsv directly:
- `(correct + partial * 0.5) / graded * 100`
- Report: accuracy %, total graded, ungraded backlog count, calibration verdict (50-70% = well-calibrated)

### Mode: stale

Staleness audit only. Run `bash scripts/stale-knowledge.sh`, then:
- Flag Known Patterns with no recent prediction confirmation
- Flag Uncertain Patterns >14d old — candidates for promotion or pruning
- Flag zombie Dead Ends that appear in recent predictions
- Generate staleness tasks (see Task generation section)

### Mode: session

Grade only the current session's predictions (filter by today's date in predictions.tsv):
- Grade each, write model_update for wrong ones
- Report session accuracy vs overall accuracy
- Flag if session had 0 predictions (learning loop starving)

### Mode: health

Dashboard view. No grading, no model changes. Read-only analysis:
- Prediction frequency (per week, last 4 weeks) via `bash scripts/learning-velocity.sh`
- Grading latency (how many ungraded, oldest ungraded date)
- Model freshness (file age of experiment-learnings.md)
- Section balance (Known vs Uncertain vs Unknown vs Dead Ends counts)
- Accuracy trend (rolling 5-prediction window, improving/declining/flat)

### Mode: dimensions

By-topic accuracy breakdown:
- Classify predictions by keyword (score/craft/delivery/eval/commands/learning/docs/approach)
- Compute accuracy per domain
- Flag domains with 3+ graded and <40% accuracy as overconfident
- Flag domains with 0 predictions as blind spots
- Generate coverage tasks for blind spots

### Mode: auto

The hands-off audit. Designed for programmatic invocation (from `/go` post-session, `/plan` health checks). Runs the full pipeline without asking questions:

1. **Mechanical grade** — run `bash bin/grade.sh` for numeric-target predictions
2. **Agent grade** — spawn grader for remaining ungraded:
   ```
   Agent(subagent_type: "rhino-os:grader", prompt: "Batch grade all ungraded predictions in predictions.tsv. Check git log, eval-cache, score-cache, experiment-learnings for evidence. Grade decisively — no 'insufficient evidence' cop-outs.")
   ```
3. **Wrong prediction analysis** — for each newly graded `no`:
   - Identify the mechanism that was wrong (not just "prediction didn't match")
   - Write `model_update` column in predictions.tsv
   - Update experiment-learnings.md with the corrected understanding
4. **Consolidate** — spawn consolidator:
   ```
   Agent(subagent_type: "rhino-os:consolidator", prompt: "Consolidate experiment-learnings.md. [N] predictions graded this session. Merge duplicates, promote uncertain→known where 3+ confirm, flag stale, revive zombie dead ends.")
   ```
5. **Generate ALL tasks** — run full task generation (see below). Write to todos.yml tagged `source: /retro auto`
6. **Log** — write `~/.claude/cache/last-retro.yml` with summary stats
7. **Output** — compact summary: accuracy, predictions graded, tasks generated, model updates made

## Task generation — the path to a smarter model

**/retro's job is not just grading. It's generating EVERY task needed to close learning gaps and fix the model.** Wrong predictions are the most valuable signal — but only if they produce action. Stale knowledge is invisible rot. Every gap in prediction coverage is a blind spot.

**For EVERY learning gap found, generate the complete task list:**

### Wrong prediction tasks
- Each wrong prediction → task: "Wrong about [X] — investigate why the model was wrong"
- Each wrong prediction with pattern → task: "Model assumes [X] but reality is [Y] — update experiment-learnings.md"
- Each wrong prediction on a high-weight feature → urgent task: "Wrong prediction on [feature] — re-evaluate approach via /eval"
- Cluster of wrong predictions in same domain → task: "3+ wrong predictions about [domain] — run /research to rebuild model"

### Stale knowledge tasks
- Each entry >30d without confirmation → task: "Knowledge entry '[X]' is [N]d stale — retest or prune"
- Each "Known Pattern" with no recent prediction → task: "Pattern '[X]' untested recently — verify still holds"
- Each "Uncertain Pattern" older than 14d → task: "Uncertain pattern '[X]' needs confirmation — design experiment"
- Dead ends that keep appearing in recent predictions → task: "Dead end '[X]' keeps resurfacing — investigate if conditions changed"

### Prediction coverage tasks
- Each feature with 0 predictions in last 7d → task: "Feature [X] has no predictions — next /go session must predict"
- Each dimension (delivery/craft/viability) with 0 predictions → task: "No predictions about [dimension] — blind spot"
- Prediction frequency <3/week → task: "Learning loop starving — enforce predictions on every move"
- Prediction accuracy >85% → task: "Predictions too safe — explore more unknown territory"
- Prediction accuracy <35% → task: "Model is broken — run /research to rebuild fundamentals"

### Model health tasks
- Experiment-learnings.md has duplicates → task: "Consolidate duplicate entries in knowledge model"
- Unknown Territory section empty → task: "No declared unknowns — the model is overconfident"
- No model updates in 7d → task: "Knowledge model hasn't been updated — run /retro or make riskier predictions"

**Write ALL tasks to /todo.** Tag with `source: /retro` and the gap type (wrong-prediction/stale/coverage/model-health). Priority: wrong predictions on high-weight features first. No cap on task count.

## System integration

Reads: `.claude/knowledge/predictions.tsv`, `.claude/knowledge/experiment-learnings.md`, `.claude/cache/eval-cache.json`, `.claude/cache/score-cache.json`, `.claude/plans/strategy.yml`, `config/rhino.yml`, `config/product-spec.yml`, `.claude/plans/todos.yml`
Writes: `.claude/knowledge/predictions.tsv` (grades), `.claude/knowledge/experiment-learnings.md` (model updates), `~/.claude/cache/last-retro.yml`, `.claude/plans/todos.yml`
Triggers: `/plan` (act on learning gaps), `/research` (rebuild broken model domains), `/eval` (re-evaluate after wrong predictions)
Triggered by: `/go` (post-session review), `/plan` (learning health check), `/ship rollback` (grade ship predictions)

## Self-evaluation

/retro succeeded if:
- All previously ungraded predictions now have a grade (yes/no/partial)
- Every wrong prediction has a model_update entry explaining WHY it was wrong
- experiment-learnings.md was updated (not just read)
- Retro session was logged
- Every learning gap found has a corresponding task

## Cost note

Spawns up to 2 agents:
- `grader` (sonnet) — batch grades ungraded predictions
- `consolidator` (sonnet) — merges duplicates, promotes patterns, flags stale entries in experiment-learnings.md
- Both agents run sequentially (consolidator needs grading results). Cost tier from `~/.claude/preferences.yml`.

## What you never do

- Skip grading because "not enough evidence" — make your best call
- Grade `yes` when outcome differs from prediction text
- Delete predictions — they're training signal
- Add predictions (that's /plan's job)
- Skip anti-rationalization checks
- Archive dead ends that keep appearing in recent predictions
- Write model updates without citing a graded prediction
- Grade everything as "partial" to avoid committing

## If something breaks

- predictions.tsv has no ungraded entries: all predictions are already graded — run `/retro health` or `/retro dimensions` for model analysis instead
- grade.sh fails with "malformed TSV": check predictions.tsv for tab corruption — open in a text editor and ensure columns are tab-separated, not spaces
- consolidator agent produces empty output: experiment-learnings.md may be missing — create it with the standard four-zone template (Known/Uncertain/Unknown/Dead)
- Staleness scan reports everything as stale: the dates in experiment-learnings.md may use a non-standard format — use `YYYY-MM-DD`

$ARGUMENTS
