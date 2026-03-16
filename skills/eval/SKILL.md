---
name: eval
description: "Is my product good? /eval runs assertions. /eval taste for visual. /eval blind for honest cold-read. /eval coverage for assertion quality. /eval vs <url> for competitive. /eval trend for assertion-level trajectory."
argument-hint: "[feature|taste|blind|coverage|trend|vs <url>|full|diff]"
allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebFetch
---

!cat .claude/cache/score-cache.json 2>/dev/null | jq '{score, features: (.features | to_entries | map({key, score: .value.score}) | from_entries)}' 2>/dev/null || echo "no cache"

# /eval

The one measurement command. Pure measurement — eval NEVER edits files. It reads, runs, judges, presents.

Six things to measure:
- **Assertions** (`/eval`) — each feature declares what it delivers. Claude judges the gap. DELIVERS/PARTIAL/MISSING.
- **Taste** (`/eval taste`) — does it look good? Claude Vision, 11 dimensions. Expensive, only when asked.
- **Blind** (`/eval blind`) — what does the code ACTUALLY deliver vs what you CLAIM? Delusion detection.
- **Coverage** (`/eval coverage`) — are your assertions any good? Quality audit of the assertions themselves.
- **Trend** (`/eval trend`) — assertion-level trajectory. Which beliefs are stable, flapping, or regressing?
- **Competitive** (`/eval vs [url]`) — your product vs a competitor, side-by-side.

Features are defined in `config/rhino.yml` under `features:`. Each has `delivers:` (what value), `for:` (who), and `code:` (where).

Score (`rhino score .`) exists for CI/scripts. Don't surface it unless asked.

## Routing

Parse `$ARGUMENTS`:

**If $ARGUMENTS is ambiguous:**
1. Exact route keyword match wins (`taste`, `blind`, `coverage`, `trend`, `full`, `diff`, `vs`, `deep`, `slop`)
2. Feature name match (check rhino.yml features → scoped assertions)
3. Free-form topic (treat as feature name lookup)
Never ask "did you mean?" — just act.

### Feature status filter
Only evaluate features with status `active` or `proven`. Skip `killed` and `archived`. Missing `status:` = `active`.

---

### No arguments → run assertions
Run `rhino eval .` and present results grouped by feature. Show pass rate as the number.

After results, one opinion: "**[worst feature]** is the bottleneck — N/M assertions failing."

If everything passes: "All green. `/ideate` to raise the bar."

### Feature name → scoped assertions
`/eval auth`, `/eval scoring cli`

Run `rhino eval . --feature [name]` for each. Rank by pass rate (worst first).

### `taste` → visual eval (expensive)
Run `rhino taste`. Screenshots every route, scores 11 dimensions via Claude Vision.

After running, apply the **Taste Intelligence Layer** (see below). Don't parrot scores.

**Founder-in-the-loop calibration:** After presenting taste results, if `founder-taste.md` exists, show the 2 weakest dimensions and ask:

```
"breathing_room scored 1.8 — does this match what you see? [Agree / Too harsh / Too generous]"
```

Disagreements auto-update `founder-taste.md` calibration section. Taste calibration happens DURING eval, not as a separate step. Over time, scores converge on founder's actual taste.

### `blind` → delusion detection

The most honest eval. Tests what your product ACTUALLY delivers vs what you CLAIM.

**Steps:**
1. Read `config/rhino.yml` features — note the `delivers:` claims but SET THEM ASIDE
2. For each feature, read ALL files in its `code:` paths (not head-500 — everything)
3. WITHOUT looking at the claims, write what each feature ACTUALLY delivers based on the code:
   - What does this code do for the user?
   - What user problem does it solve?
   - What's missing or broken?
4. NOW compare your cold-read against the `delivers:` claim
5. Score the gap:
   - **ALIGNED** — code delivers what's claimed, or more
   - **INFLATED** — claim overstates what the code does
   - **DEFLATED** — code does more than the claim says (rare but valuable — update the claim)
   - **DISCONNECTED** — claim and code are about different things entirely

