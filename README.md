# rhino-os

For solo technical founders building products with Claude Code.

Developers using AI coding tools think they're 20% more productive. [They're actually 19% less productive](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/). The gap is measurement — nobody checks whether AI-assisted work actually made the product better.

rhino-os closes that gap. It measures **product quality** (not code quality), learns what works across sessions, and reverts changes that make things worse. It's the only Claude Code plugin that scores whether your product delivers value — not just whether your code compiles.

## How it's different

Most dev tools measure code quality — linting, test coverage, type safety. rhino-os measures **product quality**: does the user get value? It plants testable beliefs about your product ("the signup flow completes in under 30 seconds"), scores them, and reverts changes that make things worse. SonarQube tells you your code is clean. rhino-os tells you your product is better.

The `/score` command orchestrates 5 measurement tiers — health, code eval, visual quality, behavioral testing, and agent-backed market viability — into one honest number with a confidence badge (●●●○○) showing how many tiers have data.

## vs alternatives

- **CI / GitHub Actions** measure whether code passes tests. rhino-os measures whether the product delivers value — assertions test what users experience, not what compilers accept.
- **SonarQube / CodeClimate** catch code smells. rhino-os catches product smells — features that don't deliver, craft that doesn't compound, viability gaps.
- **Linear / Jira** measure task throughput. rhino-os measures outcomes — a "done" task that drops the product score gets reverted automatically.
- **Cursor / Copilot** generate code. rhino-os generates code, measures whether it helped, learns what works, and stops doing what doesn't across sessions.

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

## Your first 5 minutes

After installing, open any project and start a Claude Code session:

```bash
cd your-project
claude
```

rhino-os loads automatically. You'll see a boot card with your score. Then:

1. **"What should I work on?"** → routes to `/plan`, finds the bottleneck
2. **"/go"** → builds autonomously, measures after every change, reverts regressions
3. **"Is this good?"** → routes to `/eval`, scores every feature 0-100

That's it. No configuration needed — rhino-os reads your code and generates assertions automatically. Your score starts low and climbs as you ship value.

## Walkthrough: rhino-os running on itself

Real output from rhino-os measuring itself — the actual product you're looking at.

One key concept: rhino-os uses **assertions** — testable beliefs about your product, like "score.sh exits 0 on a healthy codebase." It plants them automatically, scores them, and tracks which ones pass. Your score is the percentage of assertions passing.

### 1. "What should I work on?"

Just ask — rhino-os routes to `/plan`:

```
◆ plan

  score: 95 ●●●○○  · assertions: 55/60 · thesis: v9.4

  bottleneck: docs at 60 — w:3, walkthrough stale, no quickstart
    d:62 c:57

  move 1: update README with current data + add quickstart
    predict: "docs delivery moves from 62 to 72 in one session"
    acceptance: README opens with clear first action, not just features
```

### 2. "Just build it"

The `/go` loop predicts, builds, measures, and learns:

```
◆ go — scoring

  predict: "contextual output + error communication → scoring d:70→78"
  because: "numbers without context is the #1 gap across all features"

  move 1: add context to score output
  ▾ commit
    built: assertions show "51/60 (85%) — 9 failures block polished"
           prediction accuracy shows "(target: 50-70%)"
           stage ceiling shown inline when exceeded
    ✓ assertions pass  ✓ score held

  measure: scoring at 75 (d:78 c:70) ↑7
  grade: "Predicted d:70→78, got 78. Correct."
```

### 3. "Is this good?"

```
◆ eval — 6 features

  docs         ████████████░░░░░░░░  60  d:62 c:57
  todo         ████████████░░░░░░░░  62  d:64 c:60
  learning     █████████████░░░░░░░  67  d:70 c:62
  commands     ██████████████░░░░░░  72  d:75 c:68
  install      ██████████████░░░░░░  72  d:75 c:68
  scoring      ███████████████░░░░░  75  d:78 c:70

  beliefs: 55/60 passing
  bottleneck: docs at 60 — walkthrough stale, no quickstart
```

These are honest scores — not inflated. Docs at 60 means it works but isn't good enough yet. Scoring at 75 means it delivers value but the code is too large. The numbers tell you where to focus.

### 4. The score compounds

Every session picks up where it left off. Predictions get sharper. The knowledge model updates.

