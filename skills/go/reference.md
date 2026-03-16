# /go Reference — Output Templates & Beta Features

Loaded on demand. Loop logic and routing are in SKILL.md.

---

## Output format

### During the loop — after each move (safe mode):

```
◆ move 1 — error boundary hardening

  predict: quality_score +15 (50→65) from wrapping file I/O in try/catch
  because: Known Pattern — error handling is mechanical, high keep rate
  wrong if: subprocess calls need different error handling than file I/O

  result:  quality_score +8 (50→58). File I/O paths covered, subprocess paths still open.
  verdict: ✓ kept (scoring 58 → 63, v:62→68 q:50→58 u:60→65)

  graded: **partial** — subprocess error handling needs separate approach
  model update: file I/O and subprocess error handling are different patterns (Uncertain)
```

### During the loop — after each move (beta mode with speculation):

```
◆ move 2 — trend visualization  [SPECULATIVE]

  predict: value_score +10 from adding sparkline to score output
  because: Exploring — no data on visualization impact
  wrong if: users don't look at score output at all

  ▾ speculative branching (2 approaches)
    branch A: inline ASCII sparkline in score output
      agent: worktree-a (builder)
      result: value_score +6 (62→68), quality_score -2 (58→56)
      reviewer: KEEP — clean implementation, minor string formatting issue

    branch B: separate `rhino trend` command with full chart
      agent: worktree-b (builder)
      result: value_score +3 (62→65), quality_score +0 (58→58)
      reviewer: KEEP_WITH_FIXES — missing error handling for empty history

  winner: **branch A** (+6 value vs +3, quality regression is minor)
  verdict: ✓ kept (scoring 58 → 64)

  graded: **partial** — value improved but less than predicted (+6 vs +10)
  model update: visualization helps but inline is better than separate command (Uncertain)
```

### During the loop — adversarial review triggered revert:

```
◆ move 3 — auto-grade predictions

  predict: learning feature +12 from wiring auto-grade into session_start hook
  because: Uncertain Pattern — session_start hook is fragile (self.md)
  wrong if: hook modification breaks boot sequence

  result: assertions stable (no regression)
  reviewer: **REVERT** — hook now runs grade.sh on every session start,
    adding 2-3s latency. Silent failure at grade.sh:45 when predictions.tsv
    is empty (first session). No graceful degradation.

  verdict: ✗ reverted (assertions stable but reviewer found real problems, no value gained)

  graded: **no** — hook fragility confirmed
  model update: session_start hook is confirmed fragile — needs tests before modification (→ Known Pattern)
```

### When the loop ends:

```
◆ go — session complete [BETA]

  v8.0: **48%** → **55%** ↑7 · score: 58 → 66 ↑8
  moves: **3** completed · 1 reverted · 1 speculative
  predictions: 2/3 correct (67%)
  mode: beta (speculative branching + adversarial review)

▾ product map (after)
  scoring    ████████████████░░░░  working   w:5  58→66 ↑8
  commands   ████████████████░░░░  working   w:5  70→70 —
  learning   ██████░░░░░░░░░░░░░░  building  w:4  48→48 —  ← bottleneck
  install    ████████████████████  polished  w:3

▾ what changed
  ✓ move 1: error boundary hardening (+5 scoring, q:50→58)
  ✓ move 2: trend visualization via sparkline (+6 scoring, v:62→68) [speculated, branch A won]
  ✗ move 3: auto-grade predictions (reverted — reviewer caught hook fragility)

▾ maturity updates
  · scoring: working → working (improved but not all assertions passing yet)

▾ model updates
  · file I/O vs subprocess error handling are different patterns (Uncertain → needs confirmation)
  · inline visualization > separate commands (Uncertain)
  · session_start hook confirmed fragile (Uncertain → Known Pattern)

▾ beta metrics
  speculative moves: 1/3 (branch A beat branch B by +3 points)
  adversarial overrides: 0 (reviewer agreed with measurement on keeps)
  adversarial catches: 1 (move 3 — real problem measurement missed)
  token cost: ~3.2x safe mode

bottleneck: **learning** (building, w:4) — unchanged, needs different approach

/eval full         validate session results
/ideate learning   current approach exhausted
/retro             grade session predictions
```

### Safe mode session end:

```
◆ go — session complete [SAFE]

  v8.0: **48%** → **52%** ↑4 · score: 58 → 62 ↑4
  moves: **2** completed · 0 reverted
  predictions: 2/2 correct (100%)
  mode: safe (sequential, no beta features)

▾ what changed
  ✓ move 1: error boundary hardening (+3 scoring)
  ✓ move 2: output formatting cleanup (+1 scoring)

bottleneck: **learning** (building, w:4)

/go learning       work on the bottleneck
/eval              measure current state
/plan              next session
```

## Formatting rules

- Per-move: `◆ move N — [title]`, predict/because/wrong-if, result/verdict, graded/model-update
- Speculative moves: show both branches with scores, name the winner
- Adversarial catches: show the reviewer's specific concerns with file:line
- Session summary: moves count, eval trajectory with sub-score deltas, prediction accuracy
- Beta metrics section: only shown in beta mode
- What changed: ✓/✗ per move, sub-score deltas, [speculated] tag if applicable
- Model updates: formatted as experiment-learnings entries with confidence level
- Bottleneck: bold feature name, one-sentence diagnosis
- Bottom: 2-3 relevant next commands

## Session log format

Written to `.claude/sessions/YYYY-MM-DD-HH.yml` when loop ends. See SKILL.md for full schema.

Key fields for beta tracking:
- `mode: beta|safe` — which mode was used
- `speculated: N` — how many moves used speculative branching
- `adversarial_overrides: N` — times measurement overruled reviewer
- `adversarial_catches: N` — times reviewer caught problems measurement missed
- `features_changed` includes sub-score breakdown: `{before, after, value: [before,after], quality: [before,after], ux: [before,after]}`

## Beta feature tracking

After each session, evaluate beta features:

**Speculative branching:**
- Did the winner beat what a single approach would have produced?
- Track: `speculative_delta` = winner score - (estimated single-approach score)
- Kill if: speculative_delta < 2 after 5+ speculative moves (not worth the tokens)
- Promote if: speculative_delta > 5 consistently

**Adversarial review:**
- Track: `adversarial_catches` / total moves = catch rate
- Kill if: catch rate < 10% after 10+ moves (not finding real problems)
- Promote if: catch rate > 25% (finding problems measurement misses)

**Mechanical prediction grading:**
- Track: prediction accuracy over sessions (already in predictions.tsv)
- Compare: accuracy in sessions WITH enforcement vs WITHOUT
- Promote if: accuracy improves or holds with less manual effort
- This one probably just stays — the learning loop breaks without it