```
◆ eval blind — delusion check

▾ scoring  claim: "honest number that tells a founder if their product improved"
  cold-read: "Computes a weighted score from structure + hygiene + assertions.
  Shows penalties with reasons. Caches results. Has history tracking."
  verdict: **ALIGNED** — code delivers what's claimed
  gap: claim says "tells if improved" but no trend visualization exists

▾ learning  claim: "a model that gets smarter every session"
  cold-read: "Logs predictions to TSV. Has a grading script that partially
  works. Knowledge model is a static markdown file. No automatic learning."
  verdict: **INFLATED** — "gets smarter" overstates what the code does
  gap: prediction logging ≠ learning. No feedback loop closes automatically.

▾ summary
  4 ALIGNED · 1 INFLATED · 1 DEFLATED · 1 DISCONNECTED
  delusion score: **71%** aligned (higher = more honest)

  ⚠ learning's claim needs rewriting — code doesn't match
  ✓ scoring's claim is accurate but understates trend capability

/feature [name]    update claims to match reality
/go [name]         build what's missing
/plan              work on the gaps
```

### `coverage` → assertion quality audit

Not "are assertions passing?" — "are your assertions any GOOD?"

**Steps:**
1. Read `lens/product/eval/beliefs.yml` — all assertions
2. Read `config/rhino.yml` — features with weights
3. For each feature, analyze assertion quality:

**Metrics per feature:**
- **Count**: how many assertions?
- **Type distribution**: what % are `file_check` (easy pass), `content_check`, `command_check`, `llm_judge` (high variance)?
- **Weight coverage**: high-weight features (w:4+) with few assertions = biggest risk
- **Flakiness**: if history.tsv exists, which assertions oscillate between pass/fail?
- **Redundancy**: do multiple assertions test the same thing?
- **Missing dimensions**: does the feature have assertions for infrastructure, logic, AND UX? Or just file existence?

```
◆ eval coverage — assertion quality

▾ risk map (high weight, weak coverage)
  ⚠ commands   w:5  3 assertions  all file_check  no value assertions
  ⚠ learning   w:4  5 assertions  2 llm_judge (high variance)

▾ coverage by type
  file_check:    28 (44%) — easy pass, low signal
  content_check: 12 (19%) — medium signal
  command_check:  8 (13%) — mechanical, reliable
  llm_judge:     15 (24%) — high variance, expensive

▾ feature coverage
  scoring    w:5  11 assertions  ████████████████████  good
  commands   w:5   3 assertions  ██████░░░░░░░░░░░░░░  weak — needs value assertions
  learning   w:4   5 assertions  ████████████░░░░░░░░  ok but 2 are flaky
  install    w:3  12 assertions  ████████████████████  over-covered
  docs       w:3   6 assertions  ████████████████░░░░  ok
  todo       w:2   5 assertions  ████████████████████  good
  self-diag  w:2   9 assertions  ████████████████████  good

▾ recommendations
  · commands needs 3+ assertions testing value delivery, not just file existence
  · learning's llm_judge assertions should be converted to mechanical checks
  · install has 12 assertions at w:3 — consider pruning redundant file_checks

/assert commands: slash commands route intent correctly   add one
/eval                                                     re-run
/feature commands                                         see status
```

### `trend` → assertion-level trajectory

Not just taste trend — track individual assertions over time.

**Steps:**
1. Read `.claude/scores/history.tsv` — score trajectory
2. Read `.claude/cache/score-cache.json` — current per-feature scores
3. Read `lens/product/eval/beliefs.yml` — all assertions with IDs
4. If `.claude/evals/assertion-history.tsv` exists, read it. If not, note "first trend run — will track from here."
5. After running `rhino eval .`, append current assertion results to `.claude/evals/assertion-history.tsv`:
   ```
   date	assertion_id	feature	result	type
   ```

Classify each assertion:
- **Stable pass** (passing 5+ consecutive runs) — proven, reliable
- **Stable fail** (failing 5+ runs) — known gap, needs work or removal
- **Flapping** (alternating pass/fail) — either the assertion is bad or the feature is unstable
- **Recently changed** (status changed in last 2 runs) — progress or regression

```
◆ eval trend — assertion trajectory

▾ stable (proven)
  ✓ score-runs              12 consecutive passes   scoring
  ✓ value-hypothesis-exists  8 consecutive passes   scoring
  ✓ install-works            8 consecutive passes   install

▾ flapping (unreliable)
  ~ commands-are-intuitive   PFPFPF                 commands  ← assertion or feature?
  ~ learning-compounds       PPFPFP                 learning

▾ stuck (persistent failures)
  ✗ learning-complete        0/8 passes             learning
  ✗ self-diagnostic-complete 0/6 passes             learning

▾ momentum (recent changes)
  ↑ score-calibrated         fail → pass (last run) scoring
  ↓ readme-clear             pass → fail (2 ago)    docs

flapping rate: **12%** (2/17 assertions oscillate)
verdict: commands-are-intuitive is the weakest signal — either
sharpen the assertion or investigate why it flaps

/assert check commands-are-intuitive   test the flapper
/retro                                  grade predictions
/go learning                           fix stuck failures
```

