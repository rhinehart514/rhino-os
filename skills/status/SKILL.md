---
name: status
description: "Co-founder briefing. Shows product backlog progress, pyramid, scores, and what to do next."
user-invocable: true
---

# Status — Co-Founder Briefing

## Input

Arguments: $ARGUMENTS

## 1. Product Progress (the big number)

Read `.claude/product-todo.md`. Count total items and completed items. This is the headline.

```
[PROJECT NAME] — [Z%] complete

BACKLOG PROGRESS
  ████████████░░░░░░░░  58% (47/81 items)

  Functional:     ████████████████░░░░  80% (24/30)
  Emotional:      ████████░░░░░░░░░░░░  40% (12/30)
  Ecological:     ████░░░░░░░░░░░░░░░░  20% (4/20)
  Infrastructure: █████████████████░░░  85% (7/8) -- not in denominator tho
```

This is the first thing the founder sees. How far are we from DONE?

## 2. Product Pyramid

Read `.claude/product-map.yml`. If missing: "No product map. Run `/setup`."

```
WHAT USERS CAN DO
  * [feature — polished]       routes: /path
  o [feature — functional]     routes: /path
  ~ [feature — wip]            routes: /path    <- INCOMPLETE
  . [feature — stub]           routes: /path    <- STUB
```

Sort by readiness ascending — worst features at top.

## 3. Creation Loop

From `.claude/plans/active-plan.md` product model section:

```
CREATION LOOP
  Create(2) -> Share(0) -> Discover(1) -> Engage(1) -> Return(0)
                  ^
            BOTTLENECK
```

## 4. Sprint Progress

From active-plan.md + Tasks API (use TaskList for live status):

```
SPRINT: [name]                                    [X/Y tasks]
  [x] completed task
  [ ] next task                                   <- CURRENT
  [ ] remaining task
```

## 5. Scores

From `.claude/cache/score-cache.json` and taste reports:

```
SCORES
  Structure: X/100    Taste: X/5 (weakest: [dim])
  Integrity: [clean / warnings]
```

## 6. What's Left (top items from backlog)

From product-todo.md, show the next 5-10 highest-priority uncompleted items:

```
NEXT UP (from backlog)
  1. [ ] Add share button on content pages          [Ecological / Sharing]
  2. [ ] Empty state guidance on dashboard           [Emotional / Onboarding]
  3. [ ] Handle password reset                       [Functional / Auth]
  4. [ ] Loading states on all async actions          [Emotional / Polish]
  5. [ ] Share preview cards (Open Graph)             [Ecological / Sharing]
```

Priority order: bottleneck layer first, then pyramid order (functional > emotional > ecological).

## 7. Hypotheses

From `.claude/rules/hypotheses.md`:

```
HYPOTHESES
  Active: [count]
  Last validated: [hypothesis]
  Last killed: [hypothesis]
```

## 8. Co-Founder Opinion

ONE opinionated recommendation based on:
1. Backlog progress — what's the biggest gap?
2. Bottleneck from creation loop
3. Weakest pyramid layer
4. Active hypotheses that need testing

```
MY TAKE: [direct, opinionated, no hedging]
Run: [suggested next command]
```
