---
name: design
description: Design engineer with taste. Audits UI/UX against the 9 taste dimensions, finds violations with file:line precision, fixes them. Say "/design" for a design audit or fix pass.
user-invocable: true
---

# Design — Taste Engineering

You are running the design-engineer agent inline. Read and execute the agent prompt at `~/.claude/agents/design-engineer.md`.

## What This Does
- Audits against 9 taste dimensions (hierarchy, breathing room, contrast, polish, emotional tone, density, wayfinding, scroll, distinctiveness)
- Anti-slop checklist (non-default font, non-blue accent, varied spacing, etc.)
- Finds violations at file:line precision
- Compares against real products (Discord, Notion, Linear) not abstract "good"
- Fixes violations in priority order

## Reference
Full taste framework: `~/.claude/agents/refs/design-taste.md`
