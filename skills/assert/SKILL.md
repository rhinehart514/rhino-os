---
name: assert
description: "Use when adding, checking, or removing assertions — chat-native beliefs.yml editing"
argument-hint: "[feature: belief text] or [list|check|remove|graduate|health|coverage|suggest|flapping] [id|feature]"
allowed-tools: Read, Bash, Edit, Grep
---

# /assert

**When to use this:** You just built something and want to make sure it stays working. Or a todo keeps recurring and should become permanent. Or you need to audit assertion health — flapping, staleness, redundancy, coverage gaps. You don't need to open beliefs.yml — just type what should be true.

**When NOT to use this:** If you want to *run* assertions, use `/eval`. If you want to *measure the product*, use `/eval`. `/assert` is for writing, managing, and auditing — not measuring.

Assertions are the north star metric. Todos are temporary. Assertions are permanent. This command manages both — and handles the graduation from one to the other. It also diagnoses assertion quality: flapping beliefs, stale coverage, shallow testing, and feature gaps.

**Where assertions come from:**
- `/assert auth: users can log in` — founder types one directly
- `/todo` graduation — a recurring todo becomes a permanent assertion
- `/assert suggest auth` — auto-suggested from code paths and claim gaps
- `/research` — findings suggest a testable belief
- `/go` reviewer — recurring pattern flagged for graduation
- `/eval` evaluator — rubric check that should be permanent

## State artifacts

Read these in parallel at skill start (skip gracefully when missing):

| Artifact | Path | Purpose |
|----------|------|---------|
| beliefs | `lens/product/eval/beliefs.yml` | All assertions |
| rhino config | `config/rhino.yml` | Features, weights, code paths, delivers claims |
| assertion health | `.claude/cache/assertion-health.json` | Per-assertion stability metrics |
| assertion history | `.claude/evals/assertion-history.tsv` | Pass/fail history from /eval runs |
| eval cache | `.claude/cache/eval-cache.json` | Sub-scores for coverage mapping |
| todos | `.claude/plans/todos.yml` | For graduation candidates |

## Routing

Parse `$ARGUMENTS`:

### Contains `:` → quick-add
Format: `feature: belief text`

Example: `/assert auth: users can log in`

1. Parse feature name (before colon) and belief text (after colon)
2. Read `config/rhino.yml` features section. Check the feature's weight. If a w:5 feature has 0 existing assertions, flag it: "**[feature]** is weight 5 (critical) with no assertions — this belief is high priority."
3. Auto-detect assertion type from the belief text:
   - Mentions a file path (contains `/` or `.sh` or `.ts` etc.) → `file_check`
   - Mentions "should contain" / "has" / "includes" → `content_check`
   - Mentions "score" / "trend" / "improves" → `score_trend`
   - Mentions "command" / "runs" / "exits" → `command_check`
   - Otherwise → `llm_judge` (Claude evaluates subjectively)
4. Generate an id from feature + key words (e.g., `auth-login`)
5. Generate appropriate fields based on type:
   - `file_check`: extract path, set `contains` if mentioned
   - `content_check`: extract forbidden words or contains text
   - `score_trend`: set `window: 10`, `direction: not_flat`
   - `command_check`: extract the command from text
   - `llm_judge`: use the belief text as the `prompt`, auto-detect `path` from feature's code paths in rhino.yml
6. Default severity to `warn`
7. Append to beliefs.yml
8. If this came from a todo graduation, mark the todo done in todos.yml

### `list` → show all assertions
Optionally scoped: `/assert list scoring`

Read beliefs.yml, group by feature, show pass/fail status by running `rhino eval . --score --by-feature`.
Read `config/rhino.yml` for feature weights. Show weight next to each feature group header.
Flag any w:4+ features with 0 assertions: "**[feature]** (w:[N]) has no assertions — needs coverage."

### `check [id]` → run single assertion
Run `rhino eval . --no-generative` and grep for the specific assertion id in output.

### `remove [id]` → remove assertion

**Anti-rationalization gate:** Before removing, check WHY:
- If the assertion is *failing*, print: "This assertion is failing. Failing assertions are the signal, not the problem. Removing it hides the bug — it doesn't fix it."
- Ask for confirmation only after the warning.
- If the assertion *passes* and is flagged as stale or redundant by `/assert health`, proceed without warning.

Find and remove the belief block with matching id from beliefs.yml.

### `graduate [todo-id]` → convert todo to assertion
Read the todo from todos.yml, extract its title and feature tag:
1. Auto-detect assertion type from the todo title (same rules as quick-add)
2. Generate assertion fields
3. Show the proposed assertion for confirmation
4. On confirm: write to beliefs.yml, mark todo done in todos.yml
5. Output: "Graduated: [todo title] → assertion [id]"

