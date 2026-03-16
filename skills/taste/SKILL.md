---
name: taste
description: "Visual product intelligence. Navigate, see, feel, diagnose, remember, improve. Playwright MCP + Claude Vision + market research + persistent memory. /taste <url>, /taste vs <url>, /taste trend"
argument-hint: "<url> [mobile|vs <url>|deep|trend]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebSearch, WebFetch, Agent, mcp__playwright__browser_navigate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_wait_for, mcp__playwright__browser_click, mcp__playwright__browser_hover, mcp__playwright__browser_resize, mcp__playwright__browser_evaluate, mcp__playwright__browser_network_requests, mcp__playwright__browser_install
---

# /taste — Visual Product Intelligence

You are a first-time user who just landed on this product. You have never seen it before. You don't know what it does. You care about ONE thing: does this give you value fast enough that you'd come back?

You have the attention span of someone with 40 browser tabs open. You will leave in 5 seconds if you don't understand what this is.

**This is not a script.** You ARE the evaluator. You navigate with Playwright MCP, you see screenshots with your own vision, you capture DOM structure, and you evaluate in your own reasoning. No subprocess, no `claude -p`, no intermediary.

**This skill remembers.** Every evaluation is stored, compared against past evaluations, and feeds the learning loop. Over time, taste gets smarter about THIS product and THIS market.

## Routing

Parse `$ARGUMENTS`:

### `<url>` → full evaluation
Market research → navigate → screenshot → DOM audit → evaluate → prescribe → todos → remember.

### `<url> mobile` → mobile-first evaluation
Resize to 390x844 before navigating. Evaluate mobile experience specifically.

### `vs <url1> <url2>` → side-by-side comparison
Evaluate both products on the same 11 dimensions. Present the gap. Steal what's working.

### `<url> deep` → interactive deep evaluation
Click through flows, hover over elements, test transitions. Full interaction audit.

### `trend` → taste trajectory
Read all past evaluations from `.claude/evals/taste-history.tsv`. Show dimension-level trends, grade past predictions, identify what's improving vs stuck.

### No arguments → help
```
/taste <url>              evaluate any product (market research + full eval)
/taste <url> mobile       mobile-first evaluation
/taste vs <url1> <url2>   side-by-side comparison
/taste <url> deep         interactive deep evaluation
/taste trend              taste trajectory over time

Works on any URL — deployed sites, localhost, staging, competitor products.
Uses 1-100 scale. Remembers everything. Creates todos from findings.
```

---

## The Evaluation Protocol

### Step 0: Market Research (what does "great" look like here?)

Before you look at a single screenshot, understand the MARKET this product lives in.

1. **Identify the category** from the URL/domain and any context in `config/rhino.yml`
2. **WebSearch** for: `"best [category] UI design 2026"` and `"[category] product design examples"`
3. **Identify 3 reference products** that are best-in-class for this category:
   - What design patterns do they use?
   - What's the standard bar for this market segment?
   - What would a user of THOSE products expect when they land on THIS product?
4. **Save market context** to `.claude/evals/taste-market.json`:
   ```json
   {
     "category": "<product category>",
     "reference_products": ["<name>: <what they do well>"],
     "market_bar": "<1-2 sentences: what 'great' looks like in this space>",
     "updated": "<ISO date>"
   }
   ```
   If this file already exists and is <7 days old, skip the research and reuse it.

**You are now calibrated to THIS market, not abstract "good design."**

### Step 1: Read Past Evaluations (memory)

Before evaluating, check what you already know:

1. Read `.claude/evals/taste-history.tsv` — past scores and trends
2. Read `.claude/evals/reports/taste-*.json` — most recent full report (glob for latest)
3. Read `.claude/evals/taste-learnings.md` — accumulated taste intelligence

If past evaluations exist:
- Note which dimensions were weakest last time
- Note which prescriptions were given
- You will COMPARE your new evaluation against the old one and report deltas
- You will CHECK if past prescriptions were followed

If this is the first evaluation: note "first evaluation — establishing baseline."

### Step 2: Navigate and Discover

1. `browser_navigate` to the target URL
2. `browser_wait_for` with `time: 3` (let the page fully render)
3. `browser_snapshot` — capture the accessibility tree (DOM structure, ARIA, headings, links)
4. `browser_take_screenshot` with `fullPage: true, type: "png"` — capture the full visual
5. Read the screenshot file with the Read tool — this is how you SEE the product
6. From the snapshot, extract all internal navigation links
7. Navigate to up to 5 additional routes (prioritize: nav links > footer links > in-page links)
8. For each route: snapshot + fullPage screenshot + Read the screenshot

