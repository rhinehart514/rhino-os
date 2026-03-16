---
name: calibrate
description: "Ground taste eval in founder preferences + design system. Interview, research, verify, track drift. /calibrate [profile|design-system|dimensions|verify|refresh|drift]"
argument-hint: "[profile|design-system|dimensions|verify|refresh|drift]"
context: fork
model: sonnet
---

# /calibrate

Extracted from /eval because calibration is a SETUP workflow, not measurement. It writes files, does research, interviews the founder — none of that belongs in a measurement command.

Runs in a forked context (`context: fork`) so the research, WebSearch results, and interview don't pollute the main conversation.

## What it produces

Three artifacts that make `/taste` smarter, plus a feedback loop that keeps them accurate:

1. **Founder taste profile** (`~/.claude/knowledge/founder-taste.md`) — what the founder loves/hates
2. **Design system doc** (`.claude/design-system.md`) — tokens, patterns, anti-slop rules
3. **Dimension knowledge** (`lens/product/eval/knowledge/*.md`) — grounded rubrics per dimension
4. **Calibration history** (`.claude/cache/calibration-history.json`) — tracking what calibrations happened and whether they helped

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| founder-taste | `~/.claude/knowledge/founder-taste.md` | R+W | Founder preferences |
| design-system | `.claude/design-system.md` | R+W | Design tokens + patterns |
| dimension-knowledge | `lens/product/eval/knowledge/*.md` | R+W | Per-dimension rubrics |
| taste-history | `.claude/evals/taste-history.tsv` | R | Past taste eval scores |
| taste-learnings | `.claude/evals/taste-learnings.md` | R | Taste intelligence |
| calibration-history | `.claude/cache/calibration-history.json` | R+W | Calibration tracking |
| taste-market | `.claude/evals/taste-market.json` | R | Market research cache |

## Routing

Parse `$ARGUMENTS`:

### No arguments -> full calibration
Run all three steps in sequence, then verify. If `founder-taste.md` already exists, show existing profile first and ask what to update — don't overwrite silently.

### `profile` -> founder interview only
Just step 1.

### `design-system` -> design system documentation only
Just step 2.

### `dimensions` -> dimension research only
Just step 3. Optionally followed by dimension names: `/calibrate dimensions hierarchy breathing_room`

### `verify` -> verify calibration is working
Run a taste eval with current calibration and check whether calibrated dimensions are scoring as expected. Compare calibrated vs uncalibrated dimensions. Check: do scores match founder expectations? Are calibrated dimensions more consistent across runs? Output: verification report with per-dimension before/after.

### `refresh` -> update existing founder profile
Re-run the interview questions, compare answers against existing `founder-taste.md`, show what changed as a diff. Don't overwrite — present deltas and let the founder confirm which updates to apply. If no `founder-taste.md` exists, redirect to full interview: "No existing profile. Running full calibration instead."

### `drift` -> check for calibration drift
Read `taste-history.tsv` and compare recent taste eval scores against `founder-taste.md` expectations. Flag dimensions where the gap between expected behavior and actual scores exceeds 20 points. Suggest recalibration for drifted dimensions. If no taste history exists, say so: "No taste eval history. Run `/taste <url>` first, then check for drift."

## Steps

### Step 1: Founder taste profile

Use AskUserQuestion to interview:

```
1. "Name 2-3 products whose visual design you love. What specifically about them?"
   (Not "clean" — specific: "Linear's density", "Arc's gradients", "Notion's whitespace")
2. "What visual patterns make you cringe?"
   (Generic dashboards, shadcn defaults, dark mode for dark mode's sake, etc.)
3. "When you look at your product right now, what's the one thing that bothers you most?"
```

If `founder-taste.md` already exists (and this is a `full` or `profile` route):
1. Read the existing file
2. Show the current preferences to the founder
3. Ask: "Here's your current taste profile. What's changed? Anything to add, remove, or update?"
4. Merge new preferences — don't overwrite the whole file

