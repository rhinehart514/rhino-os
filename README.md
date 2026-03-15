# rhino-os

An operating system for Claude Code that makes your product measurably better every session.

Built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

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

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh

# Open any project
cd ~/your-project
claude
```

rhino-os boots automatically. Run `rhino score .` to get your first score. It'll be 10. That's correct — you haven't told it what your product should do yet.

**Next steps:**
1. Add `value.hypothesis` to `config/rhino.yml` (what does your product deliver?)
2. Run `/eval` to see what's passing and what's not
3. Run `/go` to build toward passing them

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval.

### What install.sh does

Symlinks only — no copies, no modifications. Updates are `git pull`.

| What | Where | Why |
|------|-------|-----|
| Mind files | `~/.claude/rules/` | Always loaded by Claude Code as system context |
| Hooks | `~/.claude/hooks/` | Boot card on session start |
| CLI | `~/bin/rhino` | Terminal access to score, taste, eval |

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
| `/plan` | What should I work on? Finds the bottleneck, writes tasks. |
| `/plan auth` | Same, but scoped to the auth feature. |
| `/go` | Build it. Autonomous — keeps what passes, reverts what doesn't. |
| `/go auth` | Build just auth. Only touches auth assertions and files. |
| `/eval` | Run assertions. See what's passing, what's failing. |
| `/eval auth` | Evaluate just auth. |
| `/feature` | List features with pass rates. |
| `/ship` | Commit, push, deploy, verify. |

**Terminal:**

| Command | What it does |
|---------|-------------|
| `rhino feature` | List all features with pass rates. |
| `rhino feature auth` | View auth's assertions (passing/failing). |
| `rhino feature detect` | Auto-detect features from your codebase. |
| `rhino score .` | The score. Assertion pass rate, per-feature breakdown. |

A typical session: `/plan auth` -> `/go auth` -> `/plan` next time.

---

## The Learning System

Every action has a prediction. Wrong predictions update the model. Over sessions, Claude gets better at knowing what works for *your* product.

- **Predictions** (`~/.claude/knowledge/predictions.tsv`) — logged with evidence, graded after measurement
- **Knowledge model** (`~/.claude/knowledge/experiment-learnings.md`) — known patterns, uncertain patterns, unknown territory, dead ends
- **Assertions** (`beliefs.yml`) — the definition of done, enforced mechanically

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
    init            Bootstrap rhino-os into any repo
    status          Health overview
    self            Self-diagnostic
    bench           Calibration check
    config          Show configuration
```

---

## File Tree

```
rhino-os/
  mind/                    identity + reasoning (always loaded via ~/.claude/rules/)
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
  .claude/commands/        slash commands (plan, go, eval, feature, etc.)
  config/
    rhino.yml              tunables + value hypothesis + signals
  hooks/
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