```
Session 1:   26% product complete  ·  48/63 assertions  ·  score 20
Session 10:  58% product complete  ·  54/63 assertions  ·  score 68
Session 20:  74% product complete  ·  56/63 assertions  ·  score 82
Session 38:  92% product complete  ·  55/60 assertions  ·  score 95 ●●●○○
```

The gap between session 1 and 10 is `/plan` finding the bottleneck + `/go` building it. The gap between 10 and 38 is compounding — the knowledge model predicts what works, less gets reverted, more sticks. Prediction accuracy went from ~40% (guessing) to 60% (calibrated — target is 50-70%). The ●●●○○ means 3 of 5 measurement tiers have data — the score is honest about what it doesn't know.

## How it works

```
  Observe ─── what's the product state? (score, eval, assertions)
     │
  Model ───── what patterns explain it? (experiment-learnings.md)
     │
  Predict ─── what will improve it? (predictions.tsv)
     │
  Act ──────── build it (/go, autonomous loop)
     │
  Measure ─── did it work? (score delta, eval delta)
     │
  Update ───── wrong predictions update the model
     │
     └──────── repeat ─── the model compounds across sessions
```

Every action starts with a prediction. Wrong predictions are the most valuable event — they update the model. Over sessions, the system stops guessing and starts citing evidence.

---

## Commands

You don't need to memorize these. Just talk — rhino-os routes your intent.

**Build**
- `/plan` — find the bottleneck, propose what to work on
- `/go` — autonomous build loop with prediction grading
- `/score` — unified product quality (5 tiers, one number, confidence badge)
- `/eval` — score every feature 0-100 (delivery + craft)
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

**Measurement** — `/score` orchestrates 5 tiers into one number: health (structural lint), code eval (delivery + craft per feature), visual quality (Playwright + Claude Vision), behavioral testing (does the frontend work?), and agent-backed viability (market-analyst + customer agents research your market position). Each tier shows confidence. Score drops after a change trigger automatic reverts.

**Learning** — Every action starts with a prediction ("I predict URL import will reach delivery 50+"). After building, the grader agent checks the prediction against the result. Wrong predictions update the knowledge model. Over sessions, the system stops guessing and starts citing evidence.

**Strategy** — 14 specialized agents handle different jobs. The builder writes code in isolated worktrees. The founder-coach detects startup failure modes (building without a named user, polishing before delivering). The customer agent synthesizes real signal. The gtm agent handles pricing and distribution. They're coordinated by commands like `/go` and `/plan`, not invoked manually.

## Quick examples

**Find the bottleneck and fix it:**
```
> what should I work on?

◆ plan
  score: 95 ●●●○○ · assertions: 55/60
  bottleneck: docs at 60 — walkthrough stale, no quickstart
  move 1: update README — push docs to 70+
```

**Score every feature:**
```
> /eval

◆ eval — 6 features
  docs       ████████████░░░░░░░░  60  d:62 c:57
  scoring    ███████████████░░░░░  75  d:78 c:70
  commands   ██████████████░░░░░░  72  d:75 c:68
  beliefs: 55/60 passing
```

**Autonomous build loop:**
```
> /go

◆ go — scoring
  predict: "contextual output → scoring d:70→78"
  ▾ commit
    assertions show "85% — 9 failures block polished"
    errors surface recovery actions instead of silence
  measure: scoring at 75 (d:78 c:70) ↑7
  grade: "Predicted d:78, got 78. Correct."
```

## Tested on

- **rhino-os itself** — score 20 to 95 over ~38 sessions across 2 weeks, 55/60 assertions passing, 60% prediction accuracy (target: 50-70%)
- **commander.js** — 80/100 on first `rhino init`, zero configuration

## Troubleshooting

**`jq: command not found` when running rhino commands**
Install jq: `brew install jq` (macOS) or `sudo apt install jq` (Linux). rhino-os uses jq for scoring, eval, init, and session boot. Everything else works without it, but scores will be blank.

**Plugin not loading after `claude /plugin install`**
Check that `skills/rhino-mind/SKILL.md` exists in the plugin root. This skill delivers mind files — without it, rhino-os loads as an empty plugin. Run `./install.sh --test` to verify the plugin structure. If the skill count is wrong, re-clone or re-install from marketplace.

**`Permission denied` when running `rhino` or `./install.sh`**
Run `chmod +x install.sh bin/rhino bin/*.sh` from the rhino-os directory. The installer sets permissions automatically, but git clone sometimes strips execute bits depending on your `core.fileMode` setting.

---

[MIT](LICENSE)
