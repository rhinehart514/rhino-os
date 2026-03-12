---
name: go
description: "Karpathy NEVER STOP mode. Plan -> build -> measure -> repeat. Eats through the backlog until done or plateau."
user-invocable: true
argument-hint: "[--corpus]"
---

# Go — Autonomous Build Loop

Plan -> build -> measure -> repeat. NEVER STOP. Eats through the product backlog.

## Setup

1. Read `.claude/product-todo.md` — the full backlog. This is what "done" looks like.
2. Read `.claude/plans/active-plan.md` — existing sprint?
3. Read `~/.claude/knowledge/experiment-learnings.md`
4. Read `.claude/rules/hypotheses.md`
5. Config: plateau_threshold=3 (from rhino.yml `go.plateau_threshold`), taste_every_n=3

## The Loop

No iteration cap. Runs until a stop condition is hit.

### 1. Plan (if no active plan or plan complete)
- Execute `programs/strategy.md` inline
- Strategy picks next items from product-todo.md targeting the bottleneck
- Create Tasks via TaskCreate for cross-session tracking
- Produces new sprint at `.claude/plans/active-plan.md`

### 2. Build Next Task
- Find next uncompleted task in active-plan.md
- Execute via `programs/build.md`
- Run `rhino score .` after each task
- On completion: check off in active-plan.md, product-todo.md, and TaskUpdate
- Run `hooks/post_build.sh` if available (scores + evals)

### 3. Measure
- Score dropped -> revert (`git reset --hard HEAD~1`), log as discard
- Score flat for plateau_threshold consecutive tasks -> **STOP** (plateau detected)
- Every taste_every_n iterations -> run `rhino taste`

### 4. Corpus Update (if `--corpus` flag)
- Every 5 iterations (configurable via `corpus.update_every_n_iterations` in rhino.yml)
- Run `/corpus update` for the next category in rotation
- Categories rotate: ui/saas -> ui/consumer -> ui/developer -> copy/landing -> copy/onboarding -> code/patterns

### 5. Review (when plan complete)
- Run `rhino score .` + `rhino taste` (if applicable)
- Extract gaps -> add new items to product-todo.md if discovered
- Write to `.claude/plans/review-gaps.md`
- Generate new plan from backlog -> continue loop

### 6. Update State
- Update `.claude/rules/product-brief.md` with scores + backlog progress
- Update `.claude/rules/hypotheses.md` if experiments validated/killed beliefs
- Log to `.claude/brains/experiment-log.md`
- Commit changes

## Stop Conditions

- **Backlog complete** — all items in product-todo.md checked off -> product is DONE
- **Plateau detected** — plateau_threshold consecutive tasks with no score improvement
- Score dropped below stage floor
- User interrupts

## After Stopping

Print summary:
```
Go loop: [N] iterations
Backlog: [X/Y] done ([Z%] of product)
Score: [start] -> [end] (delta: [+/-X])
Taste: [start] -> [end] (if ran)
Tasks completed: [N]
Plateau: [yes/no — if yes, what was flat]

[If backlog complete]: Product backlog is 100% complete! Review with /status.
[If plateau]: Score plateaued at [N] for [threshold] consecutive tasks. Consider:
  - /research to find new approaches
  - /plan --brainstorm for divergent ideas
  - /eval to check if beliefs are holding
[Otherwise]: Run /plan to pick up where this left off. [Y] items remaining.
```
