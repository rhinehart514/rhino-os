---
name: clone
description: "Use when reproducing a design from a URL using your framework and design tokens"
argument-hint: "<url> [verify|mobile|section <name>|history]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, WebFetch, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_navigate, mcp__playwright__browser_wait_for, mcp__playwright__browser_snapshot
---

# /clone

Screenshot a public URL, decompose the page into components, generate them in your stack using your conventions and design tokens. Never copy verbatim — placeholder content replaces brand-specific copy.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `references/clone-guide.md` — how clone works, what makes a good clone, limitations
- `reference.md` — output templates for every route
- `gotchas.md` — real failure modes. **Read before generating components.**

## Routing

Parse `$ARGUMENTS`:

| Pattern | Route |
|---------|-------|
| `<url>` | **clone** — full page decomposition + generation |
| `<url> verify` | **verify** — visual comparison against source |
| `<url> mobile` | **mobile** — clone for 390x844 viewport, mobile-first |
| `<url> section <name>` | **section** — clone one section only |
| `history` | **history** — show past clone operations |
| (none) | Ask for a URL via AskUserQuestion |

## Route: clone (default)

1. Check `.claude/cache/clone-history.json` for previous clones of this URL
2. Capture: `browser_navigate` → `browser_wait_for` → `browser_take_screenshot` → `browser_snapshot`
3. Read `.claude/design-system.md`, tailwind config, 3 existing components to detect stack + tokens
4. Decompose into components (nav, hero, sections, footer, reusable elements)
5. Ask what to generate via AskUserQuestion
6. Generate each component: framework conventions, design tokens, placeholder copy, proper imports
7. Scan for hardcoded values (hex, px, font stacks) — auto-fix if compliance <80%
8. Screenshot source + local at desktop (1440) and mobile (390) if dev server running
9. Record to clone-history.json
10. Report: compliance %, generated list, visual diff, 3 next commands

Read `references/clone-guide.md` for detailed guidance on decomposition and token compliance.

## Route: verify

Visual comparison of generated components against source. Screenshots at both viewports. Re-scan token compliance. Report layout/spacing/typography/color match per component.

## Route: mobile

Clone for 390x844 viewport. Mobile-first styles with responsive breakpoints going up. Touch targets 44px minimum. No horizontal scroll.

## Route: section

Clone one section from the page. Parse `<url> section <name>`. Capture full page to locate section, then generate only those components.

## Route: history

Read `.claude/cache/clone-history.json`. Display each entry: date, domain, components, compliance %, verification status.

## What you never do

- Copy brand-specific text verbatim — always placeholder content
- Hardcode hex colors, pixel values, or font stacks — use design tokens
- Generate one massive file — decompose into real components
- Install dependencies — work with what's already in the project
- Skip reading design-system.md when it exists — tokens are non-negotiable
- Skip clone history check — always check for previous clones of the same URL

## If something breaks

- Playwright screenshot times out: the target URL may block headless browsers — try adding a `browser_wait_for` with a longer timeout or check if the site requires authentication
- "No design-system.md found": clone will use raw values — create `.claude/design-system.md` first via `/taste calibrate design-system` for token compliance
- Generated components use hardcoded hex/px values: re-run with `verify` to scan token compliance, then replace hardcoded values with design tokens
- clone-history.json corrupt: delete `.claude/cache/clone-history.json` and re-run — history is convenience, not critical

$ARGUMENTS
