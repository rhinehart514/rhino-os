---
name: money
description: "Use when you need financial modeling, pricing strategy, unit economics, or runway analysis. The business model in your terminal."
argument-hint: "[price|runway|unit-economics|channels|model]"
allowed-tools: Read, Bash, Grep, Glob, WebSearch, WebFetch, Agent, AskUserQuestion
---

!cat .claude/cache/gtm-strategy.json 2>/dev/null | jq '{pricing: .pricing.recommended_model, channels: (.channels[:2] | map(.name))}' 2>/dev/null || echo "no gtm cache"
!cat config/rhino.yml 2>/dev/null | grep -A3 'pricing:' || echo "no pricing in rhino.yml"

# /money

**The business model in your terminal.** Not a spreadsheet — a strategic tool that reads your product state, market context, and customer signal to produce pricing, unit economics, channel strategy, and runway analysis grounded in evidence.

## Skill contents

This skill is a folder with composable scripts, reference data, and templates:

```
skills/money/
  SKILL.md                            — this file (orchestrator)
  reference.md                        — output templates for all modes
  scripts/
    compare-pricing.sh                — compares rhino.yml pricing vs gtm analysis vs customer signals
    runway-calc.sh [burn]             — quick breakeven calculator from gtm data
  references/
    pricing-strategies.md             — stage-appropriate pricing frameworks (free vs paid, models, rules)
    channel-selection.md              — channel scoring rubric + solo founder prioritization
  templates/
    runway-model.json                 — 12-month projection template (fill and write to cache)
    unit-economics.json               — CAC/LTV/payback template
  gotchas.md                          — financial modeling failure modes for solo founders
```

**Use the scripts** for quick mechanical checks before agent analysis. Use the references for context during analysis. Use the templates as starting points for structured output.

## Memory

After every `/money` run, append to `.claude/cache/money-history.json`:

```json
{
  "entries": [
    {
      "date": "2026-03-17",
      "mode": "price",
      "recommendation": "subscription at $19/mo",
      "evidence_quality": "medium",
      "prediction_logged": true
    }
  ]
}
```

On subsequent runs, read history to track how pricing strategy has evolved. If the recommendation changed, explain why.

**When to use this vs other commands:**

| Command | Question |
|---------|----------|
| `/strategy price` | Quick pricing intelligence within a strategy session |
| `/money price` | Deep pricing analysis with competitor data and modeling |
| `/money runway` | How long until the money runs out / breaks even? |
| `/money channels` | Where do users come from? Ranked by evidence. |
| `/money model` | Full business model: pricing + economics + channels + runway |
| `/strategy gtm` | GTM playbook (spawns same gtm agent) |

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) or `model` | Full business model — all sections |
| `price` | Pricing strategy + competitor analysis |
| `runway` | Runway modeling + breakeven analysis |
| `unit-economics` | CAC / LTV / payback calculation |
| `channels` | Channel evaluation and ranking |

## State to read (parallel)

1. `config/rhino.yml` — value hypothesis, user, features, pricing section
2. `.claude/cache/eval-cache.json` — feature maturity (only model GTM for features 50+)
3. `.claude/cache/market-context.json` — competitive landscape
4. `.claude/cache/customer-intel.json` — customer signal
5. `.claude/plans/strategy.yml` — stage, bottleneck
6. `.claude/cache/gtm-strategy.json` — prior GTM analysis (if exists)
7. `~/.claude/preferences.yml` — agent cost tier for model selection

## Agent spawning

Spawn agents based on mode:

**Full model / channels / pricing:**
```
Agent(subagent_type: "rhino-os:gtm", prompt: "[mode-specific brief with state context]", run_in_background: true)
Agent(subagent_type: "rhino-os:market-analyst", prompt: "Research pricing and distribution for [category]. Focus on: competitor pricing pages, channel strategies, unit economics benchmarks.", run_in_background: true)
```

**Runway / unit-economics:**
GTM agent only (market-analyst not needed for internal modeling).

Collect agent results, synthesize, and present.

## Pricing mode (`/money price`)

1. Spawn gtm + market-analyst agents
2. While agents run, read current pricing state from rhino.yml
3. When agents return, synthesize:
   - Competitor pricing landscape (from market-analyst)
   - Recommended model and price (from gtm)
   - Value metric alignment (does the price match the value?)
4. Present via AskUserQuestion with 2-3 pricing options
5. If founder picks one, write to `config/rhino.yml` under `pricing:`

### Pricing frameworks (from references/)

See [references/pricing-strategies.md](references/pricing-strategies.md) for stage-appropriate strategies.

## Runway mode (`/money runway`)

1. Spawn gtm agent with runway brief
2. Read current state: features scoring 50+, pricing (if set), monthly costs
3. Model 3 scenarios: conservative, expected, optimistic
4. Present breakeven timeline and decision points
5. Write to `.claude/cache/gtm-strategy.json`

## Unit economics mode (`/money unit-economics`)

1. Spawn gtm agent with economics brief
2. Calculate from available data:
   - Revenue per user (from pricing)
   - Estimated CAC by channel (from gtm research)
   - Estimated LTV (retention × revenue)
   - Payback period
3. Flag if payback > 6 months at solo founder scale

## Channels mode (`/money channels`)

1. Spawn gtm + market-analyst agents
2. Rank channels by: reach × cost × founder-fit × speed
3. For top 3: propose specific first experiment (not "try content marketing" but "write one post about [specific topic] on [specific platform]")
4. Present with launch sequence

## Output format

```
◆ money — [mode]

  stage: [stage] · [N] features at 50+
  [if pricing exists]: current: [model] at [price]

⎯⎯ [mode-specific section] ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [content from agent synthesis]

⎯⎯ verdict ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  "[one paragraph — what the numbers say about this business]"

/money [other mode]   explore another dimension
/strategy honest      check if this business makes sense
/ship release         if ready to charge
```

## What you never do

- Fabricate financial data — every number needs a source or is marked "estimate"
- Over-model — 3 scenarios max, 12 months max horizon
- Ignore stage — stage one doesn't need unit economics. It needs one paying customer.
- Make pricing decisions — present evidence, let founder decide
- Use vanity metrics — "market size" without a path to capture is meaningless
- Skip the evidence — "charge $X" without comparable data is a guess

## If something breaks

- No market-context.json: run WebSearch inline, suggest `/strategy market` first
- No features scoring 50+: "No features mature enough for GTM. Build first, sell later."
- No pricing data from competitors: flag as gap, use category benchmarks
- GTM agent fails: degrade to inline analysis with WebSearch

For gotchas and common modeling failures, see [gotchas.md](gotchas.md).
For channel scoring framework, see [references/channel-selection.md](references/channel-selection.md).

### Quick checks via scripts

Before spawning agents, run mechanical checks:
- `bash ${CLAUDE_SKILL_DIR}/scripts/compare-pricing.sh` — shows current pricing state across all sources
- `bash ${CLAUDE_SKILL_DIR}/scripts/runway-calc.sh [monthly_burn]` — instant breakeven table

These give you grounding data in <1 second. Agents provide depth.

$ARGUMENTS
