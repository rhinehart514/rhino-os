# rhino-os

**An AI cofounder for solo founders.** Not a tool that waits for commands — a cofounder that proposes what to build, pushes back with evidence, tracks hypotheses about users, and learns from every cycle.

Built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

---

## Quick Start

```bash
# 1. Install
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh

# 2. Set up your project
cd ~/your-project
claude
> /setup
```

That's it. `/setup` scans your codebase, builds a product pyramid, creates rule files, and gets you ready.

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval.

---

## What's New in v5

### Always-On Boot
When you open any project with rhino-os in Claude Code, it **boots automatically**:
- Loads your project context
- Surfaces the next task — no commands needed
- Shows which beliefs are at risk

### Beliefs — Your Product's Soul
Encode your product beliefs as mechanical evals:

```bash
# In Claude Code:
/eval --add
# "Users bounce when overwhelmed. One CTA above fold, always."
# -> generates eval, runs on every build, blocks commits that violate it
```

### The Overnight Loop
```bash
/go                  # runs autonomously until plateau
/go --corpus         # also builds the taste corpus overnight
```

### AI-Discovered Corpus
rhino-os finds examples of exceptional work autonomously:
```bash
/corpus update ui/saas    # finds top-tier SaaS UI examples
```

### Eval Tiers
1. **Computed** — contrast, hierarchy, route depth (2 sec, free, ungameable)
2. **Behavioral** — blind agent completes your primary task (the val_bpb)
3. **Corpus comparison** — gap analysis vs exceptional examples

### New Commands
| Command | What it does |
|---------|-------------|
| `/next` | Show next task — zero ceremony |
| `/eval` | Run belief evals, `/eval --add` to define beliefs |
| `/corpus` | Manage taste corpus — update, add, list |

---

## How It Works

### Three Modes

| Mode | When | What happens |
|------|------|-------------|
| **Ideate** | "what if...", "brainstorm" | Think, don't build. Explore options, push back, play devil's advocate. |
| **Research** | `/research [topic]` | WebSearch + synthesize. Taste, market, eval engineering. |
| **Build** | `/build`, "build that" | Execute plan. Score every change. Keep or discard. |

The founder picks the mode. The cofounder can suggest switching.

### The Product Pyramid

Every product has three layers:

```
Ecological  — does it grow? (sharing, discovery, return)
Emotional   — does it feel good? (onboarding, polish, feedback)
Functional  — does it work? (core features, completion)
```

Rule: don't build up the pyramid until the layer below is solid. Strategy reasons about layers. `/status` renders this visually.

### Commands

| Command | What it does |
|---------|-------------|
| `/plan` | Morning — reads pyramid, identifies weakest layer, outputs today's tasks |
| `/build` | Execute the plan. Score every change, keep or discard. `--experiment` for autoresearch. |
| `/next` | Show next task — zero ceremony, one task, why it matters |
| `/research` | When stuck — taste dimensions, market landscape, ideas, eval engineering |
| `/eval` | Run belief evals against your product. `/eval --add` to define beliefs. |
| `/corpus` | Manage taste corpus — update categories, add examples, list current state |
| `/status` | Full co-founder briefing — pyramid, scores, hypotheses, opinion |
| `/setup` | Onboard a project — scans codebase, generates product-brief + pyramid |
| `/go` | Karpathy NEVER STOP — plan → build → measure → repeat autonomously |

### CLI (terminal, not Claude Code)

| Command | What it does |
|---------|-------------|
| `rhino score .` | Structural lint — build health, structure, hygiene (2 sec, free) |
| `rhino taste` | Visual eval — Playwright screenshots scored by Claude vision (11 dimensions) |
| `rhino eval` | Run Tier 1 belief evals against your project |
| `rhino status` | Quick health overview |
| `rhino corpus list` | Show corpus size by category |
| `rhino config` | Show configuration |

---

## The Context Architecture

Instead of one giant CLAUDE.md, rhino-os uses modular rule files that Claude Code always loads:

```
.claude/rules/
  identity.md        # who you are, how you work (~15 lines)
  product-brief.md   # current product state (updated by /build)
  hypotheses.md      # beliefs about users (updated as you learn)
```

Each file is independently editable. The cofounder updates `product-brief.md` after every build session without touching `identity.md`. Total always-loaded context: ~100 lines across 3 files.

### Hypotheses as First-Class

The cofounder maintains beliefs about users:

```markdown
## Active Hypotheses
- Users won't share unless creation is < 3 taps — evidence: competitor analysis — test: add share button, measure usage

## Validated (keep building on these)
- Campus users check the app between classes — confirmed by: usage data shows 10am/2pm spikes

## Killed (don't revisit)
- Push notifications drive return — disproved by: 2% open rate after 1 week
```

---

## Scoring

Two tiers, like training loss vs eval loss.

### `rhino score .` — fast, free, every commit

Grep-based structural lint. Three dimensions: **Build** (compiles?), **Structure** (dead ends? orphan routes?), **Hygiene** (any types, console.logs, TODOs). Score: 0-100.

### `rhino taste` — slow, expensive, on demand

Playwright screenshots → Claude vision. 11 dimensions on a 1-5 scale: hierarchy, breathing room, contrast, polish, emotional tone, information density, wayfinding, distinctiveness, scroll experience, layout coherence, information architecture.

### Anti-gaming

- **Cosmetic-only detection** — shuffled comments? Flagged.
- **Inflation cap** — 15+ point jump in one commit? Warning.
- **Stage ceilings** — MVP scoring 95? Something's wrong.

---

## The Experiment Loop

`/build --experiment` enters Karpathy-style autoresearch:

1. **One mutable file** per experiment — multi-file = feature, not experiment
2. **Immutable eval** — score.sh and taste.mjs can't change during a run
3. **15-minute cap** — longer = feature, not experiment
4. **Mechanical keep/discard** — score up AND target improved → keep. Otherwise → `git reset --hard HEAD~1`
5. **Moonshot forcing** — every 5th experiment must be high-risk

---

## File Tree

```
rhino-os/
  config/
    rules/                       template rule files (copied to .claude/rules/ on setup)
    settings.json                hooks config
    rhino.yml                    all tunables (scoring, taste, evals, corpus, memory)
  bin/
    rhino                        CLI (score, taste, eval, status, setup, corpus, config)
    score.sh                     structural lint (720 lines, untouched)
    taste.mjs                    visual eval (1138 lines, untouched)
    eval.sh                      Tier 1 mechanical eval runner
    lib/config.sh                YAML config reader
  programs/
    build.md                     the Karpathy loop
    strategy.md                  pyramid-aware bottleneck diagnosis
  skills/
    plan/    build/    next/     daily workflow
    research/    eval/           investigation + belief checking
    corpus/                      taste database management
    status/    setup/    go/     system commands
  hooks/
    session_start.sh             full context boot screen
    pre_compact.sh               context recovery + session summary
    post_build.sh                auto-score + eval after builds
    post_edit_quality.sh         catch bugs at write time
  .claude/
    brains/                      living memory (longterm, daily, experiments, hypotheses)
    evals/beliefs.yml            product beliefs template
  corpus/                        taste database (ui, copy, code categories)
  tests/
    quickstart-smoke.sh          cold-start validation
  docs/
    thinking.md                  prediction protocol
    vision-v5.md                 architecture spec
```

---

## Customization

Everything tunable in `config/rhino.yml`: scoring weights, taste dimensions, integrity ceilings, experiment discipline, go loop settings.

---

## License

[MIT](LICENSE)
