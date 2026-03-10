---
name: strategy
description: Product strategy with causal diagnosis. Maps the creation loop, finds the earliest broken link, diagnoses WHY, reads experiment learnings, produces a sprint plan. Say "/strategy" to decide what to build next.
user-invocable: true
---

# Strategy — What Should We Build?

You are running the strategy program inline. Read and execute `~/.claude/programs/strategy.md` — it has everything.

## Quick Reference (the program has full detail)

1. **Map the product loop**: Create → Share → Discover → Engage → Return. Score each link by reading the actual code.
2. **Find the earliest broken link** — not the lowest score, the earliest bottleneck in the chain.
3. **Diagnose WHY** — trace the user flow through code. Where does it break?
4. **Read experiment learnings** — `~/.claude/knowledge/experiment-learnings.md`. What works in this codebase?
5. **Read landscape model** — `~/.claude/agents/refs/landscape-2026.md`. What wins in 2026?
6. **Plan the sprint** — target the bottleneck, ordered by dependency, constrained by learnings.

## Output

Write to `.claude/plans/active-plan.md` with: product model, bottleneck, diagnosis, tasks, "do not build" list.

Write product model to `.claude/plans/product-model.md`.

Update project's `CLAUDE.md` with sprint priority + "do not build" list.