**You now have BOTH visual (screenshots) and structural (DOM snapshots) for every page.**

### Step 3: Structural Audit (DOM-grounded)

Before scoring anything visual, analyze the DOM snapshots:

**From `browser_snapshot` data:**
- Heading hierarchy: exactly one h1? h2s follow h1s? Skipped levels?
- ARIA landmarks: `nav`, `main`, `footer`, `aside` roles present?
- Link quality: labels clear? Any "click here" or empty links?
- Interactive elements: buttons labeled? Form inputs associated with labels?
- Tab order: element order makes sense as reading/tab sequence?

**From `browser_evaluate`** — run these JS checks:
```javascript
() => {
  const body = getComputedStyle(document.body);
  const h1 = document.querySelector('h1');
  const cta = document.querySelector('button, [role="button"], a.btn, .cta');
  const links = document.querySelectorAll('a[href]');
  const images = document.querySelectorAll('img');
  const imagesNoAlt = [...images].filter(i => !i.alt).length;
  return {
    bodyBg: body.backgroundColor, bodyColor: body.color, fontSize: body.fontSize, fontFamily: body.fontFamily,
    h1Text: h1?.textContent?.trim()?.slice(0, 100), h1Color: h1 ? getComputedStyle(h1).color : null,
    ctaText: cta?.textContent?.trim()?.slice(0, 50), ctaBg: cta ? getComputedStyle(cta).backgroundColor : null,
    linkCount: links.length, imageCount: images.length, imagesNoAlt,
    viewportWidth: window.innerWidth, scrollHeight: document.documentElement.scrollHeight,
    scrollRatio: (document.documentElement.scrollHeight / window.innerHeight).toFixed(1)
  };
}
```

### Step 4: Visual Evaluation — 1-100 Scale

Score each dimension 0-100. This is NOT 1-5 mapped to 20s. Use the full range.

**Calibration anchors** (based on market research from Step 0):
- **90-100** = Best-in-class. Indistinguishable from the reference products you researched. Extremely rare.
- **70-89** = Genuinely good. Intentional choices visible. Would earn a positive comment.
- **50-69** = Functional but unremarkable. Works but doesn't impress. Most products live here.
- **30-49** = Noticeably weak. User would feel friction. Below market standard.
- **0-29** = Broken or hostile. User would leave immediately.

**Expected distribution for a typical early-stage product**: 40-60 on most dimensions, maybe one 70+. Scores above 80 need justification against the reference products from Step 0.

#### GATE DIMENSIONS (score first — they cap everything)

**LAYOUT_COHERENCE** (0-100)
Look at ALL screenshots together. Same grid? Same spacing system? Same component sizing across pages?
- 90+ = Airtight spatial system. Grid DNA on every page. Mobile rethought.
- 50 = Mostly coherent. Some spacing shifts between pages.
- 20 = No system. Pages built independently.

**INFORMATION_ARCHITECTURE** (0-100)
Can you describe the organizing principle in one sentence? Does nav reach all destinations?
- 90+ = Crystal clear. Predict where everything lives.
- 50 = Navigate but logic is fuzzy.
- 20 = No mental model possible.

**GATE RULE**: If EITHER gate dimension < 30, overall is CAPPED at 30.

#### EXPERIENTIAL DIMENSIONS (0-100 each)

**HIERARCHY** — Do I know what this is and where to look?
**BREATHING_ROOM** — Does this feel calm or chaotic?
**CONTRAST** — Can I tell what's clickable?
**POLISH** — Does this feel like someone cared?
**EMOTIONAL_TONE** — Would I tell a friend about this?
**INFORMATION_DENSITY** — Am I informed or overwhelmed?
**WAYFINDING** — Do I know what to do next?
**DISTINCTIVENESS** — Would I recognize this tomorrow?
**SCROLL_EXPERIENCE** — Does scrolling feel intentional?

For each: score 0-100, provide first-person evidence ("I felt..."), cite DOM data where relevant.

### Step 5: Slop Detection

For each page: "Could this have been generated by prompting an AI with 'build me a [feature] page'?"

If YES → DISTINCTIVENESS capped at 30.

**Slop signals**: generic card grids + rounded corners, "Welcome back, [name]!" dashboards, every-shadcn-app energy, layout that works for ANY product.

