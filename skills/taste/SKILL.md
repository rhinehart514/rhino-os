---
name: taste
description: "Product intelligence — visual quality (11 dimensions, 0-100) AND frontend delivery (flow audit, issue list). 'flows' mode tests if it works. Standard mode tests if it's well-designed. Use when someone says 'how does it look', 'does it work', 'visual eval', 'taste', 'design quality', 'test the frontend'."
argument-hint: "<url> [flows|mobile|vs <url>|deep|trend|calibrate [profile|design-system|verify|drift]]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebSearch, WebFetch, Agent, mcp__playwright__browser_navigate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_wait_for, mcp__playwright__browser_click, mcp__playwright__browser_hover, mcp__playwright__browser_resize, mcp__playwright__browser_evaluate, mcp__playwright__browser_network_requests, mcp__playwright__browser_console_messages, mcp__playwright__browser_fill_form, mcp__playwright__browser_press_key, mcp__playwright__browser_navigate_back, mcp__playwright__browser_install
---

!bash scripts/flows-summary.sh 2>/dev/null || true
!bash scripts/dimension-summary.sh 2>/dev/null || true

# /taste — Product Intelligence

You are a first-time user with 40 tabs open. You will leave in 5 seconds if you don't understand what this is.

## Skill folder structure

This skill is a **folder**. Read on demand — don't front-load everything.

**Scripts:**
- `scripts/checks/` — JS check files for `browser_evaluate`. Read a file, pass its contents to the tool. 7 checks: click-targets, form-labels, heading-hierarchy, aria-landmarks, images-alt, responsive-scroll, empty-state.
- `scripts/dimension-summary.sh` — latest visual eval scores + weak dimensions (zero context cost)
- `scripts/taste-history.sh` — visual score trends per dimension over time
- `scripts/flows-summary.sh` — latest flow audit results + issue trends
- `scripts/calibration-check.sh` — calibration readiness state

**References (read when needed, not upfront):**
- `references/dimensions.md` — 11 visual dimensions with scoring anchors
- `references/flows-protocol.md` — **how to run a flow audit step by step**
- `references/flow-checklist.md` — 6-layer behavioral checklist (what to check)
- `references/calibration-guide.md` — how calibration works

**Templates & docs:**
- `templates/taste-report.md` — output templates for all modes
- `reference.md` — architecture, key files, memory layout
- `gotchas.md` — real failure modes. **Read before every eval.**

## Routing

| Argument | Mode | Read first |
|----------|------|-----------|
| `<url> flows` | **Flow audit** — does it WORK? | `references/flows-protocol.md` + `gotchas.md` |
| `<url>` | Visual eval — is it well-designed? | `references/dimensions.md` + `gotchas.md` |
| `<url> mobile` | Visual eval at 390x844 | same as visual |
| `<url> deep` | Visual + click through interactions | same as visual |
| `vs <url1> <url2>` | Side-by-side comparison | `references/dimensions.md` |
| `trend` | Score trajectory over time | run `scripts/taste-history.sh` |
| `calibrate [sub]` | Ground eval in founder preferences | `references/calibration-guide.md` |
| (none) | Show available modes | — |

**The right order: flows first, then visual.** Fix broken functionality before polishing pixels.

## Flows mode

Read `references/flows-protocol.md` for the full protocol. Summary:

1. **Discover** — read product-spec + page snapshot to identify core flow
2. **Mechanical audit** — run JS checks from `scripts/checks/` via `browser_evaluate` + check console/network
3. **First contact** — can a stranger understand this in 5 seconds?
4. **Core flow** — walk the primary task step by step via Playwright
5. **Edge cases** — empty states, dead ends, deep links
6. **Responsive** — test at 390px mobile
7. **Report** — issue list by severity, cap at 10, write to `.claude/evals/reports/flows-{YYYY-MM-DD}.json`

**Optional fast path:** If node + playwright are installed locally, `node lens/product/eval/dom-eval.mjs --url <url> --json` runs comprehensive mechanical checks including axe-core WCAG contrast. Merge with MCP-based results.

Output is an **issue list**, not scores. See `templates/taste-report.md` for the flows template.

## Visual eval mode

Read `gotchas.md` first. Then:

1. **Load context** — run `scripts/calibration-check.sh`, read taste-learnings.md, founder-taste.md, design-system.md
2. **See the product** — navigate + screenshot + snapshot (3 pages max)
3. **Read the system** — code read for IA, layout, wayfinding, density dimensions
4. **Score 11 dimensions** — read `references/dimensions.md` for anchors. Score 0-100 with evidence.
5. **Prescribe** — for every dimension < 60: specific element, exact change, impact
6. **Compare** — run `scripts/taste-history.sh` for deltas and trend
7. **Remember** — write report JSON, append history TSV, update learnings
8. **Present** — use template from `templates/taste-report.md`

**Rules:** Gate (layout_coherence < 30 OR IA < 30 → cap at 30). Slop (AI-generated look → distinctiveness cap 30). Anti-inflation (avg > 70 non-mature → flag GENEROUS). When unsure, score lower.

## Calibrate mode

Read `references/calibration-guide.md`. Sub-modes: `profile`, `design-system`, `verify`, `drift`.

## Boundaries

**Write to:** `.claude/evals/taste-*`, `.claude/evals/reports/taste-*`, `.claude/evals/reports/flows-*`, `.claude/cache/calibration-history.json`

**Errors:** Playwright not installed → `browser_install`. URL won't load → report error. No past evals → "establishing baseline."

$ARGUMENTS
