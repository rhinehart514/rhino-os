---
description: "Fully autonomous mode. Plan, predict, build, measure, update model, repeat. Accepts a feature name to scope: /go auth"
---

# /go

Autonomous creation loop. You plan, build, measure, and learn — no human in the loop until you hit a wall or plateau.

## Feature scoping

`$ARGUMENTS` can contain one or more feature names: `/go auth`, `/go auth scoring`, `/go auth scoring cli`.

**Single feature**: scope everything to that feature — tasks, assertions, files.

**Multiple features**: work on them sequentially, one at a time, measuring after each.

**No features**: execute the full plan. Work through tasks in priority order.

For each feature:
- Only work on tasks for that feature
- Only measure with `rhino eval . --feature [name]`
- If no plan exists, run `/plan [feature]` logic first

## Tools to use

**Use TaskList/TaskUpdate** to track progress. At loop start, call TaskList to find tasks. Mark in_progress when starting, completed when done. This replaces checking plan.yml checkboxes.

**Use WebFetch/WebSearch for research detours.** When you hit an unknown:
- Search for solutions, docs, examples
- Fetch relevant pages
- Update experiment-learnings.md with findings

## State to read at start (parallel)

Before building, read:
1. TaskList — existing tasks
2. `rhino todo active` — promoted todos (founder's priority)
3. `.claude/plans/strategy.yml` — current bottleneck, stage
4. `.claude/plans/roadmap.yml` — current thesis (what we're trying to prove)
5. `~/.claude/knowledge/experiment-learnings.md` — known patterns, dead ends to avoid
6. `~/.claude/knowledge/predictions.tsv` — recent predictions (calibration)
7. `.claude/cache/score-cache.json` — per-feature scores (baseline)

This context informs every prediction and decision in the loop.

## The loop

```
Read state → Pick move → Predict → Build → Commit → Eval → Keep/revert → Update model → Next
```

### 1. Pick the move
A move = a feature-level intent. Not a single-file tweak. Understand the full scope before starting.
Call TaskList for existing tasks. Promoted todos = founder's explicit priority.

### 2. Predict
```
I predict: [specific outcome]
Because: [cite experiment-learnings.md or declare exploration]
I'd be wrong if: [falsification condition]
```
Log to `~/.claude/knowledge/predictions.tsv`.

### 3. Build
Build the whole feature end-to-end. Any number of files. Follow `mind/standards.md`.
Make atomic git commits — each commit is a reviewable, revertable unit.

### 4. Measure
Run `rhino eval .` after each commit. Eval = value (assertion pass rate). Use `rhino score .` as a supporting health check.

- **Assertion regressed** (was passing, now failing) → revert the commit, log why
- **Assertion progressed** (was failing, now passing) → keep
- **Eval stable or improved** → keep
- **Score dropped but assertions held** → keep (value > health)

### 5. Update model
Fill in prediction result. If wrong, update experiment-learnings.md.

### 6. Mark done
TaskUpdate → completed. Pick next move. Loop.

## Output format

### During the loop — after each move:

```
◆ move 1 — [title]

  predict: [what I expected]
  result:  [what happened]
  verdict: ✓ kept (scoring 58 → 62) | ✗ reverted (learning regressed) | — stable

  [1-2 sentences on what changed and why]
```

### When the loop ends:

```
◆ go — session complete

  moves: **3** completed · 1 reverted
  eval:  scoring 58→68 ↑10 · learning 48→48 — · commands 70→72 ↑2
  predictions: 3/4 correct (75%)

▾ what changed
  ✓ move 1: wired trend_for() in score output (+10 scoring)
  ✗ move 2: auto-grade attempt broke session_start hook (reverted)
  ✓ move 3: added cross-recommendations to /eval (+2 commands)

▾ model updates
  · trend visualization is high-ROI (Known Pattern — 3 experiments)
  · session_start hook is fragile — needs tests before modification (Uncertain)

bottleneck now: **learning** at 48 — unchanged, needs different approach

/eval full        validate before shipping
/ideate learning  current approach exhausted — brainstorm
/plan             next session
```

**Formatting rules:**
- Per-move: `◆ move N — [title]`, predict/result/verdict, brief narrative
- Session summary: moves count, eval trajectory with deltas, prediction accuracy
- What changed: ✓/✗ per move, one line each
- Model updates: new patterns discovered, formatted as experiment-learnings entries
- Bottleneck: bold feature name, current score, one-sentence diagnosis
- Bottom: 2-3 relevant next commands

## Plateau handling
If assertions haven't improved in 3 consecutive moves:
1. Stop building — current approach is exhausted
2. Research inline (WebSearch, read experiment-learnings.md Unknown Territory)
3. If research produces a hypothesis → create new task, continue
4. If no hypothesis → stop the loop

## Crash recovery
- **Trivial** (syntax error, missing import): fix inline, retry once
- **Fundamental** (missing package, design flaw): skip task
- **3 consecutive crashes**: stop the loop, ask founder

## What you never do
- Skip the prediction step
- Continue past plateau without researching
- Modify score.sh or eval.sh during the loop (immutable eval harness)
- Output walls of unformatted text — use the templates above

## If something breaks
- `rhino score .` fails: use git diff size as proxy, do NOT skip revert check
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting

$ARGUMENTS
