---
name: retro
description: "What did we learn? Grade predictions, update the knowledge model, detect staleness, surface wrong predictions as todos. The command that closes the learning loop."
argument-hint: "[accuracy|stale|session]"
allowed-tools: Read, Bash, Grep, Edit, Agent
---

!tail -n +2 ~/.claude/knowledge/predictions.tsv 2>/dev/null | awk -F'\t' '$5 == "" { c++ } END { print c+0 " ungraded" }' || echo "0 ungraded"
!ls -t .claude/sessions/*.yml 2>/dev/null | head -1 || echo "no sessions"

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

## Steps

### 1. Read state (parallel)
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

### 1.5. Auto-grade with grade.sh (mechanical first pass)
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

### 4. Update knowledge model
For wrong predictions:
- Identify WHY the prediction was wrong (the mechanism was different)
- Check if experiment-learnings.md needs an update:
  - New pattern discovered → add to Uncertain or Known
  - Existing pattern disproven → move to Dead Ends
  - Uncertain pattern confirmed → promote to Known (if 3+ experiments)

### 5. Detect staleness + prune
Scan experiment-learnings.md:
- Known Patterns: any entry >30 days without new evidence? Flag as potentially stale.
- Dead Ends: any entry that keeps showing up in recent predictions? Flag as "revisiting dead end."
- Unknown Territory: entries that have been unknown for >30 days without a first experiment? Flag as neglected.

**Pruning rules:**
1. Entries >30 days without new evidence → move to a `## Stale Patterns` section (don't delete — move)
2. Dead ends >60 days with no citations in predictions.tsv → move to `## Archived Dead Ends`
3. Report: "N stale patterns — consider re-testing or archiving"

### 6. Check maturity transitions
Review recent work and determine if any features should change maturity. Use the **Maturity Transition Rubric** in [STATE_MANIFEST.md](../STATE_MANIFEST.md) for consistent criteria:
- planned→building: code exists for the feature
- building→working: >50% assertions pass, core flow functional
- working→polished: 100% assertions pass, edge cases handled, no TODOs in feature code
- polished→proven: external validation or 3+ sessions without regression
Propose maturity updates in the output. Don't auto-write — let the founder confirm.

### 7. Compute accuracy
- Total graded predictions
- Correct (yes=1, partial=0.5, no=0)
- Accuracy = correct / total
- Assessment: 50-70% = well-calibrated, >70% = too safe, <50% = model needs work

### 8. Todo exhaust
Wrong predictions = work that needs doing. For each prediction graded `no` or `partial`:
- If the prediction was about a feature → write todo: `"[feature]: rethink [what was wrong]"` with `source: /retro`
- If the prediction revealed a dead end → check todos.yml for items pursuing that approach, suggest killing them
- If a pattern moved from Known → Dead End → write todo: `"update code relying on [dead pattern]"` with `source: /retro`

### 9. Session retro (when `session` route)
Read the most recent `.claude/sessions/*.yml`:
- Grade that session's predictions (if not already graded)
- Assess beta features:
  - **Speculative branching**: did the winner actually beat what a single approach would have produced? Check `speculated` count vs `kept` count.
  - **Adversarial review**: was `adversarial_catches` > 0? Were the catches real problems or noise?
  - **Prediction grading**: were all predictions graded? If not, flag the gap.
- Compute session ROI: score_delta / moves (points gained per move)
- Compare against previous sessions for trend

## Output format

For output templates, see [reference.md](reference.md).

### 7. Write retro artifact
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
```

## Tools to use

**Use Read** to read predictions.tsv, experiment-learnings.md, strategy.yml
**Use Bash** to run `git log --oneline -20` and read history.tsv
**Use Edit** to update predictions.tsv rows (fill in result/correct/model_update)
**Use Edit** to update experiment-learnings.md when model changes

## What you never do
- Skip grading because "there's not enough evidence" — make your best call, mark partial if unsure
- Grade predictions as "yes" when the outcome was different from what was predicted (even if the result was good)
- Delete predictions — they're the training signal
- Modify the predictions.tsv format or column order
- Add predictions (that's /plan's job)

## If something breaks
- predictions.tsv missing: "No predictions logged yet. Run `/plan` to start the learning loop."
- experiment-learnings.md missing: "No knowledge model. Run `/plan` to initialize it."
- All predictions already graded: "All caught up. Accuracy: X%. Run `/plan` to make new predictions."
- TSV parsing fails: check for tab-separated format, 6 columns (date, prediction, evidence, result, correct, model_update)

$ARGUMENTS
