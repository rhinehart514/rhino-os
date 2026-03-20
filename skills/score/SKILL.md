---
name: score
description: "Unified product quality score. Orchestrates health + code eval + visual taste + behavioral flows + agent-backed viability into one authoritative number. The real answer to 'is this product good?'"
argument-hint: "[feature|quick|deep|viability|breakdown]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebFetch, WebSearch, Agent
---

!bash scripts/cache-summary.sh 2>/dev/null || echo "no cached scores"

# /score — Unified Product Quality

You are the final judge. The question is always: **does the user get it?**

Not "is the code clean" or "does it build" — does a real human encounter this product, understand what it does, get value, and want to come back? Every tier measures a facet of that question. Health checks the foundation. Delivery checks whether the user cares. Craft checks whether the experience is well-made. Visual checks whether it looks/feels right. Behavioral checks whether it actually works. Viability checks whether the market cares.

This applies to any product — web, CLI, API, library, docs. The evidence sources change. The question doesn't.

## Skill folder structure

This skill is a **folder**. Read on demand:

- `scripts/cache-summary.sh` — reads all tier caches, shows staleness + confidence (zero context cost)
- `scripts/synthesize.sh [feature]` — computes unified score from cached tier data
- `scripts/viability-assess.sh [feature]` — checks viability cache freshness
- `references/scoring-methodology.md` — tier weights, confidence rules, staleness thresholds
- `references/viability-guide.md` — how viability scoring works with agents
- `templates/score-report.md` — output formatting for all modes
- `gotchas.md` — real failure modes. **Read before scoring.**

## Routing

| Argument | Mode |
|----------|------|
| (none) | Score all active features — full orchestration |
| `<feature>` | Deep unified score for one feature |
| `quick` | Read cached data only — no agent spawns, no fresh evals |
| `deep` | Force fresh data from ALL tiers (expensive, slow) |
| `viability` | Run viability assessment only (agent-backed) |
| `breakdown` | Show per-tier detail for all features |

## The five tiers

Each tier is independently runnable and independently cached. /score reads them all and synthesizes.

### Tier 1: Health (instant, free)

**Source:** `rhino score .` (bin/score.sh)
**Cache:** `.claude/cache/score-cache.json` (5min TTL)
**What it measures:** Build passes, structure lint, hygiene. Pass/fail gate.
**Weight in final score:** Gate only — health < 20 = total score 0.

Run: `bash bin/score.sh . --json`

### Tier 2: Code Eval (LLM, moderate cost)

**Source:** `/eval` (bin/eval.sh + evaluator agents)
**Cache:** `.claude/cache/eval-cache.json`
**What it measures:** Delivery (does code deliver value?) + Craft (is code well-made?). Per feature.
**Weight in final score:** delivery 40%, craft 25%
**Staleness:** >24h or score changed >15pts since last run.

If stale: run `rhino eval . --fresh` or spawn evaluator agents per feature.

### Tier 3: Visual Quality (Playwright, expensive)

**Source:** `/taste <url>` (taste reports)
**Cache:** `.claude/evals/reports/taste-*.json`
**What it measures:** 11 visual dimensions (layout, typography, color, spacing, etc). 0-100 per dimension.
**Weight in final score:** 15% (averaged across dimensions, applied to craft composite)
**Staleness:** >48h or code changed significantly since last taste run.

If stale: flag `visual_confidence: low` — don't penalize, but note the gap.
If no URL configured: skip tier, redistribute weight to code eval craft.

### Tier 4: Behavioral (Playwright, moderate)

**Source:** `/taste <url> flows` (flow audit reports)
**Cache:** `.claude/evals/reports/flows-*.json`
**What it measures:** Does the frontend actually work? Issue list by severity (blocker/major/minor).
**Weight in final score:** 10% (converted: 0 blockers + 0 majors = 100, each blocker = -25, each major = -10, each minor = -3)
**Staleness:** >48h or code changed significantly since last flows run.

If stale: flag `behavioral_confidence: low`.
If no URL configured: skip tier, redistribute weight to code eval delivery.

### Tier 5: Viability (intelligence-first, agent-refreshed)

**Source:** viability-cache.json (agent-backed) > market-context.json + customer-intel.json (intelligence-derived) > capped at 30
**Cache:** `.claude/cache/viability-cache.json`
**What it measures:** Market position, competitive differentiation, demand signals, UVP strength.
**Weight in final score:** 10%
**Staleness:** >72h or strategy/market context changed.

**Viability scoring priority:**
1. **Agent-backed** (viability-cache.json exists and fresh): full range 0-100. Authoritative.
2. **Intelligence-derived** (market-context.json + customer-intel.json exist): capped at 60. Uses accumulated intelligence without spawning agents.
3. **Partial intelligence** (one of market/customer exists): capped at 45.
4. **No data**: capped at 30. Honest unknown territory.

Agents are the REFRESH mechanism, not the only path. `synthesize.sh` reads intelligence files directly for scoring. Only spawn agents when intelligence is stale (>7 days) or missing entirely.

## The protocol

### Full score (no arguments)

