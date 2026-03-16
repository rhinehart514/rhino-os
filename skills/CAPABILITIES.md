# Claude Code Capabilities — What rhino-os Can Build On

Research findings from deep dive into Claude Code's extension system. This is the map of what's possible — not what rhino-os currently uses, but what it COULD use.

Last updated: 2026-03-15

---

## Skills

Skills are markdown-based instruction packages. Each is a directory with `SKILL.md` (required) + supporting files.

### Frontmatter Fields

```yaml
---
name: my-skill                    # becomes /slash-command
description: "What it does"       # Claude uses this to decide when to auto-load
disable-model-invocation: true    # only fires when human types it, not auto-triggered
user-invocable: false             # only Claude triggers it, hidden from / menu
allowed-tools: Read, Grep, Bash   # restrict tool access during execution
model: sonnet/opus/haiku          # override model for this skill
context: fork                     # run in isolated subagent (own context window)
agent: Explore                    # which subagent type when context: fork
argument-hint: "[feature|wild]"   # autocomplete hint in / menu
hooks: {}                         # lifecycle hooks scoped to this skill
---
```

### Key Features We're NOT Using

- **`context: fork`** — runs the skill in an isolated subagent. Protects main context from expensive operations. This is how `/batch` decomposes 30 units of work without filling the main context.
- **`allowed-tools`** — restricts what Claude can do during a skill. A readonly skill could block Write/Edit. A research skill could block code modification.
- **`model` override** — run cheap skills on haiku, expensive ones on opus. We hardcode nothing right now.
- **`!command` syntax** — shell commands in the skill body run BEFORE the prompt is sent. We use this for score/predictions, but could use it for much more dynamic context injection.
- **`${CLAUDE_SKILL_DIR}`** — path to the skill's own directory. Skills can reference their own supporting files portably.

### Skill Discovery

- Descriptions are loaded into context (budget: 2% of context window, ~16K chars) so Claude knows what's available
- Full content only loads on invocation — descriptions are the index
- Priority: Enterprise > Personal (`~/.claude/skills/`) > Project (`.claude/skills/`) > Plugin
- Automatic discovery from nested `.claude/skills/` supports monorepos

### Cross-Tool Portability

