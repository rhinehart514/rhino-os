# rhino-os

An operating system for Claude Code that turns it into a cofounder — one that measures your product, learns what works, and proposes what to build next.

Built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

---

## What It Actually Does

Every time you open Claude Code, rhino-os boots and shows you where things stand:

```
  ◆ rhino-os

  project  my-saas-app
  score    75/100  build 100 · struct 90 · hygiene 75
  plan     3 tasks remaining
  next     ▸ Fix dead-end after onboarding flow
  signals  Assertions: 8 planted · Predictions: 3/5 correct
```

Then you work. rhino-os gives Claude three measurement tools:

**`rhino score .`** — Structural lint. Catches dead ends, empty states, `any` types, stale builds. Fast, free, every commit.

```
  Structure  ██████████████████░░  90/100
  Hygiene    ███████████████░░░░░  75/100  ◀ weakest
```

**`rhino taste`** — Visual eval. Playwright screenshots scored by Claude Vision across 11 dimensions (hierarchy, polish, breathing room, wayfinding...). Expensive, on demand.

**`rhino eval .`** — Belief evals. Mechanical assertions about what your product must do. "The signup flow completes without errors" is a belief. Failing a `block` severity belief stops the build.

The measurements feed a learning loop: every action has a prediction, every prediction gets graded, wrong predictions update the model. Over sessions, Claude gets better at knowing what works for *your* product.

---

## Quick Start

```bash
# Install
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh

# Open any project in Claude Code
cd ~/your-project
claude
```

rhino-os boots automatically. Run `rhino score .` to get your first score.

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval.

### What install.sh does

The installer creates symlinks — it doesn't copy files or modify your project. Everything points back to `~/rhino-os/` so updates are just `git pull`.

| What | Where | Why |
|------|-------|-----|
| Mind files | `~/.claude/rules/` | Always loaded by Claude Code as system context |
| Hooks | `~/.claude/hooks/` | Boot card on session start |
| CLI | `~/bin/rhino` | Terminal access to score, taste, eval |
| Env var | `RHINO_DIR` in `.zshrc` | So scripts can find rhino-os |

Your data (plans, predictions, knowledge) lives in `~/.claude/` and is never touched by install or uninstall.

### Uninstall

```bash
cd ~/rhino-os && ./uninstall.sh        # remove all symlinks
./uninstall.sh --check                  # dry run — see what would be removed
```

---

## The Slash Commands

Inside Claude Code, these drive the workflow:

| Command | What it does |
|---------|-------------|
| `/plan` | Start a session. Reads scores, git history, predictions. Finds the bottleneck. Writes 3-5 tasks. |
| `/go` | Autonomous mode. Executes the plan — build, measure, learn, repeat. Karpathy NEVER STOP. |
| `/research [topic]` | Explore unknown territory. Fills gaps in the knowledge model before building. |
| `/strategy` | Evolve the product model. Auto-detects lifecycle stage, reassesses the bottleneck. |
| `/assert` | Plant belief evals. Define what must be true about your product. |
| `/critique` | Brutal product review. The cofounder who tells you what sucks. |
| `/ship` | Commit, push, deploy, verify — one command. |
| `/retro` | Weekly learning synthesis. Grade predictions, extract patterns. |

A typical session: `/plan` to see what matters, `/go` to build it, `/plan` again next time.

---

## The Learning System

rhino-os learns across sessions. Here's what accumulates:

**Predictions** (`~/.claude/knowledge/predictions.tsv`) — Every action has a prediction with evidence. Wrong predictions update the model. Target accuracy: 50-70% (too high = playing it safe, too low = broken model).

**Knowledge model** (`~/.claude/knowledge/experiment-learnings.md`) — Known patterns, uncertain patterns, unknown territory, dead ends. This is the causal model of what makes your product better.

**Beliefs** (`config/evals/beliefs.yml`) — Product assertions checked mechanically. "The dashboard loads in under 3 seconds" is a belief that gets enforced.

You don't need to understand any of this to start. Run `/plan`, follow its lead. The system reveals itself as you use it.

---

## CLI Reference

```
  ◆ rhino v6.0.0

  Measure
    score [dir]     Structural lint score
    taste [dir]     Visual product eval (Claude Vision)
    eval [dir]      Run belief evals
    bench [dir]     Benchmark card
    data [dir]      Learning data visualization

  Build
    go [args]       Autonomous build loop

  System
    status          Health overview
    self            Self-diagnostic
    config          Show configuration
    install         Install / update
```

---

## How It Works Under the Hood

rhino-os is 4 mind files, 3 measurement tools, and 8 slash commands.

**The mind** (`mind/`) — Not instructions. Identity. Three files tell Claude who it is, how to reason, and what quality means. Loaded automatically via `~/.claude/rules/` symlinks.

| File | Purpose |
|------|---------|
| `identity.md` | Cofounder behavior — opinions, push-back, measurement habits |
| `thinking.md` | Reasoning protocol — predict, cite evidence, update when wrong |
| `standards.md` | Quality definition — UX checklist, anti-gaming, experiment discipline |

**Anti-gaming** — Score manipulation is detected: cosmetic-only changes get flagged, 15+ point jumps trigger warnings, plateaus after 5 experiments suggest rethinking.

**Experiment discipline** — One mutable file per experiment. 15-minute cap. Immutable eval harness. Mechanical keep/discard based on score delta.

---

## Configuration

Everything tunable in `config/rhino.yml`: scoring weights, taste dimensions, integrity ceilings, experiment rules. See current values with `rhino config`.

---

## File Tree

```
rhino-os/
  mind/                    identity + reasoning (always loaded)
  bin/
    rhino                  CLI entrypoint
    score.sh               structural lint (~780 lines)
    taste.mjs              visual eval (~1140 lines)
    eval.sh                belief eval runner (~450 lines)
    self.sh                self-diagnostic
    data.sh                learning data visualization
  .claude/commands/        slash commands (plan, go, strategy, etc.)
  config/
    rhino.yml              all tunables
    evals/beliefs.yml      product assertions
  hooks/                   session start boot card
  corpus/                  taste reference database (coming soon)
  docs/                    vision docs + screenshots
```

---

## License

[MIT](LICENSE)
