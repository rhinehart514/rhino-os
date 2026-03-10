# rhino-os

A strategic operating system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Five agents that learn your taste, score your product, and decide what to build next.

Scores feed forward. Gaps become sprint priorities. The weakest dimension drives the next build cycle. Knowledge compounds across sessions.

## Getting Started

```bash
# 1. Install (idempotent, symlink-based)
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh

# 2. Bootstrap a project
cd ~/your-project
rhino init .

# 3. Open Claude Code in your project and say:
#    "run strategy"    — decides what to build
#    "let's build"     — builds it, scores it, keeps or discards
```

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth auth. macOS or Linux. Node 18+ for visual eval.

## What it does

| Command | What happens |
|---------|-------------|
| `rhino strategy` | Scans your projects, gives Buy/Sell/Hold verdicts, writes a sprint plan |
| `rhino build` | Auto-detects mode: gate, plan, build, or experiment. Measures before and after. |
| `rhino sweep` | Daily triage. Classifies issues GREEN/YELLOW/RED. Fixes safe ones inline. |
| `rhino scout` | Updates market positions with evidence. Agents reason FROM these. |
| `rhino score .` | Structural lint (free, 2 sec). Build health, structure, hygiene. |
| `rhino taste .` | Visual eval via Playwright + Claude vision. Scores what it SEES. |
| `rhino meta` | Grades its own agents. Fixes broken prompts. Agents can't silently die. |
| `rhino go .` | Strategy + build with no human gate. Point it at a project and walk away. |

## The loop

```
strategy → sprint plan → build (change → score → keep/discard) → eval → strategy
```

## How it works

**Two-tier scoring** like training loss vs eval loss:
- `rhino score .` — cheap grep-based structural lint, every commit. 3 dimensions: build health, structure, hygiene.
- `rhino taste .` — expensive visual eval via Playwright screenshots + Claude vision. 9 taste dimensions scored 1-5.

**Five agents** communicate through the filesystem (no direct calls, no RPC):
- **Strategist** — portfolio strategy + sprint planning. Writes plans.
- **Builder** — executes against plans. Scores every commit. Keeps or discards.
- **Sweep** — daily triage. Classifies and fixes issues by severity.
- **Scout** — market intelligence. Forms opinionated positions, not trends.
- **Design Engineer** — visual audit via screenshots. Taste evaluation.

**Anti-gaming guards** built into every scoring touchpoint:
- Cosmetic-only detection (hygiene moved, nothing else)
- Inflation cap (>15 point jump in one commit = warning)
- Plateau detection (unchanged across 5 runs)
- Stage ceilings (MVP expects 30-65, not 95)
- Scores are diagnostic instruments, not goals

**Knowledge compounds** across sessions:
- Taste signals (what the founder likes/rejects)
- Market positions (evidence-backed strategic claims)
- Design preferences (accumulated audit findings)
- Session context (last session summary injected into next)

## Architecture

```
Programs (brain)     →  strategy.md, build.md, meta.md
Agents (hands)       →  strategist, builder, sweep, scout, design-engineer
Knowledge (memory)   →  portfolio.json, landscape.json, taste.jsonl
Scoring (eyes)       →  score.sh (training loss) + taste.mjs (eval loss)
```

Agents communicate through the filesystem. Sweep writes state → strategist reads it next run. If one agent fails, the others keep working. Meta catches silent failures within 48h.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full breakdown.

## Install options

```bash
./install.sh              # full install with macOS LaunchAgents
./install.sh --no-launchd # skip scheduled automation
./install.sh --no-backup  # skip backing up existing files
rhino status              # verify everything is connected
```

The installer symlinks agents, skills, rules, and hooks into `~/.claude/`, merges configs additively (your existing settings are preserved), and links the `rhino` CLI to `~/bin/rhino`.

**On Linux:** Core functionality works. Scheduled automation (LaunchAgents) is macOS-only — the CLI's built-in catchup system triggers overdue agents when you run any `rhino` command.

## Customization

- `config/rhino.yml` — agent budgets, scoring thresholds, cache TTLs, integrity guards
- `config/CLAUDE.md` — project template (copied to each project on `rhino init`)
- `agents/*.md` — agent system prompts (edit directly to change behavior)
- `.claude/features.yml` — map features to routes for targeted taste evaluation

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for details.

## Experiment loop

The core pattern (inspired by [Karpathy's autoresearch](https://x.com/kaboroevich)): modify → measure → keep/discard → log → repeat.

```
rhino go .              # strategy → build, no human gate
rhino dashboard         # score history, experiments, dimensions
rhino dashboard --html  # visual dashboard
```

Every experiment is logged to `.claude/experiments/` as a TSV with commit, score, delta, status, and description. The system tracks keep rate (target: 40%) and flags if you're being too conservative or too ambitious.

## Uninstall

```bash
./uninstall.sh  # removes symlinks + LaunchAgents, preserves knowledge files
```

## License

[MIT](LICENSE)
