# rhino-os

A learning plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that makes your product measurably better every session.

**What is Claude Code?** A CLI tool where you talk to Claude in your terminal and it reads, writes, and runs code. rhino-os is a plugin that adds measurement, learning, and strategy on top.

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

---

## What rhino-os Adds to Claude Code

Claude Code provides the runtime — chat, code read/write/run, MCP tools, hooks, commands, rules. rhino-os adds the intelligence layer:

| Claude Code provides | rhino-os adds |
|---------------------|--------------|
| Read/write/run code | **Measurement** — score, eval, taste (is my product good?) |
| MCP tools (context7, playwright) | **Learning** — predictions, grading, knowledge model (get smarter each session) |
| Hooks + commands | **Strategy** — bottleneck finding, feature tracking, roadmap theses |
| Rules (system context) | **Identity** — cofounder behavior, standards, reasoning framework |
| Chat interface | **Autonomous building** — /go loop (keep what passes, revert what doesn't) |

rhino-os doesn't replace Claude Code. It makes Claude Code compound.

---

## The Idea

You define what your product must do. rhino-os measures whether it does. Every session, the score goes up or the change gets reverted.

The score is not code quality. It's not lint. **The score is the percentage of your assertions that pass.** You say "signup completes without errors" — that's an assertion. If 8 of 10 assertions pass, your score is 80.

```
  score       60/100  ████████████░░░░░░░░
              assertions 12/20  ·  health 90

  signals     Assertions: 20 planted  ·  Predictions: 3/5 correct
```

No assertions yet? The score is a **completion ratchet** (0-50) that rewards you for defining what value means: writing a hypothesis, adding signals, planting assertions. You can't score above 50 without saying what your product should do.

No value hypothesis at all? Score is 10. Honest.

### What a session looks like

```
$ cd ~/my-project
$ rhino init
  ◆ rhino init
  ✓ detected: node (src/)
  ✓ features: auth dashboard api (3 detected)
  ✓ config/rhino.yml (3 features)
  ✓ config/evals/beliefs.yml

  score  20/100  ████░░░░░░░░░░░░░░░░
         3 features

$ claude                    # start Claude Code
> /plan                     # finds the bottleneck, writes tasks
> /go                       # autonomous loop — builds, measures, keeps/reverts

# ... 20 minutes later ...

$ rhino score .
  Score: 65/100 ↑45 from 20  █████████████░░░░░░░  (7/10 assertions passing)
```

Init detects your project, generates assertions, and scores it. `/go` improves the score by building what's failing and reverting what regresses. Each session picks up where the last one left off.

---

## How It Works

Three layers, in order of what matters:

### 1. Value (the score)

You write assertions in `beliefs.yml` — mechanical checks that test whether your product works:

```yaml
- id: signup-completes
  belief: "New user can sign up without hitting an error"
  type: playwright_task
  scenario: "Sign up as a new user"
  severity: block
```

`rhino score .` runs them. The pass rate IS your score. The `/go` loop keeps changes that improve the pass rate, reverts changes that regress it.

**How the score blends:** If you have both `features:` in rhino.yml (generative eval — Claude judges if code delivers what it claims) and `beliefs.yml` (mechanical file checks), generative evals count **3x** vs beliefs. This prevents easy file-exists checks from inflating the score. The score also shows *reasons* — what penalties were applied and why.

### 2. Health (a gate, not the score)

Structure and hygiene (dead ends, `any` types, console.logs) are still checked. But they don't reduce your score — they gate it:

- Health < 20 -> score = 0 (hard gate, like a build failure)
- Health < 40 -> warning in output
- Health >= 40 -> no effect on the number

Fix your health issues, but don't confuse them with value.

### 3. Craft (on demand)

`rhino taste` — Claude Vision scores your UI across 11 dimensions. Expensive, run when visual quality matters.

---

## Quick Start

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed. macOS or Linux.

### Option A: Plugin install (recommended)

Inside Claude Code:
```
/plugin marketplace add rhinehart514/rhino-os
/plugin install rhino-os@rhino-marketplace
```

Done. Commands, skills, agents, and hooks load automatically.

### Option B: Manual install

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
source ~/.zshrc  # or restart your terminal
```

### Then, in any project:

```bash
cd ~/your-project
claude            # rhino-os boots automatically
/init             # detects project, generates config + assertions
/plan             # find the bottleneck
/go               # autonomous build loop — keeps what passes, reverts what doesn't
```

Your first score will be low. That's correct — you haven't told it what your product should do yet. `/init` generates assertions, then `/go` builds toward passing them.

**Optional:** Node 18+ for visual eval (`rhino taste`).

### What install.sh does

Symlinks only — no copies, no modifications. Updates are `rhino update` (pulls latest + refreshes symlinks).

| What | Where | Why |
|------|-------|-----|
| Mind files | `~/.claude/rules/` | Always loaded by Claude Code as system context |
| Commands | `~/.claude/commands/` | /plan, /go, /eval available in every project |
| CLI | `~/bin/rhino` | Terminal access to score, taste, eval, trail |
| PATH | `~/.zshrc` / `~/.bashrc` | Ensures `rhino` command works from any directory |

Verifies everything linked correctly before finishing. Then run `rhino init` in each project to set up per-project hooks and config.

### Uninstall

```bash
cd ~/rhino-os && ./uninstall.sh
./uninstall.sh --check   # dry run
```

---

## The Commands

Every command accepts a feature name. Work on what you want, scoped to the part of the product you care about.

| Command | What it does |
|---------|-------------|
| `/plan [feature]` | Find the bottleneck, write tasks |
| `/go [feature]` | Autonomous build loop — keeps what passes, reverts what doesn't |
| `/eval [taste\|full]` | Run assertions, visual eval |
| `/feature [name]` | List, create, detect features |
| `/todo [add\|done]` | Manage backlog across sessions |
| `/assert [feat: x]` | Add assertions from chat |
| `/ideate [wild]` | Brainstorm possibilities |
| `/research [topic]` | Explore unknown territory |
| `/retro` | Grade predictions, close learning loop |
| `/roadmap` | Version theses and progress |
| `/strategy` | Stage, bottleneck, loop health |
| `/rhino` | Status dashboard |
| `/ship` | Commit, push, deploy, verify |
| `/init` | Bootstrap into any repo |
| `/clone <url>` | Screenshot → components |
| `/skill [create]` | Manage lenses |
| `/product` | Product thinking — who, why, assumptions, focus, delight |

**Terminal:**

| Command | What it does |
|---------|-------------|
| `rhino score .` | The score. Assertion pass rate, per-feature breakdown. |
| `rhino feature` | List all features with pass rates. |
| `rhino feature detect` | Auto-detect features from your codebase. |
| `rhino todo` | Backlog management (show, add, done, promote). |
| `rhino eval .` | Run assertions from the terminal. |
| `rhino taste` | Visual eval (Claude Vision, expensive). |

A typical session: `/plan auth` -> `/go auth` -> `/plan` next time.

---

## The Learning System

Every action has a prediction. Wrong predictions update the model. Over sessions, Claude gets better at knowing what works for *your* product.

- **Predictions** (`~/.claude/knowledge/predictions.tsv`) — logged with evidence, auto-graded by `grade.sh`
- **Knowledge model** (`~/.claude/knowledge/experiment-learnings.md`) — known patterns, uncertain patterns, unknown territory, dead ends
- **Assertions** (`beliefs.yml`) — the definition of done, enforced mechanically
- **Session trail** (`rhino trail`) — persistent evidence of improvement across sessions

You don't need to understand this to start. Run `/plan`, follow its lead.

---

## The Scoring Formula

```
if build fails:              score = 0
elif health < 20:            score = 0  (health gate)
elif assertions exist:       score = assertion pass rate (0-100)
elif value hypothesis exists: score = completion ratchet (0-50)
else:                        score = 10
```

One number. Measures what matters.

---

## CLI Reference

```
  rhino v7.0.0

  Measure
    eval [dir]      Run assertions — the one command
    taste [dir]     Visual eval (Claude Vision, expensive)
    score [dir]     Score for scripts/CI (--quiet for number)

  Features
    feature         List all features with pass rates
    feature <name>  View one feature's assertions
    feature detect  Auto-detect features from codebase

  Build
    plan            View/manage build plan
    todo            Backlog (show|add|done|edit|tag|promote)
    test            Run test suites

  System
    trail           Evidence trail — session arc over time
    init            Bootstrap rhino-os into any repo
    update          Pull latest + refresh symlinks
    doctor          Verify install health (symlinks, deps)
    status          Health overview
    self            Self-diagnostic
    bench           Calibration check
    config          Show configuration
```

---

## File Tree

```
rhino-os/
  .claude-plugin/          plugin manifest (for /plugin install)
    plugin.json            name, version, description
    marketplace.json       marketplace listing
  commands/                slash commands (plan, go, eval, feature, etc.)
  .claude/commands/        symlinks → commands/ (backward compat)
  skills/                  auto-triggered skills for plugin system
    rhino-mind/SKILL.md    core operating model (identity + thinking + standards + self)
    product-lens/SKILL.md  product measurement (eyes + self + UX checklist)
  agents/                  custom agents (measurer, explorer, builder, reviewer)
  mind/                    identity + reasoning (source of truth)
    identity.md            cofounder behavior
    thinking.md            predict -> measure -> update model
    standards.md           what quality means (value > craft > health)
    self.md                self-model (capabilities, weaknesses, calibration)
  bin/
    rhino                  CLI entrypoint
    score.sh               THE score (assertion pass rate, health gate)
    eval.sh                assertion runner
    self.sh                4-system self-diagnostic
    bench.sh               calibration check against fixture repos
    init.sh                bootstrap rhino-os into any repo
  config/
    rhino.yml              tunables + value hypothesis + signals
  hooks/
    hooks.json             declarative hook config (for plugin system)
    run-hook.cmd           polyglot hook launcher (Unix + Windows)
    session_start.sh       boot card on session start
    post_skill.sh          plan file validation after skill writes
    post_edit.sh           write-time quality checks
  lens/product/            product development lens
    eval/beliefs.yml       product assertions
    eval/taste.mjs         visual eval engine
    scoring/               web-specific structure/hygiene extensions
    corpus/                taste reference database
  tests/                   mechanical tests for score, eval, self
```

---

## License

[MIT](LICENSE)
