# Architecture

## System Overview

claude-code-os is an operating system layer for Claude Code. It transforms a collection of loose agent definitions, skills, and rules into a coherent, version-controlled system that compounds knowledge over time.

```
┌─────────────────────────────────────────────────────────┐
│                    CLAUDE CODE CLI                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │   Agents     │  │   Skills    │  │   Rules         │ │
│  │             │  │             │  │                 │ │
│  │ strategist  │  │ smart-commit│  │ quality-bar     │ │
│  │ product-gate│  │ todofocus   │  │ product-        │ │
│  │ architect   │  │ product-2026│  │ reasoning       │ │
│  │ implementer │  │             │  │                 │ │
│  │ eval-runner │  └─────────────┘  └─────────────────┘ │
│  │ perspective │                                        │
│  │ scope-guard │  ┌─────────────┐  ┌─────────────────┐ │
│  │ codebase-dr │  │   Hooks     │  │   Evals         │ │
│  │ debt-collect│  │             │  │                 │ │
│  │ todo-planner│  │ ideation    │  │ money-scout     │ │
│  │ money-scout │  │ readonly    │  │ rubric          │ │
│  │ morning-    │  │             │  │ agent-session   │ │
│  │ sweep       │  └─────────────┘  │ rubric          │ │
│  │ night-watch │                    └─────────────────┘ │
│  └─────────────┘                                        │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Knowledge System                     │   │
│  │                                                  │   │
│  │  knowledge.md ←→ confidence-scores.md            │   │
│  │       ↕                    ↕                     │   │
│  │  search-strategy.md ←→ eval-history.md           │   │
│  │       ↕                                          │   │
│  │  acted-on.md (closes the feedback loop)          │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Automation                           │   │
│  │                                                  │   │
│  │  morning-sweep.sh  →  LaunchAgent (daily 8am)    │   │
│  │  run-scout.sh      →  LaunchAgent (weekly Mon)   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Design Principles

### 1. Earn Existence via Evals
Every agent has evaluation criteria. If an agent session doesn't pass its rubric, the agent's approach needs updating. No agent gets to exist just because it was created — it must prove value session over session.

### 2. Knowledge Compounds
The knowledge system is the core innovation. Unlike stateless agents that start fresh each session, learning agents (like money-scout) read their accumulated knowledge before acting, grade their output after acting, and adapt their strategy based on what worked. Each session makes the next one better.

### 3. Safety by Default
- Morning sweep requires human approval for RED items
- Night watch is budget-capped ($2.00) and never sends anything external
- Hooks enforce ideation-mode readonly
- No agent auto-deploys or communicates externally

### 4. Human in the Loop
The system amplifies a solo founder, it doesn't replace them. RED items always need approval. Features always go through product-gate → architect → implementer → eval-runner with human checkpoints.

## Agent Dispatch Flow

```
User intent
    │
    ├─ "what should I build?" ──→ strategist
    │
    ├─ "build this feature" ──→ product-gate ──→ architect ──→ implementer ──→ eval-runner
    │                              (approve)      (plan)       (build)         (verify)
    │
    ├─ "fix this bug" ──→ (just do it — quick fix path)
    │
    ├─ "this feels slow" ──→ codebase-doctor ──→ debt-collector
    │                          (diagnose)          (fix)
    │
    ├─ "am I on track?" ──→ scope-guard / todofocus
    │
    ├─ "what's trending?" ──→ money-scout
    │
    └─ (automated) ──→ morning-sweep (daily) / night-watch (overnight)
```

## File Layout

The repo mirrors `~/.claude/` structure. `install.sh` creates individual file symlinks (not directory symlinks) so you can have project-specific agents alongside OS agents.

```
~/claude-code-os/          →  ~/.claude/
├── agents/*.md            →  agents/*.md (symlinked)
├── skills/*/SKILL.md      →  skills/*/SKILL.md (symlinked)
├── rules/*.md             →  rules/*.md (symlinked)
├── hooks/*                →  hooks/* (symlinked)
├── evals/rubrics/*.md     →  evals/rubrics/*.md (symlinked)
├── config/CLAUDE.md       →  CLAUDE.md (symlinked, unless user has their own)
├── config/settings.json   →  settings.json (merged, not replaced)
├── config/config.json     →  config.json (merged, not replaced)
└── knowledge/_template/   →  knowledge/ (seeded, not symlinked — user data)
```

## Knowledge System Architecture

See [KNOWLEDGE-SYSTEMS.md](KNOWLEDGE-SYSTEMS.md) for deep dive.

The knowledge system follows a 5-file pattern:

1. **knowledge.md** — accumulated insights (read-first, write-after)
2. **confidence-scores.md** — tracks pattern confidence across sessions
3. **eval-history.md** — session scores over time
4. **search-strategy.md** — self-adapting search approach
5. **acted-on.md** — feedback loop closure

This pattern is reusable. Copy `knowledge/_template/` to create new learning agents.

## Automation Architecture

Two automated agents run on schedules via macOS LaunchAgents:

- **morning-sweep** (daily, 8am) — interactive triage with dispatch taxonomy
- **money-scout** (weekly, Monday 6am) — headless trend scanning

Both are budget-capped and write-safe. See [SAFETY.md](SAFETY.md) for constraints.
