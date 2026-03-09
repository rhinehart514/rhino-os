# rhino-os

A knowledge-compounding strategy engine for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Built for solo technical founders who need strategic clarity, not more workflow automation.

```
5 Agents  ·  3 Intelligence Layers  ·  Self-Enforcing Feedback Loops  ·  1 CLI
Thick-skinned. Charges forward. Kills what isn't working.
```

**System status:** 5/5 agents operational · rhino score 95/100 · 3 meta cycles completed · all feedback loops connected

[Overview](docs/index.html) · [Architecture](docs/architecture.html) · [Scoring](docs/scoring.html) · [Graphs](docs/graphs.html) · [Agent System](docs/agents.html)

## What is this?

The Claude Code ecosystem has 40+ workflow orchestrators, 100+ agent collections, and 349+ skills. All commodity. rhino-os doesn't compete there.

rhino-os is a **strategic operating system** that layers on top of Claude Code. It does three things no other system does:

1. **Portfolio intelligence** — Evaluates your entire project landscape with Buy/Sell/Hold verdicts, kill criteria, and focus prescriptions. Not project-level cheerleading — portfolio-level hard calls.
2. **Landscape positions** — Maintains opinionated strategic beliefs (not trend lists) that agents reason FROM. "AI wrappers are dead" isn't a trend — it's a position with evidence and implications that shapes every recommendation.
3. **Taste learning** — Observes your decisions over time and builds a preference profile. Every agent reads it before acting. By week four, agents know your judgment patterns.

The builder and design-engineer agents are just hands. The intelligence layers are the brain.

## Who is this for?

Solo technical founders running 1-3 projects who use Claude Code daily. You're building fast, juggling priorities, and need a system that:

- Tells you what to kill (not just what to build)
- Remembers your preferences across sessions
- Maintains strategic context between conversations
- Gets sharper the more you use it

If you're on a team, use something else. If you want a prettier CLI, use something else. If you want more agents and skills, there are 349 other options.

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated (OAuth — no API key needed)
- macOS or Linux (macOS for LaunchAgent automation)
- Node.js 18+ (for taste visual eval)
- `jq` recommended (`brew install jq`) for `rhino status` details

## Setup

```bash
git clone https://github.com/laneyfraass/rhino-os.git ~/rhino-os
cd ~/rhino-os
./install.sh
```

The installer is idempotent (safe to re-run). It:

