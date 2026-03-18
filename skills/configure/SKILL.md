---
name: configure
description: "Tune rhino-os behavior — agent models, output verbosity, /go gates. One place to change everything."
argument-hint: "[show|agents|output|go|reset]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion
context: fork
---

# /configure

One place to tune rhino-os behavior. Reads project config (rhino.yml) and user preferences (~/.claude/preferences.yml). Changes write to preferences.yml — rhino.yml stays as the project-level source of truth.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/config-diff.sh` — shows configured vs default values, highlights overrides
- `references/config-reference.md` — all configurable values with defaults and explanations
- `reference.md` — output templates
- `gotchas.md` — real failure modes. **Read before changing config.**

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) or `show` | Run `scripts/config-diff.sh`, display current settings with explanations |
| `agents` | Interview: cost tier and autonomy level |
| `output` | Interview: output verbosity |
| `go` | Interview: hard gate and plateau threshold |
| `reset` | Delete preferences.yml, confirm |

## Route: show (default)

Run `bash scripts/config-diff.sh` for a quick overview. Then read `references/config-reference.md` for full context on any non-default values.

Display all current settings with behavioral explanations. Show which values come from preferences vs rhino.yml defaults.

## Route: agents

Interview via AskUserQuestion. Two questions:
1. **Cost tier** — economy/balanced/premium. See `references/config-reference.md` for the agent model mapping.
2. **Autonomy** — supervised/autonomous/full-auto.

Write to `~/.claude/preferences.yml`. Merge, don't overwrite. Show resolved agent models.

## Route: output

Interview via AskUserQuestion. One question: quiet/normal/verbose. Write to preferences.yml.

## Route: go

Interview via AskUserQuestion. Two questions:
1. **Hard gate** — yes/no (approval before each /go move)
2. **Plateau threshold** — number 1-10 (flat moves before stopping)

Write to preferences.yml.

## Route: reset

Confirm via AskUserQuestion. Delete preferences.yml. Show defaults.

## What you never do

- Modify rhino.yml — it's the project-level source of truth
- Set preferences without the interview — always confirm with the user
- Skip confirmation on reset
- Recommend config changes to fix scores — the product needs work, not the config

$ARGUMENTS
