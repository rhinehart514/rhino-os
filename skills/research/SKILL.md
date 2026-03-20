---
name: research
description: "Use when the user needs evidence before making a decision — filling knowledge gaps, investigating unknowns, library docs, live site analysis, or competitive intel. Triggers on 'research', 'what do we know about', 'explore', 'docs for [lib]', 'analyze [url]'."
argument-hint: "[feature|docs <lib>|site <url>|competitor <name>|market|history|gaps|\"topic\"]"
allowed-tools: Read, Bash, Grep, Glob, Agent, WebSearch, WebFetch
---

# /research

A cofounder filling gaps in the knowledge model so the next build session is smarter.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/knowledge-gaps.sh` — scans experiment-learnings.md, counts unknowns, ranks by bottleneck relevance
- `scripts/research-log.sh` — persistent research history (add, stats, repeats, topic search). Uses `${CLAUDE_PLUGIN_DATA}`.
- `scripts/source-quality.sh` — rates sources by reliability tier (T1-T5). Run `tiers` for the hierarchy.
- `scripts/market-scan.sh` — structured competitor/market data. Outputs JSON for market-context.json.
- `references/research-methods.md` — when to use WebSearch vs context7 vs Playwright vs codebase. Signal vs noise.
- `references/evidence-hierarchy.md` — ranking evidence types (user behavior > statements > market > desk research > intuition)
- `templates/research-brief.md` — template for research output (findings, confidence, unknowns resolved)
- `templates/market-context.json` — schema for market-context.json so research outputs are structured
- `reference.md` — output formatting templates, multi-source protocol, research artifact format
- `gotchas.md` — real failure modes. **Read before every session.**

## Routing

Parse `$ARGUMENTS`:

| Input | Mode | Primary tools |
|-------|------|---------------|
| (none) | Top unknown | Run `scripts/knowledge-gaps.sh` first |
| `[feature]` | Feature deep-dive | Grep/Glob + context7 + WebSearch |
| `"topic"` | Free-form | WebSearch + WebFetch + context7 |
| `docs <library>` | Library docs | context7 (resolve-library-id -> query-docs) |
| `site <url>` | Live site analysis | Playwright (navigate, snapshot, evaluate) |
| `competitor <name>` | Competitive analysis | WebSearch + Playwright + `scripts/market-scan.sh` |
| `market` | Market landscape | Spawns market-analyst agent + `scripts/market-scan.sh` |
| `history` | Past sessions | `scripts/research-log.sh` |
| `gaps` | Ranked unknowns | `scripts/knowledge-gaps.sh` |

**Ambiguous input:** exact keyword match wins -> feature name match -> free-form topic. Never ask "did you mean?" — just act.

## When to use

Use `/research` when you need evidence before making a decision — filling knowledge gaps, investigating unknowns, or gathering competitive intel. Use `/ideate` instead when you already have enough evidence and need ideas for what to build. Use `/product` when the question is "should this exist?" rather than "how should it work?" Use `/strategy` when the question is about positioning, not information gathering.

## The protocol

### Step 0: Read gotchas + check history
Read `gotchas.md`. Run `scripts/research-log.sh topic "[topic]"` to check for repeat research. Read `config/product-spec.yml` if it exists — research should resolve unknowns in the spec. Spec questions > random curiosity.

### Step 1: Predict
```
I predict: [specific outcome]
Because: [evidence or "exploring unknown territory"]
I'd be wrong if: [what would surprise me]
```
Log to `.claude/knowledge/predictions.tsv`.

### Step 2: Investigate
Use tools based on route. Read `references/research-methods.md` for tool selection. Rate sources via `scripts/source-quality.sh`. Run multiple sources in parallel where possible.

### Step 3: Synthesize
Don't dump raw findings. Structure output using `templates/research-brief.md`. Every 5 findings, pause and write the pattern.

### Step 4: Update model
Write findings to `.claude/knowledge/experiment-learnings.md`. Grade prediction.

### Step 5: Write artifacts
- `~/.claude/cache/last-research.yml` — for /plan to read (format in `reference.md`)
- `scripts/research-log.sh add "[topic]" "[route]" [count] "[key finding]" "[confidence]"`

### Step 6: Task generation — the path from knowledge to action

See `../shared/task-generation.md` for the task generation protocol. /research generates tasks for:

**For EVERY finding, generate the corresponding tasks:**

#### Evidence-implies-action tasks
- Finding confirms a hypothesis → task: "Evidence confirms [X] — update strategy.yml and act on it"
- Finding contradicts a hypothesis → task: "Evidence contradicts [X] — update experiment-learnings.md, reconsider approach"
- Finding reveals a competitor capability → task: "Competitor [Y] does [Z] — evaluate: build, differentiate, or ignore"
- Finding reveals market shift → task: "Market moving toward [X] — update strategy via /strategy market"
- Finding reveals user need → task: "Users need [X] — evaluate as feature via /ideate"

#### Knowledge model tasks
- Each new unknown discovered → task: "New unknown: [X] — run /research [topic] to investigate"
- Each dead end confirmed → task: "Dead end confirmed: [X] — kill related todos and update learnings"
- Each uncertain pattern that could be confirmed → task: "Pattern [X] needs one more experiment — design test"
- Stale knowledge entry touched by research → task: "Knowledge entry [X] updated — retest downstream assumptions"

#### Strategy update tasks
- Research changes the competitive picture → task: "Update market-context.json with [finding]"
- Research changes the stage assessment → task: "Run /strategy honest — stage may have shifted"
- Research reveals pricing signal → task: "Competitor charges [X] — run /money price"

#### Feature impact tasks
- Finding affects a specific feature → task: "Research on [topic] affects feature [Y] — update approach"
- Finding suggests a new feature → task: "Evidence for [X] — evaluate via /ideate or /feature new"
- Finding invalidates a feature → task: "Evidence against feature [X] — consider killing via /ideate kill"

Tag with `source: /research`, topic, and confidence level. Priority: high-confidence findings on high-weight features first.

## Agent spawning
- `Agent(subagent_type: "rhino-os:explorer", ...)` — deep codebase analysis
- `Agent(subagent_type: "rhino-os:market-analyst", ...)` — market and competitor routes
- Spawn both in parallel when research spans codebase AND market

## State artifacts

| Artifact | Path | R/W |
|----------|------|-----|
| research-log | `${CLAUDE_PLUGIN_DATA}/research-log.json` | R+W |
| experiment-learnings | `.claude/knowledge/experiment-learnings.md` | R+W |
| predictions | `.claude/knowledge/predictions.tsv` | R+W |
| last-research | `~/.claude/cache/last-research.yml` | W |
| eval-cache | `.claude/cache/eval-cache.json` | R |
| market-context | `.claude/cache/market-context.json` | R+W |
| rhino.yml | `config/rhino.yml` | R |
| product-spec | `config/product-spec.yml` | R |
| todos | `.claude/plans/todos.yml` | W |

## Output format

- Header: `◆ research — [topic]`
- State bar: `v[X.Y]: **[pct]%** · product: **[pct]%** · score: [N]`
- Section markers: ▾ ▸ · ✓ ✗ ⚠
- Bottom: exactly 3 next commands
- Dense, no preamble, no trailing summaries

For full output templates, see `reference.md`.

## Self-evaluation

/research succeeded if:
- A prediction was logged before investigating
- Findings are synthesized (patterns named, not raw dumps)
- experiment-learnings.md was updated with at least one new or modified entry
- research-log.sh was called to persist the session
- Every finding that implies action has a corresponding task

## Gotchas

- **context7 for `/research docs`**: The primary path is context7 MCP (resolve-library-id then query-docs). If context7 is unavailable or returns empty, fall back to WebSearch + WebFetch for the library's official docs site. Do not guess at APIs — either cite docs or declare unknown territory.
- **Repeat research**: Always run `research-log.sh topic "[topic]"` first. If the same topic was researched in the last 7 days, state what changed since then or skip.
- **Market research depth trap**: WebSearch returns surface-level results. For competitive intel, spawn the market-analyst agent rather than doing 10+ WebSearch queries inline.
- **Source quality matters**: Run `scripts/source-quality.sh` to rate sources. T4-T5 sources (blog posts, forum comments) need corroboration from T1-T2 sources (official docs, primary research).

## Cost note

Spawns up to 2 agents depending on mode:
- `explorer` (sonnet) — codebase analysis for feature deep-dives
- `market-analyst` (opus, background) — market and competitor routes
- `docs` and `site` modes are agent-free (use context7 and Playwright directly).

## What you never do
- Research without a prediction
- Dump raw results without synthesis
- Skip the model update
- Skip the research log write
- Use WebSearch for library docs when context7 is available
- Research known territory without declaring why you're re-investigating

## If something breaks
- context7 fails -> WebSearch + WebFetch for docs
- Playwright fails -> WebSearch for site analysis
- WebSearch fails -> codebase-only + experiment-learnings.md
- No experiment-learnings.md -> create with standard template
- No research-log.json -> `scripts/research-log.sh` auto-creates

$ARGUMENTS
