---
name: openclaw
description: "Chat-optimized interface for OpenClaw users. Formats rhino-os output for messaging delivery. /openclaw pulse, /openclaw ask, /openclaw nudge, /openclaw bet, /openclaw grunt."
argument-hint: "[pulse|ask|nudge|bet|grunt]"
allowed-tools: Read, Bash, Grep, Glob, Agent
---

# /openclaw

The interface layer for OpenClaw users. When OpenClaw's coding-agent spawns Claude Code, this skill formats rhino-os intelligence for chat delivery — tight, plain-language, one-message responses that work in Telegram/Slack/WhatsApp.

**Not a separate product.** It's a view layer. Every sub-command calls existing rhino-os internals and reformats for a chat bubble.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `references/formatting-guide.md` — how to format output for messaging platforms
- `reference.md` — output templates for every route
- `gotchas.md` — real failure modes. **Read before formatting output.**

## Design rules

1. **One message.** Fits in a single chat bubble. No dashboards, no dividers.
2. **Plain language.** No `w:5` or `◐` or `███`. Write like texting a cofounder.
3. **Opinion first.** Lead with what matters, details after.
4. **Actionable.** End with what to do next — as prose, not `/command` syntax.

## Routing

### `pulse` — product heartbeat
One-message status. Run `rhino score . --quiet`, read eval-cache, rhino.yml, roadmap.yml, `git log --oneline -3`. Output: score, what happened, bottleneck, one opinion. Under 280 chars when possible.

### `ask <question>` — natural language query
Parse question, route to right internal. "how's auth?" reads feature data. "what broke?" reads git log + score delta. "what should I work on?" reads plan.yml. Direct answer in 1-3 sentences.

### `nudge` — proactive observation
Check in order, stop at first match: score drop, stale todos, ungraded predictions, stuck features, stale thesis evidence, no recent commits. One paragraph + what to do about it.

### `bet <prediction>` — log a prediction
Parse prediction, infer evidence and falsification criteria, append to predictions.tsv. Confirm what was logged.

### `grunt` — autonomous cleanup
Baseline score, find mechanical fixes (dead imports, lint warnings, stale TODOs), spawn builder agent in worktree, re-score, report delta. Auto-discard if score drops.

### (no arguments) — help
Show the 5 commands with one-line descriptions.

## System integration

Reads: `.claude/cache/score-cache.json`, `.claude/cache/eval-cache.json`, `config/rhino.yml`, `.claude/plans/roadmap.yml`, `.claude/plans/plan.yml`, `.claude/plans/todos.yml`, `~/.claude/knowledge/predictions.tsv`, `git log`
Writes: `~/.claude/knowledge/predictions.tsv` (bet mode)
Triggers: `/go` (grunt mode spawns builder), existing rhino-os internals (pulse/ask/nudge read caches)
Triggered by: OpenClaw coding-agent spawn, manual

## What you never do

- Output terminal formatting (dividers, progress bars, ANSI, box drawing)
- Give long responses — every output fits in a chat bubble
- Use rhino-os jargon without explaining it
- Recommend slash commands — the user might not be in Claude Code
- Skip the opinion — every response ends with what to do next

## If something breaks

- `pulse` returns "no score": run `rhino score .` first — pulse reads from score-cache which requires at least one score run
- `grunt` builder agent fails: the worktree may have conflicts — check `git status` in the worktree, or the project may not have a clean main branch
- `bet` prediction not logged: check that `~/.claude/knowledge/predictions.tsv` exists with the correct header row

$ARGUMENTS