1. Symlinks agents, skills, rules, and hooks into `~/.claude/`
2. Merges `settings.json` and `config.json` (preserves your existing config)
3. Seeds knowledge directories from templates
4. Copies `landscape.json` to `~/.claude/knowledge/` (won't overwrite existing)
5. Links the `rhino` CLI to `~/bin/rhino`
6. Optionally installs macOS LaunchAgents for scheduled sweep/scout

```bash
# Skip LaunchAgents (e.g., on Linux):
./install.sh --no-launchd

# Verify everything:
rhino status
```

After install, edit `~/.claude/CLAUDE.md` with your identity and project info.

## Usage

### CLI Commands — 12 commands, 3 groups

```bash
# Agents (run specialized Claude sessions)
rhino sweep                  # Daily triage — what needs attention?
rhino scout                  # Update landscape positions from market signals
rhino build                  # Auto-detects mode (gate → plan → build → experiment)
rhino build "implement task 3"   # Build a specific task
rhino strategy               # Portfolio evaluation — Buy/Sell/Hold verdicts
rhino design                 # Auto-detect design mode (audit/review/build)

# Inspect (cheap, fast, local)
rhino status                 # System health, knowledge freshness, intelligence stats
rhino score [dir]            # Structural lint score (training loss)
rhino dashboard [dir]        # Per-project dashboard (--html for visual)

# Operate (on-demand tools)
rhino taste [dir]            # Visual product eval with Claude vision (eval loss)
rhino visuals [dir]          # Generate GitHub badges from score
rhino init [dir]             # Initialize rhino in a project
rhino meta                   # Self-evaluation — rhino grades its own agents
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `RHINO_BUDGET` | per-agent defaults | Override Claude budget cap (e.g., `RHINO_BUDGET=5.00 rhino scout`) |

### First Run

1. `rhino status` — verify installation
2. `rhino strategy` — the strategist will auto-discover projects in `~/` with `.git` directories and populate your portfolio
3. Review the Buy/Sell/Hold verdicts. Update project stages and user counts as needed.
4. `rhino scout` — populates landscape positions with market intelligence
5. Start building: `rhino build`

## The Three Intelligence Layers

### Portfolio Model (`~/.claude/knowledge/portfolio.json`)

Structured JSON tracking every project, every feature, every kill criterion. The strategist reads the entire portfolio before making any recommendation.

Kill criteria are checked automatically: "No real user need in 30 days", "Can't name one person who'd pay", "Core loop incomplete for >2 months".

### Landscape Positions (`~/.claude/knowledge/landscape.json`)

Opinionated beliefs about what works right now. Not trends — positions with evidence and implications that every agent reasons from.

```
[STRONG] "AI wrappers are dead — the wedge is proprietary data + workflow"
  Implications: Any product wrapping Claude/GPT API is on borrowed time

[STRONG] "Solo founders win on context engineering + distribution, not product quality"
  Implications: Stop polishing. Focus on reaching users.
```

Scout maintains these. Strategist reasons from them. Every recommendation references a position.

### Taste Signals (`~/.claude/knowledge/taste.jsonl`)

Observations about your preferences, recorded as agents watch you work. Duplicate signals get deduplicated with strength promotion (weak → moderate → strong).

```
[product]   "Rejects onboarding flows — wants users dropped into value immediately"   [strong]
[design]    "Prefers dense data layouts over whitespace"                               [moderate]
[strategy]  "Kills features aggressively when no user signal exists"                   [moderate]
```

Every agent reads taste before acting. The design-engineer uses it instead of generic design rubrics. The builder respects your technical preferences.

## Two-Tier Scoring

```
rhino score .     = training loss (cheap, every commit, structural lint)
rhino taste .     = eval loss (expensive, on demand, Claude vision)
```

**Score** measures what grep can honestly measure: build health, structure, hygiene. Fast, free, runs every commit.

**Taste** measures what only looking can measure: hierarchy, contrast, polish, emotional tone, distinctiveness. Expensive (~1 Claude call), runs on demand. Market-aware — reads landscape positions and founder preferences before judging.

Both feed into `rhino dashboard`. Track the gap between them like training loss vs eval loss.

## Architecture

```
~/.claude/
├── agents/              # Symlinked agent definitions
│   ├── strategist.md    # Portfolio strategy, Buy/Sell/Hold
│   ├── builder.md       # Gate → Plan → Build → Experiment
│   ├── design-engineer.md # Visual eval, design systems
│   ├── scout.md         # Market intelligence, landscape maintenance
│   ├── sweep.md         # Daily triage, system health
│   └── meta.md          # Self-evaluation, agent quality grading
├── skills/              # User-invocable skills
│   ├── eval/            # Ship-readiness checks
│   ├── smart-commit/    # Conventional commits tied to plans
│   ├── experiment/      # Autonomous iteration loop
│   └── product-2026/    # Product strategy reasoning
├── rules/               # Always-on coding rules
│   ├── quality-bar.md
│   └── product-reasoning.md
├── hooks/               # Event-driven automation
│   ├── enforce_ideation_readonly.sh  # Blocks edits during ideation
│   ├── session_context.sh           # Injects eval state at session start
│   └── track_usage.sh               # Tool call logging
├── knowledge/           # Intelligence layer data (gitignored)
│   ├── portfolio.json   # Project portfolio model
│   ├── landscape.json   # Strategic positions
│   ├── taste.jsonl      # Preference signals
│   └── {agent}/         # Per-agent knowledge
├── programs/            # Detailed program instructions
│   ├── build.md         # Builder's brain
│   ├── strategy.md      # Strategist's brain
│   └── meta.md          # Meta-evaluator's brain
├── state/               # Inter-agent operational state
└── logs/                # Session and usage logs

~/rhino-os/              # Source repo
├── agents/              # Agent definitions (symlinked to ~/.claude/agents/)
├── programs/            # Program instructions (symlinked to ~/.claude/programs/)
├── bin/
│   ├── rhino            # CLI (12 commands)
│   ├── score.sh         # Structural lint scorer
│   ├── taste.mjs        # Visual product evaluator
│   └── gen-dashboard.sh # HTML dashboard generator
├── install.sh           # Idempotent installer
└── uninstall.sh         # Clean removal
```

### How agents communicate

Agents share state through the filesystem, not direct calls:

- **State files** in `~/.claude/state/` pass operational context (e.g., sweep writes `sweep-latest.md`, builder reads it)
- **Knowledge files** in `~/.claude/knowledge/{agent}/` accumulate per-agent learnings
- **Agent markdown** is injected as system prompt via `--system-prompt` when `rhino` runs an agent

This means agents work asynchronously. The sweep runs, writes state, and the strategist picks it up on the next run.

### Self-enforcing feedback loops

The system detects and fixes its own failures:

```
Agent runs → verify_artifacts() checks required outputs →
  ✓ artifacts exist → normal operation
  ✗ artifacts missing → logged to artifact-failures.jsonl →
    catchup() triggers meta within 48h →
      meta reads failures → fixes the agent prompt → clears the log
```

**Three layers prevent silent agent death:**
1. **Immediate:** `verify_artifacts()` prints a warning right after an agent runs
2. **Passive:** `catchup()` checks on every `rhino` CLI invocation — triggers meta if failures pile up
3. **Scheduled:** Meta LaunchAgent runs weekly as a floor

Each agent has **mandatory artifact requirements** — if it runs but doesn't write its outputs, meta grades it F and fixes the prompt. Agents that parrot other agents' conclusions instead of running their own checks get downgraded.

### Agent grades (meta cycle 3)

| Agent | Grade | What it produces | Key check |
|-------|-------|-----------------|-----------|
| **Sweep** | A- | `sweep-latest.md` with GREEN/YELLOW/RED/GRAY classification | Verifies all agent artifacts exist |
| **Scout** | A- | Updated `landscape.json` positions with evidence | "What I Didn't Find" must be longest section |
| **Builder** | A | Experiments, code changes, score deltas | Gate mode must run `rhino score`, produce checklist |
| **Design** | A- | `audit-history.jsonl`, design system docs | Must validate target value, take screenshots |
| **Strategist** | A- | `portfolio.json`, sprint plan + symlink | Must scan filesystem, write plan file |

### AI eval spec

The system includes a formal eval spec at `.claude/evals/agent-system-health.yml` with three tiers:

- **Deterministic** — syntax checks, artifact existence, config loads (automated, pass/fail)
- **Functional** — sweep uses all 4 tiers, builder runs score, scout unknowns exceed confirmations (AI-checked)
- **Ceiling** — meta fix improves target grade, scout changes a decision, dead agents auto-detected (human-judged)

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `enforce_ideation_readonly.sh` | PreToolUse (Edit/Write/Bash) | Blocks file edits during ideation/gate mode |
| `session_context.sh` | PreToolUse | Injects eval verdict + gaps + active plan at session start |
| `track_usage.sh` | PostToolUse (all) | Logs every tool call to `usage.jsonl` |

## Uninstall

```bash
cd ~/rhino-os
./uninstall.sh
```

Removes symlinks and LaunchAgents. Your knowledge files in `~/.claude/knowledge/` are preserved (delete manually if desired).

## Honest Limitations

**The taste system requires sessions to compound.** It starts empty. First week is generic. By week four, agents know your judgment patterns.

**Portfolio evaluation is only as good as the data.** You need to populate the portfolio with your actual projects. The strategist can auto-discover projects in `~/`, but you need to confirm stages and user counts.

**Landscape positions are opinionated and sometimes wrong.** That's the point — they're positions, not facts. Scout revises them when evidence changes.

**Budget caps are real.** The `rhino` CLI passes `--max-budget-usd` to Claude. Default is $2.00 for most agents. Override with `RHINO_BUDGET`.

**Knowledge files are gitignored.** They live in `~/.claude/knowledge/`, not in the repo.

**This is a solo founder tool.** It assumes one person making all decisions. Team dynamics, code review workflows, and multi-person taste profiles are not supported.

## Credits

Informed by [PAHF](https://arxiv.org/abs/2602.16173) (preference learning from feedback), [compound engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents) (knowledge loops), and [HBR portfolio management](https://hbr.org/2026/01/manage-your-ai-investments-like-a-portfolio) (Buy/Sell/Hold for AI investments).

## License

MIT
