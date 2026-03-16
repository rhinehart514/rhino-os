---
name: eval
description: "Is my product good? The one measurement command. /eval runs assertions. /eval taste for visual. /eval auth scopes to a feature."
---

!cat .claude/cache/score-cache.json 2>/dev/null | jq '{score, features: (.features | to_entries | map({key, score: .value.score}) | from_entries)}' 2>/dev/null || echo "no cache"

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

### Feature status filter
Only evaluate features with status `active` or `proven`. Skip `killed` and `archived` features. Missing `status:` field = `active` (include by default).

### No arguments → run assertions
Run `rhino eval .` and present results grouped by feature. Show pass rate as the number.

After results, one opinion: "**[worst feature]** is the bottleneck — N/M assertions failing."

If everything passes: "All green. `/ideate` to raise the bar."

### Feature name → scoped assertions
`/eval auth`, `/eval scoring cli`

Run `rhino eval . --feature [name]` for each. Show pass/fail per feature. If multiple features specified, rank by pass rate (worst first).

### `taste` → delegate to `/taste` skill
Taste is now its own skill. **Do not run `rhino taste` — invoke `/taste <url>` instead.**
The `/taste` skill uses Playwright MCP natively, scores 0-100, researches the market, remembers past evaluations, and creates todos.

### `full` → assertions + taste
Run both:
1. `rhino eval .` — assertions (the number that matters)
2. Invoke `/taste <url>` — visual craft eval (the `/taste` skill handles this)

Present together. No separate "health gate" or "score" — just what's true and what looks good.

### `diff` → what changed since last eval
Compare current `rhino eval . --score` against `.claude/cache/score-cache.json`.
- Show delta per feature
- Flag regressions (was passing, now failing)
- Flag progressions (was failing, now passing)

## Output format

Always use this structure. No walls of text — scannable, dense, visual.

```
◆ eval

▸ scoring         ██████░░░░  58/100
  PARTIAL: score.sh computes honest number, but no trend visualization
  MISSING: onboarding guidance for new projects is generic

▸ learning        ████░░░░░░  48/100
  DELIVERS: predictions logged to TSV with evidence
  MISSING: no automatic grading — predictions rot without manual check
  MISSING: knowledge model is append-only, no pruning

✓ commands        ███████░░░  70/100
  DELIVERS: 9 slash commands with cross-recommendations
  PARTIAL: output formatting inconsistent across commands

· install         ██████░░░░  68/100
  DELIVERS: install.sh works end-to-end
  PARTIAL: no verification that symlinks were created correctly

bottleneck: **learning** at 48 — predictions log but never auto-grade

/go learning      fix the worst feature
/ideate           raise the bar (if all green)
/feature [name]   define what's missing
```

**Formatting rules:**
- Features sorted worst-to-best
- Bar graphs: █ for passing proportion, ░ for failing
- Show DELIVERS/PARTIAL/MISSING verdicts indented under each feature
- Bold the bottleneck feature name
- Bottom: 2-3 relevant next commands (not all commands)

For **taste** output:

```
◆ eval taste

overall: **3.2**/5

▾ weakest
  · breathing room    1.8  too dense, elements crowded
  · polish            2.1  inconsistent border radius, mixed shadows
  · hierarchy         2.5  competing CTAs on dashboard

▴ strongest
  ✓ emotional tone    4.2  confident, professional
  ✓ wayfinding        3.9  clear navigation structure
  ✓ contrast          3.8  readable text, good color ratios

fix: **breathing room** — add consistent padding/margin system

/go [feature]     target the weakest dimension
/eval             run assertions alongside
```

For **diff** output:

```
◆ eval diff

  scoring      58 → 62  ↑4   trend_for() now wired
  learning     48 → 48  —    no change
  commands     68 → 70  ↑2   cross-recommendations added
  install      68 → 68  —

  ✓ NEW PASS: scoring/trend-visualization (was MISSING)
  ✗ NEW FAIL: learning/auto-grade (was PARTIAL, now MISSING)

net: +6 across 2 features
```

## State to read (parallel)

Before presenting results, read:
1. `.claude/cache/score-cache.json` — previous feature scores (for delta/trends)
2. `config/rhino.yml` — feature definitions (delivers/for/code)
3. `.claude/knowledge/predictions.tsv` — last prediction (to check if eval confirms/denies it)

After presenting results, auto-grade matching predictions:

### Prediction auto-grading protocol
1. Read `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/predictions.tsv`)
2. Find rows where `correct` column (5th) is empty
3. Match predictions that mention any feature just evaluated:
   - Exact feature name match first (e.g., "scoring" in prediction text)
   - Keyword fallback (feature's `delivers:` keywords)
4. Grade matched predictions:
   - "raise X from N to M" → compare against eval score
   - "X will DELIVER" → check verdict for that feature
   - "assertion [id] will pass" → check assertion result
5. Fill in `result`, `correct` (yes/no/partial), and `model_update` columns
6. Report inline after eval results:

```
▾ predictions graded
  ✓ "scoring will reach 65+" → 62 (partial)
  ✗ "auto-grade will work" → not implemented (no)
    model update: auto-grading needs explicit build, not emergent
```

If no ungraded predictions match evaluated features, omit the section (no noise).

- If results contradict experiment-learnings.md, flag it

## Tools to use

**Use Bash** to run `rhino eval .`. For taste, delegate to `/taste` skill.

**Use Read** to check `.claude/cache/score-cache.json` for previous results (diff mode).

## What you never do
- Modify eval.sh, score.sh, taste.mjs, or skills/taste/SKILL.md — the eval harness is immutable
- Dismiss failing assertions — they exist because someone said "this must be true"
- Run taste without being asked (it's expensive — only on `taste` or `full`)
- Run `rhino taste` directly — delegate to `/taste` skill instead
- Show "score" as a number to the founder — show pass rate and feature breakdown instead
- Output walls of unformatted text — use the template above

## If something breaks
- `rhino eval .` fails: check if `features:` section exists in rhino.yml. If not, suggest `/feature new [name]`
- `/taste` not working: check Playwright MCP installation. Legacy: `rhino taste` requires lens/product/
- No features: "No features defined. Run `/feature new [name]` to define what your product delivers."
- Falls back to beliefs.yml if no `features:` section — old assertions still work as supplementary checks

$ARGUMENTS