### `vs [url]` → competitive eval

Side-by-side product comparison via taste eval.

**Steps:**
1. Run `rhino taste` on your product (or use cached results if <1 hour old)
2. Use Playwright MCP to navigate to `[url]`:
   - `browser_navigate` → URL
   - `browser_wait_for` → networkidle (or 3s timeout)
   - `browser_take_screenshot` → full page capture
   - `browser_snapshot` → accessibility tree
3. Score the competitor's page on the same 11 taste dimensions
4. Present side-by-side comparison

```
◆ eval vs — [your product] vs [competitor.com]

                    yours    theirs    gap
hierarchy           2.5      4.2      -1.7  ↓↓
breathing_room      1.8      3.8      -2.0  ↓↓↓
contrast            3.8      3.5      +0.3  ↑
polish              2.1      4.5      -2.4  ↓↓↓
emotional_tone      4.2      3.0      +1.2  ↑↑
information_density 2.8      4.0      -1.2  ↓
wayfinding          3.9      3.2      +0.7  ↑
distinctiveness     3.2      2.8      +0.4  ↑
                    ────     ────
overall             3.0      3.6      -0.6

▾ where they beat you
  **polish** (-2.4): consistent border-radius, shadow system, transitions
  on every interactive element. Your product mixes 3 different radius values.

  **breathing_room** (-2.0): they use 24px section gaps, 16px card gaps.
  You use 8px everywhere. Their content breathes.

▾ where you beat them
  **emotional_tone** (+1.2): your copy is confident and specific.
  Theirs is generic SaaS boilerplate ("streamline your workflow").

verdict: they're more polished, you have more personality.
polish is mechanical — it's the easiest gap to close.

/go [feature]       fix the biggest gap
/clone [url]        steal their best patterns
/eval taste         re-run your own eval
```

### `deep [feature]` → deep evaluation via evaluator agent

Spawns the `evaluator` agent for thorough feature analysis. Full code read, rubric generation, 3-sample median, sub-score breakdown, slop detection, delta tracking.

**Steps:**
1. Spawn the evaluator agent with the target feature name
2. Agent reads ALL code files (not truncated), generates/refreshes rubric
3. Runs `rhino eval . --feature <name> --samples 3 --fresh`
4. Reports decomposed sub-scores (value/quality/ux) with evidence
5. Detects slop patterns and reports % human-quality
6. Compares against previous eval for delta

If no feature specified, runs deep eval on the worst-scoring feature.

### `slop [feature]` → anti-slop detection

Lightweight single haiku call checking for AI-generated code patterns.

**Steps:**
1. Read feature code paths from `config/rhino.yml`
2. Scan for slop indicators:
   - Boilerplate comments restating code (`// Get the user` above `getUser()`)
   - Over-engineered abstractions for simple operations
   - Default framework patterns without customization
   - Generic variable names (data, result, items, response)
   - Unnecessary wrapper functions
3. Report with file:line citations

```
◆ eval slop — scoring

  slop: **78%** human-quality

  ▾ slop found (4 instances)
    · bin/score.sh:45 — comment restates code: "# Calculate score"
    · bin/score.sh:120 — generic variable name: `result`
    · bin/eval.sh:88 — unnecessary wrapper: `print_score_bar()` wraps printf
    · bin/eval.sh:650 — boilerplate error handling pattern

  ▾ clean code (good examples)
    · bin/eval.sh:584 — specific, non-generic prompt construction
    · bin/score.sh:200 — domain-specific logic with clear intent

/go scoring    fix the slop
/eval deep scoring    full evaluation
```

### `full` → assertions + taste
Run both in parallel where possible:
1. `rhino eval .` — assertions
2. `rhino taste` — visual craft eval

Present together. Assertions are the number that matters. Taste is the feel.

### `diff` → what changed since last eval
Compare current `rhino eval . --score` against `.claude/cache/score-cache.json`.
- Show delta per feature
- Flag regressions (was passing, now failing)
- Flag progressions (was failing, now passing)

---

## Taste Intelligence Layer

When presenting taste results (from `taste`, `full`, or `taste trend`), don't just format scores. Add intelligence:

