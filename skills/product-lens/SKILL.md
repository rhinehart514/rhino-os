---
name: product-lens
description: "Use when evaluating visual quality, UX, running taste/DOM/copy evals, or checking product standards"
---

<!-- Plugin system: This skill is a system context skill, not user-invocable.
     It is preloaded into agents and skills via the `skills:` field in agents.yml
     and SKILL.md frontmatter (e.g., `skills: [rhino-mind, product-lens]`).
     In plugin mode, the plugin system concatenates lens/product/mind/ files into
     this single skill. In manual mode, the same files are symlinked into
     ~/.claude/rules/. Both paths produce the same measurement context. -->

# Product Measurement — How You See

The product lens adds specific measurement tools beyond the base loop.

## Measurement Stack

- `rhino score .` — structural lint (health tier). For web products: dead ends, empty states, TS hygiene, navigation gaps. Fast, free, every change.
- `/taste <url>` — visual product intelligence (craft tier). Claude Code skill using Playwright MCP + Claude Vision natively. 11 dimensions scored 0-100, market-calibrated, persistent memory, auto-creates todos. Legacy CLI: `rhino taste`. Slow, expensive. Use when visual quality matters.
- `rhino eval .` — mechanical belief evals (value tier). DOM checks (contrast, click targets, hierarchy, distinctiveness), copy checks (clarity, specificity), positioning checks, blind playwright tests. Requires dev server for behavioral tiers.

Score drops after a change → revert. Score plateaus → rethink the approach.
The founder's words override scores when they conflict.

---

# Product Self-Model

Product-specific measurement details and unknowns.

## Product Measurement Stack
- `rhino score .` — structural lint for web products. Checks dead ends (pages with no outbound links), empty states without CTAs, IA audit, `:any` types, console.log in TSX, unused imports, lint overrides. Status: operational.
- `/taste <url>` — visual product intelligence via Playwright MCP + Claude Vision. 11 dimensions, 0-100 scale. Market-calibrated, persistent memory, auto-creates todos, self-improving. Status: operational. Legacy CLI: `rhino taste` (1-5 scale, backward compat).
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

---

# UX Checklist (Craft Layer)

After every feature or significant UI change, check your own work against these.
LLMs consistently miss them. You will too unless you explicitly check.

1. **Empty state** — What does a new user with zero data see? Blank screen = bug. Add guidance, a CTA, sample content.
2. **Dead ends** — After the user completes the action, where do they go? Every page leads somewhere.
3. **Loading states** — Every async operation: loading, success, error. Skeleton > spinner > nothing.
4. **Visual hierarchy** — What's the first thing the eye hits? One primary action per screen. Secondary elements recede.
5. **First-time experience** — Pretend you've never seen the product. Is it obvious what to do? If it requires prior context, explain it.
6. **Mobile** — Does it work at 390px? Tables readable? Touch targets 44px? No horizontal scroll.
7. **User feedback** — After every action, does something visible change? Silent actions feel broken.
8. **Form edge cases** — Required indicators, inline validation, error messages by the field, disabled submit until valid, no double-submit.
9. **Navigation coherence** — Can the user get back? Can they find this page from main nav?
10. **Information density** — Too much? Progressive disclosure. Too little? More context. Match density to task.

These aren't polish. They're the gap between "code that works" and "product users love."

## If something breaks

- `rhino score .` returns 0 with no details: `config/rhino.yml` may be missing or have no features — run `/onboard`
- `/taste` fails to connect: Playwright MCP must be available and the target URL must be reachable — check dev server is running
- DOM eval returns "no elements found": the dev server may not be serving the expected page — verify the URL and check for client-side rendering that needs time to hydrate
- Copy eval scores everything low: check that the page has actual content rendered (not just loading spinners) — add `browser_wait_for` if needed
