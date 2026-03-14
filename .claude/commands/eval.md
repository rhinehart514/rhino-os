---
description: "Is my product good? The one measurement command. /eval runs assertions. /eval taste for visual. /eval auth scopes to a feature."
---

# /eval

The one measurement command. Answers: "Is my product good?"

Two things to measure:
- **Generative eval** (`/eval`) — each feature declares what it delivers. Claude judges the gap between claim and code. DELIVERS/PARTIAL/MISSING per feature.
- **Taste** (`/eval taste`) — does it look good? Claude Vision, 11 dimensions. Expensive, only when asked.

Features are defined in `config/rhino.yml` under `features:`. Each has `delivers:` (what value), `for:` (who), and `code:` (where). The eval reads the claim + code and judges the gap.

If no `features:` section exists, falls back to beliefs.yml mechanical assertions.

Score (`rhino score .`) exists for CI/scripts. Don't surface it to the founder unless they ask.

## Routing

Parse `$ARGUMENTS`:

### No arguments → run assertions
Run `rhino eval .` and present results grouped by feature. Show pass rate as the number.

After results, one opinion: "**[worst feature]** is the bottleneck — N/M assertions failing."

If everything passes: "All green. `/ideate` to raise the bar."

### Feature name → scoped assertions
`/eval auth`, `/eval scoring cli`

Run `rhino eval . --feature [name]` for each. Show pass/fail per feature. If multiple features specified, rank by pass rate (worst first).

### `taste` → visual eval (expensive)
Run `rhino taste` in the project directory. Screenshots every route, scores 11 dimensions via Claude Vision.

Present results as:
- Overall average (1-5 scale)
- Bottom 3 dimensions (the craft bottleneck)
- Top 3 dimensions (strengths — don't touch)
- One recommendation: which dimension to improve and why

### `full` → assertions + taste
Run both:
1. `rhino eval .` — assertions (the number that matters)
2. `rhino taste` — visual craft eval

Present together. No separate "health gate" or "score" — just what's true and what looks good.

### `diff` → what changed since last eval
Compare current `rhino eval . --score` against `.claude/cache/score-cache.json`.
- Show delta per feature
- Flag regressions (was passing, now failing)
- Flag progressions (was failing, now passing)

## Tools to use

**Use Bash** to run `rhino eval .` and `rhino taste`.

**Use Read** to check `.claude/cache/score-cache.json` for previous results (diff mode).

## What you never do
- Modify eval.sh, score.sh, or taste.mjs — the eval harness is immutable
- Dismiss failing assertions — they exist because someone said "this must be true"
- Run taste without being asked (it's expensive — only on `taste` or `full`)
- Show "score" as a number to the founder — show pass rate and feature breakdown instead

## Next action (always recommend one)
- Assertions failing → "`/go [worst feature]` to fix."
- All passing → "`/ideate` to raise the bar."
- Taste scores low → "`/go` targeting that dimension."
- No features defined → "`/feature new [name]` to define what this feature delivers."

## If something breaks
- `rhino eval .` fails: check if `features:` section exists in rhino.yml. If not, suggest `/feature new [name]`
- `rhino taste` fails: check if lens/product/ exists. If not, taste isn't installed for this project
- No features: "No features defined. Run `/feature new [name]` to define what your product delivers."
- Falls back to beliefs.yml if no `features:` section — old assertions still work as supplementary checks

$ARGUMENTS