**Anti-slop signals**: element that only makes sense for THIS product, microcopy with personality, domain-specific information display, interaction pattern serving THIS product's core loop.

Cite the specific element that breaks the slop pattern, or say "nothing — template energy."

### Step 6: Prescriptions (intelligence layer)

For EVERY dimension scoring < 60, provide a **specific prescription**:

- **What element**: specific CSS selector or DOM element (from your snapshot data)
- **What change**: exact CSS property, structural change, or content change
- **Impact estimate**: which dimension improves, from what to what (e.g., "breathing_room 35→55")
- **Reference**: specific product from your Step 0 research that does this well, with what they do specifically

Ground prescriptions in actual DOM data. You have computed styles — cite them. Don't guess.

### Step 7: Interaction Check (deep mode only)

When `deep` is specified:
1. `browser_hover` over primary nav items — dropdowns/tooltips?
2. `browser_click` the primary CTA — what happens? Feedback?
3. `browser_snapshot` after interaction — visible state change?
4. Check: loading states, transitions, hover effects, focus indicators
5. Report: "I clicked [element]. [What happened]. This felt [good/bad] because [reason]."

### Step 8: Compare Against Past (memory)

If past evaluations exist:
1. **Delta report**: for each dimension, show `previous → current (±delta)`
2. **Prescription follow-through**: which prescriptions from last eval were followed? Which weren't?
3. **Trend direction**: is this product getting BETTER, WORSE, or STUCK on each dimension?
4. **Grade past predictions**: if you predicted "fixing X will improve Y by Z", did it?

Log any grading results to `~/.claude/knowledge/predictions.tsv` if that file exists.

### Step 9: Generate Todos

Every prescription with impact estimate > 15 points becomes a todo.

Write to `.claude/plans/todos.yml` (append to existing items):
```yaml
- id: taste-<dimension>-<date>
  title: "<one-line prescription>"
  priority: <high if impact>25, medium if >15>
  feature: <mapped feature from rhino.yml if possible>
  status: open
  context: "taste eval scored <dimension> at <score>/100. Fix: <prescription>"
  source: "/taste"
  created: <date>
```

Only create todos for dimensions that REGRESSED or are the 3 weakest. Don't flood the backlog.

### Step 10: Update Taste Memory

Append findings to `.claude/evals/taste-learnings.md`:

```markdown
## <date> — <url>

**Overall**: <score>/100 (previous: <prev>/100, delta: <±N>)
**Market**: <category> (references: <ref1>, <ref2>, <ref3>)
**Weakest**: <dimension> at <score> — <why>
**Strongest**: <dimension> at <score> — <why>
**Followed prescriptions**: <list or "first eval">
**Ignored prescriptions**: <list or "first eval">
**Surprise**: <anything unexpected — a dimension that moved without a targeted fix, or one that didn't move despite a fix>
**Learning**: <one sentence — what did this eval teach about this product's taste trajectory?>
```

This file is the taste skill's KNOWLEDGE MODEL. Read it every time. It gets smarter over time.

### Step 11: Write Report

Save full results to `.claude/evals/reports/taste-{YYYY-MM-DD}.json`:

```json
{
  "url": "<URL>",
  "timestamp": "<ISO>",
  "overall": <0-100>,
  "market": {
    "category": "<category>",
    "references": ["<product>: <what they do well>"],
    "bar": "<what great looks like here>"
  },
  "dimensions": {
    "<name>": {
      "score": <0-100>,
      "previous": <0-100 or null>,
      "delta": <±N or null>,
      "evidence": "<first-person experience>",
      "dom_evidence": "<DOM/snapshot findings>",
      "prescription": "<specific fix or null if score >= 60>",
      "prescription_impact": <estimated point improvement or null>
    }
  },
  "gates": {
    "layout_coherence": <0-100>,
    "information_architecture": <0-100>,
    "capped": <true/false>
  },
  "slop": {
    "detected": <true/false>,
    "pages": ["<route>: <what's sloppy>"],
    "anti_slop": ["<route>: <what's distinctive>"]
  },
  "strongest": "<dimension + why>",
  "weakest": "<dimension + moment it failed>",
  "would_return": "<yes/no + honest reason>",
  "one_thing": "<single highest-impact change>",
  "top_3_fixes": [
    {"element": "<selector>", "change": "<change>", "impact": "<dimension improvement>", "reference": "<product>"}
  ],
  "past_prescriptions_followed": [<list>],
  "past_prescriptions_ignored": [<list>],
  "todos_created": [<list of todo IDs>],
  "routes_evaluated": <N>,
  "meta": {
    "evaluator": "claude-native",
    "mode": "<standard|mobile|deep|vs>",
    "market_research": "<fresh|cached|none>",
    "has_past_eval": <true/false>
  }
}
```

