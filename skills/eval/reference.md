# /eval Reference — Output Templates & Protocols

## Generative eval output

```
◆ eval

v8.0: **43%** · product: **64%** · assertions: 57/63

▸ scoring         ██████░░░░  58/100  (v:62 q:50 u:60)
  PARTIAL: score.sh computes honest number, but no trend visualization
  MISSING: onboarding guidance for new projects is generic

▸ learning        ████░░░░░░  48/100  (v:55 q:40 u:48)  ↓3
  DELIVERS: predictions logged to TSV with evidence
  MISSING: no automatic grading — predictions rot without manual check
  MISSING: knowledge model is append-only, no pruning

✓ commands        ███████░░░  70/100  (v:75 q:65 u:68)  ↑2
  DELIVERS: 17 slash commands with cross-recommendations
  PARTIAL: output formatting inconsistent across commands

· install         ██████░░░░  68/100  (v:70 q:60 u:72)  —
  DELIVERS: install.sh works end-to-end
  PARTIAL: no verification that symlinks were created correctly

bottleneck: **learning** at 48 — predictions log but never auto-grade

/go learning      fix the worst feature
/ideate           raise the bar (if all green)
/feature [name]   define what's missing
```

**Formatting rules:**
- Header includes version completion + product completion + assertion count
- Features sorted worst-to-best
- Bar graphs: █ for passing proportion, ░ for failing
- Sub-scores shown in parentheses: `(v:N q:N u:N)` for value/quality/ux
- Delta shown after score: `↑N` / `↓N` / `—` (vs previous eval)
- DELIVERS/PARTIAL/MISSING verdicts indented under each feature
- Bold the bottleneck feature name
- Bottom: exactly 3 next commands

## Deep eval output

```
◆ eval deep — scoring

  value     ██████████████░░░░░░  68/100
    ✓ delivers: score.sh computes weighted total (bin/score.sh:45)
    ✓ delivers: health gate blocks broken builds (bin/score.sh:12)
    · gap: no trend visualization (claimed but MISSING)

  quality   ████████████░░░░░░░░  50/100
    ✓ error handling: build check failures caught (bin/score.sh:30)
    · gap: 4 unhandled paths: file I/O at :520, :535 without fallback
    · gap: 2>/dev/null at :531 swallows real errors

  ux        ████████████████░░░░  60/100
    ✓ output: score bar visualization clear
    · gap: penalty reasons too terse for new users

  total     █████████████░░░░░░░  58/100
  delta     ↑4 vs previous (54)
  slop      82% human-quality
  samples   3 (median: 58, range: 54-62)

  rubric: .claude/cache/rubrics/scoring.json
```

## Rubric display format

When `/eval deep` shows the generated rubric:

```
▾ rubric: scoring

  spec_alignment
    80: score.sh computes value*weight for all features, health gate blocks
    40: computes a number but ignores feature weights or health
    check: bin/score.sh exports .score file, reads rhino.yml features

  integrity
    80: all file I/O paths have error handling, graceful fallback on missing files
    40: happy path works but crashes on missing config or empty features
    check: grep for 2>/dev/null, || true, set -e behavior

  ux
    80: output shows score + per-feature breakdown + actionable next steps
    40: shows a number with no context or breakdown
    check: output format, color usage, next-command suggestions

  anti_slop
    80: domain-specific logic, meaningful variable names, no boilerplate comments
    40: generic patterns, restating-code comments, unnecessary abstractions
    check: comment quality, function naming, abstraction depth
```

## Slop report format

```
◆ eval slop — scoring

  slop: **78%** human-quality

  ▾ slop found (4 instances)
    · bin/score.sh:45 — comment restates code
    · bin/score.sh:120 — generic variable name: `result`
    · bin/eval.sh:88 — unnecessary wrapper
    · bin/eval.sh:650 — boilerplate error handling

  ▾ clean code (good examples)
    · bin/eval.sh:584 — specific prompt construction
    · bin/score.sh:200 — domain-specific logic

/go scoring    fix the slop
/eval deep scoring    full evaluation
```

## Diff output

```
◆ eval diff

  scoring      58 → 62  ↑4   (v:60→65 q:50→55 u:60→62)  trend_for() now wired
  learning     48 → 48  —    (v:55→55 q:40→40 u:48→48)   no change
  commands     68 → 70  ↑2   (v:72→75 q:65→65 u:65→68)   cross-recommendations added
  install      68 → 68  —    (v:70→70 q:60→60 u:72→72)

  ✓ NEW PASS: scoring/trend-visualization (was MISSING)
  ✗ NEW FAIL: learning/auto-grade (was PARTIAL, now MISSING)

net: +6 across 2 features
delta history: .claude/cache/eval-deltas.json

/go learning      fix regressions
/eval             re-run full
/retro            grade predictions
```

