---
name: taste
description: "Product intelligence — visual + system design + calibration. Playwright sees the product, code reading understands the architecture. 11 dimensions, 0-100, gets smarter over time. Calibrate to ground eval in founder preferences."
argument-hint: "<url> [mobile|vs <url>|deep|trend|calibrate [profile|design-system|verify|drift]]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebSearch, WebFetch, Agent, mcp__playwright__browser_navigate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_wait_for, mcp__playwright__browser_click, mcp__playwright__browser_hover, mcp__playwright__browser_resize, mcp__playwright__browser_evaluate, mcp__playwright__browser_network_requests, mcp__playwright__browser_install
---

# /taste — Product Intelligence

You are a first-time user with 40 tabs open. You will leave in 5 seconds if you don't understand what this is.

You evaluate TWO layers: what the user SEES (Playwright) and what the user EXPERIENCES (code reading). Visual quality without system coherence is decoration. System coherence without visual quality is engineering. You measure both.

## Routing

Parse `$ARGUMENTS`:

- `<url>` — full evaluation (visual + system)
- `<url> mobile` — resize to 390x844 before navigating
- `<url> deep` — click through flows, test interactions
- `vs <url1> <url2>` — side-by-side comparison
- `trend` — taste trajectory from history
- `calibrate [profile|design-system|verify|drift]` — calibration (see below)
- No arguments → show help text:
  ```
  /taste <url>              full evaluation (visual + system design)
  /taste <url> mobile       mobile-first (390x844)
  /taste vs <url1> <url2>   side-by-side comparison
  /taste <url> deep         interactive flow audit
  /taste trend              trajectory over time
  /taste calibrate          full calibration (interview + design system + dimensions)
  /taste calibrate profile  founder taste preferences only
  /taste calibrate design-system  extract/update design system from codebase
  /taste calibrate verify   check current eval against calibration
  /taste calibrate drift    detect when founder preferences have shifted
  ```

---

### `calibrate` → Ground taste eval in founder preferences

Runs in the main context (not forked — needs AskUserQuestion for interview).

Parse the sub-argument after `calibrate`:

#### No sub-argument → full calibration
Run all steps in sequence (profile, design-system, dimensions), then verify. If `founder-taste.md` already exists, show existing profile first and ask what to update — don't overwrite silently.

#### `profile` → founder interview only

Use AskUserQuestion to interview:

```
1. "Name 2-3 products whose visual design you love. What specifically about them?"
   (Not "clean" — specific: "Linear's density", "Arc's gradients", "Notion's whitespace")
2. "What visual patterns make you cringe?"
   (Generic dashboards, shadcn defaults, dark mode for dark mode's sake, etc.)
3. "When you look at your product right now, what's the one thing that bothers you most?"
```

If `founder-taste.md` already exists:
1. Read the existing file
2. Show current preferences to the founder
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

#### `design-system` → extract/update design system from codebase

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

#### `verify` → check current eval against calibration

1. Read current calibration state: `~/.claude/knowledge/founder-taste.md`, `.claude/design-system.md`, `lens/product/eval/knowledge/*.md`, `.claude/evals/taste-history.tsv`
2. Identify calibrated vs uncalibrated dimensions (calibrated = has knowledge file)
3. Run a taste eval and compare results against founder expectations
4. Gap < 10 = aligned, 10-20 = acceptable, > 20 = miscalibrated
5. Check consistency: calibrated dimensions should have lower variance than uncalibrated
6. Output verification report with per-dimension alignment status
7. Record verification in `.claude/cache/calibration-history.json`

#### `drift` → detect when founder preferences have shifted

1. Check prerequisites: `founder-taste.md` must exist, `taste-history.tsv` must exist
2. Read founder expectations and recent taste scores (last 3-5 evals)
3. Map expectations to ranges: high = 70+, medium = 40-69, low = 0-39
4. Compute drift per dimension (gap between expected range midpoint and actual average)
5. Flag dimensions where drift > 20 points for recalibration
6. Check for stale calibration (profile > 30 days old + significant score shifts)
7. Output drift report with per-dimension status

#### Dimension research (part of full calibration)

