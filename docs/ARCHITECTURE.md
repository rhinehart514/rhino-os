# Architecture

## System Overview

rhino-os is an operating system layer for Claude Code. A bash CLI (`rhino`) orchestrates agents, an MCP server provides structured state access, and a localhost API enables programmatic integration.

```
+-------------------------------------------------------------------+
|  rhino (bash CLI)                                                  |
|  rhino sweep | scout | build | strategy | design | status | ...   |
+------+--------------------------------------------------------+---+
       |                                                         |
       v                                                         v
+------+------------------------------+   +---------------------+---+
|  CLAUDE CODE CLI                     |   |  API Server (:7890)     |
|  claude -p --agent X --max-budget $  |   |  POST /agents/:name/run |
+------+------------------------------+   |  GET  /runs/:id/stream  |
       |                                   |  GET  /state/latest     |
       v                                   +-------------------------+
+------+------------------------------+
|  Agents | Skills | Rules | Hooks     |
|                                      |
|  +--------------------------------+  |
|  | MCP: rhino-state (stdio)       |  |
|  | rhino_get_state                |  |
|  | rhino_set_state                |  |
|  | rhino_query_knowledge          |  |
|  | rhino_update_knowledge         |  |
|  | rhino_log_session              |  |
|  | rhino_get_usage                |  |
|  | rhino_backup_knowledge         |  |
|  +--------------------------------+  |
|                                      |
|  +-------------+  +--------------+   |
|  | State/      |  | Knowledge/   |   |
|  | sweep-      |  | scout/       |   |
|  | latest.md   |  | design-eng/  |   |
|  |             |  | sessions/    |   |
|  +-------------+  +--------------+   |
+--------------------------------------+
```

## How Agents Communicate

No agent can invoke another agent. Instead: **MCP tools as structured IPC** (with filesystem fallback).

```
sweep runs
  → rhino_set_state("sweep-latest.md", findings)
  → executes GREEN/YELLOW items inline

builder runs (later)
  → rhino_get_state("sweep-latest.md") in Step 0
  → if sweep flagged RED items, auto-selects mode

strategist runs
  → rhino_get_state("sweep-latest.md") (what's on fire?)
  → rhino_query_knowledge(agent: "scout") (market context)

design-engineer runs
  → rhino_get_state("sweep-latest.md") (design items?)
  → rhino_query_knowledge(agent: "design-engineer", file: "system.md")

scout finishes
  → rhino_update_knowledge(agent: "scout", file: "knowledge.md", content)
```

**The rule:** Sweep is the entry point. It writes state via MCP. Other agents read it via MCP. If MCP is unavailable, agents fall back to direct file access. The user just runs `rhino <agent>` — context flows automatically.

## MCP Server: rhino-state

Stdio transport — starts/stops with each Claude Code session. Not a daemon.

**Tools:**
| Tool | Purpose |
|------|---------|
| `rhino_get_state` | Read inter-agent state files |
| `rhino_set_state` | Write inter-agent state |
| `rhino_query_knowledge` | Query knowledge with agent/file/confidence filters |
| `rhino_update_knowledge` | Append or replace knowledge entries |
| `rhino_log_session` | Log session metadata |
| `rhino_get_usage` | Query tool usage stats |
| `rhino_backup_knowledge` | Snapshot knowledge to backup |

**Design decisions:**
- Reads/writes the same files as direct filesystem access — no lock-in
- If MCP server is unavailable, agents work identically via file reads/writes
- No SQLite — JSONL + markdown is the storage layer

## Localhost API

Started via `rhino serve`. Binds to `127.0.0.1:7890`.

Spawns `claude -p --agent X` as child processes, streams output via SSE. Queues concurrent runs (max 1 active). Stores run history in `~/.claude/state/runs/`.

**Security:** localhost only, optional `RHINO_API_KEY` for defense-in-depth.

## Knowledge Capture Hook

Post-session hook (`capture_knowledge.sh`) fires on Stop event. If the session had >5 tool uses, runs a lightweight `claude -p` summarization ($0.25 budget) and appends to `~/.claude/knowledge/sessions/[project].md`. Prunes entries older than 60 days.

## Design Principles

### 1. Momentum Over Process
One agent (builder) handles gate → plan → build → doctor. No 4-agent pipeline. Skip modes you don't need.

### 2. Minimal Manual Input
Agents read shared state from prior runs. The user doesn't relay information between agents. Sweep writes findings, builder reads them. Mode detection is automatic.

### 3. Context Efficiency
Agents load only what they need for the current mode. Design-engineer in audit mode doesn't load design-taste.md. Knowledge files have enforced max sizes with pruning rules. Every token of context should be working.

### 4. Knowledge Compounds (with limits)
Learning agents read accumulated knowledge, grade output, and adapt. But knowledge files have max sizes (150 lines for knowledge.md, 80 for search-strategy.md). Agents prune stale entries at end of session. Unbounded knowledge degrades performance.

### 5. Safety by Default
- Sweep requires human approval for RED items
- Budget-capped automated agents
- Hooks enforce ideation-mode readonly
- No agent auto-deploys or communicates externally

## File Layout

```
~/rhino-os/                  →  ~/.claude/
  bin/rhino                  →  ~/bin/rhino (symlinked — CLI entry point)
  agents/*.md                →  agents/*.md (symlinked)
  agents/refs/*.md           →  agents/refs/*.md (symlinked)
  skills/*/SKILL.md          →  skills/*/SKILL.md (symlinked)
  rules/*.md                 →  rules/*.md (symlinked)
  hooks/*                    →  hooks/* (symlinked)
  config/CLAUDE.md           →  CLAUDE.md (symlinked, unless user has their own)
  config/settings.json       →  settings.json (merged, not replaced)
  config/config.json         →  config.json (merged — includes rhino-state MCP)
  knowledge/_template/       →  knowledge/ (seeded, not symlinked — user data)
  src/mcp-server/            →  (installed in-place, referenced by config.json)
  src/api-server/            →  (installed in-place, started by `rhino serve`)
                                state/ (created by install, written by agents)
                                state/runs/ (API server run history)
                                plans/ (created by install, written by builder)
                                backups/ (created by `rhino backup`)
```

## State Directory Convention

`~/.claude/state/` holds ephemeral inter-agent state. Files here are overwritten each run.

| File | Written By | Read By | Contents |
|------|-----------|---------|----------|
| `sweep-latest.md` | sweep | builder, strategist, design-engineer | Structured triage: executed items, pending RED items with suggested agent+mode, focus recommendation |

State files older than 7 days are stale. Sweep deletes them during system audit.

## What This Is Not

- **No web dashboard** — `rhino status` in terminal is enough for one user
- **No Agent SDK** — stays CLI-only to use Max subscription
- **No agent orchestration/chaining** — Claude Code's Agent Teams handles this
- **No plugin system** — "create markdown, run install.sh" IS the plugin system
- **No multi-user features** — one user, one machine
- **No database** — JSONL + markdown is the storage layer