Write `~/.claude/knowledge/founder-taste.md`:

```markdown
# Founder Taste Profile

## Preferences
- Loves: [specific products + what about them]
- Hates: [specific patterns to avoid]
- Current pain: [what bothers them about their own product]

## Calibration
- [Product A] scores 4-5 on: [dimensions]
- Patterns to penalize: [what they hate -> dimension mappings]
- Patterns to reward: [what they love -> dimension mappings]

## Dimension Expectations
- [dimension]: founder expects [high/medium/low] — because [reason from interview]
- ...

## Last updated: [date]
```

### Step 2: Design system documentation

Auto-detect the project's visual language:

1. Read tailwind config (`tailwind.config.*`) — colors, spacing, radius, fonts, breakpoints
2. Read CSS variables (`:root` blocks in global CSS)
3. Scan 3-5 existing components — recurring patterns (cards, buttons, spacing, typography)
4. Read package.json for UI libraries

Write `.claude/design-system.md`:

```markdown
# Design System

## Tokens
- **Colors**: primary, secondary, accent, bg, surface
- **Spacing**: base unit, common gaps/padding
- **Radius**: cards, buttons, inputs
- **Shadows**: cards, modals, buttons
- **Typography**: headings, body, mono

## Component Patterns
- Cards: [exact classes]
- Buttons: [exact classes]
- Inputs: [exact classes]
- Nav: [exact classes]

## Rules (anti-slop)
- [Detected anti-patterns from codebase scan]

## Framework
- [Library + version + import patterns]
```

If no design system exists: say so honestly, propose a minimal one from what exists, ask founder.

### Step 3: Dimension knowledge

For each of the 11 taste dimensions, create `lens/product/eval/knowledge/[dimension].md`:

Use WebSearch to research what makes each dimension excellent in real products:

```markdown
# [Dimension Name]

## Patterns (what good looks like)
- [Specific pattern]: [product example]

## Anti-Patterns (what bad looks like)
- [Specific anti-pattern]: [why it fails]

## Scoring Guide
- 5: [concrete description with examples]
- 3: [concrete description]
- 1: [concrete description]
```

Prioritize dimensions the founder cares most about (from step 1).

The 11 dimensions: `hierarchy`, `breathing_room`, `contrast`, `polish`, `emotional_tone`, `information_density`, `wayfinding`, `distinctiveness`, `scroll_experience`, `layout_coherence`, `information_architecture`

### Step 4: Verify

Run `/taste <url>` to test with new knowledge (the taste skill reads founder-taste.md, design-system.md, and dimension knowledge automatically). Compare against previous taste report if one exists. If no URL is known, ask the founder for their product URL or localhost port.

## Verify Route Protocol

When running the `verify` route specifically:

1. **Read current calibration state**:
   - `~/.claude/knowledge/founder-taste.md` — what does the founder expect?
   - `.claude/design-system.md` — what tokens are documented?
   - `lens/product/eval/knowledge/*.md` — which dimensions have knowledge files?
   - `.claude/evals/taste-history.tsv` — recent taste eval scores

2. **Identify calibrated vs uncalibrated dimensions**:
   - Calibrated = has a knowledge file in `lens/product/eval/knowledge/`
   - Uncalibrated = no knowledge file

3. **Run a taste eval** (invoke `/taste <url>`) with current calibration

4. **Compare results against founder expectations**:
   - For each dimension in `founder-taste.md` with an expectation, check: does the taste eval score align?
   - Gap < 10 points = calibrated well
   - Gap 10-20 points = acceptable, note for monitoring
   - Gap > 20 points = miscalibrated, needs recalibration

5. **Check consistency**:
   - If 2+ past taste evals exist, compare score variance per dimension
   - Calibrated dimensions should have lower variance than uncalibrated ones
   - If calibrated dimensions have HIGHER variance, the calibration is adding noise, not signal