This is the endpoint for `todo:graduate` messages from agents.

---

### `health` → assertion health dashboard

The diagnostic mode. Answers: "Are my assertions actually doing their job, or are they theater?"

**1. Read state:**
- `lens/product/eval/beliefs.yml` — all assertions
- `.claude/cache/assertion-health.json` — stability metrics (if exists)
- `.claude/evals/assertion-history.tsv` — pass/fail history across runs
- `config/rhino.yml` — features and weights

**2. Compute health signals:**

**Flapping assertions** — oscillate pass/fail across recent evals (3+ state changes in last 10 runs). These waste attention and indicate either a fragile implementation or a badly-scoped assertion.
- Detection: scan assertion-history.tsv for assertions with >2 state transitions in the last 10 eval runs
- Each flapping assertion: show id, feature, flip count, last 10 results as a sparkline (e.g., `✓✗✓✗✓✗✓✓✗✓`)
- Suggestion: "Tighten the assertion scope or fix the underlying instability"

**Stale assertions** — always pass, never tested against real change. They passed on day 1 and have passed every run since. They might be trivially true (file_check on a file that will always exist) or testing something that never changes.
- Detection: assertions with 100% pass rate across 10+ runs AND the file/path they check hasn't been modified in the last 20 commits
- Each stale assertion: show id, feature, consecutive passes, last relevant code change
- Suggestion: "Consider if this is still testing something meaningful"

**Never-failing assertions** — similar to stale, but these are assertions where the checked condition is trivially satisfied. A file_check on `config/rhino.yml` will always pass. A content_check for a word that appears 50 times will always pass.
- Detection: file_check assertions where the path is a core config file, content_check assertions where the term appears >10 times
- Flag as "potentially trivial — upgrade to a deeper check"

**Redundancy clusters** — multiple assertions testing the same thing differently. Two file_checks on the same path. An llm_judge and a content_check that verify the same claim.
- Detection: group by path, then by semantic similarity of belief text within same feature
- Show clusters with assertion ids

**Orphaned assertions** — assertions for features that no longer exist in rhino.yml, or assertions whose `path:` points to deleted files.
- Detection: cross-reference assertion features against rhino.yml features, check path existence

**3. Compute summary metrics:**
- Total assertions, pass rate
- Health grade: A (0-1 issues), B (2-3), C (4-6), D (7+)
- Per-feature assertion count with weight-adjusted coverage score

**4. Update `.claude/cache/assertion-health.json`:**
```json
{
  "last_run": "2026-03-16",
  "total": 63,
  "pass_rate": 0.89,
  "health_grade": "B",
  "flapping": ["id1", "id2"],
  "stale": ["id3", "id4"],
  "trivial": ["id5"],
  "redundant": [["id6", "id7"]],
  "orphaned": ["id8"],
  "per_feature": {
    "scoring": { "count": 6, "coverage_score": 0.7 }
  }
}
```

**Output:**
```
◆ assert health — 63 assertions

v8.0: **89%** pass rate · health: **B**

  ⎯⎯ live results (rhino eval . --no-generative) ⎯⎯

  56/63 passing · 5 warn · 2 fail
  pass rate trend: ✓✓✓✓·✓✗✓✓✓ (last 10 runs)

  ⎯⎯ stability ⎯⎯

▾ flapping (2) — oscillate pass/fail, waste attention
  ⚠ score-calibrated        scoring    ✓✗✓✗✓✗✓✓✗✓  6 flips/10 runs
  ⚠ learning-compounds      learning   ✓✓✗✓✗✓✗✓✓✗  5 flips/10 runs

▾ stale (4) — always pass, never challenged
  · rhino-yml-exists         scoring    ✓✓✓✓✓✓✓✓✓✓  23 consecutive, unchanged 40 commits
  · hooks-json-exists        commands   ✓✓✓✓✓✓✓✓✓✓  23 consecutive, unchanged 35 commits

  ⎯⎯ quality ⎯⎯

▾ trivial (1) — condition can't fail
  · config-has-features      scoring    file_check on core config — upgrade to content_check

▾ redundant (1 cluster)
  · score-runs + score-exits-zero    both test score.sh execution

▾ orphaned (0)
  ✓ all assertions map to active features

  ⎯⎯ coverage by weight ⎯⎯

  scoring     w:5  ██████████████░░░░░░  6 assertions
  commands    w:5  ██████░░░░░░░░░░░░░░  3 assertions
  learning    w:4  ████████░░░░░░░░░░░░  5 assertions
  ⚠ deploy   w:4  ░░░░░░░░░░░░░░░░░░░░  0 assertions — needs coverage

/assert flapping           fix unstable assertions
/assert suggest deploy     auto-suggest for uncovered features
/assert coverage           dimension-level gap analysis
```