## Prediction auto-grading protocol

After presenting eval results:

1. Read `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/predictions.tsv`)
2. Find rows where `correct` column (5th) is empty
3. Match predictions that mention any feature just evaluated:
   - Exact feature name match first
   - Keyword fallback (feature's `delivers:` keywords)
4. Grade matched predictions:
   - "raise X from N to M" → compare against eval score
   - "X will DELIVER" → check verdict
   - "assertion [id] will pass" → check result
5. Fill in `result`, `correct` (yes/no/partial), `model_update` columns
6. Report inline:

```
▾ predictions graded
  ✓ "scoring will reach 65+" → 62 (partial)
  ✗ "auto-grade will work" → not implemented (no)
    model update: auto-grading needs explicit build, not emergent
```

If no ungraded predictions match, omit the section.

## Taste dimension → feature mapping guide

| Dimension | Maps to | Look at |
|-----------|---------|---------|
| hierarchy | landing, dashboard | above-fold layout, CTA prominence |
| breathing_room | all pages | padding, margins, gap values |
| contrast | interactive elements | button/link styles, focus states |
| polish | all features | radius consistency, shadows, transitions |
| emotional_tone | copy, palette | microcopy, errors, empty states |
| information_density | data-heavy pages | tables, lists, cards |
| wayfinding | navigation, routing | nav, breadcrumbs, back buttons, dead ends |
| distinctiveness | overall product | custom vs framework defaults |
| scroll_experience | long pages | section pacing, sticky headers |
| layout_coherence | cross-page | grid system, max-width, alignment |
| information_architecture | nav + content | mental model, labels, grouping |

## Assertion-level trend tracking

`/eval trend` reads and writes `.claude/evals/assertion-history.tsv`:

```
date	assertion_id	feature	result	type
2026-03-15	score-runs	scoring	PASS	command_check
2026-03-15	value-hypothesis-exists	scoring	PASS	file_check
2026-03-15	learning-complete	learning	FAIL	llm_judge
```

**Classification rules:**
- 5+ consecutive same result → **stable** (pass or fail)
- Alternating in last 6 runs → **flapping** (unreliable)
- Changed in last 2 runs → **recently changed** (momentum signal)
- <3 data points → **insufficient data** (don't classify yet)

**Flapping analysis:** A flapping assertion means either:
1. The assertion is poorly written (vague llm_judge prompt)
2. The feature is genuinely unstable
3. The eval has high variance (generative eval ~15 point swing)

Surface which one it is: check assertion type (llm_judge flaps more than command_check), check if the feature code changed between runs (git log), check if other assertions for the same feature also flap.

## Blind eval protocol

The blind eval is the most expensive route — it reads FULL files, not head-500.

**Context management:** For each feature, read files in `code:` paths fully. If total lines would exceed ~2000 per feature, read entry points + exports first, then drill into specific functions that seem like core logic.

**Cold-read structure:** For each feature, write:
1. What the code DOES (functional description from reading it cold)
2. What user problem it SOLVES (infer from function names, UI text, API patterns)
3. What's MISSING or BROKEN (gaps, TODOs, error handling, edge cases)

Then compare against `delivers:` claim. The gap categories:
- **ALIGNED** — claim matches code (healthy)
- **INFLATED** — claim overstates code (delusion — rewrite claim or build more)
- **DEFLATED** — code does more than claimed (rare — update claim to capture full value)
- **DISCONNECTED** — claim and code are about different things (worst case — feature identity crisis)

## Coverage quality tiers

For `/eval coverage`, assess assertion quality on a per-feature basis:

**Tier 1 — File existence only** (lowest signal)
All assertions are `file_check`. Passes if the file exists. Tells you nothing about value delivery.

**Tier 2 — Mechanical checks** (medium signal)
Mix of `file_check`, `content_check`, `command_check`. Tests that specific things exist and specific commands work. Good for infrastructure, weak for UX.

**Tier 3 — Value assertions** (high signal)
Includes `llm_judge` or `score_trend` assertions that test whether the feature DELIVERS VALUE, not just exists. The gold standard — but higher variance.

**Ideal distribution per feature:**
- 30% mechanical (infrastructure works)
- 50% content/command (logic is correct)
- 20% llm_judge (value is delivered)

Flag features where >80% of assertions are file_check — they have coverage but not signal.

## Competitive eval calibration

For `/eval vs`, the competitor's page is evaluated by Claude Vision using the same 11 taste dimensions. But there's a bias risk: your product has full code context, theirs has only a screenshot.

**Mitigation:** Score BOTH products from screenshots only for the taste comparison. Don't use code knowledge for the comparison dimensions — that would unfairly penalize the competitor on dimensions like information_architecture where code context gives you more signal.

The comparison is visual-only. Assertions and code quality are YOUR product's domain — the competitor comparison is purely about craft.
