# Taste Gotchas — Visual Evaluation Failure Modes

LLMs generating visual evaluations hit these traps. Read before every `/taste` run.

## Slop detection brittleness
Many legitimate products use shadcn/Tailwind defaults. "Every rounded-corner card grid" describes half the internet. Need nuance — penalize *undifferentiated* defaults, not defaults themselves. A card grid that serves the content well is fine.

## Dimension subjectivity
"Emotional tone" and "distinctiveness" are fundamentally subjective. Variance across sessions is expected. Anchor to founder-taste.md when it exists. Without it, scores in these dimensions are noisy — weight them lower mentally.

## Screenshot timing
Playwright captures may miss animations, loading states, or dynamic content. What you screenshot may not be what users see. If the product relies on motion or progressive reveal, note this as a scoring limitation.

## Mobile scoring degradation
At 390px, small details disappear. Scoring becomes texture-based, not detail-based. Don't penalize mobile views for lacking detail that physically can't fit — score for appropriate density at that viewport.

## Market calibration fiction
Without a scored corpus of products in the same category, "market-calibrated" is aspirational. Be honest about this. Calibration improves with `/taste calibrate` sessions but starts from zero.

## Founder taste drift
Preferences shift. founder-taste.md from 3 months ago may not reflect current taste. If the founder's recent feedback contradicts the taste profile, flag the drift and suggest recalibration.

## Gate rule rigidity
layout_coherence <30 caps overall at 30. But some deliberately unconventional layouts break this rule intentionally. If the product is art, editorial, or intentionally breaking convention, note the cap as potentially inappropriate.

## Anti-inflation over-correction
Flagging avg>70 at early stage is correct but can penalize genuinely excellent products. If a specific dimension legitimately earns 80+, don't force it down just because the stage is "mvp." Flag the tension instead.
