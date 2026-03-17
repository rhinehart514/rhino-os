---
name: ideate
description: "Brainstorm WHAT to build. Evidence-weighted ideas, not quadrant filler. Steals from what's working. Kills what shouldn't exist. Every idea becomes a feature or dies."
argument-hint: "[feature|wild|kill|\"constraint\"]"
allowed-tools: Read, Bash, Grep, Glob, Edit, AskUserQuestion, WebSearch, Agent
---

# /ideate

**This is not a brainstorming exercise.** This is a cofounder saying "here's what we should build next and here's what we should stop building." Every idea is backed by evidence — from the codebase, from the market, from what's been tried. Ideas that survive become features via `/feature new`. Ideas that don't get killed explicitly.

**When to use this vs other commands:**

| Command | Role | Question |
|---------|------|----------|
| `/product` | **WHY** | Should this exist? Who cares? |
| `/ideate` | **WHAT** | What specific things should we build next? |
| `/roadmap ideate` | **WHERE** | Where does the project go after this thesis? |
| `/research` | **HOW** | What do we need to know before deciding? |
| `/feature new` | **DO** | Commit to building a named feature. |

## Routing

Parse `$ARGUMENTS`:

### No arguments → product-level ideation
Full evidence read → generate ideas → kill list → present.

### Feature name → feature-level ideation
Focus on one feature's weakest dimension. What would raise its eval score?

### `wild` → high-conviction bets
3 ideas that would fundamentally change the product. Not experiments — committed directions that burn bridges. Each must cite why NOW, not someday.

### `kill` → what to stop building
Pure kill exercise. Which features, todos, or assertions should die? Argues for killing at least one thing.

### `[any text]` → constrained ideation
Ideas within a specific constraint or direction.

## The Ideation Protocol

### 1. Read state (parallel)

