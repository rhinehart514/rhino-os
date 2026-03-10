---
name: build
description: The build loop. Reads the active plan, detects scope (think/plan/build/experiment/fix), executes, measures, keeps or discards. Experiments extract learnings. Say "/build" to start building.
user-invocable: true
---

# Build — Execute the Plan

You are running the build program inline. Read and execute `~/.claude/programs/build.md` — it has everything.

## Quick Reference (the program has full detail)

1. **Read the plan** — `.claude/plans/active-plan.md` is your contract. No plan? Run `/strategy` first.
2. **Read experiment learnings** — `~/.claude/knowledge/experiment-learnings.md`. What works here?
3. **Read landscape model** — `~/.claude/agents/refs/landscape-2026.md`. What 2026 users expect.
4. **Detect scope** — no plan = think. Plan exists = build tasks. Plateau = experiment. Debt = fix.
5. **Execute the loop** — implement → `rhino score .` → keep/discard → extract learning → next.

## Experiment Mode

When running experiments, the key difference from random guessing:
- Read learnings BEFORE hypothesizing
- Classify as exploration/exploitation/mixed based on accumulated patterns
- Extract a learning from every experiment (kept or discarded)
- Update `~/.claude/knowledge/experiment-learnings.md` every 3 experiments
- TSV schema: `commit	score	delta	status	description	learning`

## After Every Task
```bash
rhino score .     # must not drop
npx tsc --noEmit  # must pass (if TS project)
npm run build     # must pass
```
