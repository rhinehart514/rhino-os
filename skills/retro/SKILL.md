---
name: retro
description: "What did we learn? Grade predictions, update the knowledge model, detect staleness, surface wrong predictions as todos. The command that closes the learning loop."
argument-hint: "[accuracy|stale|session|health|dimensions|auto]"
allowed-tools: Read, Bash, Grep, Edit, Agent
---

!tail -n +2 ~/.claude/knowledge/predictions.tsv 2>/dev/null | awk -F'\t' '$5 == "" { c++ } END { print c+0 " ungraded" }' || echo "0 ungraded"
!ls -t .claude/sessions/*.yml 2>/dev/null | head -1 || echo "no sessions"
!cat .claude/cache/retro-health.json 2>/dev/null | jq '{last_retro: .last_retro_date, grading_latency: .grading_latency_days, prediction_count: (.prediction_count_by_type | add)}' 2>/dev/null || echo "no retro-health cache"

# /retro

The learning system's health check. `/go` grades predictions inline during the build loop — that's the high-frequency case. `/retro` is the periodic audit: catching predictions that slipped through, pruning stale knowledge, evaluating whether the learning system itself is working. Run it between sessions, not during them.

**`/go`** = grade predictions as you build (every move)
**`/retro`** = grade everything that was missed + audit the learning model (weekly)

## Routing

Parse `$ARGUMENTS`:

### No arguments → full retro
Grade ungraded predictions, surface accuracy trend, detect stale knowledge, flag dead ends, produce todos from wrong predictions.

### `accuracy` → just the number
Show prediction accuracy and calibration assessment. One line.

### `stale` → knowledge staleness check
Scan experiment-learnings.md for entries older than 30 days without new evidence.

### `session` → retro on the last /go session
Read the most recent `.claude/sessions/*.yml` file. Grade that session's predictions, assess whether speculative branching and adversarial review helped, update model.

### `health` → learning system health dashboard
Prediction frequency (per week), grading latency (avg days from prediction to grade), model update frequency, knowledge section sizes (Known/Uncertain/Unknown/Dead), prediction type distribution. This is meta — how healthy is the learning system itself, not the product.

### `dimensions` → prediction accuracy by topic
Accuracy broken down by feature and prediction type. Which areas are we best/worst at predicting? Surfaces blind spots (features with zero predictions) and overconfidence (features where we're always wrong).

### `auto` → auto-grade ungraded predictions
Mechanically grade ALL ungraded predictions using score-cache.json, eval-cache.json, and git log evidence. Numeric targets get compared directly. Qualitative predictions get proposed grades with evidence. Human reviews results before committing.

---

## State to read at start (parallel)

Read these simultaneously:

1. `.claude/knowledge/predictions.tsv` — all predictions (fall back to `~/.claude/knowledge/`)
2. `.claude/knowledge/experiment-learnings.md` — knowledge model (fall back to `~/.claude/knowledge/`)
3. `git log --oneline -20` — recent commits (evidence for grading)
4. `.claude/scores/history.tsv` — score history (evidence for grading)
5. `.claude/cache/eval-cache.json` — per-feature sub-scores + deltas (evidence for grading score predictions)
6. `.claude/cache/eval-deltas.json` — delta history across sessions
7. `.claude/plans/strategy.yml` — unknowns that predictions might resolve
8. `config/rhino.yml` features section — maturity, weight (for product completion context)
9. `.claude/plans/todos.yml` — todo completion rate + sources
10. `~/.claude/cache/last-research.yml` — recent research findings
11. `.claude/sessions/*.yml` — recent session logs (for `session` route)
12. `.claude/cache/retro-health.json` — learning system health metrics (for `health` route)
13. `.claude/cache/score-cache.json` — latest scores (for `auto` route)

---

## Steps (full retro — no arguments)

### 1. Auto-grade with grade.sh (mechanical first pass)
Run `bash bin/grade.sh` first. This mechanically grades any predictions with extractable directional claims (e.g., "raise X from N to M") by comparing against score-cache.json. Review the auto-grades for correctness. Then manually grade the remainder that grade.sh couldn't handle.

### 2. Find remaining ungraded predictions
Predictions where `correct` column (5th) is still empty after grade.sh. For each:
- Read the prediction text and evidence
- Check git log, score history, and code state for outcomes
- Propose a grade: `yes`, `no`, or `partial`
- Write a `model_update` when the prediction was wrong

### 3. Grade them
For each ungraded prediction, update the TSV row:
- Fill in `result` column with what actually happened
- Fill in `correct` column with yes/no/partial
- Fill in `model_update` column when wrong (what changes about the model)

### 4. Anti-rationalization checkpoint
Before committing any grades, run these checks:

**All predictions correct = too safe.** If the last 5 graded predictions are all `yes`, flag it. These predictions aren't informative — they're confirmatory. The system isn't learning, it's performing. Output: `⚠ last 5 predictions all correct — predictions may be too safe. Push into Unknown Territory.`

**Grading own predictions generously.** If accuracy jumps >20% in a single retro session (e.g., from 50% to 72%), review grades. Something is off — either past grades were too harsh or current grades are too lenient. Output: `⚠ accuracy jumped [old]% → [new]% in one retro — review grades for leniency.`

**Model update without evidence.** Every model update in experiment-learnings.md must cite at least one graded prediction. If you're about to write a model update that can't point to a specific prediction result, stop. Output: `⚠ model update "[text]" has no supporting prediction — defer or make a prediction first.`

**Pruning inconvenient dead ends.** Before archiving any Dead End, ask: is this being archived because it's truly abandoned, or because it's uncomfortable? Dead ends that keep appearing in predictions are NOT dead — they're unresolved. Output: `⚠ dead end "[text]" referenced in N recent predictions — not actually dead, move to Uncertain.`

**All predictions are "partial".** If >50% of grades in this retro session are `partial`, push harder. Partial is the easy answer. For each partial, ask: would rounding to yes or no change the model update? If yes, round. Output: `⚠ [N]/[M] grades are partial — push for yes/no where possible.`

### 5. Update knowledge model
For wrong predictions:
- Identify WHY the prediction was wrong (the mechanism was different)
- Check if experiment-learnings.md needs an update:
  - New pattern discovered → add to Uncertain or Known
  - Existing pattern disproven → move to Dead Ends
  - Uncertain pattern confirmed → promote to Known (if 3+ experiments)

### 6. Detect staleness + prune
Scan experiment-learnings.md:
- Known Patterns: any entry >30 days without new evidence? Flag as potentially stale.
- Dead Ends: any entry that keeps showing up in recent predictions? Flag as "revisiting dead end."
- Unknown Territory: entries that have been unknown for >30 days without a first experiment? Flag as neglected.

**Pruning rules:**
1. Entries >30 days without new evidence → move to a `## Stale Patterns` section (don't delete — move)
2. Dead ends >60 days with no citations in predictions.tsv → move to `## Archived Dead Ends`
3. Report: "N stale patterns — consider re-testing or archiving"

### 7. Check maturity transitions
Review recent work and determine if any features should change maturity. Use the **Maturity Transition Rubric** in [STATE_MANIFEST.md](../STATE_MANIFEST.md) for consistent criteria:
- planned→building: code exists for the feature
- building→working: >50% assertions pass, core flow functional
- working→polished: 100% assertions pass, edge cases handled, no TODOs in feature code
- polished→proven: external validation or 3+ sessions without regression
Propose maturity updates in the output. Don't auto-write — let the founder confirm.

### 8. Compute accuracy
- Total graded predictions
- Correct (yes=1, partial=0.5, no=0)
- Accuracy = correct / total
- Assessment: 50-70% = well-calibrated, >70% = too safe, <50% = model needs work

### 9. Todo exhaust
Wrong predictions = work that needs doing. For each prediction graded `no` or `partial`:
- If the prediction was about a feature → write todo: `"[feature]: rethink [what was wrong]"` with `source: /retro`
- If the prediction revealed a dead end → check todos.yml for items pursuing that approach, suggest killing them
- If a pattern moved from Known → Dead End → write todo: `"update code relying on [dead pattern]"` with `source: /retro`

### 10. Write retro-health.json
After every retro run, update `.claude/cache/retro-health.json` with computed metrics (see State Artifacts below).

### 11. Write retro artifact
Write `~/.claude/cache/last-retro.yml` so /ideate and /plan can read it:
```yaml
date: YYYY-MM-DD
product_completion: 64
accuracy: 63
accuracy_trend: improving  # improving / stable / declining
graded_count: 3
stale_patterns:
  - "pattern name — last evidence 45 days ago"
dead_ends_archived: 1
model_updates:
  - "Moved X from Uncertain → Known"
unknowns_surfaced:
  - "new unknown from grading"
maturity_proposals:
  - feature: scoring
    from: working
    to: polished
    reason: "100% assertions, tests exist"
wrong_predictions:
  - prediction: "auto-grade via hook"
    feature: learning
    dimension: quality_score
    todo_created: "rethink auto-grade approach"
todos_created: 2
todos_killed: 1
anti_rationalization_warnings: 0
```

---

## Steps (health route)

### 1. Parse predictions.tsv
Group by week. Compute: **prediction frequency** (per week, trend), **grading latency** (avg days from prediction to grade, use git log dates), **ungraded backlog** (count + oldest date).

### 2. Parse experiment-learnings.md
Count entries per section: Known, Uncertain, Unknown, Dead Ends, Stale, Archived. Compute Known:Unknown ratio (healthy = 1:1 to 3:1, too safe if >5:1).

### 3. Prediction type distribution
Categorize each prediction: **score** ("raise X from N to M"), **feature** ("feature X will reach maturity Y"), **approach** ("this approach will/won't work"), **meta** (about the learning system itself), **other**.

### 4. Model update frequency
`git log --follow experiment-learnings.md` — count commits, compute updates/week, last update date.

### 5. Write retro-health.json
Write `.claude/cache/retro-health.json` with: `last_retro_date`, `grading_latency_days`, `model_update_frequency_per_week`, `prediction_frequency_per_week`, `ungraded_count`, `oldest_ungraded_date`, `knowledge_section_sizes` (known/uncertain/unknown/dead_ends/stale/archived), `known_unknown_ratio`, `prediction_count_by_type` (score/feature/approach/meta/other), `accuracy_by_dimension`, `health_warnings`.

### 6. Diagnose health
- Prediction frequency <1/week → `⚠ prediction starvation`
- Grading latency >7 days → `⚠ grading too slow`
- Ungraded >5 → `⚠ grading backlog`
- Known:Unknown >5:1 → `⚠ exploiting too much`
- Known:Unknown <0.5:1 → `⚠ not enough confirmed patterns`
- Model updates <0.5/week → `⚠ model stagnant`
- >80% score-type predictions → `⚠ prediction monoculture`

---

## Steps (dimensions route)

### 1. Categorize all graded predictions
For each graded prediction, extract: **feature** (match against rhino.yml), **dimension** (value_score, quality_score, ux_score, maturity, approach, etc.), **type** (score/feature/approach/meta/other).

### 2. Compute accuracy per feature
Total predictions, correct count, accuracy %, 20-char bar. Features with 0 predictions = blind spots.

### 3. Compute accuracy per dimension
Same breakdown by dimension. Flag overconfident dimensions (<40% accuracy with 3+ predictions).

### 4. Surface insights
- **Worst**: lowest accuracy with 3+ predictions — most wrong
- **Best**: highest accuracy with 3+ predictions — well-understood
- **Blind spots**: 0-1 predictions — unknown accuracy, highest information value
- **Overconfidence**: <40% accuracy = systematic overprediction

---

## Steps (auto route)

### 1. Identify ungraded predictions
Find rows in predictions.tsv where `correct` column (5th) is empty.

### 2. Gather evidence
Read in parallel: score-cache.json, eval-cache.json, eval-deltas.json, `git log --since="[prediction_date]"`, history.tsv.

### 3. Classify and grade
**Numeric** ("raise X from N to M"): extract target, compare against score-cache/eval-cache. Hit = `yes`, missed <30% = `partial`, missed >30% or wrong direction = `no`.

**Directional** ("X will improve"): check eval-deltas for direction. Correct = `yes`, flat = `partial`, wrong = `no`.

**Approach** ("this will work because"): check if commits exist and were kept/reverted. Kept + assertions up = `yes`, kept + flat = `partial`, reverted = `no`.

**Qualitative** (can't be mechanically graded): propose grade with evidence, mark `[proposed]` in result — requires human confirmation.

### 4. Present grouped by confidence
**Mechanical** (committed directly) → **Proposed** (needs review) → **Skipped** (no evidence, remains ungraded).

### 5. Anti-rationalization checks
Run the same checks from Step 4 of the full retro against auto-graded results.

---

## Steps (session route)

Read the most recent `.claude/sessions/*.yml`:
- Grade that session's predictions (if not already graded)
- Assess beta features:
  - **Speculative branching**: did the winner actually beat what a single approach would have produced? Check `speculated` count vs `kept` count.
  - **Adversarial review**: was `adversarial_catches` > 0? Were the catches real problems or noise?
  - **Prediction grading**: were all predictions graded? If not, flag the gap.
- Compute session ROI: score_delta / moves (points gained per move)
- Compare against previous sessions for trend

---

## Steps (accuracy route)

Compute accuracy from predictions.tsv: total graded, correct (yes=1, partial=0.5, no=0), percentage, calibration assessment. Include per-dimension breakdown if enough data exists.

---

## Steps (stale route)

Scan experiment-learnings.md:
- Known Patterns with no new evidence in 30+ days
- Unknown Territory items with 0 experiments in 30+ days
- Dead Ends with 0 citations in 60+ days
- Propose: move to Stale, re-test, or archive

---

## State Artifacts

### READ (existing)
- `.claude/knowledge/predictions.tsv` (fall back `~/.claude/knowledge/`) — predictions with grades
- `.claude/knowledge/experiment-learnings.md` (fall back `~/.claude/knowledge/`) — knowledge model
- `git log` — commit history as grading evidence
- `.claude/scores/history.tsv` — score trajectory
- `.claude/cache/eval-cache.json` — per-feature sub-scores
- `.claude/cache/eval-deltas.json` — score deltas across sessions
- `.claude/plans/strategy.yml` — unknowns, bottleneck
- `config/rhino.yml` — features, maturity, weight
- `.claude/plans/todos.yml` — todo state
- `~/.claude/cache/last-research.yml` — recent research
- `.claude/sessions/*.yml` — session logs
- `.claude/cache/score-cache.json` — latest scores (for auto route)

### READ + WRITE
- `.claude/cache/retro-health.json` — learning system health metrics
  - Tracks: `last_retro_date`, `grading_latency_days`, `model_update_frequency_per_week`, `prediction_frequency_per_week`, `ungraded_count`, `oldest_ungraded_date`, `knowledge_section_sizes`, `known_unknown_ratio`, `prediction_count_by_type`, `accuracy_by_dimension`, `health_warnings`
  - Updated on every retro run (any route)
  - Generated from predictions.tsv analysis if missing

### WRITE (existing)
- `~/.claude/cache/last-retro.yml` — retro summary for /plan and /ideate
- `.claude/knowledge/predictions.tsv` — fill in grades
- `.claude/knowledge/experiment-learnings.md` — model updates

---

## Output format

For all output templates (full retro, session, accuracy, stale, health, dimensions, auto), see [reference.md](reference.md).

---

## Degraded Mode Paths

When state is missing, degrade gracefully — never crash, never skip silently.

**predictions.tsv missing**: "No predictions logged yet. Run `/plan` to start the learning loop." — exit early for all routes.

**experiment-learnings.md missing**: "No knowledge model. Run `/plan` to initialize it." — skip staleness check, model update steps. Grading can still proceed.

**retro-health.json missing**: Generate fresh from predictions.tsv analysis. No cache means first run — compute everything from source data. Output: `· retro-health.json generated (first run)`

**grade.sh fails or missing**: Skip auto-grade step in Step 1. Do manual grading only. Output: `· grade.sh unavailable — manual grading only`

**eval-deltas.json missing**: Skip delta-based auto-grading in `auto` route. Output: `⚠ no eval-deltas.json — install post_commit hook for delta tracking. Numeric predictions only.`

**eval-cache.json missing**: Skip sub-score evidence in grading. Output: `· no eval-cache — grading without sub-score evidence`

**score-cache.json missing**: Skip score-based auto-grading in `auto` route. Output: `⚠ no score-cache.json — run rhino eval . to generate. Auto-grade limited to git evidence.`

**No sessions directory**: Skip session route entirely. Output: `· no session logs found — /go writes session logs after each loop`

**All predictions already graded**: "All caught up. Accuracy: X%. Run `/plan` to make new predictions." — still run staleness check, health update, and anti-rationalization review on recent grades.

**TSV parsing fails**: Check for tab-separated format, 6 columns (date, prediction, evidence, result, correct, model_update). If format is wrong, report the issue and exit.

**history.tsv missing**: Grade without score trajectory evidence. Output: `· no score history — grading with git + eval-cache evidence only`

---

## Tools to use

**Use Read** to read predictions.tsv, experiment-learnings.md, strategy.yml, retro-health.json, eval-cache.json, score-cache.json
**Use Bash** to run `git log --oneline -20`, read history.tsv, compute dates, parse TSV with awk
**Use Grep** to search predictions.tsv for specific features/dimensions, search experiment-learnings.md for section headers
**Use Edit** to update predictions.tsv rows (fill in result/correct/model_update)
**Use Edit** to update experiment-learnings.md when model changes
**Use Edit** to write retro-health.json

---

## What you never do
- Skip grading because "there's not enough evidence" — make your best call, mark partial if unsure
- Grade predictions as "yes" when the outcome was different from what was predicted (even if the result was good)
- Delete predictions — they're the training signal
- Modify the predictions.tsv format or column order
- Add predictions (that's /plan's job)
- Skip anti-rationalization checks — they exist because this system grades its own homework
- Archive dead ends that keep appearing in recent predictions (they're not dead)
- Write model updates without citing a graded prediction
- Grade everything as "partial" to avoid committing to yes/no

---

## Anti-Rationalization Guide

| Trap | Detection | Response |
|------|-----------|----------|
| "All predictions correct" | Last 5 graded all `yes` | Flag as too-safe. Push into Unknown Territory. |
| "Accuracy jumped in one session" | >20% accuracy increase in single retro | Review grades for leniency. Compare against evidence quality. |
| "Model update without evidence" | Writing to experiment-learnings without citing a prediction | Defer the update or make a prediction first. |
| "Pruning inconvenient dead ends" | Archiving Dead End that has recent prediction citations | Move to Uncertain instead. It's not dead if you keep thinking about it. |
| "Everything is partial" | >50% of session grades are `partial` | Push for yes/no. Partial is the easy answer. |
| "Grading is too hard" | Skipping ungraded predictions for 2+ retros | Use `/retro auto` to get mechanical first pass. No excuses. |
| "The prediction was right in spirit" | Grading `yes` when outcome differs from prediction text | Grade against what was written, not what was meant. |
| "Model is fine, just needs time" | No model updates in 3+ retro sessions | Model stagnation. Force an update or the model is dead. |

$ARGUMENTS
