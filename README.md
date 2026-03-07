# claude-code-os

An operating system for Claude Code. Not just configuration — a self-improving, knowledge-compounding agent system for solo technical founders.

```
┌──────────────────────────────────────────────────────────┐
│  claude-code-os                                          │
│                                                          │
│  13 Agents  ·  3 Skills  ·  2 Rules  ·  1 Hook          │
│  Knowledge Systems  ·  Automated Orchestration           │
│                                                          │
│  git clone → ./install.sh → you have an OS               │
└──────────────────────────────────────────────────────────┘
```

## Quickstart

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-os.git ~/claude-code-os
cd ~/claude-code-os
./install.sh
```

Edit `~/.claude/CLAUDE.md` with your identity and project info. Then:

```bash
claude --agent morning-sweep    # daily triage
claude --agent strategist       # what should I build?
claude --agent money-scout      # what's trending?
```

## Philosophy

### 1. Earn Existence via Evals
Every agent has evaluation criteria. No agent gets a free pass. If it doesn't produce value above its API cost, it gets revised or killed.

### 2. Knowledge Compounds
Learning agents don't start fresh. They read accumulated knowledge, skip confirmed patterns, focus on gaps, and grade themselves. Each session makes the next one better.

### 3. Safety by Default
Automated agents are budget-capped ($2/session), never send external communications, and never make irreversible changes without human approval.

### 4. Human in the Loop
The system amplifies you, it doesn't replace you. Critical decisions (deploy, merge, communicate) always require your approval.

## Agent Catalog

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| **strategist** | Product strategy, project prioritization | "What should I build?" |
| **product-gate** | Feature evaluation, prevents premature coding | Before any non-trivial feature |
| **architect** | ADR creation, implementation planning | After product-gate approves |
| **implementer** | Code execution from approved plans | After architect produces ADR |
| **eval-runner** | Feature evaluation (code + product + UX) | After implementation, before shipping |
| **perspective-runner** | User persona stress-testing | Evaluate features from user POV |
| **scope-guard** | Drift detection during implementation | When work feels like it's expanding |
| **codebase-doctor** | Health diagnostics, velocity blockers | When project feels slow or broken |
| **debt-collector** | Batch-fix mechanical tech debt | After codebase-doctor identifies issues |
| **todo-planner** | Session planning, next task recommendation | Start of work session |
| **money-scout** | Trend scanning, opportunity intelligence | Weekly (automated or manual) |
| **morning-sweep** | Daily triage with dispatch taxonomy | Start of day (automated or manual) |
| **night-watch** | Overnight maintenance, diagnostics | Overnight (automated) |

## Dispatch Taxonomy

Morning sweep classifies every action into four categories:

| Category | Meaning | Human Approval? |
|----------|---------|-----------------|
| **GREEN** | Safe, reversible, mechanical | No — auto-dispatched |
| **YELLOW** | Low-risk, human notified after | No — but you see a summary |
| **RED** | High-impact, judgment required | Yes — always waits for you |
| **GRAY** | Information only, no action | N/A |

See [docs/DISPATCH-TAXONOMY.md](docs/DISPATCH-TAXONOMY.md) for full details.

## Knowledge System

The secret sauce. Learning agents maintain persistent knowledge across sessions:

```
knowledge/[agent-name]/
├── knowledge.md          # Accumulated insights
├── confidence-scores.md  # Pattern confidence tracking
├── eval-history.md       # Session quality over time
├── search-strategy.md    # Self-adapting approach
└── acted-on.md           # Feedback loop closure
```

Create your own learning agents using the template:
```bash
cp -r knowledge/_template/ knowledge/my-agent/
```

See [docs/KNOWLEDGE-SYSTEMS.md](docs/KNOWLEDGE-SYSTEMS.md) for the full pattern.

## Workflow

The recommended daily workflow:

```
Morning:
  claude --agent morning-sweep    # What needs attention?
  → Review RED items, approve/skip
  → Start on recommended focus

During work:
  claude --agent product-gate     # Should I build this?
  claude --agent architect        # How should I build this?
  claude --agent implementer      # Build it
  claude --agent eval-runner      # Did I build it well?
  /todofocus                      # Am I still on track?
  /smart-commit                   # Commit with context

Weekly:
  claude --agent money-scout      # What's trending?
  claude --agent strategist       # Am I building the right thing?

Overnight (automated):
  night-watch runs diagnostics and knowledge updates
```

## Installation Details

`install.sh` does the following:

1. **Symlinks individual files** from repo into `~/.claude/` (not whole directories)
2. **Backs up** existing files before overwriting
3. **Merges** `settings.json` and `config.json` via `jq` (preserves your MCP servers, hooks)
4. **Seeds** knowledge directories from templates (doesn't overwrite existing data)
5. **Installs** LaunchAgents on macOS (optional: `--no-launchd`)

The installer is idempotent — safe to re-run after pulling updates.

### Uninstall

```bash
./uninstall.sh                            # remove symlinks
./uninstall.sh --restore-backup <DIR>     # restore backed-up files
```

## Customization

- Add agents: create `agents/[name].md` and re-run `./install.sh`
- Add skills: create `skills/[name]/SKILL.md` and re-run
- Add rules: create `rules/[name].md` and re-run
- Add knowledge systems: copy `knowledge/_template/` and create matching agent + rubric

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for full guide.

## Docs

| Document | What's Inside |
|----------|--------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, data flows, design principles |
| [DISPATCH-TAXONOMY.md](docs/DISPATCH-TAXONOMY.md) | GREEN/YELLOW/RED/GRAY classification |
| [KNOWLEDGE-SYSTEMS.md](docs/KNOWLEDGE-SYSTEMS.md) | How learning agents compound knowledge |
| [SAFETY.md](docs/SAFETY.md) | Budget caps, never-send rules, tool scoping |
| [CUSTOMIZATION.md](docs/CUSTOMIZATION.md) | Add your own agents, skills, knowledge systems |

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- macOS (for LaunchAgents) or Linux (use cron instead)
- `jq` for config merging: `brew install jq`
- `gh` CLI for GitHub integration (optional): `brew install gh`

## Credits

Inspired by [jimprosser/claude-code-cos](https://github.com/jimprosser/claude-code-cos) (Claude OS concept). Built for solo founders who want their AI tooling to compound, not just assist.
