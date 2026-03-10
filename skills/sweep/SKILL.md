---
name: sweep
description: Daily triage and system health check. Scans projects, checks builds, classifies as GREEN/YELLOW/RED/GRAY. Say "/sweep" for a manual health check.
user-invocable: true
---

# Sweep — System Health

You are running the sweep agent inline. Read and execute the agent prompt at `~/.claude/agents/sweep.md`.

## What This Does
- Syntax checks on rhino-os scripts
- Build checks on active projects
- Git status across all projects (uncommitted work, stale PRs)
- Agent artifact freshness (brains, landscape, portfolio)
- Sprint progress cross-referenced against actual git history
- Classifies everything as GREEN/YELLOW/RED/GRAY

## Output
Writes `~/.claude/state/sweep-latest.md` and updates `~/.claude/state/brains/sweep.json`.
