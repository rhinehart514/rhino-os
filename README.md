# rhino-os

For solo technical founders building products with Claude Code.

Developers using AI coding tools think they're 20% more productive. [They're actually 19% less productive](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/). The gap is measurement — nobody checks whether AI-assisted work actually made the product better.

rhino-os closes that gap. It measures **product quality** (not code quality), learns what works across sessions, and reverts changes that make things worse. It's the only Claude Code plugin that scores whether your product delivers value — not just whether your code compiles.

## How it's different

Most dev tools measure code quality — linting, test coverage, type safety. rhino-os measures **product quality**: does the user get value? It plants testable beliefs about your product ("the signup flow completes in under 30 seconds"), scores them, and reverts changes that make things worse. SonarQube tells you your code is clean. rhino-os tells you your product is better.

The `/score` command orchestrates 5 measurement tiers — health, code eval, visual quality, behavioral testing, and agent-backed market viability — into one honest number with a confidence badge (●●●○○) showing how many tiers have data.

## vs alternatives

| Tool | Measures | rhino-os difference |
|------|----------|---------------------|
| GitHub Actions / CI | Code passes tests | CI validates code correctness. rhino-os validates product value — assertions test what users experience, not what compilers accept. |
| SonarQube / CodeClimate | Code quality — complexity, duplication, smells | These tools catch code smells. rhino-os catches product smells — features that don't deliver, craft that doesn't compound, viability gaps. |
| Linear / Jira | Task completion | Task trackers measure throughput. rhino-os measures outcome — a "done" task that drops the product score gets reverted automatically. |
| Cursor / Copilot | Code generation | Copilots generate code. rhino-os generates code, measures whether it helped, learns what works, and stops doing what doesn't across sessions. |

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

  score: 88 ●●●○○  · assertions: 51/60 · thesis: v9.4

  bottleneck: docs at 84 — w:3, METR positioning missing, walkthrough stale
    d:86 c:82

  move 1: add METR -19% hook to README headline
    predict: "METR positioning will push docs to 88+ in one session"
    acceptance: README opens with the measurement gap, not a feature list

  move 2: fill visual + behavioral tiers — run /taste
    depends on: URL configured
```

Notice the startup pattern warning — rhino-os detected feature sprawl and flagged it before building anything new.

### 2. "Just build it"

```
> /go
```

The `/go` loop predicts, builds, measures, and learns:

```
◆ go — scoring

  predict: "5 /score improvements will push scoring to 92+"
  because: "sparkline, tier badge, score diff, viability from intelligence, kill code-only mode"

  move 1: sparkline + tier badge + score diff on commit
  ▾ commit — 2341dce
    built: score.sh --trend outputs sparkline from history.tsv.
           session hook shows ●●●○○ tier fill badge.
           post_commit.sh shows score delta after every commit.
    files: bin/score.sh, hooks/post_commit.sh, hooks/session_start.sh
    ✓ sparkline-shows-trend  PASS
    ✓ tier-badge-visible     PASS

  measure: scoring at 92 (d:93 c:90)
  score: 86 → 88 ↑2

  grade: "Predicted 92+, got 92. Correct."
```

### 3. "Is this good?"

```
> is this good?
```

```
◆ eval — 6 features

  todo         ████████████████░░░░  82  d:82 c:82
  docs         ████████████████░░░░  84  d:86 c:82
  install      █████████████████░░░  85  d:86 c:84
  learning     █████████████████░░░  89  d:90 c:88
  scoring      ██████████████████░░  92  d:93 c:90
  commands     ██████████████████░░  92  d:93 c:91

  beliefs: 51/60 passing
  bottleneck: todo at 82 — smart promote doesn't read eval-cache
```

### 4. The score compounds

Every session picks up where it left off. Predictions get sharper. The knowledge model updates. Startup pattern checks keep you honest.

```
> /plan

  score: 88 ●●●○○ · assertions: 51/60 · v9.4

  bottleneck: docs at 84 — METR positioning missing
    d:86 c:82

  move 1: add METR -19% finding to README — strongest positioning hook
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

### Results

rhino-os running on itself over ~35 sessions:

```
Session 1:   26% product complete  ·  48/63 assertions  ·  score 20
Session 10:  58% product complete  ·  54/63 assertions  ·  score 68
Session 20:  74% product complete  ·  56/63 assertions  ·  score 82
Session 35:  92% product complete  ·  51/60 assertions  ·  score 88 ●●●○○
```

The gap between session 1 and session 10 is `/plan` finding the bottleneck + `/go` building it. The gap between 10 and 35 is compounding — the knowledge model gets better at predicting what works, so less gets reverted and more sticks. Prediction accuracy went from ~40% (guessing) to 63% (calibrated). The ●●●○○ means 3 of 5 measurement tiers have data — the score is honest about what it doesn't know.

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
  score: 88 ●●●○○ · assertions: 51/60
  bottleneck: docs at 84 — METR positioning missing
  move 1: add METR -19% finding to README — push docs to 88+
```

**Score every feature in one command:**
```
> /eval

◆ eval — 6 features
  scoring    ██████████████████░░  92  d:93 c:90
  commands   ██████████████████░░  92  d:93 c:91
  learning   █████████████████░░░  89  d:90 c:88
  beliefs: 51/60 passing
```

**Autonomous build loop:**
```
> /go

◆ go — scoring
  predict: "Sparkline + tier badge will push scoring to 92+"
  ▾ commit — 2341dce
    5 improvements: sparkline, tier badge, score diff, viability from intelligence
  measure: scoring at 92 (d:93 c:90) ↑2
  grade: "Predicted 92+, got 92. Correct."
```

## Tested on

- **rhino-os itself** — score 20 to 88 over ~35 sessions across 2 weeks, 51/60 assertions passing, 63% prediction accuracy
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
