---
name: taste
description: "Visual product intelligence — 11 dimensions scored 0-100. Playwright sees the product, code reading understands the architecture. Calibrate to ground eval in founder preferences. Use when someone says 'how does it look', 'visual eval', 'taste', 'design quality'."
argument-hint: "<url> [mobile|vs <url>|deep|trend|calibrate [profile|design-system|verify|drift]]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebSearch, WebFetch, Agent, mcp__playwright__browser_navigate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_wait_for, mcp__playwright__browser_click, mcp__playwright__browser_hover, mcp__playwright__browser_resize, mcp__playwright__browser_evaluate, mcp__playwright__browser_network_requests, mcp__playwright__browser_install
---

# /taste — Product Intelligence

You are a first-time user with 40 tabs open. You will leave in 5 seconds if you don't understand what this is.

You evaluate TWO layers: what the user SEES (Playwright) and what the user EXPERIENCES (code reading). Visual quality without system coherence is decoration. System coherence without visual quality is engineering. You measure both.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/dimension-summary.sh` — structured output of all 11 dimensions from latest eval (zero context cost)
- `scripts/taste-history.sh` — score trends over time per dimension, trajectory classification
- `scripts/calibration-check.sh` — checks calibration state: founder profile, design system, dimension knowledge
- `references/dimensions.md` — all 11 dimensions with scoring anchors and what moves each score
- `references/calibration-guide.md` — how calibration works, when to recalibrate, what makes good data
- `templates/taste-report.md` — output templates for all taste modes (eval, trend, compare, calibrate, verify)
- `reference.md` — architecture, key files, memory layout, score mapping
- `gotchas.md` — real failure modes. **Read before every eval.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Mode | What happens |
|----------|------|-------------|
| `<url>` | Full eval | Visual + system eval. Run `scripts/calibration-check.sh` first. |
| `<url> mobile` | Mobile | Resize to 390x844 before navigating |
| `<url> deep` | Interactive | Click through flows, test interactions |
| `vs <url1> <url2>` | Compare | Side-by-side, gap analysis, steal list |
| `trend` | Trajectory | Run `scripts/taste-history.sh`, classify per dimension |
| `calibrate [sub]` | Calibration | Interview, design system, dimension research |
| (none) | Help | Show available modes |

## The protocol

### Step 1: Load context

Run `scripts/calibration-check.sh` via Bash. Read `gotchas.md`. Then read in parallel (skip missing silently):

- `.claude/evals/taste-learnings.md` — accumulated intelligence (most important)
- `~/.claude/knowledge/founder-taste.md` — founder preferences
- `.claude/design-system.md` — project visual rules (deviations are bugs)
- `config/rhino.yml` — features, code paths, stage
- `config/product-spec.yml` — evaluate whether UX serves the spec's core loop and first experience

If past evals exist: run `scripts/dimension-summary.sh` to see latest scores + weak dimensions.

### Step 2: See the product (Playwright)

Navigate landing + 2 key routes (3 pages max). For each page:
1. `browser_navigate` to URL
2. `browser_wait_for` with `time: 3`
3. `browser_snapshot` — DOM structure, ARIA, headings, links
4. `browser_take_screenshot` — returns image inline, do NOT Read screenshot files

For `mobile`: `browser_resize` to 390x844 first.
For `deep`: also hover nav, click primary CTA, snapshot after interaction.

### Step 3: Read the system

For system dimensions (information_architecture, layout_coherence, wayfinding, information_density), read code:
- Route definitions, navigation components, layout components, data flow patterns
- Use Glob/Read to find these from `config/rhino.yml` features

### Step 4: Score 11 dimensions

Read `references/dimensions.md` for anchors. Score each 0-100 with first-person evidence.

**Gate rule:** layout_coherence < 30 OR information_architecture < 30 → overall capped at 30.
**Slop rule:** "Could AI generate this by prompting 'build me a [feature] page'?" → distinctiveness capped at 30.
**Anti-inflation:** avg > 70 non-mature → GENEROUS. Min > 65 → NO_WEAKNESS. All within 10pts → FLAT_EVAL. Jump > 25pts → SUSPICIOUS_JUMP. When unsure, pick the LOWER score.

### Step 5: Prescribe

For every dimension < 60: specific element (CSS selector/DOM), exact change, impact estimate.

### Step 6: Compare with history

Run `scripts/taste-history.sh` if past data exists. Show deltas, followed/ignored prescriptions, trend.

### Step 7: Remember

Write report to `.claude/evals/reports/taste-{YYYY-MM-DD}.json`, append to `.claude/evals/taste-history.tsv`, update `.claude/evals/taste-learnings.md` (max 5 entries).

### Step 8: Present

Use template from `templates/taste-report.md` for the active mode.

## Calibrate mode

Read `references/calibration-guide.md` for the full calibration protocol. Sub-modes: `profile`, `design-system`, `verify`, `drift`, or no arg for full calibration.

## Task generation — the path to visual completion

**/taste's job is not just scoring. It's generating EVERY task needed to reach 80+ on every dimension.** The backlog IS the roadmap to a beautiful product. If /taste doesn't populate /todo, the founder has scores but no path to fixing them.

**For EVERY page/screen evaluated, generate the complete task list to reach visual excellence:**

### Per-dimension tasks (for each of the 11 dimensions)
For each dimension scoring below 80, generate SPECIFIC tasks:
- What exactly is wrong (cite the screenshot, the element, the coordinates)
- What it should look like instead (cite the design system, calibration, or market reference)
- Which file/component to change

### Layout & composition tasks
- Misaligned elements — which ones, by how many pixels
- Inconsistent spacing — where, what the spacing should be
- Visual hierarchy violations — what draws the eye vs what should
- Content that overflows or clips at any viewport

### Typography tasks
- Font size/weight inconsistencies between similar elements
- Line height issues (too tight, too loose)
- Missing text truncation on dynamic content
- Heading hierarchy violations (h3 looks bigger than h2)

### Color & contrast tasks
- Contrast ratio failures (WCAG AA = 4.5:1 for text)
- Inconsistent color usage (same semantic meaning, different colors)
- Missing dark mode support (if applicable)
- Color-only information (no alternative for colorblind users)

### Interaction & feedback tasks
- Hover/focus states missing on interactive elements
- Click targets smaller than 44px
- Missing loading states on async actions
- Missing error states on forms
- Missing success confirmation after actions
- Disabled states that look clickable

### Responsive tasks
- Layout breaks at specific breakpoints
- Touch targets too small on mobile
- Horizontal scroll at any viewport
- Content that's invisible or inaccessible on mobile
- Navigation that doesn't work on small screens

### Empty state & dead end tasks
- Pages with no data that show blank
- Flows that end without a next step
- Error pages with no recovery path
- First-time experience with no guidance

### Consistency tasks
- Same component styled differently on different pages
- Same action labeled differently in different places
- Same icon meaning different things
- Different navigation patterns on similar pages

### Competitor gap tasks
- Visual patterns competitors nail that we don't
- Polish level differences (animations, transitions, micro-interactions)
- Information density differences (too much vs too little vs just right)

**Write ALL tasks to /todo.** Tag with `source: /taste`, URL, and dimension. Priority: tasks on dimensions scoring lowest first.

**There is no cap on task count.** A page with 5 dimensions below 60 might need 30 tasks. Generate all of them. The founder uses /plan to pick which to work on — /taste's job is to make sure EVERY visual issue is captured.

After writing tasks, show: "Generated N tasks across M dimensions. Worst dimension: [name] at [score] needs [X] tasks."

## Boundaries

**Write to:** `.claude/evals/taste-*`, `.claude/evals/reports/taste-*`, `.claude/cache/calibration-history.json`

## Errors

- Playwright not installed → `mcp__playwright__browser_install`
- URL won't load → report error, check auth or localhost
- No past evaluations → "first evaluation — establishing baseline"

$ARGUMENTS