### 1. Read context (parallel)
- `.claude/evals/reports/taste-*.json` — latest taste report
- `.claude/evals/taste-history.tsv` — trend data
- `~/.claude/knowledge/founder-taste.md` — founder preferences
- `lens/product/eval/knowledge/*.md` — dimension knowledge
- `config/rhino.yml` — features (to map dimensions → features)

### 2. Map dimensions to features
When a dimension is weak, name the responsible feature:
- `hierarchy` → landing/dashboard feature
- `wayfinding` → navigation, commands
- `distinctiveness` → design system, product identity
- `breathing_room` → layout, component density
- `polish` → overall craft across all features

### 3. Specific prescription
Don't say "improve breathing room." Say:
- Read the `evidence` field from the taste report
- Read code files for the mapped feature
- 2-3 sentence prescription: what file, what change, what it fixes

### 4. Founder-taste mismatches
If `founder-taste.md` exists:
- Scored high on something founder hates? Flag it.
- Scored low on something founder loves? Priority fix.

### 5. Integrity warnings
```
⚠ integrity: GENEROUS — avg 3.8/5 exceeds 3.5 for early stage. May be inflated.
```

---

## State to read (parallel)

Before presenting results, read:
1. `.claude/cache/score-cache.json` — previous feature scores (delta/trends)
2. `config/rhino.yml` — feature definitions (delivers/for/code)
3. `.claude/knowledge/predictions.tsv` — check if eval confirms/denies predictions
4. `.claude/plans/roadmap.yml` — current thesis + version (header context)

For the full state source list, see [STATE_MANIFEST.md](../STATE_MANIFEST.md).

After presenting results, auto-grade matching predictions — see [reference.md](reference.md) for protocol.

## Tools to use

**Use Bash** to run `rhino eval .` and `rhino taste`.
**Use Read** to check taste reports, history, founder taste profile, dimension knowledge, code files.
**Use Grep/Glob** to scan code for coverage analysis and blind eval.
**Use AskUserQuestion** for founder-in-the-loop taste calibration during taste eval.
**Use WebFetch** for competitive eval screenshots when playwright isn't available.

**Note:** `allowed-tools` is set in frontmatter. Eval CANNOT use Edit or Write — it is pure measurement. If you need to write files (taste calibrate workflow), use `/calibrate` instead.

## What you never do
- Modify eval.sh, score.sh, or taste.mjs — the eval harness is immutable
- Edit ANY files — eval is read-only measurement (enforced by allowed-tools)
- Dismiss failing assertions — they exist because someone said "this must be true"
- Run taste without being asked (expensive — only on `taste`, `full`, or `vs`)
- Show "score" as a number — show pass rate and feature breakdown
- Present taste scores without reading evidence fields — numbers alone are meaningless
- Skip the prescription — every taste eval must end with a specific, actionable fix
- Run blind eval and then silently accept inflated claims — flag them

## Anti-Rationalization Guide

| Excuse | Reality |
|--------|---------|
| "The score is wrong, product is better" | Score is a thermometer. Fix the product, not the thermometer. |
| "That assertion is too strict" | Someone said "this must be true." Fix the code, not the assertion. |
| "Taste eval is subjective anyway" | Read the evidence field, not just the number. |
| "Blind eval is unfair to our claims" | That's the point. INFLATED claims need rewriting. |
| "Coverage doesn't matter, enough assertions" | High-weight features with 2 assertions = flying blind. |

## Red Flags — STOP

- Assertion was passing, now failing, and you're considering keeping the change
- Taste scores all above 4.0 for early-stage product (inflation)
- Blind eval shows INFLATED on 3+ features (systematic delusion)
- Same assertion flapping 5+ times without investigation

**All of these mean: investigate before proceeding. No exceptions.**

## If something breaks
- `rhino eval .` fails: check if `features:` section exists in rhino.yml
- `rhino taste` fails: check if lens/product/ exists
- No features: "No features defined. `/feature new [name]`"
- Falls back to beliefs.yml if no `features:` section
- No taste history: first eval — no trend to show
- No founder-taste.md: run inline calibration during taste eval, or suggest `/calibrate`
- No assertion-history.tsv: first trend run — "Tracking from now. Re-run after next session for trajectory."
- Playwright not available for `vs`: use WebFetch for screenshots, note reduced accuracy
- `vs` URL won't load: report error, suggest trying without auth-gated pages

$ARGUMENTS