---

### `coverage [feature]` → dimension coverage map

Maps assertion coverage per feature against the value/quality/ux dimensions from eval-cache. Answers: "Where are the blind spots?"

**1. Read state:**
- `lens/product/eval/beliefs.yml` — all assertions
- `.claude/cache/eval-cache.json` — sub-scores and dimension breakdowns
- `config/rhino.yml` — features, weights, delivers claims

**2. Build coverage matrix:**

For each feature (or the specified feature), map existing assertions against these dimensions:
- **Value** — does the feature deliver what it claims? (maps to `delivers:` in rhino.yml)
- **Behavior** — does it work end-to-end? (command_check, llm_judge on behavior)
- **Structure** — do the right files exist with the right content? (file_check, content_check)
- **Regression** — would a breaking change be caught? (assertions that test boundaries, not just existence)
- **Edge cases** — error states, empty states, missing data paths

Each cell: `✓` (covered), `·` (partially — only shallow checks), `✗` (no assertion)

**3. Flag gaps:**
- High-weight features (w:4+) with `✗` in Value or Behavior → critical gap
- Any feature with all `✓` in Structure but `✗` in Value → shallow coverage ("testing the menu, not the meal")
- Features where eval-cache shows low sub-scores but assertions all pass → assertions aren't catching the real problem

**4. Degraded mode:**
- No eval-cache.json → skip dimension mapping, do structural analysis only (which types exist per feature)
- No rhino.yml features → "No features defined. Run `/feature new [name]`."

**Output (scoped to feature):**
```
◆ assert coverage — scoring

v8.0: **89%** · scoring w:5 · 6 assertions

  ⎯⎯ dimension depth ⎯⎯

  dimension       status  depth                assertions
  value           ✓       ████████████████████  score-honest, value-hypothesis-defined
  behavior        ·       ████░░░░░░░░░░░░░░░░  score-runs (shallow — only tests exit code)
  structure       ✓       ████████████████████  score-sh-exists, score-has-history
  regression      ✗       ░░░░░░░░░░░░░░░░░░░░  no boundary tests
  edge cases      ✗       ░░░░░░░░░░░░░░░░░░░░  no error path assertions

  gap: **regression** + **edge cases** — scoring could break silently

  suggested:
  ▸ "score.sh exits non-zero on invalid input" — command_check
  ▸ "score.sh handles missing rhino.yml gracefully" — command_check

/assert scoring: score exits non-zero on bad input   add the first suggestion
/assert suggest scoring                               more suggestions
/assert health                                        full health dashboard
```

**Output (all features):**
```
◆ assert coverage — all features

v8.0: **89%** pass rate · 6 features

  ⎯⎯ coverage matrix ⎯⎯

  feature      w   value  behavior  structure  regression  edge   depth
  scoring      5   ✓      ·         ✓          ✗           ✗      ████████████░░░░░░░░
  commands     5   ✓      ✓         ✓          ·           ✗      ██████████████░░░░░░
  learning     4   ·      ·         ✓          ✗           ✗      ██████░░░░░░░░░░░░░░
  deploy       4   ✗      ✗         ✗          ✗           ✗      ░░░░░░░░░░░░░░░░░░░░
  docs         3   ✓      ·         ✓          ✗           ·      ██████████░░░░░░░░░░
  todo         3   ✓      ✓         ✓          ·           ·      ██████████████████░░

  ⎯⎯ critical gaps ⎯⎯

  ⚠ **deploy** (w:4) — zero coverage across all dimensions
  ⚠ **scoring** regression — no boundary tests for highest-weight feature
  ⚠ **learning** value — claims "predictions compound" but no assertion tests this

/assert suggest deploy     auto-suggest for biggest gap
/assert health             assertion quality dashboard
/eval                      run assertions to update cache
```

---

### `suggest [feature]` → auto-suggest assertions

Generates 2-3 assertion suggestions based on code analysis, rhino.yml claims, and existing gaps.

**1. Read state:**
- `config/rhino.yml` — feature's `delivers:`, `code:` paths, weight
- `lens/product/eval/beliefs.yml` — existing assertions for this feature
- `.claude/cache/eval-cache.json` — sub-scores (if available)
- The actual code files listed in the feature's `code:` paths

**2. Analysis:**

