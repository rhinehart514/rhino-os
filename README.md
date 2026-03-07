# claude-code-os

An operating system for Claude Code. Agents, skills, rules, and a self-improving knowledge system for solo technical founders.

```
┌──────────────────────────────────────────────────────────┐
│  claude-code-os                                          │
│                                                          │
│  10 Agents  ·  3 Skills  ·  2 Rules  ·  2 Hooks         │
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
| **eval-runner** | Feature eval (code + perspectives + UX) | After implementation, before shipping |
| **codebase-doctor** | Health diagnostics + mechanical debt fixes | "This feels slow" or "clean this up" |
| **money-scout** | Trend scanning, opportunity intelligence | Weekly (automated or manual) |
| **morning-sweep** | Daily triage with dispatch taxonomy | Start of day (automated or manual) |
| **self-audit** | System health: usage stats, prompt costs, stale knowledge | Periodically, to keep the system lean |
| **design-engineer** | Design engineer with taste. Five modes: init, audit, review (subjective), recommend, build | "How does my UI feel?" / "What would look good?" |

**Consolidated from 13 → 10.** Perspective-runner merged into eval-runner. Debt-collector merged into codebase-doctor (two modes: diagnose/fix). Scope-guard merged into `/todofocus` skill. Todo-planner absorbed by morning-sweep. Night-watch cut (aspirational automation that doesn't reliably work). Self-audit added for system introspection.

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
├── knowledge.md              # Accumulated insights (markdown)
├── confidence-scores.jsonl   # Pattern confidence tracking (queryable)
├── eval-history.jsonl        # Session quality over time (queryable)
├── search-strategy.md        # Self-adapting approach (markdown)
└── acted-on.jsonl            # Feedback loop closure (queryable)
```

Structured data uses JSONL for machine-readable querying:
```bash
# Query knowledge via included script
./automation/scripts/query-knowledge.sh my-agent confirmed
./automation/scripts/query-knowledge.sh my-agent stale 30
```

Create your own learning agents using the template:
```bash
cp -r knowledge/_template/ knowledge/my-agent/
```

See [docs/KNOWLEDGE-SYSTEMS.md](docs/KNOWLEDGE-SYSTEMS.md) for the full pattern.

## Workflow

```
Morning:
  claude --agent morning-sweep    # What needs attention? What to work on?

During work:
  claude --agent product-gate     # Should I build this?
  claude --agent architect        # How should I build this?
  claude --agent implementer      # Build it
  claude --agent eval-runner      # Did I build it well?
  /todofocus                      # Am I on track? Scope drifting?
  /smart-commit                   # Commit with context

Weekly:
  claude --agent money-scout      # What's trending?
  claude --agent strategist       # Am I building the right thing?

When things feel broken:
  claude --agent codebase-doctor  # Diagnose, then fix

Periodically:
  claude --agent self-audit       # Is the system itself healthy?

Design:
  claude --agent design-engineer              # Subjective review (default)
  claude --agent design-engineer "recommend"  # What would look good?
  claude --agent design-engineer "build"      # Fix + generate
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

## Honest Limitations

This section exists because a system that evaluates everything should evaluate itself first.

**It's markdown files pretending to be an operating system.** There is no kernel, no process manager, no scheduler. It's prompt engineering in a trenchcoat. `install.sh` creates symlinks — that's the entire "runtime."

**The 4-agent pipeline is heavy.** product-gate → architect → implementer → eval-runner before you write a line of code. For a solo founder who preaches velocity, that's ceremony. The "quick fix — just do it" escape hatch will become your default, and that's fine. Use the pipeline for features that matter, skip it for everything else.

**"Self-improving knowledge system" is a generous description of empty markdown files.** No code enforces that agents read before they write. No validation. No database. An LLM parsing its own previous markdown output is not a knowledge graph — it's a game of telephone with itself.

**Budget caps are vibes, not enforcement.** The prompt says "$2.00 max." Nothing actually tracks spend. Claude cannot read its own API meter. You'll find out what it cost on your Anthropic dashboard.

**The automation is fragile.** LaunchAgents calling `claude` CLI headlessly assumes non-interactive auth, no rate limits, and stable CLI behavior across updates. All three assumptions can break.

**`install.sh` does a shallow jq merge.** Nested hook configs can get clobbered. The "preserves your settings" promise is approximately true, which in software means false.

**Knowledge files are gitignored.** The most valuable part — accumulated intelligence — doesn't survive a machine wipe, isn't backed up, and can't be shared. The disposable parts are version-controlled. The irreplaceable parts aren't.

**This is one person's workflow exported as if it's a product.** The agent prompts encode specific opinions (3x rule, Christensen disruption test, kill criteria) useful for one founder's context. You'll need to rewrite prompts to match your situation.

**The supreme irony:** A system built to prevent premature infrastructure is itself premature infrastructure. It has zero users, no tests, and was built instead of shipping the product it's supposed to help ship.

Steal the parts that work for you. Don't mistake the map for the territory.

## Credits

Inspired by [jimprosser/claude-code-cos](https://github.com/jimprosser/claude-code-cos) (Claude OS concept). Built for solo founders who want their AI tooling to compound, not just assist.
