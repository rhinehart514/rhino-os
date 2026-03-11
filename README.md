# rhino-os

**A brain for your AI coding agent.** It decides what to build, builds it, scores the result, and learns from every cycle.

Your AI coding agent can execute tasks, but it doesn't know what to build next, can't tell if what it built is good, forgets everything between sessions, and has no strategy. rhino-os fixes all of that.

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — the same modify-measure-keep/discard loop, applied to product development instead of ML training.

![rhino-os overview](docs/screenshots/overview-hero.png)

---

## Quick Start

### 1. Install rhino-os

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
```

This symlinks skills into Claude Code, sets up hooks, and configures the CLI. Safe to re-run anytime.

### 2. Set up your project

```bash
cd ~/your-project
rhino setup .
```

This detects your project type, creates a `.claude/` folder with plans and config, sets a baseline score, and registers the project in the workspace.

### 3. Open Claude Code and start working

```bash
cd ~/your-project
claude
```

Then type any of these inside Claude Code:

```
/plan          # figure out what to work on today
/build         # build the plan, score every change
/go            # do everything autonomously — walk away
```

That's it. Three commands to go from "what should I work on?" to shipping.

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval (`rhino taste`).

---

## How It Works

### The daily loop

```
/plan (morning) → /build (during day) → /review (evening)
       ↑                                        |
       └──────── gaps feed back ────────────────┘
