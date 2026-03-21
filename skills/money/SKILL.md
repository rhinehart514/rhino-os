---
name: money
description: "Use when the user needs pricing strategy, unit economics, runway analysis, or channel evaluation — evidence-grounded financial modeling"
argument-hint: "[price|runway|unit-economics|channels|model]"
allowed-tools: Read, Bash, Grep, Glob, WebSearch, WebFetch, Agent, AskUserQuestion
---

# /money

The business model in your terminal. Reads product state, market context, and customer signal to produce pricing, unit economics, channel strategy, and runway analysis grounded in evidence.

## Skill folder structure

This skill is a **folder**. Read these on demand:

- `scripts/revenue-scan.sh` — reads pricing config, calculates MRR/ARR estimates, runway
- `scripts/pricing-compare.sh` — outputs competitor pricing data from market-context.json
- `scripts/compare-pricing.sh` — compares rhino.yml pricing vs gtm analysis vs customer signals
- `scripts/runway-calc.sh [burn]` — quick breakeven calculator from gtm data
- `references/pricing-guide.md` — solo founder pricing rules, stage-appropriate pricing, common mistakes
- `references/unit-economics.md` — CAC/LTV/churn formulas with examples
- `references/pricing-strategies.md` — stage-by-stage pricing frameworks
- `references/channel-selection.md` — channel scoring rubric + prioritization
- `templates/pricing-model.md` — template for pricing analysis output
- `templates/runway-model.json` — 12-month projection template
- `templates/unit-economics.json` — CAC/LTV/payback template
- `reference.md` — output templates for all modes
- `gotchas.md` — financial modeling failure modes. **Read before any analysis.**

## Memory

If `${CLAUDE_PLUGIN_DATA}` is available, append to `money-history.json` to track pricing strategy evolution. If not available, skip history — the skill works without persistence.

## Routing

| Input | Mode |
|-------|------|
| (none) or `model` | Full business model — all sections |
| `price` | Pricing strategy + competitor analysis |
| `runway` | Runway modeling + breakeven analysis |
| `unit-economics` | CAC / LTV / payback calculation |
| `channels` | Channel evaluation and ranking |

## How it works

**Read product context:** Read `config/product-spec.yml` first — pricing should serve the spec's person. Fall back to `config/rhino.yml` if no product-spec exists. If neither exists, ask via AskUserQuestion: "Who is this for and what problem does it solve?" — pricing without a person is guessing.

**Mechanical scan:** Run `bash ${CLAUDE_SKILL_DIR}/scripts/revenue-scan.sh` for current financial state. For pricing modes, also run `bash ${CLAUDE_SKILL_DIR}/scripts/pricing-compare.sh`.

**Read gotchas + mode-specific reference:** `gotchas.md`, then price→`references/pricing-guide.md`, runway/unit-economics→`references/unit-economics.md`, channels→`references/channel-selection.md`, model→all references.

**Agent spawning** — proportional to the question:
- **Simple pricing questions** (e.g., "what should I charge?"): No agents. Use existing market-context.json + references. Present 1 recommendation with rationale.
- **Runway / unit-economics**: Spawn `rhino-os:gtm` only — needs financial modeling.
- **Full model / channels / deep pricing analysis**: Spawn both `rhino-os:gtm` and `rhino-os:market-analyst` when market-context.json is stale (>7d) or missing.

**Synthesize** — use `templates/pricing-model.md` for structure, present via AskUserQuestion with 2-3 options when decisions are needed.

**Persist** — write decisions to `config/rhino.yml` under `pricing:`. Append to money-history.json if `${CLAUDE_PLUGIN_DATA}` is available.

## System integration

Reads: `config/product-spec.yml` (primary), `config/rhino.yml` (fallback — features, stage, pricing), `.claude/cache/market-context.json`, `.claude/cache/customer-intel.json`, `.claude/cache/eval-cache.json` (feature maturity gate)
Writes: `config/rhino.yml` (pricing section), `${CLAUDE_PLUGIN_DATA}/money-history.json` (if available)
Triggers: `/strategy honest` (business viability), `/ship release` (if ready to charge), `/todo` (financial gap tasks)
Triggered by: `/strategy` (revenue avoidance detection), `/plan` (stage-appropriate nudge), manual

## Output format

See `reference.md` for mode-specific templates. Every output ends with:

```
/money [other mode]   explore another dimension
/strategy honest      check if this business makes sense
/ship release         if ready to charge
```

## Output

/money produces: 1 pricing recommendation + rationale + next step. Not a task backlog.

For each mode, end with:
- The recommendation (specific: "$19/mo per seat" not "consider charging")
- The rationale (grounded in evidence — competitor data, stage, value delivered)
- The next step (one command: `/money channels`, `/strategy honest`, etc.)

If the analysis surfaces a critical gap (e.g., no pricing at stage-some, negative unit economics), flag it as a single finding with a next step. Do not generate task lists — /plan handles that.

## Self-evaluation

The skill worked if:
- Every number has a cited source or is explicitly marked "estimate"
- Pricing recommendations are stage-appropriate (no unit economics at stage one)
- One clear recommendation with rationale was produced
- Decisions (when confirmed by founder) were written to rhino.yml pricing section

## Agent cost note

Agent spawning is proportional to the question:
- Simple pricing questions: 0 agents (use existing data + references)
- Runway / unit-economics: 1 agent (gtm only)
- Full model / channels / deep pricing: up to 2 agents (gtm + market-analyst) — skip market-analyst if market-context.json is fresh (<7d)

## Gotchas

- Financial projections are estimates, not forecasts. Every number the agents produce is bounded by the quality of inputs (which are often zero at stage one).
- GTM agent tends toward optimistic TAM -- cross-check with stage-appropriate expectations from `references/pricing-guide.md`.
- If no features score 50+, financial modeling is premature. The skill should flag this and redirect to building.
- `money-history.json` grows without pruning. Old pricing strategies may confuse the narrative if the product pivoted.

## What you never do

- Fabricate financial data — every number needs a source or is marked "estimate"
- Over-model — 3 scenarios max, 12 months max horizon
- Ignore stage — stage one needs one paying customer, not unit economics
- Make pricing decisions — present evidence, let founder decide
- Use vanity metrics — "market size" without path to capture is meaningless

## If something breaks

- No market-context.json: run WebSearch inline, suggest `/strategy market`
- No features scoring 50+: "No features mature enough for GTM. Build first."
- No pricing data from competitors: flag gap, use category benchmarks
- GTM agent fails: degrade to inline analysis with WebSearch

$ARGUMENTS