6. **Output verification report**:
```
◆ calibrate verify

  ▸ calibration state
    founder profile: [exists/missing] (last updated: [date])
    design system: [exists/missing]
    dimensions calibrated: [N]/11
      calibrated: hierarchy, breathing_room, contrast, ...
      uncalibrated: emotional_tone, scroll_experience, ...

  ▸ alignment check (founder expectations vs actual scores)
    [dimension]   expected: [high/med/low]   actual: [score]   [aligned/misaligned]
    ...

  ▸ consistency check (calibrated vs uncalibrated variance)
    calibrated avg variance: [N] points
    uncalibrated avg variance: [N] points
    [verdict: calibration is reducing/increasing/not affecting consistency]

  ▸ misaligned dimensions (gap > 20)
    [dimension]: founder expects [X], taste scores [Y] — recalibrate with /calibrate dimensions [name]

  ▸ verdict
    [summary: calibration is working / partially working / needs attention]

  next: /calibrate dimensions [list]   fix misaligned dimensions
        /calibrate refresh             update founder preferences
        /taste <url>                   re-evaluate with fixes
```

7. **Record verification** in calibration-history.json with `verification_score` = % of dimensions aligned

## Refresh Route Protocol

When running the `refresh` route:

1. **Check for existing profile**: if `~/.claude/knowledge/founder-taste.md` does not exist, redirect: "No existing profile found. Running full calibration instead." Then execute the full calibration route.

2. **Read existing profile**: parse current preferences, calibration mappings, dimension expectations

3. **Re-run interview questions** (same 3 questions as Step 1)

4. **Show deltas** — don't overwrite:
```
◆ calibrate refresh

  ▸ current profile (from [date])
    loves: Linear's density, Arc's gradients
    hates: generic dashboards, shadcn defaults
    pain: navigation feels buried

  ▸ new answers
    loves: Linear's density, Vercel's typography [NEW]
    hates: generic dashboards [UNCHANGED], dark mode for dark mode's sake [NEW]
    pain: information density is too low now [CHANGED from "navigation feels buried"]

  ▸ proposed changes
    + add "Vercel's typography" to loves
    + add "dark mode for dark mode's sake" to hates
    ~ update pain: "navigation feels buried" -> "information density is too low now"
    - remove nothing

  confirm these updates? (y/n, or specify which to apply)
```

5. **Wait for confirmation** via AskUserQuestion before writing

6. **Update dimension expectations** based on changed preferences — if the founder's pain shifted from navigation to density, the dimension expectations for `wayfinding` and `information_density` should update

7. **Record refresh** in calibration-history.json

## Drift Route Protocol

When running the `drift` route:

1. **Check prerequisites**:
   - `~/.claude/knowledge/founder-taste.md` must exist — if not: "No founder profile. Run `/calibrate profile` first."
   - `.claude/evals/taste-history.tsv` must exist — if not: "No taste eval history. Run `/taste <url>` first, then check for drift."

2. **Read founder expectations** from `founder-taste.md` — parse dimension expectations and calibration mappings

3. **Read recent taste scores** from `taste-history.tsv` and `reports/taste-*.json` — get the last 3-5 evaluations

4. **Compute drift per dimension**:
   - Map founder expectations (high/medium/low) to score ranges: high = 70+, medium = 40-69, low = 0-39
   - Compare against average of recent taste scores for that dimension
   - Drift = gap between expected range midpoint and actual average

5. **Check for stale calibration**:
   - If `founder-taste.md` last updated > 30 days ago AND taste scores have shifted significantly (avg delta > 15 across dimensions), flag: "Founder preferences may have evolved. `/calibrate refresh`"
   - If any dimension knowledge file in `lens/product/eval/knowledge/` hasn't been updated in 30+ days AND that dimension's taste scores are consistently < 40, flag as stale: "[dimension].md is [N] days old and scores are low — knowledge may be outdated"

