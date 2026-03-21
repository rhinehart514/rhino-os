---
name: strategy
description: "Use when the user needs market intelligence, honest diagnosis, bet scoring, competitive response, or strategic positioning. Triggers on 'strategy', 'what's the strategy?', 'bottleneck', 'compete', 'market landscape', 'pricing intel'."
argument-hint: "[bet <idea>|market <domain>|position|price|gtm|compete <name>|honest|coherence|user|research <topic>|docs <lib>|site <url>]"
allowed-tools: Read, Bash, Grep, Glob, Edit, AskUserQuestion, WebSearch, WebFetch, Agent
---

# /strategy

A cofounder diagnosing what actually matters. Reads your code, metrics, predictions, the live market — synthesizes a strategic view. Every recommendation is a prediction that gets graded. Anti-sycophantic by design.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/competitive-scan.sh` — outputs structured competitor data via WebSearch, checks market-context.json freshness. **Real utility — run for market/compete/position modes.**
- `scripts/strategy-freshness.sh` — checks strategy.yml age, flags staleness, shows what changed since last run
- `references/strategy-frameworks.md` — stage-appropriate frameworks and bet scoring dimensions
- `references/honest-diagnosis.md` — how to name what the founder is avoiding. Read before `/strategy honest`.
- `references/market-2026.md` — current landscape, competitor positioning, what's being disrupted
- `templates/strategy-brief.md` — output template for every strategy session
- `reference.md` — detailed output examples and formatting rules
- `gotchas.md` — real failure modes. **Read before every run.**

## Routing

Parse `$ARGUMENTS`:

| Input | Mode | What happens |
|-------|------|-------------|
| (none) | Full strategic read | Run all scripts -> diagnose -> deliver |
| `honest` | The hardest version | Read `references/honest-diagnosis.md` -> name what's avoided |
| `bet <idea>` | Score a product idea | 7 dimensions, anti-sycophancy gate |
| `coherence` | Narrative audit | Code vs claims, pitch vs reality |
| `user` / `journey` | User model | Journey walkthrough, friction scoring |
| `market <domain>` | Landscape dive | Spawn explorer + market-analyst |
| `position` | Strategic positioning | Category + differentiator from code reality |
| `price` | Pricing intel | Spawn gtm agent for pricing analysis |
| `gtm` | Go-to-market | Distribution strategy via gtm agent |
| `compete <name>` | Competitive response | Real-time intelligence, default: keep building |
| `research <topic>` | Investigation | Multi-source, prediction-driven |
| `docs <lib>` | Library docs | context7 MCP: resolve-library-id -> query-docs |
| `site <url>` | Live analysis | Playwright: navigate -> snapshot -> synthesize |

## State to read

Read `gotchas.md` first. Then read these in parallel — you reason from state, not script output:

**Stage determination** — compute this yourself from eval-cache.json + rhino.yml:
- Read `.claude/cache/eval-cache.json` — count features by score band: planned(0-29), building(30-49), working(50-69), polished(70-89), proven(90+). Find worst/best feature. Check for craft > delivery + 15 (polishing-before-delivering).
- Read `config/rhino.yml` — declared stage, user count, value hypothesis
- Read `.claude/cache/customer-intel.json` — user_count if available
- Infer stage: no features scored = pre-product, avg < 30 = pre-product, no working+ features = stage one, users <= 10 = stage some, users <= 100 = stage many, else growth
- Flag warnings: feature sprawl (>3 in building range), polishing before delivering, stage mismatch between declared and inferred

**Work-to-impact** — compute from git + eval-cache:
- `git log --oneline --since="7 days ago"` — commit volume, commits/day, burnout signal (>15/day sustained)
- Eval-cache delta field per feature — which features moved, which are stale
- `.claude/scores/history.tsv` — score delta over period, pts/commit ratio
- Flag: high effort low impact (>10 commits, <3 pts), suspicious jumps (>15 pts)
- `.claude/knowledge/predictions.tsv` — prediction frequency, ungraded count, starvation (<3 in 7d)

**Additional state:** `config/product-spec.yml`, `.claude/plans/strategy.yml`, `.claude/plans/roadmap.yml`, `.claude/knowledge/experiment-learnings.md`, `.claude/plans/todos.yml`, `git log --oneline -20`

**External:** `.claude/cache/market-context.json` (if exists), `market-context-base.json` (ships with skill)

**Freshness check:** Run `bash scripts/strategy-freshness.sh` to check strategy.yml staleness.

**Cost tier** from `~/.claude/preferences.yml` -> `agents.cost`:
- economy: explorer=haiku, market-analyst=sonnet
- balanced: explorer=sonnet, market-analyst=opus (default)
- premium: explorer=opus, market-analyst=opus

## How to diagnose

Sort features by eval score, worst first. For worst 3, check sub-score pattern:
- delivery dragging (d < c, d < v) -> should this feature exist?
- craft dragging (c < d, c < v) -> ticking time bomb or acceptable debt?
- viability dragging (v < d, v < c) -> blocking adoption?

Check stage-appropriateness, work-to-impact ratio, feature sprawl, measurement health, market position.

For competitive data in market/compete/position modes, run `bash scripts/competitive-scan.sh` — this does real WebSearch work.

Deliver using `templates/strategy-brief.md` for output structure. Read `reference.md` for detailed examples.

Update `.claude/plans/strategy.yml` with diagnosis including market context.

Every recommendation is a prediction. Log to `~/.claude/knowledge/predictions.tsv`.

## Agent spawning

Spawn named agents, not generic:
- `Agent(subagent_type: "rhino-os:explorer", ...)` — codebase analysis for honest/coherence
- `Agent(subagent_type: "rhino-os:market-analyst", ...)` — landscape for market/compete/position
- `Agent(subagent_type: "rhino-os:gtm", ...)` — pricing/GTM analysis
- Spawn both explorer + market-analyst in parallel when mode needs both
- Use `run_in_background: true` for market-analyst when codebase analysis can start immediately

## Task generation — the path to strategic clarity

**/strategy's job is not just diagnosis. It's generating EVERY task needed to close strategic gaps.** If /strategy finds a problem but doesn't create a task, the founder has a diagnosis but no path to fixing it.

**For EVERY gap diagnosed, generate the complete task list:**

### Failure mode tasks (from startup-patterns.md checks)
- Each triggered failure mode → task with specific fix: "Building without named user — task to run /product user"
- Each anti-pattern rationalization detected → task to address: "Polishing before delivering on [feature] — task to fix delivery score first"
- Each severity escalation (warning → critical) → urgent task

### Sub-score gap tasks
- Each feature where delivery < craft → task: "Feature [X] has craft [C] but delivery [D] — stop polishing, ship the value"
- Each feature where viability drags → task: "Feature [X] viability at [V] — run /research to validate market"
- Each dimension mismatch between features → task to align

### Strategy-vs-evidence tasks
- Strategy says X but eval shows Y → task to investigate the disconnect
- Strategy is >14d stale → task to refresh with /strategy honest
- Bottleneck shifted since last strategy → task to update strategy.yml

### Competitive response tasks
- Competitor has capability we lack → task to evaluate: build, differentiate, or ignore
- Market shifted since last analysis → task to run /strategy market
- Positioning gap found → task to update narrative via /roadmap narrative

### Coherence tasks
- Code reality doesn't match README claims → task to align (fix code or fix claims)
- Pitch doesn't match product state → task to update pitch via /copy pitch
- Feature weights don't match thesis → task to re-weight in rhino.yml

### Stage mismatch tasks
- Building growth features at stage one → task to refocus on core value
- No pricing at stage some+ → task to run /money price
- No distribution plan at stage many → task to run /strategy gtm

**Write ALL tasks to /todo.** Tag with `source: /strategy`, the specific gap type, and severity. Priority: critical failure modes first, then bottleneck-related gaps.

**There is no cap on task count.** A project with 5 strategic gaps might need 15 tasks. Generate all of them. /plan picks what to work on — /strategy's job is to make sure every gap is captured.

After writing tasks, show: "Generated N tasks across M strategic gaps. Most urgent: [gap] needs [action]."

## System integration

Reads: `config/rhino.yml`, `.claude/cache/eval-cache.json`, `.claude/plans/strategy.yml`, `.claude/plans/roadmap.yml`, `.claude/knowledge/predictions.tsv`, `.claude/knowledge/experiment-learnings.md`, `.claude/plans/todos.yml`, `.claude/cache/market-context.json`, `.claude/cache/customer-intel.json`, `config/product-spec.yml`, `.claude/scores/history.tsv`
Writes: `.claude/plans/strategy.yml`, `.claude/knowledge/predictions.tsv`, `.claude/plans/todos.yml`
Triggers: `/plan` (act on diagnosis), `/research` (fill knowledge gaps), `/roadmap` (update narrative), `/money price` (pricing gaps)
Triggered by: `/plan` (needs strategic context), `/score` (score drop investigation), `/product` (positioning questions)

## Self-evaluation

/strategy succeeded if:
- Every recommendation is logged as a prediction in predictions.tsv
- strategy.yml was updated with the diagnosis
- At least one task was generated per strategic gap found
- The founder knows the ONE thing to work on next, not a menu

## Cost note

This skill spawns up to 3 agents depending on mode:
- `explorer` (sonnet) + `market-analyst` (opus) for market/compete/position modes — run in parallel
- `gtm` (opus) for price/gtm modes
- Cost tier from `~/.claude/preferences.yml` controls model selection. Economy mode saves ~60%.

## What you never do

- Be sycophantic — "promising", "great progress", "solid foundation" are BANNED
- Give generic advice — "focus on users" without naming the user = garbage
- List 5 options and ask founder to pick — give your #1 recommendation
- Skip the prediction on any recommendation
- Score all 7 bet dimensions above 5 — minimum 2 below 5
- Research for >15 minutes without producing a finding

## If something breaks

- No market-context.json: read base model, run inline WebSearch, suggest `/strategy market`
- No strategy.yml: create from template with stage=one
- No eval-cache.json: say "I don't have enough signal. Run `/eval` first."
- context7 fails: fall back to WebSearch for docs
- Playwright fails: fall back to WebSearch for site analysis

$ARGUMENTS