---
name: calibrate
description: "Build taste knowledge — founder interview, design system docs, dimension research. Makes /eval taste scores grounded, not generic. Run once, refine over time."
argument-hint: "[dimensions|design-system|profile]"
context: fork
model: sonnet
---

# /calibrate

Extracted from /eval because calibration is a SETUP workflow, not measurement. It writes files, does research, interviews the founder — none of that belongs in a measurement command.

Runs in a forked context (`context: fork`) so the research, WebSearch results, and interview don't pollute the main conversation.

## What it produces

Three artifacts that make `/eval taste` smarter:

1. **Founder taste profile** (`~/.claude/knowledge/founder-taste.md`) — what the founder loves/hates
2. **Design system doc** (`.claude/design-system.md`) — tokens, patterns, anti-slop rules
3. **Dimension knowledge** (`lens/product/eval/knowledge/*.md`) — grounded rubrics per dimension

## Routing

Parse `$ARGUMENTS`:

### No arguments → full calibration
Run all three steps in sequence.

### `profile` → founder interview only
Just step 1.

### `design-system` → design system documentation only
Just step 2.

### `dimensions` → dimension research only
Just step 3. Optionally followed by dimension names: `/calibrate dimensions hierarchy breathing_room`

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

Write `~/.claude/knowledge/founder-taste.md`:

```markdown
# Founder Taste Profile

## Preferences
- Loves: [specific products + what about them]
- Hates: [specific patterns to avoid]
- Current pain: [what bothers them about their own product]

## Calibration
- [Product A] scores 4-5 on: [dimensions]
- Patterns to penalize: [what they hate → dimension mappings]
- Patterns to reward: [what they love → dimension mappings]
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

Run `rhino taste --force` to test with new knowledge. Compare against previous taste report if one exists.

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
  → taste will reward information_density ≥ 3 (founder wants data-rich UIs)

/eval taste        run with calibrated knowledge
/calibrate dimensions   fill remaining 7 dimensions
/eval vs [url]     compare against a reference product
```

## Tools to use

**Use AskUserQuestion** for founder interview
**Use WebSearch** for dimension research
**Use Read** to detect design system from codebase
**Use Write/Edit** to create knowledge files and design-system.md
**Use Bash** to run `rhino taste --force`

## What you never do
- Skip the founder interview — generic calibration is useless
- Write vague dimension knowledge — "good hierarchy means clear structure" is garbage
- Modify taste.mjs — the eval harness is immutable
- Run calibration silently — always show what was written and where

## If something breaks
- No tailwind or CSS variables: document "no design system" honestly
- WebSearch fails: use codebase patterns only for dimension knowledge
- No lens/product/ directory: taste isn't installed, suggest `/skill install product-lens`
- founder-taste.md already exists: update it, don't overwrite (merge new preferences)

$ARGUMENTS
