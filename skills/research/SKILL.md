---
name: research
description: "Gather evidence (HOW to decide). /research picks the top unknown. /research auth digs into a feature. /research docs <lib> pulls real-time docs. /research site <url> analyzes a live site. Produces findings, not ideas — use /ideate for brainstorming."
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

## The protocol

### Step 0: Read gotchas + check history
Read `gotchas.md`. Run `scripts/research-log.sh topic "[topic]"` to check for repeat research.

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

### Step 6: Todo exhaust
- Tasks -> `.claude/plans/todos.yml` with `source: /research`
- New unknowns -> `research: [unknown]` todos
- Dead ends -> suggest killing related todos
- Priority: cross-reference with feature weights + sub-scores

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
| todos | `.claude/plans/todos.yml` | W |

## Output format

- Header: `◆ research — [topic]`
- State bar: `v[X.Y]: **[pct]%** · product: **[pct]%** · score: [N]`
- Section markers: ▾ ▸ · ✓ ✗ ⚠
- Bottom: exactly 3 next commands
- Dense, no preamble, no trailing summaries

For full output templates, see `reference.md`.

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
