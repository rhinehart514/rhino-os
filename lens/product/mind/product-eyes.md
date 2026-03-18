# Product Measurement — How You See

The product lens adds specific measurement tools beyond the base loop.

## Measurement Stack

Five tiers, orchestrated by `/score`:

1. `rhino score .` — **health tier**. Structural lint: dead ends, empty states, hygiene. Fast, free, every change. Gate: < 20 = score 0.
2. `/taste <url> flows` — **behavioral tier**. Does the frontend WORK? 6-layer audit via Playwright MCP. Reports issues by severity.
3. `/taste <url>` — **visual tier**. Product intelligence via Playwright MCP + Claude Vision. 11 dimensions, 0-100.
4. `rhino eval .` — **code tier**. Delivery + craft per feature (Claude judges claim vs code). No viability — that's tier 5.
5. `/score viability` — **viability tier**. Agent-backed market assessment. Spawns market-analyst + customer agents. Requires cited evidence.

**`/score`** — the unified orchestrator. Reads all five tier caches, flags staleness, synthesizes one authoritative number per feature. Run this when you want the real answer.

**The right order:** health → flows → visual → code → viability. Fix the foundation before polishing the surface.

Score drops after a change → revert. Score plateaus → rethink the approach.
The founder's words override scores when they conflict.