Skills follow the [AgentSkills.io](https://agentskills.io) open standard. SKILL.md files work across Claude Code, Cursor, Gemini CLI, and others. rhino-os skills could theoretically run outside Claude Code.

---

## Agents (Subagents)

Specialized AI assistants with their own context window, custom prompts, specific tool access, and independent permissions.

### Agent Frontmatter

```yaml
---
name: code-reviewer
description: "When to delegate to this agent"
tools: Read, Glob, Grep, Bash            # tool allowlist
disallowedTools: Write, Edit              # tool denylist
model: sonnet/opus/haiku/inherit          # model selection
permissionMode: default/acceptEdits/dontAsk/bypassPermissions/plan
maxTurns: 20                              # max agentic turns
skills: [api-conventions, error-handling] # preloaded skills
memory: user/project/local               # persistent cross-session memory
background: true/false                    # run as background task
isolation: worktree                       # isolated git worktree
mcpServers:                               # scoped MCP servers
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
hooks: {}                                 # lifecycle hooks
---
```

### Key Features We're NOT Using

- **`memory: user`** — persistent cross-session learning for agents. An agent that LEARNS your codebase patterns over time. Native to Claude Code — no manual experiment-learnings.md needed per agent.
- **`skills` preloading** — agents can have skills pre-loaded. A builder agent with design-system + error-handling skills auto-loaded.
- **`isolation: worktree`** — agents work in isolated git worktrees. Safe parallel work. Code generation doesn't touch your working tree until you merge.
- **`maxTurns`** — prevent runaway agents. Set a ceiling on how long an agent can work.
- **`permissionMode: bypassPermissions`** — fully autonomous agents that don't ask for permission. Dangerous but powerful for trusted loops.
- **`background: true`** — agents run concurrently while you keep working.

### Agent Locations (priority)

1. `--agents` CLI flag (session-only)
2. `.claude/agents/` (project-level, check into VCS)
3. `~/.claude/agents/` (user-level, all projects)
4. Plugin's `agents/` directory

### Limitations

- Subagents CANNOT spawn other subagents (no nesting)
- Main agents can restrict which subagents they spawn: `tools: Agent(worker, researcher)`
- Auto-compaction at ~95% context capacity

### Agent Teams (Experimental)

The most powerful orchestration primitive. Multiple named agents coordinating:

- **Shared task lists** — agents see and claim tasks
- **Inter-agent messaging** — `SendMessage({to: "reviewer"})` while running
- **Task dependencies** — agent B waits until agent A completes its task
- **Plan approval gates** — human reviews before execution proceeds
- **Named agents** — addressable by name for targeted communication

Anthropic built a 100K-line C compiler with 16 agents across 2,000 sessions using this.

---

## Hooks (22 Events)

Shell commands, HTTP endpoints, LLM prompts, or agents that execute at lifecycle points.

### All Available Events

| Event | Blockable | When | rhino-os uses? |
|-------|-----------|------|----------------|
| `SessionStart` | No | Session begins/resumes | YES |
| `InstructionsLoaded` | No | CLAUDE.md or rules loaded | no |
| `UserPromptSubmit` | Yes | User submits prompt | no |
| `PreToolUse` | Yes | Before tool execution | no |
| `PermissionRequest` | Yes | Permission dialog appears | no |
| `PostToolUse` | No | After tool succeeds | no |
| `PostToolUseFailure` | No | After tool fails | no |
| `Notification` | No | Notification sent | no |
| `SubagentStart` | No | Subagent spawned | no |
| `SubagentStop` | Yes | Subagent finishes | YES |
| `Stop` | Yes | Claude finishes responding | YES |
| `TeammateIdle` | Yes | Agent team teammate about to idle | no |
| `TaskCompleted` | Yes | Task marked complete | no |
| `ConfigChange` | Yes | Config file changes | no |
| `WorktreeCreate` | Yes | Worktree created | no |
| `WorktreeRemove` | No | Worktree removed | no |
| `PreCompact` | No | Before context compaction | YES |
| `PostCompact` | No | After compaction | no |
| `Elicitation` | Yes | MCP server requests user input | no |
| `ElicitationResult` | Yes | User responds to MCP elicitation | no |
| `SessionEnd` | No | Session terminates | no |

**We use 8 of 22 events.** 14 untapped.

### Four Hook Handler Types

1. **`command`** — shell scripts, receives JSON on stdin
2. **`http`** — POST requests to endpoints, supports auth headers
3. **`prompt`** — single-turn LLM evaluation
4. **`agent`** — multi-turn agentic verification with tool access

### Powerful Patterns We're NOT Using

- **`PreToolUse`** — can MODIFY tool inputs via `updatedInput` in response. Could auto-fix common mistakes before they happen.
- **`PostToolUse`** — can MODIFY MCP tool output via `updatedMCPToolOutput`. Could filter, enhance, or transform tool results.
- **`UserPromptSubmit`** — can block or transform user prompts. Could auto-route intent to skills before Claude even processes the message.
- **`TaskCompleted`** — quality gate. Block task completion if quality criteria aren't met. Perfect for autonomous loops.
- **`TeammateIdle`** — in agent teams, can redirect idle agents to new work or send feedback.
- **`PostCompact`** — rebuild context after compaction. We use PreCompact but not PostCompact.
- **`SessionEnd`** — cleanup, stats, session summary logging.

### Environment Variables

- `CLAUDE_PROJECT_DIR` — project root
- `CLAUDE_PLUGIN_ROOT` — plugin directory
- `CLAUDE_ENV_FILE` — SessionStart ONLY: write vars here to persist them for the session

---

## Plugin System

### Structure

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # manifest (required)
├── skills/                  # SKILL.md files
├── agents/                  # agent .md files
├── commands/                # command .md files (legacy)
├── hooks/
│   └── hooks.json           # hook definitions
└── .mcp.json                # MCP server config
```

### Marketplace

- Marketplace = git repo with `.claude-plugin/marketplace.json`
- Sources: GitHub repos, git URLs, git subdirs (sparse clone), npm/pip packages
- Version pinning via `ref` (branch/tag) and `sha` (exact commit)
- Release channels (stable/latest) via separate marketplaces pointing to different refs
- Anthropic has official directory at `plugins.claude.ai`
- Enterprise: `strictKnownMarketplaces` restricts sources, `extraKnownMarketplaces` auto-prompts team install

---

## Ecosystem Patterns (What People Are Building)

### The Ralph Wiggum Pattern (dominant)

Named by Geoffrey Huntley. Continuously run an agent until success criteria are met:
```
test → fail → retry with error context → loop until green
```
Multiple implementations: ralph-claude-code, ralph-orchestrator, multi-agent-ralph-loop. This is `/go` but formalized.

### Orchestration Tools

- **Claude Squad** — terminal app managing multiple Claude Code instances in parallel
- **TSK** — Rust CLI delegating tasks to agents in sandboxed Docker, returning git branches
- **HCOM** — real-time multi-agent communication via hooks with @-mention targeting
- **Gas Town** — high-throughput orchestration with "Mayor" and "Deacon" roles

### Massive Skill Libraries

- **anthropics/skills** — Anthropic's official public skill repository
- **VoltAgent/awesome-agent-skills** — 500+ skills, cross-tool compatible (Claude Code, Codex, Gemini CLI, Cursor)
- **alirezarezvani/claude-skills** — 180+ production-ready skills
- **Anthropic's frontend-design skill** — 277K+ installs

### The `/batch` Pattern (canonical composite)

Ships with Claude Code. The reference for composite skills:
1. Decompose work into 5-30 units
2. Spawn one agent per unit in isolated git worktree
3. Each agent works independently
4. Each opens a PR when done
5. Human reviews and merges

This is the pattern — not sequential command chaining, but **parallel agent orchestration with worktree isolation**.

---

## What This Means for rhino-os

### Immediate Opportunities (use existing features better)

1. **`context: fork` on expensive skills.** /eval taste, /research, /clone should run in isolated context to protect the main conversation.
2. **`model: haiku` on cheap skills.** /assert list, /todo show, /rhino don't need opus. Save tokens.
3. **`allowed-tools` on readonly skills.** /eval, /strategy, /retro shouldn't be able to Write files during analysis phase.
4. **`memory: user` on agents.** Builder and reviewer agents that learn codebase patterns across sessions.
5. **`isolation: worktree` on /go.** Build in a worktree, merge on keep, discard on revert. Clean.

### Medium-Term Opportunities (new capabilities)

6. **`UserPromptSubmit` hook for intent routing.** Auto-route "is this good?" to /eval before Claude even processes the message. Currently in CLAUDE.md instructions — could be a hook.
7. **`TaskCompleted` hook as quality gate.** Block /go loop tasks from completing if assertions regressed. Mechanical enforcement.
8. **`PostCompact` hook for context rebuild.** We save context pre-compaction but don't rebuild post-compaction.
9. **Agent teams for /batch-style composite skills.** /audit spawns taste-agent + eval-agent + product-agent in parallel, synthesizes results.
10. **`SessionEnd` hook for session logging.** Auto-write session summary to `.claude/sessions/` without manual /go reference.md logic.

### Big Bets (new product surface)

11. **Composite skills using `context: fork` + agent orchestration.** /pulse, /prove, /speedrun as real agent-orchestrated workflows, not sequential command calls.
12. **Cross-tool portability via AgentSkills.io.** rhino-os skills working in Cursor and Gemini CLI. Massively expands TAM.
13. **Marketplace distribution with version pinning.** `claude plugin install rhino-os@v8.0.3` with guaranteed compatibility.
14. **The "/batch for product" pattern.** Decompose a feature into N tasks, spawn N agents in worktrees, each builds one piece, human reviews PRs. /go but parallel.