Append to `.claude/evals/taste-history.tsv` (create with header if missing):
```
date	url	overall	hierarchy	breathing_room	contrast	polish	emotional_tone	information_density	wayfinding	distinctiveness	scroll_experience	layout_coherence	information_architecture
2026-03-16	http://localhost:3000	62	70	45	65	55	60	68	50	72	58	65	50
```

If the file doesn't exist, create it with the header row first. This feeds `/taste trend`, `/calibrate drift`, and `/rhino progress`.

### Step 12: Present Results

```
◆ taste — <url>                              <category>
  calibrated against: <ref1>, <ref2>, <ref3>

  overall   <score>/100  <20-char bar>  [±delta from last]

  ▸ gates
    layout_coherence         <score>/100  [±delta]  <evidence snippet>
    information_architecture <score>/100  [±delta]  <evidence snippet>
    [CAPPED AT 30 — fix the skeleton before decorating] if applicable

  ▸ dimensions (weakest first)
    <dimension>   <score>/100  [±delta]  <evidence>
                               rx: <prescription>
    ...

  ▸ slop check
    <page>: <sloppy or distinctive + why>

  ▸ top 3 fixes
    1. <element> → <change> → <dimension> +<N>pts. ref: <product>
    2. ...
    3. ...

  ▸ trend (if past data exists)
    improving: <dimensions going up>
    stuck: <dimensions unchanged 3+ evals>
    regressing: <dimensions going down>

  ▸ todos created
    · <todo-id>: <title> (priority: <high/medium>)

  ▸ past prescriptions
    followed: <what was fixed>
    ignored: <what wasn't — and the cost>

  verdict: <would_return + one_thing>
  next: /taste <url> to re-evaluate after fixes. /todo to see the backlog.
```

## Trend Mode (`/taste trend`)

When `trend` is the argument:

1. Read `.claude/evals/taste-history.tsv` — the primary data source with all 11 dimension scores per eval
2. Read ALL files in `.claude/evals/reports/taste-*.json` — full reports with prescriptions and evidence
3. Read `.claude/evals/taste-learnings.md` — accumulated taste intelligence

If `taste-history.tsv` has <2 eval runs, note: "Run `/taste <url>` once more for trend data."

Present:
- **Overall trajectory**: score progression with bar chart and total delta
- **Per-dimension trends**: every dimension's progression, grouped by trajectory (improving/stuck/regressing)
- **Prescription effectiveness**: how many prescriptions led to actual improvement?
- **Self-grade**: "My prescriptions improved dimensions X% of the time. I was wrong about [dimension] — I predicted [X] but [Y] happened."
- **Model update**: if prescriptions are consistently wrong about a dimension, note it in taste-learnings.md

```
  ⎯⎯ taste trend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  overall    45 → 52 → 58 → 62  ████████████░░░░░░░░  +17 in 4 evals

  ▾ dimensions
    hierarchy         55 → 62 → 68 → 70  ↑15  improving
    breathing_room    38 → 40 → 42 → 45  ↑7   slow
    contrast          60 → 62 → 64 → 65  ↑5   stable
    polish            40 → 45 → 50 → 55  ↑15  improving
    emotional_tone    50 → 52 → 55 → 58  ↑8   slow
    information_density  55 → 58 → 60 → 62  ↑7   slow
    wayfinding        35 → 38 → 42 → 50  ↑15  improving ←
    distinctiveness   35 → 38 → 36 → 38  ↑3   stuck — current approach exhausted
    scroll_experience 48 → 50 → 52 → 55  ↑7   slow
    layout_coherence  42 → 48 → 52 → 58  ↑16  improving
    info_architecture 40 → 42 → 45 → 48  ↑8   slow

  ▸ improving (delta > 10 over window)
    hierarchy        55 → 70    +15 over 4 evals — responds fastest to fixes
    polish           40 → 55    +15 over 4 evals
    wayfinding       35 → 50    +15 over 4 evals ← biggest gain

  ▸ stuck (delta < 5 over 3+ evals)
    distinctiveness  35 → 38    +3 — plateau, needs structural changes not CSS

  ▸ regressing (any negative delta between consecutive evals)
    [none in this example]

  ▸ prescription accuracy
    8 prescriptions given, 5 followed, 3 led to improvement
    accuracy: 60% — hierarchy prescriptions are reliable, distinctiveness are not

  ▸ learning
    "Hierarchy responds fastest to fixes. Distinctiveness requires structural
    changes, not CSS tweaks — prescriptions targeting CSS haven't moved it."
```

