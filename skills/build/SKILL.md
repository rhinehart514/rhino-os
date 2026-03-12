---
name: build
description: "Execute the plan. Scores every change, keeps or discards. Updates backlog + Tasks API on completion."
user-invocable: true
argument-hint: "[--experiment [dim]]"
---

# Build — Execute the Plan

## Input

Arguments: $ARGUMENTS

## Setup

1. Read `.claude/plans/active-plan.md` — your contract. No plan? Run `/plan` first.
2. Read `~/.claude/knowledge/experiment-learnings.md` — what works here.
3. Read `.claude/product-todo.md` — the full backlog (know where this task fits in the big picture).
4. Use TaskList to check current task status from Tasks API.

## Execute

Read and execute `programs/build.md` with the context loaded above.

**Standard build**: Detect scope -> execute -> score -> keep/discard -> next.

**Experiment mode** (`--experiment`): Autoresearch loop targeting a dimension.
Each experiment: one mutable file, immutable eval, 15-minute cap, mechanical keep/discard.

## After Every Task

```bash
rhino score .          # must not drop
```

Then update tracking:

1. **Check off in active-plan.md**: `- [ ]` -> `- [x]`
2. **Update Tasks API**: Use TaskUpdate to set task status to "completed"
3. **Check off in product-todo.md**: Find the matching item, mark as `[x]`
4. **Update product-map.yml**: Adjust completion % and quality % for the affected feature
5. **Update product-brief.md**: Refresh backlog progress count

This triple-write (plan + backlog + Tasks API) ensures nothing falls through cracks.

## Post-Build Hook

After the build task completes, run the post-build hook if available:

```bash
# In rhino-os install dir
bash hooks/post_build.sh
```

This runs `rhino score .` and belief evals automatically.

## Cold-Start Path

If `.claude/brains/experiment-log.md` is empty (no `## ` entries) OR this is a new project (no score history):
- Skip council check
- Skip taste knowledge
- Focus: implement task -> score -> report delta
- Use simplified "first build" mode — just get the task done and measure

## Teardown

1. Update `.claude/rules/product-brief.md` with current state
2. Print backlog progress: "Backlog: [X/Y] done ([Z%]). [N] items remaining in [layer]."
