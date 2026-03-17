---
name: retro
description: "What did we learn? Grade predictions, update the knowledge model, detect staleness, surface wrong predictions as todos. The command that closes the learning loop."
argument-hint: "[accuracy|stale|session|health|dimensions|auto]"
allowed-tools: Read, Bash, Grep, Edit, Agent
---

!bash scripts/prediction-stats.sh 2>/dev/null || echo "no prediction stats"
!bash scripts/stale-knowledge.sh 2>/dev/null || echo "no staleness data"

# /retro

The learning system's health check. `/go` grades predictions inline — that's the high-frequency case. `/retro` is the periodic audit: catching missed predictions, pruning stale knowledge, evaluating the learning system itself. Run between sessions, not during them.

**`/go`** = grade predictions as you build (every move)
**`/retro`** = grade everything missed + audit the learning model (weekly)

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/prediction-stats.sh` — prediction accuracy, domain breakdown, calibration (zero context cost)
- `scripts/stale-knowledge.sh` — staleness scan of experiment-learnings.md
- `scripts/learning-velocity.sh` — patterns added/updated per week, accuracy trend, model freshness
- `scripts/retro-log.sh` — persistent retro session log (uses `${CLAUDE_PLUGIN_DATA}`)
- `references/grading-guide.md` — how to grade predictions, partial credit, model update quality
- `references/knowledge-maintenance.md` — promotion rules, pruning rules, staleness thresholds
- `templates/retro-report.md` — output template for retro sessions
- `reference.md` — full output templates for all routes
- `gotchas.md` — real failure modes. **Read before grading.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Mode | What happens |
|----------|------|-------------|
| (none) | Full retro | Grade ungraded, staleness check, model updates, todos |
| `accuracy` | Just the number | Accuracy + calibration. One line. |
| `stale` | Staleness check | Scan experiment-learnings.md for stale entries |
| `session` | Last session retro | Grade session predictions, assess beta features |
| `health` | Health dashboard | Prediction frequency, grading latency, model freshness |
| `dimensions` | By-topic accuracy | Accuracy by feature and dimension. Blind spots. |
| `auto` | Auto-grade | Mechanical grading from score-cache + eval-cache + git |

## The protocol

### Step 1: Run scripts + read gotchas

Run `scripts/prediction-stats.sh` and `scripts/stale-knowledge.sh` via Bash. Read `gotchas.md`. Read `references/grading-guide.md` for grading rules.

### Step 2: Grade predictions

1. Run `bash bin/grade.sh` for mechanical first pass (numeric targets)
2. For remaining ungraded, spawn grader agent:
   ```
   Agent(subagent_type: "rhino-os:grader", prompt: "Batch grade all ungraded predictions in predictions.tsv. Check git log, eval-cache, experiment-learnings for evidence.")
   ```
3. Run anti-rationalization checks (see `references/grading-guide.md`)

### Step 3: Update knowledge model

For wrong predictions: identify WHY, update experiment-learnings.md. Then spawn consolidator:
```
Agent(subagent_type: "rhino-os:consolidator", prompt: "Consolidate experiment-learnings.md. [N] predictions graded. Merge duplicates, promote uncertain→known where 3+ confirm, flag stale, revive zombie dead ends.")
```
Read `references/knowledge-maintenance.md` for promotion/pruning rules.

### Step 4: Staleness + pruning

Run `scripts/stale-knowledge.sh`. Apply rules from `references/knowledge-maintenance.md`.

### Step 5: Learning velocity check

Run `scripts/learning-velocity.sh` to assess learning rate trend.

### Step 6: Todo exhaust + output

Wrong predictions → todos with `source: /retro`. Log session via `scripts/retro-log.sh`. Write `~/.claude/cache/last-retro.yml`. Format output per `templates/retro-report.md`.

## State (read at start, parallel)

1. `.claude/knowledge/predictions.tsv` (fall back `~/.claude/knowledge/`)
2. `.claude/knowledge/experiment-learnings.md` (fall back `~/.claude/knowledge/`)
3. `git log --oneline -20`
4. `.claude/cache/eval-cache.json` — per-feature sub-scores
5. `.claude/cache/score-cache.json` — latest scores
6. `.claude/plans/strategy.yml` — unknowns
7. `config/rhino.yml` — features, weights
8. `.claude/plans/todos.yml` — todo state
9. `~/.claude/preferences.yml` — agent cost tier (economy/balanced/premium)

## What you never do

- Skip grading because "not enough evidence" — make your best call
- Grade `yes` when outcome differs from prediction text
- Delete predictions — they're training signal
- Add predictions (that's /plan's job)
- Skip anti-rationalization checks
- Archive dead ends that keep appearing in recent predictions
- Write model updates without citing a graded prediction
- Grade everything as "partial" to avoid committing

$ARGUMENTS
