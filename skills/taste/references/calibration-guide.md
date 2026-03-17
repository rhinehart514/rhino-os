# Calibration Guide

How taste calibration works, when to recalibrate, and what makes good calibration data.

## What calibration does

Uncalibrated taste evals use generic anchors. They're directionally correct but miss what matters to the specific founder and product. Calibration grounds the eval in three sources:

1. **Founder taste profile** — what the founder loves, hates, and cares about
2. **Design system** — the project's actual visual tokens and patterns
3. **Dimension knowledge** — researched rubrics per dimension with market examples

Each source is independent. Partial calibration is better than none.

## Calibration artifacts

| Artifact | Path | What it does |
|----------|------|-------------|
| Founder profile | `~/.claude/knowledge/founder-taste.md` | Weights dimensions by founder preference. "Loves density" → information_density scoring shifts. |
| Design system | `.claude/design-system.md` | Flags deviations as bugs. Components that break the system get penalized. |
| Dimension knowledge | `lens/product/eval/knowledge/*.md` | Per-dimension research with patterns, anti-patterns, and scoring examples. |
| Calibration history | `.claude/cache/calibration-history.json` | Tracks when calibration happened and what was calibrated. |

## When to calibrate

### First time
Run `/taste calibrate` (full) before the first eval on a project. Takes 5-10 minutes. Produces all three artifacts. The founder interview is the most important part — design system and dimension knowledge are supplementary.

### Recalibrate when
- **Founder profile > 30 days old** — preferences shift. `/taste calibrate drift` detects this.
- **Design system changed** — new UI library, major redesign, color palette swap. Run `/taste calibrate design-system`.
- **Scores feel wrong** — if the founder consistently disagrees with scores, the calibration is stale. Run `/taste calibrate verify` to check alignment.
- **New product category** — pivoted from B2B to B2C? Different taste standards. Full recalibration.

### Don't recalibrate when
- Scores are low but accurate — calibration doesn't make the product better
- You want higher scores — that's gaming, not calibrating
- Minor UI tweaks — the design system doesn't need updating for every change

## What makes good calibration data

### Founder interview (profile)

Good answers:
- "Linear's information density — lots of data visible without feeling cramped, because of their spacing system"
- "I hate gradient hero sections that say nothing. Every AI startup has one."
- "The sidebar feels wrong — it's too wide and the hierarchy between sections isn't clear"

Bad answers (push for specifics):
- "I like clean design" → which product? what specifically about it?
- "It should look professional" → what does professional mean to you? what's an example?
- "Everything bothers me" → what's the ONE thing you'd fix first?

### Design system extraction

Good design system:
- Exact token values (colors as hex, spacing as px, radius as px)
- Component patterns with actual class names
- Anti-slop rules grounded in the codebase ("never use default shadcn card without custom border")

Weak design system:
- Generic descriptions ("modern and clean")
- Token values without source (made up, not extracted from code)
- Rules that don't map to actual codebase patterns

### Dimension knowledge

Good dimension research:
- Cites specific products as anchors ("Stripe's hierarchy: headline is 4x body size")
- Anti-patterns with WHY they fail ("equal-weight everything fails because the eye has no entry point")
- Score anchors tied to observable properties, not vibes

Weak dimension research:
- Generic design advice ("use whitespace effectively")
- No product examples
- Scoring guide that's just reworded scale labels

## Calibration sub-commands

### `/taste calibrate` (full)
Runs all steps: interview, design system, dimension research, then verify. If artifacts exist, shows them first and asks what to update — doesn't overwrite.

### `/taste calibrate profile`
Founder interview only. Uses AskUserQuestion. If `founder-taste.md` exists, shows current profile and asks what changed.

### `/taste calibrate design-system`
Auto-detects from codebase: tailwind config, CSS variables, component patterns, UI libraries. If no design system exists, proposes a minimal one from what's in the code.

### `/taste calibrate verify`
Compares current eval scores against founder expectations. Gap < 10 = aligned, 10-20 = acceptable, > 20 = miscalibrated.

### `/taste calibrate drift`
Detects when founder preferences have shifted. Requires both `founder-taste.md` and `taste-history.tsv`. Maps expectations to ranges, computes drift per dimension.

## Calibration traps

- **Calibrating to inflate scores** — founder preferences are inputs, not truth. Market references matter too. If calibrated dimensions consistently score higher, flag sycophancy.
- **Over-calibrating** — running calibrate after every eval. Calibration is meant to be stable. Recalibrate on schedule or when something changed, not reactively.
- **Calibrating without verification** — always suggest `/taste calibrate verify` after calibration. Calibration is a hypothesis until tested.
- **Stale dimension knowledge** — web research citations have a shelf life. If the market has moved (new product category leaders), dimension knowledge may need refreshing.