6. **Check for calibration effectiveness**:
   - If calibration-history.json has 3+ entries, compute: which calibrations led to score improvements? Which had no effect?
   - Report effectiveness per calibration type

7. **Output drift report**:
```
◆ calibrate drift

  ▸ drift detection (founder expectations vs recent scores)
    [dimension]   expected: [range]   recent avg: [score]   drift: [±N]   [ok/drifted]
    ...

  ▸ drifted dimensions (gap > 20)
    [dimension]: expected [range], scoring [avg]. Recalibrate: /calibrate dimensions [name]
    ...

  ▸ stale calibration files
    [dimension].md: last updated [date] ([N] days ago), scores avg [X] — refresh recommended
    ...

  ▸ calibration effectiveness (last [N] calibrations)
    [date] [type]: [dimensions] — [improved/no effect/unknown]
    ...

  ▸ founder profile freshness
    last updated: [date] ([N] days ago)
    [fresh / stale — recommend /calibrate refresh]

  next: /calibrate dimensions [list]   fix drifted dimensions
        /calibrate refresh             update founder preferences
        /calibrate verify              full verification
```

## Calibration History Protocol

After EVERY calibration action (full, profile, design-system, dimensions, verify, refresh, drift), append to `.claude/cache/calibration-history.json`:

```json
{
  "calibrations": [
    {
      "date": "2026-03-16",
      "type": "full|profile|design-system|dimensions|verify|refresh|drift",
      "dimensions_calibrated": ["hierarchy", "breathing_room"],
      "verification_score": null,
      "drift_detected": [],
      "effectiveness": null,
      "notes": ""
    }
  ]
}
```

If the file doesn't exist, create it with an empty `calibrations` array and note "Tracking calibration from now."

After 3+ taste evals post-calibration, compute effectiveness: which dimension calibrations actually improved score consistency? Which had no effect? Update the most recent matching calibration entry with `effectiveness` scores:

```json
"effectiveness": {
  "hierarchy": {"before_avg": 42, "after_avg": 58, "improved": true},
  "breathing_room": {"before_avg": 55, "after_avg": 53, "improved": false}
}
```

## Learning Additions

The calibration system learns from its own performance:

### Drift detection
Compare recent taste scores against `founder-taste.md` expectations. If gap > 20 on any dimension, flag for recalibration. Drift is natural — founder taste evolves, products change, market standards shift. The system should detect it, not prevent it.

### Effectiveness tracking
After calibration, did taste eval accuracy improve? Track in `calibration-history.json`. If a calibration type consistently shows no effect (3+ instances with `improved: false`), flag: "Dimension knowledge for [X] isn't helping. Try a different approach — market research, founder re-interview, or reference product comparison."

### Continuous refinement
Every `verify` or `drift` check produces actionable next steps for dimensions that need recalibration. These should be specific: not "recalibrate hierarchy" but "hierarchy knowledge file emphasizes whitespace patterns but founder prefers density — update knowledge file to match."

### Self-improvement
If a dimension's knowledge file hasn't been updated in 30+ days but taste scores for that dimension are consistently low (< 40 across 3+ evals), flag as stale: "The knowledge for [dimension] was written [N] days ago. Scores haven't improved. The knowledge may be wrong, not just old."

## Output

```
◆ calibrate

  ✓ founder profile written (3 preferences, 2 anti-patterns)
  ✓ design system documented (.claude/design-system.md)
    tokens: 5 color, 4 spacing, 3 radius, 2 shadow, 3 typography
    components: card, button, input, nav (4 patterns)
    rules: 6 anti-slop rules
  ✓ dimension knowledge: 4/11 dimensions researched
    hierarchy ✓  breathing_room ✓  distinctiveness ✓  polish ✓
    contrast ·  emotional_tone ·  information_density ·
    wayfinding ·  scroll_experience ·  layout_coherence ·  information_architecture ·

  calibration: founder prefers [Linear-style density] over [Notion-style whitespace]
  → taste will penalize breathing_room > 4 (founder finds sparse layouts empty)
  → taste will reward information_density >= 3 (founder wants data-rich UIs)

  ✓ calibration logged to .claude/cache/calibration-history.json

/taste <url>                    run with calibrated knowledge
/calibrate dimensions           fill remaining 7 dimensions
/calibrate verify               check if calibration is working
/calibrate drift                check for score drift over time
/calibrate refresh              update founder preferences
```

