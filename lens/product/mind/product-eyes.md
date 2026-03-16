# Product Measurement — How You See

The product lens adds specific measurement tools beyond the base loop.

## Measurement Stack

- `rhino score .` — structural lint (health tier). For web products: dead ends, empty states, TS hygiene, navigation gaps. Fast, free, every change.
- `/taste <url>` — visual product intelligence (craft tier). Claude Code skill using Playwright MCP + Claude Vision natively. 11 dimensions scored 0-100, market-calibrated, persistent memory, auto-creates todos. Legacy CLI: `rhino taste`. Slow, expensive. Use when visual quality matters.
- `rhino eval .` — mechanical belief evals (value tier). DOM checks (contrast, click targets, hierarchy, distinctiveness), copy checks (clarity, specificity), positioning checks, blind playwright tests. Requires dev server for behavioral tiers.

Score drops after a change → revert. Score plateaus → rethink the approach.
The founder's words override scores when they conflict.
