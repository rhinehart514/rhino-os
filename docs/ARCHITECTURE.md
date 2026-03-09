# Architecture

## System Overview

rhino-os is an operating system layer for Claude Code. A bash CLI (`rhino`) orchestrates agents via `claude -p` with agent markdown injected as system prompts. Agents communicate through the filesystem — no MCP server, no API server, no daemon.

```
+-------------------------------------------------------------------+
|  rhino (bash CLI)                                                  |
|  rhino sweep | scout | build | strategy | design | status | ...   |
+------+------------------------------------------------------------+
       |
       v
+------+------------------------------+
|  CLAUDE CODE CLI                     |
|  claude -p --system-prompt agent.md  |
+------+------------------------------+
       |
       v
+------+------------------------------+
|  Agents | Skills | Rules | Hooks     |
|                                      |
|  +-------------+  +--------------+   |
|  | State/      |  | Knowledge/   |   |
|  | sweep-      |  | scout/       |   |
|  | latest.md   |  | design-eng/  |   |
|  |             |  | taste.jsonl  |   |
|  +-------------+  +--------------+   |
+--------------------------------------+
```

## How Agents Communicate

No agent can invoke another agent. Instead: **filesystem as shared state.**

```
sweep runs
  → writes ~/.claude/state/sweep-latest.md
  → executes GREEN/YELLOW items inline

builder runs (later)
  → reads ~/.claude/state/sweep-latest.md in Step 0
  → if sweep flagged RED items, auto-selects scope

strategist runs
  → reads ~/.claude/state/sweep-latest.md (what's on fire?)
  → reads ~/.claude/knowledge/scout/knowledge.md (market context)

design-engineer runs
  → reads ~/.claude/state/sweep-latest.md (design items?)
  → reads ~/.claude/knowledge/design-engineer/system.md

scout finishes
  → edits ~/.claude/knowledge/landscape.json (positions)
  → edits ~/.claude/knowledge/scout/knowledge.md (findings)

meta runs (periodic)
  → reads ~/.claude/logs/ (agent outputs)
  → grades each agent's output quality
  → proposes fixes to agent .md files
```

**The rule:** Sweep is the entry point. It writes state. Other agents read it. The user just runs `rhino <agent>` — context flows automatically.

## Knowledge Capture Hook

Post-session hook (`session_context.sh`) fires on session start. Injects eval verdict, gaps, and active plan into the conversation context. 30-minute cooldown prevents duplicate injection.

## Design Principles

### 1. Momentum Over Process
One agent (builder) handles the full loop: assess scope → execute → measure → keep/discard. No 4-agent pipeline. Skip modes you don't need.

### 2. Minimal Manual Input
Agents read shared state from prior runs. The user doesn't relay information between agents. Sweep writes findings, builder reads them. Scope detection is automatic.

### 3. Context Efficiency
Agents load only what they need for the current mode. Design-engineer in audit mode doesn't load design-taste.md. Knowledge files have enforced max sizes with pruning rules. Every token of context should be working.

### 4. Knowledge Compounds (with limits)
Learning agents read accumulated knowledge, grade output, and adapt. But knowledge files have max sizes (150 lines for knowledge.md, 80 for search-strategy.md). Agents prune stale entries at end of session. Unbounded knowledge degrades performance.

### 5. Safety by Default
- Sweep requires human approval for RED items
- Budget-capped automated agents
- Hooks enforce ideation-mode readonly
- No agent auto-deploys or communicates externally

### 6. Self-Sustaining
Meta evaluates agent outputs. Scout requires adversarial positions. Taste reads landscape intelligence. The system improves itself — the human reviews the improvements, not the process.

## File Layout

```
~/rhino-os/                  →  ~/.claude/
  bin/rhino                  →  ~/bin/rhino (symlinked — CLI entry point)
  agents/*.md                →  agents/*.md (symlinked)
  agents/refs/*.md           →  agents/refs/*.md (symlinked)
  programs/*.md              →  programs/*.md (symlinked)
  skills/*/SKILL.md          →  skills/*/SKILL.md (symlinked)
  rules/*.md                 →  rules/*.md (symlinked)
  hooks/*                    →  hooks/* (symlinked)
  config/CLAUDE.md           →  CLAUDE.md (symlinked, unless user has their own)
  config/settings.json       →  settings.json (merged, not replaced)
  config/config.json         →  config.json (merged)
  knowledge/_template/       →  knowledge/ (seeded, not symlinked — user data)
                                state/ (created by install, written by agents)
                                plans/ (created by install, written by builder)
```

## State Directory Convention

`~/.claude/state/` holds ephemeral inter-agent state. Files here are overwritten each run.

| File | Written By | Read By | Contents |
|------|-----------|---------|----------|
| `sweep-latest.md` | sweep | builder, strategist, design-engineer | Structured triage: executed items, pending RED items with suggested agent+mode, focus recommendation |

State files older than 7 days are stale. Sweep deletes them during system audit.

## Autonomous Operation

```
                    ┌──────────────┐
                    │  LaunchAgent │
                    │  (scheduled) │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         ┌────────┐  ┌─────────┐  ┌─────────┐
         │ sweep  │  │  scout  │  │  meta   │
         │ daily  │  │ weekly  │  │ monthly │
         │ 8 AM   │  │ Mon 6AM │  │ on-demand│
         └───┬────┘  └────┬────┘  └────┬────┘
             │            │            │
             ▼            ▼            ▼
      sweep-latest.md  landscape.json  agent grades
             │            │            │
             └────────────┼────────────┘
                          ▼
              ┌───────────────────────┐
              │  builder / strategist │
              │  design-engineer      │
              │  (human-triggered)    │
              └───────────────────────┘
```

Sweep and scout run autonomously via LaunchAgents. They write state and knowledge. Human-triggered agents read that context automatically. Meta grades everything periodically. The system compounds without human relay.

## What This Is Not

- **No web dashboard** — `rhino dashboard --html` generates static HTML
- **No Agent SDK** — stays CLI-only to use Max subscription
- **No agent orchestration/chaining** — agents are independent, share state via filesystem
- **No plugin system** — "create markdown, run install.sh" IS the plugin system
- **No multi-user features** — one user, one machine
- **No database** — JSONL + markdown is the storage layer
