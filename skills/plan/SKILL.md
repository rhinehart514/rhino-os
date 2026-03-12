---
name: plan
description: "Morning command. Reads the product backlog, identifies highest-leverage items, creates sprint tasks via Tasks API."
user-invocable: true
argument-hint: "[--brainstorm]"
---

# Plan — Start Your Day

## Input

Arguments: $ARGUMENTS

## Setup

1. Read `.claude/product-todo.md` — the full product backlog. This is the source of truth for what's left.
2. Read `.claude/product-map.yml` — pyramid state, features, completion, quality
3. Read `.claude/plans/active-plan.md` — existing sprint?
4. Read `.claude/rules/hypotheses.md` — active beliefs about users
5. Read `~/.claude/knowledge/experiment-learnings.md` — what works here

## Execute

### Path A: Active plan with uncompleted tasks

If active-plan.md exists with unchecked tasks:

1. Show sprint progress: X/Y tasks complete
2. Show backlog progress: X/Y total items ([Z%] of product complete)
3. Identify the next uncompleted task
4. Sync with Tasks API — use TaskGet to check if tasks exist, update status if needed
5. Check score cache (`.claude/cache/score-cache.json`) for integrity warnings
6. Output: "Continue sprint. Next task: [task]. Backlog: [X/Y] done overall."

### Path B: No plan or all tasks complete

1. **Health check**:
   - Git status: uncommitted work?
   - Score freshness: when was score last run?
   - Build status: does the build pass?
   - Classify: GREEN / YELLOW / RED
   - If RED -> surface the blocker

2. **Pick from backlog**:
   - Read `.claude/product-todo.md` — what's left?
   - Run `programs/strategy.md` inline to diagnose bottleneck
   - Strategy picks 3-5 items from the backlog that target the bottleneck
   - These become the sprint tasks

3. **Create Tasks via Tasks API**:
   - For each sprint task, call TaskCreate with description and status "pending"
   - Set dependencies between tasks (if task B requires A, use addBlockedBy)
   - This gives cross-session persistence and survives compaction

4. **Write active-plan.md** (the reasoning):
   - WHY these tasks (bottleneck diagnosis, evidence)
   - The tasks themselves (matching what was created in Tasks API)
   - Sprint prediction

5. Output: Sprint plan summary + today's top 3 tasks + backlog context

### Path C: Brainstorm (`--brainstorm`)

1. Read product-todo.md — identify weak pyramid layers and large gaps
2. Read experiment-learnings.md + hypotheses.md
3. Generate **5 options** across three layers:
   - At least 1 **build option** (product change targeting a loop link)
   - At least 1 **messaging option** (reframe, reposition — no code)
   - At least 1 **landscape play** (positioning, distribution, partnership)
4. Present options. Founder picks -> becomes next sprint.
5. Add any new items to product-todo.md that emerge from brainstorm.

## Output

Always ends with:

```
## Today

Backlog: [X/Y] items done ([Z%] of product)
Sprint: [X/Y tasks] or [new sprint started]
Health: [GREEN/YELLOW/RED]

1. [most important task] — [why]
2. [second task] — [why]
3. [third task] — [why]
```