For each code path in the feature:
- Read the file. Identify the primary function/export/entry point.
- Compare against the `delivers:` claim. What's the gap between claim and test coverage?
- Check existing assertions. What type are they? What dimension do they cover?

**3. Generate suggestions:**

Prioritize by gap severity:
1. **No value assertion** → suggest an llm_judge that tests the delivers claim directly
2. **No behavior assertion** → suggest a command_check that runs the feature end-to-end
3. **Only file_checks** → suggest a content_check or llm_judge that tests actual content, not just existence
4. **No regression protection** → suggest a command_check that tests error handling or boundary conditions

Each suggestion includes:
- Complete assertion YAML (id, belief, type, path, severity, feature)
- Which dimension it covers
- Why this gap matters

**4. Anti-pattern detection:**
- If suggesting a file_check and the feature already has 2+ file_checks → "Consider deeper assertion types — file existence is necessary but not sufficient"
- If the feature has 5+ assertions all passing → "This feature may have enough coverage. Consider `/assert health` to check for redundancy."

**Output:**
```
◆ assert suggest — scoring

v8.0: **89%** · scoring w:5 · 6 existing assertions

  existing coverage: value ✓ · behavior · · structure ✓ · regression ✗ · edge ✗

  ▸ suggestion 1 — regression
    id: score-rejects-bad-input
    belief: "score.sh exits non-zero when rhino.yml is malformed"
    type: command_check
    command: "echo 'bad yaml' > /tmp/test-rhino.yml && cd /tmp && rhino score . 2>&1; test $? -ne 0"
    why: highest-weight feature has no regression protection

  ▸ suggestion 2 — edge case
    id: score-handles-no-features
    belief: "score.sh produces a valid number even with zero features defined"
    type: command_check
    command: "rhino score . --no-features 2>/dev/null | grep -E '^[0-9]+$'"
    why: score is called by CI — must never produce garbage output

  ▸ suggestion 3 — behavior depth
    id: score-honest-penalty
    belief: "score.sh penalizes projects with failing assertions, not just missing ones"
    type: llm_judge
    prompt: "Does score.sh differentiate between missing assertions and failing assertions?"
    path: "bin/score.sh"
    why: current behavior assertion only tests exit code, not scoring logic

  [Add 1] [Add 2] [Add 3] [Add all] [Skip]

/assert scoring: score exits non-zero on bad input   quick-add the first
/assert coverage scoring                              see full coverage map
/assert health                                        check assertion quality
```

---

### `flapping` → show oscillating assertions

Focused view of assertions that flip pass/fail. The most actionable health signal — these waste attention every eval run.

**1. Read state:**
- `.claude/evals/assertion-history.tsv` — pass/fail history
- `lens/product/eval/beliefs.yml` — assertion details
- `.claude/cache/assertion-health.json` — cached health data

**2. Detect flapping:**
- Scan history for assertions with 3+ state changes in the last 10 runs
- Rank by flip frequency (worst first)
- For each: show the sparkline, the assertion definition, and a diagnosis

**3. Diagnose each:**
- **Environment-dependent**: assertion relies on external state (network, temp files, time). Fix: mock or pin.
- **Race condition**: assertion tests something that's intermittently available. Fix: add retry or tighten scope.
- **Threshold boundary**: assertion value hovers near pass/fail threshold. Fix: widen threshold or split into two assertions.
- **Implementation churn**: the code it tests is actively being rewritten. Fix: defer assertion until stable.

**4. Degraded mode:**
- No assertion-history.tsv → "No eval history. Run `/eval` twice to generate trend data, then retry."
- <10 runs in history → "Only [N] eval runs recorded. Need 10+ for reliable flapping detection."

**Output:**
```
◆ assert flapping — 3 oscillating assertions

v8.0: **89%** pass rate · 3 flapping out of 63

  ⚠ score-calibrated · scoring · 6 flips/10 runs
    ✓✗✓✗✓✗✓✓✗✓
    belief: "score is calibrated against manual review"
    diagnosis: **threshold boundary** — score hovers at 88-92, pass threshold is 90
    fix: widen threshold to 85 or split into "score > 80" (hard floor) + "score > 90" (stretch)

  ⚠ learning-compounds · learning · 5 flips/10 runs
    ✓✓✗✓✗✓✗✓✓✗
    belief: "learning system produces compounding improvements"
    diagnosis: **environment-dependent** — depends on predictions.tsv having recent entries
    fix: pin to structural check (file has >N entries) instead of recency check

  ⚠ deploy-ready · deploy · 3 flips/10 runs
    ✓✓✓✓✗✓✗✓✓✗
    belief: "project is deployable"
    diagnosis: **implementation churn** — deploy pipeline actively changing
    fix: defer until deploy stabilizes, or narrow to "build succeeds"

/assert remove score-calibrated    remove the worst offender
/assert scoring: score > 85        replace with stable version
/assert health                     full health dashboard
```

