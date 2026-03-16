# rhino-os

A learning plugin for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that makes your product measurably better every session.

**What is Claude Code?** A CLI tool where you talk to Claude in your terminal and it reads, writes, and runs code. rhino-os is a plugin that adds measurement, learning, and strategy on top.

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

`rhino taste` — Claude Vision scores your UI across 11 dimensions (hierarchy, breathing room, contrast, polish, emotional tone, information density, wayfinding, distinctiveness, scroll experience, layout coherence, information architecture). Expensive, run when visual quality matters.

---

## Install

**Prerequisites:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed. macOS or Linux. [`jq`](https://jqlang.github.io/jq/download/) installed.

### Option 1: Plugin install (recommended)

```bash
claude /plugin marketplace add https://github.com/rhinehart514/rhino-os
claude /plugin install rhino-os
```

No git clone, no symlinks, no shell profile changes. Claude Code manages everything.

### Option 2: Manual install

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
source ~/.zshrc && rhino doctor   # verify install
```

Then in any project:

```bash
cd ~/your-project
rhino init        # detects project, generates config + assertions, first score
claude            # start Claude Code — rhino-os boots automatically
/plan             # find the bottleneck
/go               # autonomous build loop
```

Your first score will be low. That's correct — you haven't told it what your product should do yet. `rhino init` generates assertions, then `/go` builds toward passing them.

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

## Commands

17 slash commands. Every command accepts a feature name to scope work.

### Build

| Command | What it does |
|---------|-------------|
| `/plan [feature]` | Find the bottleneck, write tasks |
| `/go [feature]` | Autonomous build loop — keeps what passes, reverts what doesn't |
| `/todo [add\|done]` | Manage backlog across sessions |
| `/assert [feat: x]` | Add assertions from chat |

### Measure

| Command | What it does |
|---------|-------------|
| `/eval [taste\|full]` | Run assertions, visual eval, sub-scores per feature |
| `/calibrate` | Ground taste eval in founder preferences + design system |

### Think

| Command | What it does |
|---------|-------------|
| `/product` | Product thinking — who cares, why, assumptions, focus |
| `/ideate [wild]` | Evidence-weighted brainstorming + kill list |
| `/research [topic]` | Explore unknown territory with multi-agent synthesis |
| `/strategy` | Anti-sycophantic strategic diagnosis |

### Navigate

| Command | What it does |
|---------|-------------|
| `/feature [name]` | List, create, detect features |
| `/roadmap` | Version theses, progress, external narrative |
| `/retro` | Grade predictions, close the learning loop |
| `/rhino` | Status dashboard |

### Ship

| Command | What it does |
|---------|-------------|
| `/ship` | Commit, push, deploy, GitHub releases |
| `/onboard` | Bootstrap rhino-os into any repo |
| `/clone <url>` | Screenshot a site, decompose into components |
| `/skill [create]` | Create and manage measured skills |

### Terminal (CLI)

| Command | What it does |
|---------|-------------|
| `rhino score .` | The score. Assertion pass rate, per-feature breakdown. |
| `rhino eval .` | Run assertions from the terminal. |
| `rhino taste` | Visual eval (Claude Vision, expensive). |
| `rhino feature` | List all features with pass rates. |
| `rhino feature detect` | Auto-detect features from your codebase. |
| `rhino todo` | Backlog management (show, add, done, promote). |
| `rhino trail` | Evidence trail — session arc over time. |
| `rhino init` | Bootstrap rhino-os into any repo. |
| `rhino update` | Pull latest + refresh symlinks. |
| `rhino doctor` | Verify install health (symlinks, deps). |
| `rhino self` | Self-diagnostic (4-system health check). |
| `rhino bench` | Calibration check against fixture repos. |
| `rhino status` | System health overview. |
| `rhino config` | Show configuration. |
| `rhino plan` | View/manage build plan. |

A typical session: `/plan auth` -> `/go auth` -> `/plan` next time.

---

## The Learning System

Every action has a prediction. Wrong predictions update the model. Over sessions, Claude gets better at knowing what works for *your* product.

- **Predictions** (`~/.claude/knowledge/predictions.tsv`) — logged with evidence, auto-graded by `grade.sh`
- **Knowledge model** (`~/.claude/knowledge/experiment-learnings.md`) — known patterns, uncertain patterns, unknown territory, dead ends
- **Assertions** (`beliefs.yml`) — the definition of done, enforced mechanically
- **Session trail** (`rhino trail`) — persistent evidence of improvement across sessions

The predict -> measure -> update loop runs automatically. Target prediction accuracy: 50-70% (well-calibrated). Too high means predictions are too safe. Too low means the model is broken.

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

## Agents

6 custom agents that work inside Claude Code sessions:

| Agent | Role |
|-------|------|
| **builder** | Writes code. Full editing capability. Used by `/go`. |
| **explorer** | Researches unknowns, pulls docs, analyzes sites. Read-only. |
| **measurer** | Runs score, eval, taste. Read-only. Honest measurement. |
| **reviewer** | Post-build quality review against product standards. Read-only. |
| **evaluator** | Evaluates product quality with structured rubrics. |
| **market-analyst** | Competitive analysis and market research. |

Agents are spawned by commands when needed. `/go` uses builder + measurer. `/research` uses explorer + market-analyst. `/eval` uses evaluator.

---

## Hooks

9 lifecycle hooks that fire automatically during Claude Code sessions:

| Hook | When | What it does |
|------|------|-------------|
| `session_start.sh` | Session begins | Boot card with score, signals, learning status |
| `pre_compact.sh` | Before context compression | Saves recovery context so Claude rebuilds its model |
| `post_edit.sh` | After file edits | Write-time quality checks |
| `post_skill.sh` | After skill runs | YAML validation for plan files |
| `post_commit.sh` | After git commit | Post-commit checks |
| `pre_commit_check.sh` | Before commit | Pre-commit validation |
| `stop.sh` | Session ends | Cleanup and session logging |
| `subagent_stop.sh` | Agent completes | Agent output processing |

---

## Skills

20 skills that Claude loads automatically when relevant:

**Core:** `rhino-mind` (identity + thinking + standards + self-model), `product-lens` (product measurement + UX checklist)

**Commands (user-invoked):** `plan`, `go`, `eval`, `feature`, `todo`, `assert`, `product`, `ideate`, `research`, `strategy`, `roadmap`, `retro`, `rhino`, `ship`, `onboard`, `clone`, `skill`, `calibrate`

Skills use the [Agent Skills](https://claude.com/blog/skills) format — the same `SKILL.md` files work in Claude Code, Cursor, Codex CLI, and Gemini CLI.

---

## Product Lens

The product lens (`lens/product/`) adds web-product-specific measurement:

- **taste.mjs** — Claude Vision visual eval across 11 dimensions
- **beliefs.yml** — product-specific assertions
- **scoring/** — web structure checks (dead ends, empty states, IA audit)
- **corpus/** — taste reference database for calibrated scoring
- **mind/** — product-eyes.md (measurement stack), product-self.md (unknowns), product-standards.md (UX checklist)

Install other lenses by dropping directories into `lens/`. Each lens provides its own config, commands, scoring extensions, and mind files.

---

## File Tree

```
rhino-os/
  .claude-plugin/            plugin manifest
    plugin.json              name, version, description
    marketplace.json         marketplace listing
  skills/                    20 skills (auto-triggered + user-invoked)
    rhino-mind/SKILL.md      core operating model
    product-lens/SKILL.md    product measurement
    plan/SKILL.md            bottleneck finding + task writing
    go/SKILL.md              autonomous build loop
    eval/SKILL.md            assertion runner + sub-scores
    ...                      (17 more)
  commands/                  slash command definitions (*.md)
  agents/                    6 custom agents
    builder.md               writes code (used by /go)
    explorer.md              researches unknowns (used by /research)
    measurer.md              runs evals (used by /go, /eval)
    reviewer.md              post-build quality review
    evaluator.md             structured rubric evaluation
    market-analyst.md        competitive analysis
  mind/                      identity + reasoning (source of truth)
    identity.md              cofounder behavior
    thinking.md              predict -> measure -> update model
    standards.md             what quality means (value > craft > health)
    self.md                  self-model (capabilities, weaknesses, calibration)
  bin/                       CLI tools
    rhino                    CLI entrypoint (v8.0.3)
    score.sh                 THE score (assertion pass rate, health gate)
    eval.sh                  assertion runner + generative eval
    grade.sh                 prediction auto-grading + knowledge consolidation
    trail.sh                 session evidence trail
    feature.sh               feature management (list, detect, view)
    todo.sh                  backlog management
    plan.sh                  build plan management
    init.sh                  bootstrap rhino-os into any repo
    self.sh                  4-system self-diagnostic
    bench.sh                 calibration check against fixtures
    skill.sh                 skill management
    data.sh                  data utilities
    serve.mjs                dev server for eval
    lib/                     shared libraries (config.sh)
  config/
    rhino.yml                tunables, value hypothesis, features, signals
  hooks/                     9 lifecycle hooks
    hooks.json               declarative hook config (for plugin system)
    run-hook.cmd             polyglot hook launcher (Unix + Windows)
    session_start.sh         boot card on session start
    pre_compact.sh           context recovery before compression
    post_edit.sh             write-time quality checks
    post_skill.sh            plan file validation
    post_commit.sh           post-commit checks
    pre_commit_check.sh      pre-commit validation
    stop.sh                  session cleanup
    subagent_stop.sh         agent output processing
  lens/product/              product development lens
    lens.yml                 lens manifest
    eval/beliefs.yml         product assertions
    eval/taste.mjs           visual eval engine (11 dimensions)
    scoring/                 web-specific structure/hygiene extensions
    corpus/                  taste reference database
    mind/                    product-eyes, product-self, product-standards
  tests/                     mechanical tests + fixture repos
    fixtures/                healthy, decent, mediocre test projects
  install.sh                 symlink installer
  uninstall.sh               clean removal
```

---

## How Versions Work

Versions are theses, not releases. Each one asks a question. It gets proven, disproven, or abandoned.

| Version | Thesis | Status |
|---------|--------|--------|
| v6.0 | Identity + measurement > prescribed workflows | Proven |
| v7.0 | Score measures value, not health | Proven |
| v7.1 | Every workflow needs a command | Proven |
| v7.2 | The loop works on itself | Proven |
| v8.0 | Someone who isn't us can complete a loop | Proven |
| v8.1 | Every skill measured, every agent produces work | Proven |
| v9.0 | Plugin marketplace distribution | Future |

Future versions emerge from evidence. `/roadmap` tracks the arc.

---

## Inspired By

- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — autonomous research loops
- [SWE-bench](https://www.swebench.com/) — task-resolution benchmarks for code agents
- [Octalysis](https://yukaichou.com/gamification-examples/octalysis-complete-gamification-framework/) — motivation architecture framework
- [DORA metrics](https://dora.dev/) — throughput, failure rate, lead time, recovery

---

## License

[MIT](LICENSE)
