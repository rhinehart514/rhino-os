---
description: "Fully autonomous mode. Plan, predict, build, measure, update model, repeat. Accepts a feature name to scope: /go auth"
---

# /go

Autonomous creation loop. You plan, build, measure, and learn — no human in the loop until you hit a wall or plateau.

## Feature scoping

`$ARGUMENTS` can contain one or more feature names: `/go auth`, `/go auth scoring`, `/go auth scoring cli`.

**Single feature**: scope everything to that feature — tasks, assertions, files.

**Multiple features**: spawn an Agent per feature with `isolation: "worktree"`. Each works in its own branch. Merge when assertions pass.

**No features**: execute the full plan. If tasks span 3+ features, auto-parallelize with agents.

For each feature:
- Only work on tasks for that feature
- Only measure with `rhino eval . --feature [name]`
- If no plan exists, run `/plan [feature]` logic first

## Tools to use

**Use TaskList/TaskUpdate** to track progress. At loop start, call TaskList to find tasks. Mark in_progress when starting, completed when done. This replaces checking plan.yml checkboxes.

**Use worktrees when working on multiple features.** If the plan has tasks across 2+ features, use `isolation: "worktree"` on Agent calls to work in isolated branches. Each feature gets its own branch — merge when assertions pass.

**Use CronCreate for auto-scoring.** At loop start, schedule a recurring score check:
- Every 10 minutes: `rhino score . --quiet` → if score dropped, notify
- This catches regressions while you're building, not just at measure time

**Use Agent with worktrees for parallel feature work.** When multiple features need work:
- Spawn an Agent per feature with `isolation: "worktree"`
- Each agent works independently in its own branch
- When an agent's assertions pass, merge its branch

**Use WebFetch/WebSearch for research detours.** When you hit an unknown:
- Search for solutions, docs, examples
- Fetch relevant pages
- Update experiment-learnings.md with findings

## The loop

```
Read tasks → Pick task → Predict → Build → Measure → Update model → Next task
```

### 1. Pick the task
Call TaskList. Find next task with status todo. If tasks span multiple features and you're not scoped to one, consider spawning parallel agents.

### 2. Predict
```
I predict: [specific outcome]
Because: [cite experiment-learnings.md or declare exploration]
I'd be wrong if: [falsification condition]
```
Log to `~/.claude/knowledge/predictions.tsv`.

### 3. Build
Execute the task. Follow `mind/standards.md`.

### 4. Measure
Run `rhino score .` after every task. The score IS the assertion pass rate.

- **Assertion regressed** (was passing, now failing) → revert, log why
- **Assertion progressed** (was failing, now passing) → keep
- **Score up or flat** → keep
- **Score down >15** → revert immediately

### 5. Update model
Fill in prediction result. If wrong, update experiment-learnings.md.

### 6. Mark done
TaskUpdate → completed. Pick next task. Loop.

## Plateau handling
If score hasn't improved in 3 consecutive tasks:
1. Stop building — current approach is exhausted
2. Research inline (WebSearch, read experiment-learnings.md Unknown Territory)
3. If research produces a hypothesis → create new task, continue
4. If no hypothesis → stop the loop

## Auto-scoring (CronCreate)
At loop start, set up recurring score monitoring:
```
CronCreate: "Run rhino score . --quiet and report if score changed"
Interval: 10 minutes
```
Cancel the cron when the loop ends.

## Crash recovery
- **Trivial** (syntax error, missing import): fix inline, retry once
- **Fundamental** (missing package, design flaw): skip task
- **3 consecutive crashes**: stop the loop, ask founder

## When the loop ends
Output:
- Tasks completed (with kept/reverted counts)
- Score trajectory (start → end)
- Prediction accuracy for this session
- What the bottleneck is NOW

Cancel any CronCreate jobs. Clean up any worktrees.

## What you never do
- Skip the prediction step
- Continue past plateau without researching
- Modify score.sh or eval.sh during the loop (immutable eval harness)

## If something breaks
- `rhino score .` fails: use git diff size as proxy, do NOT skip revert check
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting

$ARGUMENTS
