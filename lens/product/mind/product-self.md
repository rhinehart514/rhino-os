# Product Self-Model

Product-specific measurement details and unknowns.

## Product Measurement Stack
- `rhino score .` — structural lint for web products. Checks dead ends (pages with no outbound links), empty states without CTAs, IA audit, `:any` types, console.log in TSX, unused imports, lint overrides. Status: operational.
- `rhino taste` — visual eval via Claude Vision. 11 dimensions, 1-5 scale. Anti-sycophancy rubric. Status: operational.
- DOM eval (`dom-eval.mjs`) — mechanical DOM checks: contrast ratio, click target size, heading hierarchy, visual distinctiveness. Requires dev server.
- Copy eval (`copy-eval.mjs`) — headline clarity, value prop specificity, positioning. Requires dev server.
- Blind eval (`blind-eval.mjs`) — Playwright task completion tests. Requires dev server.

## Product-Specific Unknowns
(Never tested — highest information value)
- How often do score improvements translate to taste improvements?
- What's the false-negative rate of DOM/copy eval? (real UX problems they miss)
- Score-to-value correlation: does a higher structural score actually mean better user experience?
- Taste-to-user-satisfaction correlation: do taste dimensions predict what users actually care about?
- Does the corpus (taste reference database) meaningfully improve eval calibration vs. no corpus?
