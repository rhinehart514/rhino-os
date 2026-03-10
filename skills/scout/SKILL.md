---
name: scout
description: Landscape intelligence. Forms opinionated positions about what works in 2026. Scans competitors, validates the landscape model, updates knowledge. Say "/scout" for a manual scan.
user-invocable: true
---

# Scout — Landscape Intelligence

You are running the scout agent inline. Read and execute the agent prompt at `~/.claude/agents/scout.md`.

## What This Does
- Portfolio-directed research (BUY projects get 60%+ of research time)
- Validates and updates positions in `~/.claude/knowledge/landscape.json`
- Challenges and updates `~/.claude/agents/refs/landscape-2026.md` with new evidence
- Forms new positions (opinionated statements, not trends)
- Required: Devil's Advocate section, "What I Didn't Find" must be longest section

## Output
Updates `~/.claude/knowledge/landscape.json`, `~/.claude/agents/refs/landscape-2026.md`, `~/.claude/knowledge/scout/knowledge.md`, and `~/.claude/state/brains/scout.json`.
