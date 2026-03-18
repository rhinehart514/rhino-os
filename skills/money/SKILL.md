---
name: money
description: "Use when you need financial modeling, pricing strategy, unit economics, or runway analysis. The business model in your terminal."
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

After every `/money` run, append to `${CLAUDE_PLUGIN_DATA}/money-history.json`. Read history on subsequent runs to track pricing strategy evolution.

## Routing

| Input | Mode |
|-------|------|
| (none) or `model` | Full business model — all sections |
| `price` | Pricing strategy + competitor analysis |
| `runway` | Runway modeling + breakeven analysis |
| `unit-economics` | CAC / LTV / payback calculation |
| `channels` | Channel evaluation and ranking |

## The protocol

### Step 1: Mechanical scan (always first)

Run `bash ${CLAUDE_SKILL_DIR}/scripts/revenue-scan.sh` for current financial state. For pricing modes, also run `bash ${CLAUDE_SKILL_DIR}/scripts/pricing-compare.sh`.

Also read `config/product-spec.yml` if it exists — pricing should serve the spec's person at the spec's why_now price point.

### Step 2: Read gotchas + relevant references

Read `gotchas.md`. Then read the mode-specific reference:
- price: `references/pricing-guide.md`
- runway/unit-economics: `references/unit-economics.md`
- channels: `references/channel-selection.md`
- model: all references

### Step 3: Agent spawning

**Full model / channels / pricing:**
```
Agent(subagent_type: "rhino-os:gtm", prompt: "[mode-specific brief]", run_in_background: true)
Agent(subagent_type: "rhino-os:market-analyst", prompt: "Research pricing and distribution for [category].", run_in_background: true)
```

**Runway / unit-economics:** GTM agent only.

### Step 4: Synthesize and present

Collect agent results. Use `templates/pricing-model.md` for pricing output structure. Present via AskUserQuestion with 2-3 options when pricing decisions are needed.

### Step 5: Persist

Write decisions to `config/rhino.yml` under `pricing:`. Append to money-history.json.

## Output format

See `reference.md` for mode-specific templates. Every output ends with:

```
/money [other mode]   explore another dimension
/strategy honest      check if this business makes sense
/ship release         if ready to charge
```

## Task generation — the path to a working business model

**/money's job is not just analysis. It's generating EVERY task needed to close pricing and revenue gaps.** Financial analysis without action items is a slide deck. Every gap between "what the business needs" and "what exists" is a task.

**For EVERY financial gap found, generate a task:**

### Pricing tasks
- No pricing config in rhino.yml → task: "Define pricing in rhino.yml — run /money price to decide"
- No competitor pricing data → task: "Gather competitor pricing — run /strategy compete or /research market"
- Pricing doesn't match stage → task: "Pricing strategy misaligned with stage [X] — review via /money price"
- No free tier / trial defined → task: "No trial/free tier — evaluate for stage [X]"
- Pricing hasn't been tested → task: "Pricing is theoretical — design pricing experiment"

### Unit economics tasks
- No CAC estimate → task: "No customer acquisition cost — estimate from channel strategy"
- No LTV estimate → task: "No lifetime value estimate — define from pricing + retention assumption"
- CAC > LTV → task: "Unit economics negative (CAC [X] > LTV [Y]) — fix pricing or reduce CAC"
- No churn data → task: "No churn measurement — instrument or estimate"
- Payback period >12mo → task: "Payback too slow ([N]mo) — review pricing or reduce acquisition cost"

### Channel tasks
- No distribution channels identified → task: "No channels — run /money channels to evaluate"
- Channel strategy not tested → task: "Channel [X] untested — design experiment"
- Channel cost unknown → task: "Channel [X] cost unknown — research or test with small budget"

### Revenue tasks
- Features scoring 50+ but no revenue → task: "Working features but no revenue — revenue avoidance (run /money)"
- No runway model → task: "No runway estimate — run /money runway"
- Burn rate unknown → task: "Monthly costs unknown — document in runway model"

### Stage-appropriate tasks
- Stage one with pricing optimization → task: "Premature pricing optimization — focus on one paying customer"
- Stage some with no pricing at all → task: "Have users, no pricing — avoidance pattern. Run /money price"
- Stage many with no unit economics → task: "Scaling without unit economics — dangerous. Run /money unit-economics"

**Write ALL tasks to /todo.** Tag with `source: /money` and type (pricing/unit-economics/channels/revenue/stage). Priority: stage-appropriate gaps first.

**There is no cap on task count.** A project with no pricing at all might need 10+ tasks. Generate all of them.

After analysis, show: "Generated N tasks across M financial gaps. Most critical: [gap]."

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
