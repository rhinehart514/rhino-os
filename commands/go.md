---
name: go
description: "Use when you want autonomous building with measurement and prediction grading"
---

!cat .claude/cache/score-cache.json 2>/dev/null | jq -r '.score // "?"' 2>/dev/null || echo "no score"
!tail -5 .claude/knowledge/predictions.tsv 2>/dev/null || echo "no predictions"

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

**Use context7 for library/framework docs.** When you hit an unknown about a library or framework, use context7 (resolve-library-id → query-docs) instead of web search. Real docs beat search results for technical accuracy.

**Use playwright for visual verification.** When you need to verify visual behavior or test a live deployment, use playwright (browser_navigate, browser_snapshot, browser_evaluate).

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
5. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known patterns, dead ends to avoid
6. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — recent predictions (calibration)
7. `.claude/cache/score-cache.json` — per-feature scores (baseline)
8. `config/rhino.yml` features section — maturity, weight, depends_on

**Compute the product map:**
- Product completion % (weighted maturity average)
- Bottleneck feature (lowest maturity × highest weight)
- Dependency order (don't build features whose dependencies aren't working yet)

If no tasks exist and no plan exists, use the product map to decide what to build: target the bottleneck feature, aim to move it to the next maturity level.

This context informs every prediction and decision in the loop.

## Agent-assisted mode

When a move is complex (multiple files, new feature, unfamiliar territory):
1. Spawn `explorer` agent if the move requires research (unfamiliar library, unknown territory)
2. Spawn `builder` agent with task description + acceptance criteria
3. Spawn `measurer` agent after builder commits — get honest measurement
4. Spawn `reviewer` agent for quality check against product standards
5. Decide keep/revert based on measurer + reviewer results

For simple single-file fixes, work directly (no agents needed). Agent coordination adds overhead — only use it when the move genuinely benefits from parallel investigation or honest external measurement.

Agent definitions live in `agents/` (measurer.md, explorer.md, builder.md, reviewer.md).

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
Because: [cite specific entry from experiment-learnings.md or self.md — "I think this will work" without citation is not valid]
  OR: Exploring: [what this experiment will teach us if it works / if it fails]
I'd be wrong if: [falsification condition]
```
Log to `.claude/knowledge/predictions.tsv`.

### 3. Build
Build the whole feature end-to-end. Any number of files. Follow `mind/standards.md`.
Make atomic git commits — each commit is a reviewable, revertable unit.

### 4. Measure
Run `rhino eval .` after each commit. Eval = value (assertion pass rate). Use `rhino score .` as a supporting health check.

- **Infrastructure or logic layer regressed** → revert the commit, log why (mechanical, reliable)
- **UX layer regressed** → warn but don't auto-revert (LLM variance too high for mechanical keep/revert)
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

  product: **58%** → **64%** ↑6   score: 50 → 68 ↑18
  moves: **3** completed · 1 reverted
  predictions: 3/4 correct (75%)

▾ product map (after)
  scoring    ████████████████████  polished  w:5
  commands   ████████████████░░░░  working   w:5
  learning   ██████░░░░░░░░░░░░░░  building  w:4  ← bottleneck
  install    ████████████████████  polished  w:3

▾ what changed
  ✓ move 1: wired trend_for() in score output (+10 scoring)
  ✗ move 2: auto-grade attempt broke session_start hook (reverted)
  ✓ move 3: added cross-recommendations to /eval (+2 commands)

▾ maturity updates
  · scoring: working → polished (all assertions passing + tests)
  · commands: building → working (cross-recommendations wired)

▾ model updates
  · trend visualization is high-ROI (Known Pattern — 3 experiments)
  · session_start hook is fragile — needs tests before modification (Uncertain)

bottleneck: **learning** (building, w:4) — unchanged, needs different approach

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

## Session log (after loop ends)

When the loop ends, write a session summary to `.claude/sessions/YYYY-MM-DD-HH.yml`:

```yaml
date: 2026-03-14T02:30:00Z
scope: learning
moves: 3
kept: 2
reverted: 1
score_before: 84
score_after: 86
delta: +2
predictions:
  - text: "grade.sh will raise learning from 62 to 70+"
    correct: partial
    model_update: "auto-grading helps but doesn't replace Claude judgment"
features_changed:
  learning: 62 → 68
  commands: 65 → 65
learnings:
  - "Auto-grading works for directional claims but misses nuanced predictions"
```

Create the `.claude/sessions/` directory if it doesn't exist. Use the session's start time for the filename. Include all predictions made during this session with their outcomes. The `learnings` field captures model updates — what the system learned that it didn't know before.

This file is the evidence trail. `rhino trail` aggregates these into a visible arc of improvement.

## What you never do
- Skip the prediction step
- Continue past plateau without researching
- Modify score.sh or eval.sh during the loop (immutable eval harness)
- Output walls of unformatted text — use the templates above

## If something breaks
- `rhino score .` fails: use git diff size as proxy, do NOT skip revert check
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting
- strategy.yml missing: skip strategy read, use feature pass rates as priority
- experiment-learnings.md missing: create with standard template (Known/Uncertain/Unknown/Dead Ends)
- predictions.tsv missing: create with header row, note "first session"

$ARGUMENTS