- `config/rhino.yml` — features, weight, depends_on, value hypothesis
- `.claude/cache/eval-cache.json` — sub-scores + deltas per feature
- `.claude/cache/rubrics/<feature>.json` — rubric gaps (if exists)
- `.claude/knowledge/experiment-learnings.md` — Known Patterns, Dead Ends
- `.claude/plans/roadmap.yml` — thesis + unproven evidence
- `.claude/plans/todos.yml` — backlog (what's been captured but not built?)
- `.claude/plans/strategy.yml` — bottleneck, stage
- `.claude/cache/market-context.json` — competitive landscape (if exists from /research market)
- `.claude/cache/customer-intel.json` — customer signal, demand signals, unmet needs (if exists)
- `.claude/cache/narrative.yml` — current positioning (what are we claiming?)
- `git log --oneline -20` — what's actually been worked on
- `~/.claude/cache/last-retro.yml` — recent wrong predictions (these point to real gaps)

### 2. Evidence-weighted generation

**Don't balance across a matrix. Follow the evidence.**

Sources of ideas, ranked by signal strength:

1. **Wrong predictions** — a prediction that failed reveals a real gap in understanding. Ideas that address WHY a prediction was wrong are highest-signal.

2. **Sub-score gaps** — eval-cache shows which dimensions are weak. Low craft_score on a w:5 feature → specific ideas for error handling, edge cases. Low delivery_score → ideas for delivery gaps.

3. **Market context** — what's working in adjacent products that we haven't tried? Use `.claude/cache/market-context.json` or quick WebSearch. Not "copy competitors" but "steal patterns that are proven elsewhere."

4. **Dead end rebounds** — Dead Ends in experiment-learnings.md that point to a better approach. "X failed because Y — what if we tried Z instead?"

5. **Backlog clusters** — 3+ todos tagged to the same feature = a pattern. The backlog is telling you something.

6. **Thesis gaps** — unproven evidence items from roadmap.yml. Ideas that directly prove thesis evidence are highest leverage.

Generate **3-5 ideas**. No filler. If only 2 ideas have evidence behind them, generate 2. Don't pad to hit a number.

### 3. The kill list (mandatory)

Every ideation session produces a kill list. At least one of:

- **Feature to kill or defer** — a `planned` or `building` feature that isn't advancing the thesis
- **Todos to kill** — stale backlog items that are no longer relevant
- **Assertions to remove** — passing assertions that don't actually measure value
- **Work to stop** — a direction that recent evidence says is wrong

The kill list is as important as the ideas. You can't build 3 new things without killing something — attention is finite.

If you can't find anything to kill, you're not looking hard enough.

### 4. Present via AskUserQuestion

Show ideas with the kill list. Founder picks which to commit and which to kill. Selections go directly to materialization.

### 5. Materialize

When the founder picks an idea:
1. Write feature to `config/rhino.yml` (delivers, for, code, weight, depends_on)
2. Convert draft assertions to `beliefs.yml` — prefer mechanical over llm_judge
3. Run baseline: `rhino eval . --feature [name] --fresh`
4. Log prediction to predictions.tsv
5. Write todo items for the feature with `source: /ideate`

When the founder kills something:
1. If feature: update `status: killed` with `killed_reason:` and `killed_date:` in rhino.yml
2. If todo: mark done or remove from todos.yml
3. If assertion: remove from beliefs.yml

## The Idea Brief

Every idea is a brief, not a bullet point:

- **What**: 3-5 sentences. Walk through what changes for the user.
- **Evidence**: what data says this is the right idea? Cite specifics.
- **Who benefits**: name the person and their situation.
- **What changes**: the measurable difference. Which sub-score moves? Which assertion passes?
- **What it costs**: what gets deprioritized or killed to make room?
- **What kills it**: the failure mode.
- **Draft assertions**: 2-3 testable beliefs.

For output templates and formatting rules, see [reference.md](reference.md).

## Feature-level ideation

When scoped to a feature, the protocol tightens:

1. Read sub-scores — identify weakest dimension
2. Read rubric if it exists — its specific checks point to specific gaps
3. Read todos tagged to this feature — what's been captured?
4. Read eval-cache delta — is this feature improving or stuck?

Generate ideas that raise the feature's eval score. Each idea targets the weakest sub-score:
- Low delivery_score → "code doesn't deliver the claim — here's what's missing"
- Low craft_score → "error handling, edge cases, robustness gaps"
- Low viability_score → "output clarity, user feedback, progressive disclosure"

## Tools to use

**Use AskUserQuestion** for presenting ideas + kill list. Ideation is collaborative.
**Use WebSearch** for market patterns — "what's working in [adjacent space]?"
**Use Agent (rhino-os:explorer)** for deep codebase analysis — spawn with `Agent(subagent_type: "rhino-os:explorer", ...)`.
**Use Agent (rhino-os:customer)** for signal-weighted ideation — spawn with `Agent(subagent_type: "rhino-os:customer", prompt: "Research customer signal for [product/category]. Focus on: demand signals (what are people asking for?), unmet needs, competitor complaints. Write to .claude/cache/customer-intel.json.", run_in_background: true)`. Customer signal enriches evidence-weighted generation — demand signals from real users are higher-signal than market analysis alone.
**Use Read** for all state files.
**Use Edit** for materialization (rhino.yml, beliefs.yml, todos.yml).

## What you never do
- Generate filler ideas to hit a number — 2 good ideas beats 5 mediocre ones
- Skip the kill list — every ideation session kills something
- Write code — ideation produces features and assertions, not implementations
- Skip the failure mode — every idea includes what kills it
- Generate ideas with no evidence — "wouldn't it be cool if" is not ideation
- Ignore the backlog — existing todos are captured intent, don't duplicate them

## If something breaks
- No features defined: ideate at product level, suggest `/feature new [name]`
- No eval-cache: run `rhino eval .` first for sub-scores
- No market-context: use WebSearch inline for 2-3 comparable products
- No experiment-learnings.md: ideate from rhino.yml + codebase only, flag low confidence

$ARGUMENTS
