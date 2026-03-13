---
description: "Fully autonomous mode. Plan, predict, build, measure, update model, repeat. Karpathy NEVER STOP. Use when you want hands-off progress."
---

# /go

Autonomous creation loop. You plan, build, measure, and learn — no human in the loop until you hit a wall or plateau.

## System awareness
You are one of 8 skills that form a single system:

**The build loop** (your world):
- `/plan` → wrote the plan you're executing. If no plan exists, run /plan logic first.
- `/strategy` → owns the product model + learning agenda. If strategy is stale (>3 days), pause and refresh.
- `/research` → explores unknowns. **When a task says "Run `/research [topic]`", execute /research inline before continuing.**
- `/go` (you) → autonomous executor. You consume the plan, invoke /research when needed, and update the model.

**Around the loop** (you don't call these, but know they exist):
- `/assert` → plants evals that define "done." Failing assertions become your highest-priority tasks.
- `/ship` → deploy pipeline. After you finish, the founder runs /ship to get code to users.
- `/critique` → brutal product review. The founder runs this to find what sucks.
- `/retro` → weekly learning synthesis. Extracts meta-patterns from your predictions and experiments.

You are not isolated. Tasks may require calling `/research`. The plan's task mix reflects the lifecycle stage — respect it.

## Output style
Read `mind/voice.md` and follow it. Use iteration pulse format (predict/build/measure/model, 4 lines max). Progress summary every 3 iterations. Close with a completion block. No prose between iterations.

## Compaction recovery
If you have no memory of prior iterations (compaction hit mid-loop):
1. Read `.claude/plans/plan.yml` — tasks with `status: done` are complete, `status: todo` remain. Fallback: `.claude/plans/active-plan.md` (checked `[x]` = done, `[ ]` = remaining)
2. Read `.claude/cache/score-cache.json` — last known score is your baseline
3. Count done tasks to reconstruct iteration count
4. Resume from the next todo task — no need to re-read state you already consumed

## Freshness check
Before starting the loop, check if `.claude/plans/plan.yml` (or `.claude/plans/active-plan.md`) was last modified >24h ago (`stat -f %m` on macOS). If stale, warn: "Plan is >24h old — context may have shifted. Consider running /plan to refresh." Proceed anyway (don't block), but note the staleness.

## The loop

```
Plan → Predict → Build → Measure → Update Model → Repeat
```

Run until one of these stops you:
- **Unknown blocker**: something you genuinely can't resolve without the founder
- **Plan complete**: all tasks checked off AND no unknown territory worth exploring
- **Plateau + exhausted exploration**: see below

### Plateau → pivot, don't stop
When score hasn't improved in `plateau_threshold` (default 3) consecutive build tasks, DON'T STOP. Instead:
1. The current BUILD approach is exhausted — stop building.
2. Read the "Unknown Territory" section of experiment-learnings.md.
3. If unknowns exist: run `/research` inline on the highest-value unknown. This produces a state transition + new hypothesis.
4. If the research produces an actionable hypothesis: create a new task from it, predict, build, measure. The loop continues.
5. If no unknowns exist OR research doesn't produce an actionable hypothesis: NOW stop. The approach is truly exhausted.

This is Karpathy's "never stop training" — when the loss plateaus on known data, don't stop. Switch to exploring new data. A cofounder who plateaus on build pivots to research, not to the couch.

## Each iteration

### 1. Pick the task
Read `.claude/plans/plan.yml` — find the next task with `status: todo`. Use `rhino plan next` for a quick view. If no plan exists, run the /plan logic first (read state, find bottleneck, write plan). Fallback: if plan.yml is missing, read `.claude/plans/active-plan.md` and take the next unchecked `[ ]` task.

**Dead-end check**: Before starting, read the "Dead Ends" section of `~/.claude/knowledge/experiment-learnings.md`. If the task's approach matches a known dead end, skip the task — log "Skipped: matches dead end '[entry]'" and move to the next task.

Tasks in plan.yml have typed fields — read and use all of them:
- **accept**: criteria that define "done" — verify these before marking complete
- **touch**: scoped file paths — limit changes to these unless the task requires otherwise
- **touch** may say `/research [topic]` — this means run the /research skill inline before building
- **dont**: explicit boundaries — respect these even if it seems helpful to cross them

Also update the Claude Code task status (TaskUpdate → in_progress) if tasks were created by /plan.

### 2. Predict
Before touching any code:
```
I predict: [specific outcome]
Because: [cite a specific entry from experiment-learnings.md, e.g. "Known pattern: copy changes have 80% keep rate"]
         OR: "No prior evidence — exploring unknown territory: [what you hope to learn]"
I'd be wrong if: [falsification condition]
```
The "Because" field MUST cite a specific pattern from experiment-learnings.md (Known, Uncertain, or Dead End) or explicitly declare exploration of unknown territory. Vague evidence like "this should work" or "best practice" is not valid — cite or explore, never guess.

Log to `~/.claude/knowledge/predictions.tsv`:
```
date\tprediction\tevidence\tresult\tcorrect\tmodel_update
```

### 3. Build
Execute the task. One concern at a time. Follow `mind/standards.md`. If the product lens is installed (`lens/product/mind/product-standards.md` exists), check the 10-point UX checklist for UI work.

**Experiment discipline** (from `config/rhino.yml`):
- One mutable file per experiment when exploring
- 15-minute cap on experiments
- Every 5th task: moonshot — pick from unknown territory in the knowledge model

### 4. Measure
Three tiers, in priority order:

**Value** (the one that matters): Run `rhino eval .` — did any assertions change status? An assertion going from Failing → Passing is the strongest signal that real progress happened. An assertion going from Passing → Failing is a regression that matters more than any score drop.

**Health**: Run `rhino score .` after every task. Compare to previous score. Read `integrity.max_single_commit_delta` from `config/rhino.yml` (default: 15).

- **Score up** → keep the change, check off the task
- **Score flat** → keep if the change is structural/foundational, otherwise reconsider
- **Score down >max_single_commit_delta** → revert immediately (`git checkout -- .`), no discussion. Log why the drop happened, update model.
- **Score down 1–max_single_commit_delta** → explain specifically why keeping the change is worth the regression. If you can't articulate a concrete reason tied to the bottleneck, revert.
- **EXCEPTION**: if the change caused an assertion to go Failing → Passing, a score drop up to max_single_commit_delta is acceptable. Value outranks health.

This is mechanical. "The change is foundational" is not a valid reason to keep a score drop. Cite the bottleneck OR a passing assertion.

**Craft**: If `rhino taste` is available (product lens installed at `lens/product/`), run it every 3 iterations (configurable via `go.taste_every_n`) or when visual quality matters.

### 4b. Log results
Append to `.claude/experiments/results.tsv`. Create with header if missing:
```
date	commit	score	eval_pass_rate	delta	lines_changed	status	description
```

Fields:
- `status`: kept | discarded | crashed | skipped
- `description`: prediction text, truncated to 80 chars, tabs replaced with spaces
- `delta`: score change from previous iteration
- `lines_changed`: net lines from `git diff --stat HEAD~1`

Log every iteration, including crashes and skips.

### 4c. Complexity gate
After the score decision, measure the diff:
- Run `git diff --stat HEAD~1` → net lines added/removed, files touched

Rules:
- **Net negative lines (simplification)**: always keep if score didn't drop
- **Small change** (net ≤ `simplicity_bias` from config, default 20, AND ≤ 2 files): standard keep/discard rules
- **Complex + marginal** (net > `simplicity_bias` OR > 2 files, AND gain < `marginal_gain_threshold` from config, default 2): flag as suspect. Keep only if the change directly addresses the current bottleneck
- This is a bias, not a hard gate — bottleneck relevance and founder direction override

### 5. Update the model
Fill in the `result`, `correct`, and `model_update` columns in predictions.tsv.

If the prediction was wrong:
1. Why? What mechanism was different than expected?
2. Update `~/.claude/knowledge/experiment-learnings.md` — move patterns between Known/Uncertain/Unknown/Dead Ends as evidence warrants.

### 6. Check off and continue
Before marking done:
1. Verify the task's `accept` criteria are met. If any criterion fails, fix it before marking complete.
2. If the task was generated from a failing assertion (beliefs.yml), run `rhino eval .` to verify the assertion now passes. If it still fails, the task is NOT done — keep iterating.
3. Mark task complete: run `rhino plan done <task-id>` (updates plan.yml). Fallback: mark `[x]` in active-plan.md. Also update the Claude Code task (TaskUpdate → completed). Pick the next one. Loop.

### Mid-loop research detour
If during a build task you hit an unknown that blocks progress (not in experiment-learnings.md, no relevant predictions):
1. Log the unknown
2. Run `/research [the unknown]` inline — this produces a state transition + hypothesis
3. Resume the build task with the new knowledge
Don't guess through unknowns. Research them.

### Mid-loop friction logging
When you encounter unexpected friction during a build task (confusing code, missing types, undocumented behavior, brittle patterns):
1. Note it in `.claude/state/codebase-model.md` under "Technical Debt & Risks"
2. Don't fix it unless it's the current task — just log it for future `/plan` sessions
3. This builds the codebase model incrementally through actual build experience

## Between iterations — status pulse
Every 3 iterations, output a brief status line:
```
[iteration N] score: X → Y | tasks: done/total | prediction accuracy: N/M
```

## When the loop ends

### Learnings compaction
If this session completed 10+ iterations, compact `~/.claude/knowledge/experiment-learnings.md`:
- Merge related entries in the same zone (e.g., two Uncertain patterns about the same mechanism → one entry with combined evidence)
- Update keep rates on Known patterns using predictions.tsv
- Prune entries that haven't been cited in any prediction for 20+ experiments (they're noise)
- Move Uncertain patterns with 3+ confirming experiments to Known

### Completion summary
Output:
- Tasks completed (with kept/reverted counts)
- Score trajectory (start → end)
- Prediction accuracy for this session
- Knowledge model updates made
- What the bottleneck is NOW (it may have shifted)
- **Results stats** (from `.claude/experiments/results.tsv`):
  - Experiments: N total (K kept, D discarded, C crashed)
  - Keep rate: K/(K+D)
  - Best single improvement: description (+X pts)

If the plan is complete, note what the next bottleneck would be — set up tomorrow's /plan.

## Overnight mode

When the loop completes 10+ iterations, write `.claude/state/morning-summary.md` with a structured handoff for the founder:

```markdown
# Morning Summary — [date]

## Experiments
| # | Hypothesis | File changed | Score delta | Kept/Reverted |
|---|-----------|-------------|-------------|---------------|
| 1 | ...       | ...         | +3          | kept          |

**Results**: N total (K kept, D discarded, C crashed) · Keep rate: X% · Best: description (+Y pts)

## Assertions
- [belief-id]: Failing → Passing (or vice versa)
- (list any status changes)

## Prediction Accuracy
- This session: N/M correct (X%)
- Calibration: HEALTHY / TOO_SAFE / BROKEN

## Proposed Next Bottleneck
[What the system thinks should be worked on next, with evidence]
```

Create `.claude/state/` directory if it doesn't exist. This summary is the overnight handoff — the founder reads it in the morning instead of re-reading the full session.

## Corpus research mode (--corpus)

When `/go --corpus` is used, the loop switches to corpus research mode instead of the normal build loop:

1. **Search for candidates**: scan reputation signals (Awwwards, Product Hunt top products, design galleries) for sites in the target categories defined in `corpus.categories` from rhino.yml
2. **Screenshot + score**: for each candidate, use `rhino taste` to screenshot and score via multi-model consensus
3. **Admit if exceptional**: if consensus score > `corpus.min_consensus_score` (default 8.0) and variance < `corpus.max_score_variance` (default 0.5), admit to corpus under the matching category
4. **Evict stale**: remove corpus entries older than `corpus.staleness_days` (default 90 days)
5. **Write summary**: write `lens/product/corpus/LAST_RESEARCH.md` with candidates evaluated, admitted/rejected with scores, evictions made

The corpus is taste memory — it anchors the visual eval against real examples instead of abstract criteria.

## What you never do
- Skip the prediction step. Every iteration predicts.
- Continue past a plateau without changing strategy. Plateau = the current approach is exhausted.
- Modify score.sh, score-product.sh, or taste.mjs during the loop. The eval harness is immutable.
- Run more than 15 minutes on a single experiment without measuring.

## Crash recovery

When any step in the iteration fails (build error, test failure, tool crash):
1. Read last 50 lines of error output
2. Classify:
   - **Trivial** (syntax error, missing import, typo): fix inline + retry once
   - **Fundamental** (missing package, incompatible API, design flaw): skip
3. On second failure or fundamental error: `git checkout -- .`, log "crashed" to results.tsv, continue to next task
4. Track consecutive crashes. If `crash_retry_limit` (default 3 from `config/rhino.yml`) consecutive tasks crash, **stop the loop** — something systemic is wrong. Output the crash patterns and ask the founder to investigate.

Crash recovery is automatic. Don't ask for permission to retry trivial errors. Do ask before stopping the loop for systemic failures.

## If something breaks
- **`rhino score .` fails**: check if the project builds (`npm run build` or equivalent). If build is broken, fix the build first — that's now your task. If score.sh itself errors, log the error and continue without scoring (but do NOT skip the revert check — use git diff size as a proxy).
- **plan.yml AND active-plan.md missing**: run /plan logic inline (read state, find bottleneck, write plan). Do not improvise tasks.
- **Dirty git state** (uncommitted changes from outside the loop): stash with `git stash` before starting. Do not build on top of unknown changes.
- **experiment-learnings.md missing**: create it with empty sections (Known, Uncertain, Unknown, Dead Ends) and continue. First predictions will declare "No prior evidence — exploring."

$ARGUMENTS
