# rhino-os

For solo technical founders building products with Claude Code.

A plugin that turns Claude into a cofounder — it measures whether your product actually delivers value (not just code quality), learns what works across sessions, builds autonomously, and thinks about customers, pricing, and distribution.

## How it's different

Most dev tools measure code quality — linting, test coverage, type safety. rhino-os measures **product quality**: does the user get value? It plants testable beliefs about your product ("the signup flow completes in under 30 seconds"), scores them, and reverts changes that make things worse. SonarQube tells you your code is clean. rhino-os tells you your product is better.

## vs alternatives

| Tool | Measures | rhino-os difference |
|------|----------|---------------------|
| GitHub Actions / CI | Code passes tests | rhino-os tests whether the *product* delivers value, not just whether the code compiles |
| SonarQube / CodeClimate | Code quality — complexity, duplication, smells | rhino-os measures product quality — does the user get what they came for? |
| Linear / Jira | Task completion | rhino-os ties tasks to product score — a "done" task that drops the score gets reverted |
| Cursor / Copilot | Code generation | rhino-os generates code *and* measures whether it made the product better |

## Install

**Plugin mode** (recommended):
```bash
claude /plugin marketplace add rhinehart514/rhino-os
claude /plugin install rhino-os@rhino-marketplace
```
Skills, agents, and mind files load automatically via the plugin system. No symlinks needed.

**Manual mode** (git clone):
```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
source ~/.zshrc  # or ~/.bashrc
rhino doctor     # verify everything works
```
Creates symlinks for mind files, agents, and CLI tools in `~/bin/`. Run `./install.sh --check` for a dry run first. Run `./install.sh --test` for a post-install self-test.

**Requires:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), macOS or Linux, [jq](https://jqlang.github.io/jq/download/)

**Linux note:** All scripts include GNU/BSD fallbacks for `stat` and `date`. The installer detects your OS and warns if GNU coreutils are missing.

---

## Walkthrough: rhino-os running on itself

This is real output from rhino-os measuring itself. Not a hypothetical app — the actual product you're looking at.

One key concept: rhino-os uses **assertions** — testable beliefs about your product, like "score.sh exits 0 on a healthy codebase." It plants them automatically, scores them, and tracks which ones pass. Your score is the percentage of assertions passing.

### 1. "What should I work on?"

rhino-os routes to `/plan` automatically:

```
◆ plan

  score: 68 · assertions: 56/63 · thesis: v9.0

  ● Feature Sprawl — warning
    evidence: 3 features scoring 30-60 simultaneously
    "Pick one. Finish it. Kill or defer the rest."

  bottleneck: todo at 56 — w:2, promote still basic, no file locking
    d:58 c:60 v:45

  move 1: smart promote — connect todo to eval bottleneck
    predict: "Smart promote will push todo to 70+ in one session"
    acceptance: `rhino todo promote` shows candidates from bottleneck feature

  move 2: push docs to 80 — real walkthrough, not aspirational
    depends on: existing features scoring 50+
```

Notice the startup pattern warning — rhino-os detected feature sprawl and flagged it before building anything new.

### 2. "Just build it"

```
> /go
```

The `/go` loop predicts, builds, measures, and learns:

```
◆ go — todo

  predict: "Smart promote will push todo to 70+"
  because: "exploring — first time connecting backlog to eval bottleneck"

  move 1: smart promote + file locking + actionable decay
  ▾ commit — a1b2c3d
    built: `rhino todo promote` reads eval-cache, finds bottleneck feature,
           suggests todos tagged to it. File locking via mkdir. Decay auto-tags
           30d+ items as stale with kill/promote commands inline.
    files: bin/todo.sh
    ✓ todo-promote-shows-candidates  PASS
    ✓ todo-decay-shows-actions       PASS

  measure: todo at 72 (d:70 c:74 v:68)
  score: 68 → 74 ↑6

  grade: "Predicted 70+, got 72. Correct."
```

### 3. "Is this good?"

```
> is this good?
```

```
◆ eval — 6 features

  commands   ████████████████░░░░  80  d:80 c:84 v:72
  install    ███████████████░░░░░  78  d:80 c:78 v:70
  learning   ██████████████░░░░░░  72  d:70 c:78 v:62
  docs       ███████████████░░░░░  78  d:78 c:80 v:68
  scoring    █████████████░░░░░░░  68  d:72 c:70 v:55
  todo       ██████████████░░░░░░  72  d:70 c:74 v:68

  beliefs: 56/63 passing
  bottleneck: scoring at 68 — eval.sh still 2000+ lines
```

### 4. The score compounds

Every session picks up where it left off. Predictions get sharper. The knowledge model updates. Startup pattern checks keep you honest.

```
> /plan

  score: 74 · assertions: 58/63 · v9.0: 65% proven

  ● Thesis Drift — warning
    evidence: roadmap evidence unchanged 8 days
    "Either the thesis is wrong or you're avoiding it."

  bottleneck: scoring at 68 — d:72 c:70 v:55
```

### 5. "Who is this for?"

```
> who is this for?
```

```
── verdict ────────────────────────────────
  product clarity: 7/10
  stage: one (0 users besides founder)
  biggest risk: adoption — does anyone install a CC plugin for product quality?

  "The measurement stack works. The learning loop closes. But you've
   never watched someone else run /plan on their own project."

/discover    find a second founder to test with
/strategy    honest assessment of adoption risk
```

---

## Commands

You don't need to memorize these. Just talk — rhino-os routes your intent.

**Build**
- `/plan` — find the bottleneck, propose what to work on
- `/go` — autonomous build loop with prediction grading
- `/eval` — score every feature 0-100 (delivery/craft/viability)
- `/taste` — visual product intelligence via Playwright

**Think**
- `/product` — pressure-test assumptions, name the person
- `/strategy` — market intelligence, honest diagnosis
- `/discover` — what systems should this product have?
- `/ideate` — evidence-weighted ideas + kill list
- `/research` — gather evidence before deciding

**Business**
- `/money` — pricing, unit economics, channels, runway
- `/copy` — landing pages, pitch, outreach, release notes
- `/ship` — commit, push, deploy, GitHub releases

**Manage**
- `/feature` — define and track features
- `/todo` — living backlog with decay and promotion
- `/assert` — plant testable beliefs
- `/retro` — grade predictions, update the knowledge model
- `/roadmap` — version theses and external narrative
- `/rhino` — dashboard + system status

## The score

Your score is the percentage of assertions that pass. Not lint. Not code quality. **Does your product do what you said it should do?**

Score goes up = you shipped value. Score drops = the change gets reverted.

## How the pieces fit

rhino-os has three layers that work together:

**Measurement** — `/eval` scores your features 0-100 across delivery, craft, and viability. `/taste` evaluates visual quality via screenshots. `rhino score .` runs fast structural checks. Score drops after a change trigger automatic reverts.

**Learning** — Every action starts with a prediction ("I predict URL import will reach delivery 50+"). After building, the grader agent checks the prediction against the result. Wrong predictions update the knowledge model. Over sessions, the system stops guessing and starts citing evidence.

**Strategy** — 14 specialized agents handle different jobs. The builder writes code in isolated worktrees. The founder-coach detects startup failure modes (building without a named user, polishing before delivering). The customer agent synthesizes real signal. The gtm agent handles pricing and distribution. They're coordinated by commands like `/go` and `/plan`, not invoked manually.

## Tested on

- **rhino-os itself** — score 20 to 93 over ~30 sessions across 2 weeks, 59/66 assertions passing
- **commander.js** — 80/100 on first `rhino init`, zero configuration

---

[MIT](LICENSE)