1. Read `gotchas.md` first
2. Run `bash scripts/cache-summary.sh` — see what's cached, what's stale
3. Read `config/rhino.yml` — get feature list, stage, URL
4. **Health gate:** run `bash bin/score.sh . --json`. If health < 20, stop. Score = 0.
5. **Code eval tier:** read `.claude/cache/eval-cache.json`. If stale (>24h), run fresh eval per feature.
6. **Visual tier:** find latest `taste-*.json` in `.claude/evals/reports/`. If stale or missing, flag low confidence.
7. **Behavioral tier:** find latest `flows-*.json` in `.claude/evals/reports/`. If stale or missing, flag low confidence.
8. **Viability tier:** `synthesize.sh` handles viability automatically:
   - Reads viability-cache.json first (agent-backed, authoritative)
   - Falls back to scoring from market-context.json + customer-intel.json (capped at 60)
   - No intelligence at all = capped at 30
   - Only spawn agents if viability-cache.json is stale (>72h) AND intelligence files are stale (>7d):
     - `Agent(subagent_type: "rhino-os:market-analyst", prompt: "Analyze market position for [product]. Write to .claude/cache/market-context.json", run_in_background: true)`
     - `Agent(subagent_type: "rhino-os:customer", prompt: "Gather customer signal for [product]. Write to .claude/cache/customer-intel.json", run_in_background: true)`
9. **Synthesize:** run `bash scripts/synthesize.sh` — handles all tier reading, weight redistribution, and confidence computation.
   - Output includes `tiers` count (0-5) and `viability_source` (agents/intelligence/capped) per feature
   - Product total: weighted average across features (by `weight:` field in rhino.yml)
10. Write unified results to `.claude/cache/score-unified.json`
11. Present using `templates/score-report.md` — always show tier fill badge (●●○○○)

### Quick mode

Read all caches. No fresh runs. No agent spawns. Flag stale data. Fastest possible answer.

### Deep mode

Auto-fill all tiers sequentially. One command, all tiers, one number:

1. **Health gate:** `bash bin/score.sh . --json`
2. **Code eval:** if stale, spawn evaluator agents per feature
3. **Visual:** if URL configured in rhino.yml, run `/taste <url>` (Playwright + Vision)
4. **Behavioral:** if URL configured, run `/taste <url> flows` (Playwright flow audit)
5. **Viability:** spawn market-analyst + customer agents regardless of cache age

Show progress as each tier completes. Most accurate, most expensive (~$2-5 API, 10+ minutes).
Warn about cost before starting. Use `AskUserQuestion` to confirm if not explicitly requested.

### Viability mode

Only run tier 5. Spawn agents, gather evidence, score viability. Useful when you want to pressure-test market position without re-running everything.

### Breakdown mode

Show per-tier detail: each tier's raw scores, staleness, confidence level, evidence citations. No synthesis — just the data.

## Viability scoring protocol

Read `references/viability-guide.md` for the full protocol. Summary:

1. Read existing intelligence: `market-context.json`, `customer-intel.json`, `strategy.yml`, `product-spec.yml`
2. If data is stale (>72h) or missing, spawn market-analyst + customer agents in parallel
3. Score viability per feature based on agent evidence:
   - **UVP clarity** (0-25): Can you name what's unique in one sentence?
   - **Competitive gap** (0-25): Does market-context.json show something no competitor has?
   - **Demand signal** (0-25): Does customer-intel.json show people wanting this?
   - **Positioning** (0-25): Does strategy.yml show a clear stage-appropriate position?
4. Every viability claim must cite a source. No source = no points.
5. Write per-feature viability scores to `.claude/cache/viability-cache.json`

**Hard rules:**
- viability > 50 requires citing market-context.json OR customer-intel.json
- viability > 75 requires BOTH market context AND customer signal
- viability with zero external data = capped at 30 ("unknown territory")

## Confidence levels

Each tier gets a confidence tag based on data freshness and completeness:

- **high** — fresh data (<24h for eval, <48h for taste/flows, <72h for viability)
- **medium** — cached data within 2x staleness threshold
- **low** — stale data beyond 2x threshold, or tier data missing entirely

Product-level confidence = minimum confidence across all tiers. One `low` tier = `low` overall.

## State to read (parallel)

`config/rhino.yml`, `config/product-spec.yml`, `.claude/cache/eval-cache.json`, `.claude/cache/score-cache.json`, `.claude/cache/viability-cache.json`, `.claude/cache/market-context.json`, `.claude/cache/customer-intel.json`, `.claude/evals/reports/taste-*.json` (latest), `.claude/evals/reports/flows-*.json` (latest), `.claude/plans/strategy.yml`

## Cross-skill synthesis

After scoring:
- Read `.claude/cache/outside-in.json` if present. Surface journey gaps and unmet needs as opportunity context — not a penalty, but a "what's missing" signal. This is surface-agnostic: gaps could be filled by CLI, web, API, or distribution channels.
- Lowest-scoring feature by unified score = the bottleneck. Suggest `/plan` to target it.
- If visual confidence is low and product has a URL: suggest `/taste <url>`.
- If behavioral confidence is low: suggest `/taste <url> flows`.
- If viability is lowest dimension: suggest `/research` or `/strategy`.
- If journey gaps > 0 or unmet needs > 0: suggest `/ideate` to generate ideas for the gaps.
- If all tiers are high confidence and score > 80: suggest `/ship`.

## Agents

- **rhino-os:evaluator** — per feature, for fresh code eval (when eval cache stale)
- **rhino-os:market-analyst** — viability tier, competitive landscape (background)
- **rhino-os:customer** — viability tier, demand signals (background)

## What you never do

- Score without checking all available cached data first
- Invent viability scores without agent evidence
- Skip the health gate
- Present a score without confidence levels
- Edit code — /score is measurement only
- Run taste/flows without being asked (expensive) — read caches, flag staleness

## If something breaks

- No features in rhino.yml: "No features defined. `/feature new [name]`"
- No eval cache: run quick eval, establish baseline
- No taste/flows data: flag low confidence, score without those tiers
- No viability data: cap viability at 30, suggest `/score viability` or `/research`
- Agent spawn fails: score with available data, flag viability as `low` confidence

$ARGUMENTS
