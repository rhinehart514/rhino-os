# Taste Gotchas

Real failure modes from past sessions. Read before every `/taste` run.

## Screenshot captures a loading state, not the product

Playwright screenshots fire after `wait_for(time: 3)` but some SPAs take longer. If the screenshot shows a spinner, skeleton, or blank page — that's not the product. Re-navigate with a longer wait or check network requests for pending fetches. Do NOT score a loading state as the actual product.

## Scoring the framework, not the product

shadcn/Tailwind defaults describe half the internet. Penalize *undifferentiated* defaults, not defaults themselves. A card grid that serves the content well is fine. The slop rule asks: "could AI generate this by prompting 'build me a [category] page'?" — not "does it use rounded corners?"

## Dimension subjectivity produces session variance

"Emotional tone" and "distinctiveness" vary 10-15 points across sessions. Without `founder-taste.md`, these dimensions are noise. When calibration exists, anchor to it. When it doesn't, weight these lower mentally and note "uncalibrated — variance expected" in the report.

## Generous scoring on first eval

First eval has no baseline to compare against. LLMs default to polite — "this is pretty good, 65/100." On the first eval, actively look for the weakest dimension and score it honestly. If avg > 60 on an early-stage product, re-check each dimension against the anchors in `references/dimensions.md`.

## Mobile scoring is texture, not detail

At 390px, small details disappear. Scoring becomes texture-based. Don't penalize mobile views for lacking detail that physically can't fit. Score for appropriate density and touch target sizing at that viewport. A mobile view that reorganizes content well can score higher than desktop on information_density.

## Market calibration is aspirational without a corpus

"Market-calibrated" requires a scored corpus of products in the same category. Without `taste-market.json`, scores are anchored to generic best-in-class (Linear, Stripe, Notion). Be honest: note "uncalibrated against market" in the report. Don't pretend generic anchors are specific.

## Gate rule punishes intentional unconventionality

layout_coherence < 30 caps overall at 30. But some products — editorial, art, experimental — break grids intentionally. If the product is deliberately unconventional and the "incoherence" is a design choice, note the cap as potentially inappropriate. Still enforce it — but flag the tension.

## Anti-inflation over-correction flattens real strengths

Flagging avg > 70 at early stage is correct, but don't force genuinely strong dimensions down. If hierarchy is legitimately 82 because of excellent typography choices, that's real — don't cap it because the product is "early." Flag the tension between stage and score, don't resolve it by lying.

## Prescriptions that say "add more whitespace" every time

Generic prescriptions are useless. "Add more whitespace" is always technically correct and never actionable. Prescriptions must reference a specific DOM element, a specific CSS property, and a specific target value. "`.hero-section` padding: 24px → 48px" is a prescription. "Improve spacing" is not.

## Code reading misses dynamic content

System dimensions (wayfinding, information_architecture) rely on code reading, but code shows potential routes — not what users actually encounter. A route that exists in the router but has no nav link scores differently than one with prominent navigation. Score what the user sees, not what the code can do.

## Comparing across different URLs without noting the context

When past evals exist for a different URL, deltas are misleading. "Overall went from 55 to 42" sounds like regression, but if the first was a marketing site and the second is an app dashboard, they're different products. Always check URL matches before computing deltas.