## Tools to use

**Use AskUserQuestion** for founder interview (profile, refresh)
**Use WebSearch** for dimension research
**Use Read** to detect design system from codebase, read taste history, read calibration state
**Use Write/Edit** to create knowledge files, design-system.md, calibration-history.json
**Invoke `/taste <url>`** to verify calibration (taste skill uses Playwright MCP natively)
**Use Glob** to find dimension knowledge files, taste report files

## Anti-rationalization checks

Before acting, check for these failure modes:

- **"Calibrating without verification"** — always verify after calibration. A calibration that's never tested is just documentation. If the founder runs `full`, `profile`, `design-system`, or `dimensions` without a subsequent `verify`, suggest it in the output: "Run `/calibrate verify` to check if this calibration is actually helping."

- **"All dimensions calibrated to founder preference"** — founder preferences are inputs, not truth. Market references matter too. If all dimensions are calibrated to "what founder likes" without market grounding, flag: "Calibration is founder-biased. `/calibrate dimensions` with market research to balance."

- **"Calibration inflation"** — if calibrated dimensions consistently score higher than uncalibrated ones across 3+ taste evals, the calibration may be sycophantic. Flag: "Calibrated dimensions score [N]% higher on average — check if this reflects real quality or calibration bias."

- **"Stale calibration"** — if `founder-taste.md` is > 30 days old and taste scores have changed significantly, flag: "Founder preferences may have evolved. `/calibrate refresh`"

## What you never do
- Skip the founder interview — generic calibration is useless
- Write vague dimension knowledge — "good hierarchy means clear structure" is garbage
- Modify taste.mjs or skills/taste/SKILL.md — the eval harness is immutable
- Run calibration silently — always show what was written and where
- Overwrite founder-taste.md without showing what changed — always diff, always confirm
- Skip calibration-history.json logging — every action gets recorded
- Ignore drift signals — if drift is detected during any route, mention it even if the founder didn't ask

## Degraded Modes

Not everything will be available. Handle gracefully:

- **No taste-history.tsv** — "No taste eval history. Run `/taste <url>` first, then verify calibration." (Blocks `verify` and `drift` routes from producing meaningful results. `full`, `profile`, `design-system`, `dimensions` work fine.)
- **No calibration-history.json** — create empty structure: `{"calibrations": []}`. Note "Tracking calibration from now."
- **No taste-learnings.md** — note "No taste intelligence yet — calibration verification will be limited to founder expectations only, no trend data."
- **WebSearch fails** — dimension knowledge from codebase patterns + existing reference products only. Note "uncalibrated against market — WebSearch unavailable."
- **No founder-taste.md + `refresh` route** — redirect to full interview: "No existing profile. Running full calibration instead."
- **No founder-taste.md + `drift` route** — "No founder profile to drift from. Run `/calibrate profile` first."
- **founder-taste.md exists + `full` calibration** — show existing profile, ask what to update. Don't silently overwrite.
- **No tailwind or CSS variables** — document "no design system detected" honestly in design-system.md. Propose minimal tokens from whatever exists. Ask founder.
- **No lens/product/ directory** — taste isn't installed, suggest `/skill install product-lens`
- **No dimension knowledge files + `verify`** — "No dimensions calibrated yet. Run `/calibrate dimensions` first, then verify."
- **< 3 taste evals + effectiveness tracking** — "Need 3+ taste evals to compute effectiveness. Run more `/taste <url>` evaluations."

$ARGUMENTS