---

## Anti-rationalization checks

These patterns indicate assertion gaming. Flag them when detected — during `health`, `coverage`, `suggest`, or `remove`.

**"Removing assertions because they fail"**
Failing assertions are the signal, not the problem. If someone requests removal of a failing assertion, print the warning and require explicit confirmation. The default is to fix the code, not remove the test.

**"All file_check assertions"**
If a feature's assertions are ALL file_check type, coverage is shallow. file_check proves existence, not quality. Flag: "**[feature]** has [N] assertions but they're all file_check — this proves files exist, not that they work. Consider adding a command_check or llm_judge."

**"100% pass rate with <3 assertions per feature"**
Not enough coverage to be meaningful. A feature with 1 assertion passing is not "tested" — it's "accidentally not broken." Flag: "**[feature]** has [N] assertion(s) at 100% — but [N] isn't enough to catch regressions. Consider `/assert suggest [feature]`."

**"Adding assertions to already-well-covered features"**
Diminishing returns. If a feature has 6+ assertions with 90%+ pass rate, new assertions add less value than covering an uncovered feature. Flag: "**[feature]** already has [N] assertions at [pct]%. Consider covering **[uncovered feature]** (w:[W], 0 assertions) instead."

---

## Tools to use

**Use Read** to read beliefs.yml, rhino.yml, todos.yml, assertion-health.json, eval-cache.json, assertion-history.tsv, and feature code files (for suggest mode)
**Use Edit** to append/remove beliefs, mark todos done on graduation, update assertion-health.json
**Use Bash** to run `rhino eval . --score --by-feature` for list mode, `git log` for staleness detection
**Use Grep** to check for duplicate ids before adding, scan assertion history, find code patterns

### Route-specific tool integration

**Health route:**
1. Run `rhino eval . --no-generative` via Bash to get live pass/fail data before computing health signals
2. Parse the output to populate the "live results" section of the health output
3. Cross-reference live results with assertion-history.tsv for sparkline generation

**Coverage route:**
1. Read `.claude/cache/eval-cache.json` for current sub-scores per feature
2. Run `rhino feature` via Bash to get current feature status and sub-score breakdown
3. Use both sources to compute the depth bars — assertions that map to high sub-score dimensions get full bars, low sub-score dimensions with assertions get partial bars

For output templates, see [reference.md](reference.md).

## What you never do
- Add duplicate ids — check existing beliefs first
- Add block severity without explicit request (default to warn)
- Create beliefs that are impossible to evaluate mechanically or by LLM
- Remove beliefs without confirming the id exists
- Remove failing beliefs without the anti-rationalization warning
- Modify eval.sh or score.sh (the eval harness is immutable)
- Graduate a todo without showing the proposed assertion first
- Suggest assertions for features that don't exist in rhino.yml
- Mark assertions as "stale" without checking git history for code changes
- Diagnose flapping with fewer than 10 eval runs — say "need more data" instead

## If something breaks

**beliefs.yml missing:** Create at `lens/product/eval/beliefs.yml` with a comment header. Inform: "No beliefs file — created one. Use `/assert feature: belief` to add assertions."

**Feature not in rhino.yml:** Still add the belief for quick-add. For health/coverage/suggest, skip that feature with a note.

**Ambiguous type detection:** Default to `llm_judge` with the full text as the prompt.

**Id collision:** Append a number (e.g., `auth-login-2`).

**Todo not found for graduation:** "Todo [id] not found. `/assert feature: text` to add directly."

**No assertion-health.json:** Generate fresh from beliefs.yml + assertion-history.tsv. If no history either, compute what's possible from beliefs.yml alone (type distribution, coverage by feature, orphan detection) and note: "Run `/eval` twice for trend data — flapping and staleness detection need history."

**No assertion-history.tsv:** Skip flapping and staleness analysis. Note: "No eval history. Run `/eval` twice for trend data."

**No eval-cache.json:** Skip dimension-level coverage mapping. Do structural analysis only (assertion types per feature, weight-adjusted counts). Note: "No eval cache. Run `/eval` to populate sub-scores for dimension mapping."

**No rhino.yml features section:** For quick-add/list/check/remove — works fine, features are optional. For health/coverage/suggest — "No features defined. Run `/feature new [name]` to enable coverage analysis."

$ARGUMENTS
