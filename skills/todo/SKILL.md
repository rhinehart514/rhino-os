---
name: todo
description: "Use when managing backlog items — capture, tag, prioritize, promote, decay"
argument-hint: "[add \"title\"|done <id>|promote <id>|active|health|decay]"
allowed-tools: Read, Bash, Edit, Grep, Glob, AskUserQuestion
---

!cat .claude/plans/todos.yml 2>/dev/null | grep -c 'status: backlog' 2>/dev/null || echo "0"
!cat .claude/plans/todos.yml 2>/dev/null | grep -c 'status: active' 2>/dev/null || echo "0"

# /todo

A living backlog. Decays stale items, graduates recurring todos to assertions, surfaces the right item based on what the product needs.

Storage: `.claude/plans/todos.yml`

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/todo-stats.sh` — backlog health: counts, age distribution, feature clusters, stale items
- `scripts/todo-decay.sh` — finds items >7d, >14d, >30d — flags for review or auto-kill suggestions
- `scripts/todo-promote.sh` — finds todos that should graduate to assertions or activate based on eval-cache bottleneck
- `references/todo-lifecycle.md` — captured→tagged→prioritized→promoted/killed, decay rules, graduation criteria
- `references/todo-sources.md` — where todos come from: /ideate, /eval, /go, manual, agents
- `templates/todo-template.yml` — valid fields for a todo item
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read before any batch operation.**

## Routing

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| (no args) or `show` | Run `todo-stats.sh` → list items → decay check → smart promote |
| `add "title"` | Capture to backlog. Auto-tag if feature/version detected. |
| `done <id>` | Mark complete. Check graduation via `todo-promote.sh`. |
| `promote <id>` | Activate for session |
| `active` | Show active only |
| `tag <id> <feature>` | Tag to feature (validated against rhino.yml) |
| `tag <id> v8.0` | Tag to version |
| `feature [name]` | Filter by feature |
| `version [tag]` | Filter by version |
| `health` | Run `todo-stats.sh` — full backlog health report |
| `decay` | Run `todo-decay.sh` — force stale item decisions |
| `all` | Show all including done |
| (plain text) | Quick capture: treat as `add "$ARGUMENTS"` |

## Core behaviors

**Decay**: Run `todo-decay.sh` on every show. Surfaces stale items, forces decisions. Never auto-deletes.

**Graduation**: On `done`, run `todo-promote.sh` to check if recurring pattern should become an assertion. Needs founder confirmation via AskUserQuestion.

**Smart promote**: When 0 active items, `todo-promote.sh` suggests highest-leverage item based on eval-cache bottleneck.

**Auto-tag**: On `add`, scan title for feature names from `config/rhino.yml`, version refs, file paths. Confirm with founder.

**Cross-skill capture**: Skills and agents write todos via `todo:` prefixed SendMessage. See `references/todo-sources.md`.

For lifecycle details: `references/todo-lifecycle.md`
For output templates: `reference.md`

## State to read

- `.claude/plans/todos.yml` — the backlog
- `config/rhino.yml` — feature names for validation + auto-tagging
- `.claude/cache/eval-cache.json` — sub-scores for smart promote
- `lens/product/eval/beliefs.yml` — existing assertions (for graduation dedup)

## What you never do

- Auto-delete stale items — decay surfaces, founder decides
- Auto-promote items — suggest, don't act
- Show done items unless `all` or `version` specified
- Graduate to assertion without founder confirmation

## If something breaks

- No todos.yml → create it on first `add`
- Invalid subcommand → show routing table
- No eval-cache for smart promote → skip, show basic list
- No beliefs.yml for graduation → create it with the graduated assertion

$ARGUMENTS