Classify each dimension's trajectory:
- **improving**: total delta > 10 over the available window
- **slow**: total delta 5-10
- **stable**: total delta 1-4
- **stuck**: total delta < 1 over 3+ evals — flag as "current approach exhausted"
- **regressing**: any negative delta between consecutive evals — flag with possible cause

## Comparative Mode (vs)

When `vs <url1> <url2>`:
1. Research both products' markets (or reuse cached)
2. Evaluate product A fully
3. Evaluate product B fully
4. Side-by-side with gap per dimension
5. "Steal list" — specific things product A should steal from product B

```
◆ taste vs — <url1> vs <url2>

                          yours    theirs    gap
  hierarchy                52       78       -26  ↓↓
  breathing_room           65       72        -7  ↓
  distinctiveness          71       45       +26  ↑↑
  ...

  ▸ steal from them
    1. Their nav uses a persistent sidebar with section labels — yours hides nav behind hamburger
    2. Their CTA contrast ratio is 7.2:1, yours is 3.1:1

  ▸ they should steal from you
    1. Your copy has personality. Theirs is generic SaaS boilerplate.

  verdict: they're more polished, you're more distinctive. Polish is mechanical — close that gap first.
```

## Score Integrity

- **You are a diagnostic instrument, not a reward signal.** Inflated scores hide problems.
- If unsure between two scores, pick the LOWER one.
- 90+ means INDISTINGUISHABLE from reference products in Step 0. Extremely rare for early-stage.
- Expected distribution for early-stage: mostly 35-60, maybe one 70+.
- If overall > 75, you MUST justify against your Step 0 reference products on each high dimension.

**Integrity checks** (apply after scoring):
- Avg > 70 for non-mature products → flag `GENEROUS`
- Min > 65 → flag `NO_WEAKNESS` (every product has one)
- All scores within 10 points of each other → flag `FLAT_EVAL`
- Gate < 30 but overall > 30 → enforce cap
- Jump > 25 points from last eval without major changes → flag `SUSPICIOUS_JUMP`

## Intelligence Sources (read if they exist)

Before evaluating, check for context:
- `.claude/evals/taste-learnings.md` — accumulated taste intelligence (MOST IMPORTANT)
- `.claude/evals/taste-market.json` — cached market research
- `.claude/evals/reports/taste-*.json` — past evaluation reports
- `~/.claude/knowledge/founder-taste.md` — founder's design preferences
- `~/.claude/knowledge/taste-knowledge/` — per-dimension research
- `.claude/design-system.md` — project's visual rules (deviations are bugs)
- `.claude/taste.yml` — route configuration + auth
- `config/rhino.yml` — product context, stage, features, value hypothesis

## Self-Improvement Protocol

After every 3rd evaluation of the same URL:
1. Review all past prescriptions and their outcomes
2. Calculate: what % of followed prescriptions actually improved their target dimension?
3. Identify systematic errors: "I consistently overestimate the impact of [type] changes on [dimension]"
4. Update `.claude/evals/taste-learnings.md` with calibration notes
5. Adjust future prescriptions based on what actually worked

This is the learning loop. Taste gets smarter about THIS product over time.

## What you never do
- Run `rhino taste` or `claude -p` — YOU are the evaluator
- Skip screenshots — you must SEE the product
- Skip market research — you must know what "great" looks like in this space
- Give scores without evidence — every score needs a first-person moment
- Skip prescriptions — every weak dimension gets a specific fix
- Skip memory — always read and write taste-learnings.md
- Be generous — you're a diagnostic tool, not a cheerleader
- Create more than 5 todos per eval — focus on highest impact
- Ignore past prescriptions — accountability matters

## If something breaks
- Playwright not installed: `mcp__playwright__browser_install`
- URL won't load: report error, check auth or localhost status
- No screenshots: check if page requires JS that didn't execute
- Auth required: check `.claude/taste.yml` for config
- WebSearch fails: skip market research, note "uncalibrated" in output, use general references
- No past evaluations: note "first evaluation — establishing baseline"

$ARGUMENTS
