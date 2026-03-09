# Safety

How rhino-os prevents autonomous agents from causing harm.

## Core Principles

1. **Never send** — No agent sends external communications (emails, DMs, comments, posts)
2. **Budget caps** — Automated agents are capped at $2.00/session
3. **Human in the loop** — RED items always require human approval
4. **Reversibility first** — If an action can't be undone, it needs human approval
5. **Fail open** — When uncertain about classification, escalate to RED

## Agent Safety Matrix

| Agent | Sends External? | Modifies Code? | Budget Cap | Human Required? |
|-------|-----------------|----------------|------------|-----------------|
| strategist | No | No | None | No (read-only) |
| builder (gate) | No | No | None | Yes (approval gate) |
| builder (plan) | No | No | None | Yes (ADR approval) |
| builder (build) | No | Yes | None | Yes (task approval) |
| design-engineer | No | Yes (build mode) | None | Yes (build mode) |
| scout | No | Yes (knowledge only) | $2.00 | No |
| sweep | No | No | $2.00 | Yes (RED items) |

## Hooks

- `enforce_ideation_readonly.sh` — blocks Edit/Write/Bash in ideation output mode
- Prevents accidental code changes during brainstorming sessions

## What Could Go Wrong (and mitigations)

| Risk | Mitigation |
|------|------------|
| Agent sends a message | No agent has email/Slack/social media tools |
| Agent deploys bad code | No agent has deploy permissions; builder needs approval |
| Agent spends too much | Budget caps on automated agents; manual agents are interactive |
| Agent deletes files | install.sh backs up; no agent has rm permissions by default |
| Agent leaks secrets | .gitignore excludes personal data; templates use placeholders |
| Agent runs indefinitely | LaunchAgents don't restart on failure |

## Adding New Agents Safely

1. **Define tool access explicitly** — list only the tools the agent needs
2. **Default to read-only** — start with Read/Grep/Glob, add Write/Bash only if needed
3. **Add budget caps** — if the agent runs autonomously
4. **Classify all actions** — use the dispatch taxonomy
5. **Test interactively first** — run manually before automating