```

Each cycle, rhino-os gets smarter. `/review` extracts what went well and what didn't. `/plan` reads those gaps the next morning and plans accordingly. Knowledge compounds automatically.

### Commands

You have **5 primary commands** (the daily loop) and **6 utility commands** (always available).

#### Primary — the daily loop

| Command | When to use | What it does |
|---------|------------|-------------|
| `/plan` | Start of day | Checks project health, reads yesterday's gaps, produces today's prioritized task list |
| `/build` | During the day | Builds the plan task by task, scores every change, keeps improvements, discards regressions |
| `/research` | When stuck | Deep-dives into taste dimensions, market landscape, or any topic you need |
| `/review` | End of day | Runs score + taste eval, extracts gaps, writes tomorrow's input for `/plan` |
| `/go` | Walk away | Runs plan → build → review → repeat autonomously until plateau or you stop it |

#### Utility — always available

| Command | What it does |
|---------|-------------|
| `/setup` | Onboard a new project (run once per project) |
| `/status` | Dashboard — all projects, scores, system health |
| `/meta` | Self-improvement loop — grades the system, applies one fix, verifies it worked |
| `/docs` | Generates context documents (platform-docs, architecture, styleguide) |
| `/council` | Shows what each part of the system recommends doing next |
| `/smart-commit` | Writes a conventional commit message tied to the active plan |

#### CLI — run from your terminal, not inside Claude Code

| Command | What it does |
|---------|-------------|
| `rhino score .` | Instant structural quality check — build health, structure, hygiene (2 seconds, free) |
| `rhino taste` | Visual eval — takes real screenshots and scores what it *sees* across 11 dimensions |
| `rhino status` | System health overview |
| `rhino bench` | Runs the full test suite across 3 tiers |
| `rhino dashboard` | Score + experiments + evals in one view |
| `rhino config` | Shows current configuration |

---

## Scoring

rhino-os has two scoring tiers, like training loss vs eval loss in ML.

### `rhino score .` — fast, free, every commit

A grep-based structural lint for your whole project. Three dimensions:

- **Build** — does it compile? TypeScript errors? Stale build artifacts?
- **Structure** — dead-end pages? Orphan routes? Empty states with no CTAs? (powered by `ia-audit.sh`)
- **Hygiene** — `any` types, `console.log`s, TODOs, lint overrides

Score range: 0-100. Takes ~2 seconds. Run it constantly.

### `rhino taste` — slow, expensive, on demand

Takes real Playwright screenshots of your app and sends them to Claude for visual evaluation. Scores 11 dimensions on a 1-5 scale:

`hierarchy` · `breathing_room` · `contrast` · `polish` · `emotional_tone` · `information_density` · `wayfinding` · `distinctiveness` · `scroll_experience` · `layout_coherence` · `information_architecture`

This is how you know if your app is actually good — not just structurally sound, but visually and experientially right.

### Anti-gaming

AI agents love to game metrics. rhino-os fights back:

- **Cosmetic-only detection** — shuffled comments but changed nothing real? Flagged.
- **Inflation cap** — score jumped 15+ points in one commit? Warning.
- **Plateau detection** — same score for 5 runs? You're stuck, not stable.
- **Stage ceilings** — your MVP scoring 95/100? Something's wrong.
- **IA audit** — orphan routes and dead-end pages penalize structure score automatically.

Scores are diagnostic instruments, not goals.

---

## The Experiment Loop

When you run `/build --experiment`, rhino-os enters a Karpathy-style autoresearch loop:

```
predict → implement → measure → keep or discard → log learning → repeat
```

The rules are mechanical — no discretion:

1. **Mandatory prediction** — you must predict the outcome before every change
2. **Mechanical discard** — score dropped or delta < 0.02? Hard reset. No exceptions.
3. **Ratcheting** — keeps are committed (new baseline). Discards are reverted. Progress is monotonic.
4. **Moonshot forcing** — every Nth experiment must be high-risk (ambition 4+/5)
5. **Discard rate floor** — below 25% discard rate? You're playing it too safe. Next 3 must be ambitious.
6. **Scope guard** — after each change, checks if modified files match the plan. Flags drift.

---

## What It Looks Like

### Visual taste eval — 11 dimensions scored by Claude vision

The system takes Playwright screenshots of your app and scores what it *sees*. 40/100 here. Honest.

![Taste radar](docs/screenshots/taste-radar.png)

### Ship readiness — the system said NOT READY

Scored 0.35/1.0. Identified "Day 3 return" at 0.2 as the critical bottleneck. It didn't tell us what we wanted to hear.

![Product eval](docs/screenshots/product-eval.png)

### Self-healing — 3 dead components → all operational

Meta found that 3 parts of the system were silently failing. It diagnosed the root cause, applied the fix, and verified everything came back online.

![Self-healing timeline](docs/screenshots/self-healing.png)

---

## Architecture

Four programs. Five reference docs. Five internal skills. Zero agent wrappers. Every file fits in working context.

```
programs/          4 files, ~480 lines    ← the brain (build, strategy, meta, review)
agents/refs/       5 reference docs       ← thinking protocol, design taste, score integrity, landscape, escalation
skills/_internal/  5 internal skills      ← score, taste, experiment, strategy, todofocus
skills/            11 user-facing skills  ← /plan, /build, /review, /research, /go, /setup, /status, /meta, /docs, /council, /smart-commit
bin/               score.sh, ia-audit.sh, taste.mjs  ← measurement layer
hooks/             session_context.sh     ← injects score + plan + warnings into every session (~110 lines)
config/            rhino.yml              ← all tunable parameters in one place
tests/             175 tests, 3 tiers     ← deterministic, functional, canary
```

![Architecture](docs/screenshots/architecture.png)

---

## Customization

Everything is tunable from `config/rhino.yml`:

| Section | What it controls |
|---------|-----------------|
| `scoring` | Build/structure/hygiene penalty weights and thresholds |
| `taste` | Screenshot count, viewports, dimensions, timeouts |
| `integrity` | Stage ceilings, inflation caps, plateau detection |
| `experiments` | Keep/discard rates, moonshot frequency, scope limits |
| `ia_audit` | IA issue thresholds for structure score penalties |
| `hooks` | Per-edit quality checks, thinking nudges, cost tracking |

Other files you can modify:

| File | What it controls |
|------|-----------------|
| `programs/*.md` | The workflows — how the system thinks and acts |
| `skills/*/SKILL.md` | Slash command entry points |
| `agents/refs/design-taste.md` | The 11-dimension taste rubric with FAIL examples |
| `agents/refs/thinking.md` | The thinking protocol (predict, cite, update) |
| `config/CLAUDE.md` | Your identity, goals, and project-specific rules |

---

## Works with OpenClaw

If you use [OpenClaw](https://github.com/openclaw/openclaw), rhino-os skills work out of the box — both use the `skills/*/SKILL.md` format.

```bash
# Copy skills + programs into your OpenClaw workspace
cp -r ~/rhino-os/skills/build ~/your-openclaw-workspace/skills/
cp -r ~/rhino-os/programs ~/your-openclaw-workspace/
cp ~/rhino-os/bin/score.sh ~/your-openclaw-workspace/bin/
```

The scoring system (`score.sh`) is a standalone bash script with zero dependencies.

> **Note:** Full orchestration (meta-grading, session hooks, experiment enforcement) is Claude Code-native. OpenClaw users get the skills, scoring, and programs.

---

## Uninstall

```bash
cd ~/rhino-os && ./uninstall.sh
```

Removes symlinks and LaunchAgents. Keeps your knowledge files and experiment history.

---

## License

[MIT](LICENSE)
