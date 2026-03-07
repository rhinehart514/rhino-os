# Safety

How claude-code-os prevents autonomous agents from causing harm.

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
| product-gate | No | No | None | Yes (approval gate) |
| architect | No | No | None | Yes (ADR approval) |
| implementer | No | Yes | None | Yes (task approval) |
| eval-runner | No | No | None | No (diagnostic) |
| perspective-runner | No | No | None | No (diagnostic) |
| scope-guard | No | No | None | No (diagnostic) |
| codebase-doctor | No | No | None | No (diagnostic) |
| debt-collector | No | Yes | None | Yes (tier approval) |
| todo-planner | No | No | None | No (read-only) |
| money-scout | No | Yes (knowledge only) | $2.00 | No |
| morning-sweep | No | No | $2.00 | Yes (RED items) |
| night-watch | No | Yes (reports only) | $2.00 | No |

## Specific Safeguards

### Morning Sweep
- Classifies all items using [DISPATCH-TAXONOMY.md](DISPATCH-TAXONOMY.md)
- GREEN items auto-dispatch (safe, reversible)
- YELLOW items dispatch with summary (low-risk, human notified)
- RED items NEVER auto-dispatch (requires explicit human approval)
- Total GREEN + YELLOW budget capped at $2.00

### Night Watch
- Budget capped at $2.00 per session
- NEVER sends anything external
- NEVER deploys to production
- NEVER makes irreversible changes
- NEVER creates user-facing features
- Write-safe only (reports, knowledge files)
- Code changes (if any) go to a separate branch, never merged

### Money Scout
- Never posts, sends, or communicates externally
- Draft artifacts are saved to files, never sent
- Knowledge updates are append-only (never deletes existing knowledge)
- Budget naturally limited by search/fetch operations

### Hooks
- `enforce_ideation_readonly.sh` — blocks Edit/Write/Bash in ideation output mode
- Prevents accidental code changes during brainstorming sessions

## What Could Go Wrong (and mitigations)

| Risk | Mitigation |
|------|------------|
| Agent sends a message | No agent has email/Slack/social media tools |
| Agent deploys bad code | No agent has deploy permissions; implementer needs approval |
| Agent spends too much | Budget caps on automated agents; manual agents are interactive |
| Agent deletes files | night-watch explicitly cannot delete; install.sh backs up |
| Agent leaks secrets | .gitignore excludes personal data; templates use placeholders |
| Agent runs indefinitely | LaunchAgents don't restart on failure; --max-turns limits |

## Adding New Agents Safely

When creating new agents:

1. **Define tool access explicitly** — list only the tools the agent needs
2. **Default to read-only** — start with Read/Grep/Glob, add Write/Bash only if needed
3. **Add budget caps** — if the agent runs autonomously
4. **Classify all actions** — use the dispatch taxonomy
5. **Create an eval rubric** — so bad sessions are caught and corrected
6. **Test interactively first** — run manually before automating