For each of the 11 taste dimensions, create `lens/product/eval/knowledge/[dimension].md`:

Use WebSearch to research what makes each dimension excellent. Cite sources explicitly.

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

## Sources
- [URL 1] — [what was learned]
```

Prioritize dimensions the founder cares most about (from profile step).

The 11 dimensions: `hierarchy`, `breathing_room`, `contrast`, `polish`, `emotional_tone`, `information_density`, `wayfinding`, `distinctiveness`, `scroll_experience`, `layout_coherence`, `information_architecture`

#### Calibration state artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| founder-taste | `~/.claude/knowledge/founder-taste.md` | Founder preferences |
| design-system | `.claude/design-system.md` | Design tokens + patterns |
| dimension-knowledge | `lens/product/eval/knowledge/*.md` | Per-dimension rubrics |
| calibration-history | `.claude/cache/calibration-history.json` | Calibration tracking |

After every calibration action, append to `.claude/cache/calibration-history.json`. If the file doesn't exist, create it with `{"calibrations": []}`.

#### Calibration output format

```
◆ taste calibrate

  --- founder profile ---

  ✓ written to ~/.claude/knowledge/founder-taste.md
    preferences: 3 loves, 2 anti-patterns
    pain: [current pain point]

  --- design system ---

  ✓ written to .claude/design-system.md
    tokens:      5 color, 4 spacing, 3 radius, 2 shadow, 3 typography
    components:  card, button, input, nav (4 patterns)
    rules:       6 anti-slop rules

  --- dimension knowledge ---

  calibrated: ████████░░░░  4/11
    hierarchy          ✓ researched
    breathing_room     ✓ researched
    ...

  ✓ calibration logged to .claude/cache/calibration-history.json

  next: /taste <url>                  run with calibrated knowledge
        /taste calibrate verify       check if calibration is working
        /taste calibrate drift        check for score drift over time
```

#### Anti-rationalization checks

- **Calibrating without verification** — always suggest `/taste calibrate verify` after calibration
- **All dimensions calibrated to founder preference** — founder preferences are inputs, not truth. Market references matter too
- **Calibration inflation** — if calibrated dimensions consistently score higher, flag possible sycophancy
- **Stale calibration** — if `founder-taste.md` is > 30 days old and scores shifted, flag for refresh

#### Calibration degraded modes

- **No taste-history.tsv** — blocks `verify` and `drift` from producing meaningful results
- **No founder-taste.md + drift** — "No founder profile to drift from. Run `/taste calibrate profile` first."
- **No tailwind or CSS** — document "no design system detected" honestly, propose minimal tokens
- **WebSearch fails** — dimension knowledge from codebase patterns only, note "uncalibrated against market"

---

## Phase 1: Load Context

Read these in parallel (skip missing files silently):

**Intelligence sources:**
- `.claude/evals/taste-learnings.md` — accumulated taste intelligence (most important)
- `~/.claude/knowledge/taste-knowledge/` — per-dimension research
- `~/.claude/knowledge/founder-taste.md` — founder preferences
- `.claude/evals/taste-market.json` — cached market context
- `.claude/design-system.md` — project visual rules (deviations are bugs)
- `config/rhino.yml` — features, code paths, stage

**Past evaluations:**
- `.claude/evals/taste-history.tsv` — score history
- `.claude/evals/reports/taste-*.json` — most recent full report (glob for latest)

If past evaluations exist, note weakest dimensions and which prescriptions were given.

**Market calibration:**
- Read `.claude/evals/taste-market.json` if it exists. Do NOT WebSearch for market research — it produces garbage from SEO content.
- If no market context exists, note "uncalibrated — run /research or /calibrate for market context" in output.

## Phase 2: See the Product

Navigate the landing page + 2 key routes (3 pages max). Prioritize: landing, primary CTA destination, one secondary route.

For each page:
- `browser_navigate` to the URL
- `browser_wait_for` with `time: 3`
- `browser_snapshot` — DOM structure, ARIA, headings, links
- `browser_take_screenshot` — Playwright returns the image inline. Do NOT try to Read screenshot files separately.

Extract internal navigation links from the snapshot to choose the 2 follow-up routes.

For `mobile` mode: `browser_resize` to 390x844 before navigating.

For `deep` mode: after screenshots, also hover nav items, click the primary CTA, snapshot after interaction. Report what happened and how it felt.

## Phase 3: Read the System

For system layer dimensions (information_architecture, layout_coherence, wayfinding, information_density), you need code context — screenshots alone are insufficient.

From `config/rhino.yml` features, read:
- Route definitions (Next.js pages/, app/, or router config)
- Navigation components (nav, sidebar, header, footer)
- Layout components (shared layouts, wrappers)
- Data flow patterns (what links to what, how state moves)

Use Glob and Read to find these. Look for patterns: How many routes exist? Is there a shared layout? Does navigation reach all destinations? Is information organized by a principle you can name in one sentence?

## Phase 4: Score 11 Dimensions

Score each 0-100. Provide first-person evidence for every score. Cite DOM data where relevant.

**Calibration anchors:**
- **90-100** = Indistinguishable from best-in-class references. Extremely rare for early-stage.
- **70-89** = Intentional choices visible. Would earn a positive comment.
- **50-69** = Functional but unremarkable. Most products live here.
- **30-49** = Noticeable friction. Below market standard.
- **0-29** = Broken or hostile.

Expected distribution for early-stage: mostly 35-60, maybe one 70+.

### Gate Dimensions (score first — they cap everything)

**LAYOUT_COHERENCE** (0-100)
Same grid? Same spacing system? Same component sizing across pages? Scored from screenshots AND layout code.

**INFORMATION_ARCHITECTURE** (0-100)
Can you describe the organizing principle in one sentence? Does nav reach all destinations? Scored from snapshots AND route/nav code.

### Visual Dimensions (from screenshots)

**HIERARCHY** — Do I know what this is and where to look?
**BREATHING_ROOM** — Does this feel calm or chaotic?
**CONTRAST** — Can I tell what's clickable?
**POLISH** — Does this feel like someone cared?
**EMOTIONAL_TONE** — Would I tell a friend about this?
**DISTINCTIVENESS** — Would I recognize this tomorrow?
**SCROLL_EXPERIENCE** — Does scrolling feel intentional?

### System Dimensions (from code + screenshots)

**WAYFINDING** — Do I know what to do next? (requires understanding nav model + data flow)
**INFORMATION_DENSITY** — Am I informed or overwhelmed? (requires understanding what data is shown and why)

## Phase 5: Check Integrity

**Overall score formula:**
```
overall = mean(all 11 dimensions)
```

**GATE RULE:** If layout_coherence < 30 OR information_architecture < 30, overall capped at 30.

**SLOP RULE:** For each page — "Could this have been generated by prompting an AI with 'build me a [feature] page'?" If YES, distinctiveness capped at 30. Slop signals: generic card grids + rounded corners, every-shadcn-app energy, layout that works for ANY product. Anti-slop: element that only makes sense for THIS product, microcopy with personality, domain-specific display.

**Anti-inflation checks:**
- Avg > 70 for non-mature products → flag `GENEROUS`
- Min > 65 → flag `NO_WEAKNESS`
- All scores within 10pts → flag `FLAT_EVAL`
- Gate < 30 but overall > 30 → enforce cap
- Jump > 25pts from last eval → flag `SUSPICIOUS_JUMP`
- If unsure between two scores, pick the LOWER one

## Phase 6: Prescribe

For every dimension < 60, provide:
- **What element**: specific CSS selector or DOM element from snapshot
- **What change**: exact CSS property, structural change, or content change
- **Impact estimate**: which dimension improves, from what to what (e.g., "breathing_room 35 to 55")

Ground prescriptions in actual DOM data. You have computed styles — cite them.

## Phase 7: Compare

If past evaluations exist:
- Delta per dimension: `previous to current (+/-delta)`
- Which past prescriptions were followed vs ignored
- Trend direction per dimension: improving, stuck, or regressing

## Phase 8: Remember

**Write report JSON** to `.claude/evals/reports/taste-{YYYY-MM-DD}.json`:
```json
{
  "url": "<URL>",
  "timestamp": "<ISO>",
  "overall": 0,
  "dimensions": {
    "<name>": {
      "score": 0,
      "previous": null,
      "delta": null,
      "evidence": "<first-person>",
      "prescription": "<fix or null>"
    }
  },
  "gates": { "layout_coherence": 0, "information_architecture": 0, "capped": false },
  "slop": { "detected": false, "pages": [], "anti_slop": [] },
  "strongest": "<dimension + why>",
  "weakest": "<dimension + why>",
  "would_return": "<yes/no + reason>",
  "one_thing": "<highest-impact change>",
  "top_3_fixes": [{ "element": "", "change": "", "impact": "" }],
  "routes_evaluated": 0,
  "meta": { "mode": "standard", "market_research": "cached|none", "has_past_eval": false }
}
```

**Append to TSV** `.claude/evals/taste-history.tsv` (create with header if missing):
```
date	url	overall	hierarchy	breathing_room	contrast	polish	emotional_tone	information_density	wayfinding	distinctiveness	scroll_experience	layout_coherence	information_architecture
```

**Update taste-learnings.md** — append new entry, prune to max 5 entries:
```markdown
## <date> — <url>
Overall: <score>/100 (previous: <prev>, delta: <+/-N>)
Weakest: <dimension> at <score> — <why>
Strongest: <dimension> at <score> — <why>
Followed: <list or "first eval">
Ignored: <list or "first eval">
Surprise: <anything unexpected>
Learning: <one sentence>
```

## Phase 9: Present

```
◆ taste — <url>                              <category>
  calibrated against: <refs or "uncalibrated">

  overall   <score>/100  <bar>  [+/-delta]

  ▸ gates
    layout_coherence         <score>/100  [+/-delta]  <evidence>
    information_architecture <score>/100  [+/-delta]  <evidence>
    [CAPPED AT 30 — fix the skeleton before decorating] if applicable

  ▸ dimensions (weakest first)
    <dim>   <score>/100  [+/-delta]  <evidence>
                          rx: <prescription>

  ▸ slop check
    <page>: <verdict>

  ▸ top 3 fixes
    1. <element> → <change> → <dim> +<N>pts
    2. ...
    3. ...

  ▸ trend (if past data exists)
    improving: <dims going up>
    stuck: <dims unchanged 3+ evals>
    regressing: <dims going down>

  ▸ past prescriptions (if past data exists)
    followed: <what was fixed>
    ignored: <what wasn't — and the cost>

  verdict: <would_return + one_thing>
  next: /taste <url> to re-evaluate. /todo to capture fixes.
```

---

## Trend Mode

When `trend` is the argument:

Read `.claude/evals/taste-history.tsv` and `.claude/evals/reports/taste-*.json` and `.claude/evals/taste-learnings.md`.

If < 2 evals: "Run `/taste <url>` once more for trend data."

Classify each dimension:
- **improving**: delta > 10 over window
- **slow**: delta 5-10
- **stable**: delta 1-4
- **stuck**: delta < 1 over 3+ evals — "current approach exhausted"
- **regressing**: negative delta between consecutive evals

Present overall trajectory, per-dimension trends, prescription effectiveness rate. Update taste-learnings.md if prescriptions are consistently wrong about a dimension.

## Comparative Mode (vs)

Evaluate both products on all 11 dimensions. Present gap per dimension, "steal list" of specific things each should take from the other, and verdict on where the gap matters most.

## Boundaries

**DO write to:**
- `.claude/evals/taste-learnings.md` (own memory)
- `.claude/evals/taste-history.tsv` (own data)
- `.claude/evals/reports/taste-*.json` (own artifacts)

**Do NOT write to:**
- `.claude/plans/todos.yml` — output prescriptions, let the founder or /todo handle it
- `~/.claude/knowledge/predictions.tsv` — that's /retro
- Any file outside `.claude/evals/`

## Errors

- Playwright not installed: `mcp__playwright__browser_install`
- URL won't load: report error, check auth or localhost status
- Auth required: check `.claude/taste.yml` for config
- No past evaluations: "first evaluation — establishing baseline"

$ARGUMENTS
