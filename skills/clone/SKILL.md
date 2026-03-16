---
name: clone
description: "Use when reproducing a design from a URL using your framework and design tokens"
argument-hint: "<url> [verify|mobile|section <name>|history]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, WebFetch, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_resize, mcp__playwright__browser_navigate, mcp__playwright__browser_wait_for, mcp__playwright__browser_snapshot
---

# /clone

Screenshot a public URL, decompose the page into components, generate them in your stack using your conventions and design tokens. Never copy verbatim — placeholder content replaces brand-specific copy.

## Routing

Parse `$ARGUMENTS` to determine the route:

| Pattern | Route | What it does |
|---------|-------|--------------|
| `<url>` | **clone** | Full page clone (default — the 7-step flow below) |
| `<url> verify` | **verify** | Visual comparison of generated components against source |
| `<url> mobile` | **mobile** | Clone for mobile viewport (390x844) |
| `<url> section <name>` | **section** | Clone one section (hero, nav, footer, pricing, features, etc.) |
| `history` | **history** | Show past clone operations from clone-history.json |

If no arguments: use AskUserQuestion to ask for a URL.

---

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| clone-history | `.claude/cache/clone-history.json` | R+W | Past clone operations |
| design-system | `.claude/design-system.md` | R | Design tokens (from /calibrate) |
| founder-taste | `~/.claude/knowledge/founder-taste.md` | R | Founder preferences |

---

## Route: clone (default)

### Step 0: Check clone history

Read `.claude/cache/clone-history.json` if it exists. If this URL was cloned before, show what was generated last time:

```
◆ clone — previous operation found

  ⎯⎯ history ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [domain] — cloned [date]
  components: [N] generated
  compliance: ████████████████░░░░  [N]%

  Re-clone the full page, or clone a specific section?
```

Wait for founder response before proceeding. If no history file exists, create an empty one and continue.

### Step 1: Parse URL

Extract the URL from `$ARGUMENTS`. If no URL provided, use AskUserQuestion to ask for one.

### Step 2: Capture the page

Use Playwright MCP tools in sequence:

```
browser_navigate → URL
browser_wait_for → networkidle (or 3s timeout)
browser_take_screenshot → full page capture
browser_snapshot → accessibility tree (component structure)
```

Study both the screenshot and the accessibility tree. The screenshot shows visual design — layout, spacing, color, typography. The snapshot shows semantic structure — headings, landmarks, interactive elements.

### Step 3: Detect the founder's stack

Read these files in parallel to understand the codebase conventions:

- `package.json` — framework, dependencies, UI libraries
- Tailwind config (`tailwind.config.*`, `postcss.config.*`) — design tokens, theme
- `.claude/design-system.md` — documented design tokens from /calibrate
- `~/.claude/knowledge/founder-taste.md` — founder taste preferences
- 3 existing components (glob `src/components/**/*.{tsx,jsx,vue,svelte}` or `app/components/**/*`) — naming, structure, patterns

Determine:
- **Framework**: React/Next.js/Vue/Svelte/etc.
- **Styling**: Tailwind/CSS modules/styled-components/etc.
- **Component directory**: where components live
- **Naming convention**: PascalCase files? kebab-case? barrel exports?
- **Design tokens**: colors, spacing, fonts from tailwind config, design-system.md, or theme

If no codebase exists (empty repo, no package.json): default to React + Tailwind, note it to the founder.

### Step 4: Decompose the page

From the screenshot and accessibility tree, identify component boundaries:

- Navigation (nav, header)
- Hero / above-the-fold section
- Content sections (features, testimonials, pricing, etc.)
- Footer
- Reusable elements (cards, buttons, CTAs)

Name each component using the founder's naming convention.

### Step 5: Ask what to generate

Use AskUserQuestion:

> Found N components: [list them]. Generate all, or pick specific ones?

### Step 6: Generate components

For each selected component:

1. Create the file in the founder's component directory
2. Use the founder's framework and styling approach
3. Use design tokens from tailwind config / design-system.md — never hardcode hex colors, pixel values, or font names
4. Replace brand-specific copy with placeholder content (realistic but generic)
5. Import patterns match existing components (named exports, default exports, etc.)
6. Props interface if TypeScript

Each component is its own file. No monolithic page dump.

### Step 6.5: Design token compliance

After generating all components, scan them for hardcoded values:

- Hex colors that should use theme tokens (e.g., `#3B82F6` → `theme.primary` or `text-blue-500`)
- Pixel values that should use spacing tokens (e.g., `24px` → `space-6` or `gap-6`)
- Font stacks that should use typography tokens (e.g., `font-family: Inter` → `font-sans`)
- Hardcoded border-radius that should use radius tokens (e.g., `8px` → `rounded-lg`)

Report compliance %: `(total_values - hardcoded) / total_values x 100`

If compliance <80%: auto-fix the hardcoded values using the closest design token match. Show what was fixed:

```
  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  [N]% ([M] hardcoded values found)
  auto-fixed:
    Hero.tsx:12 — #3B82F6 → text-blue-500
    FeatureGrid.tsx:8 — 24px → gap-6
```

If compliance >=80%: report the number and list any remaining hardcoded values for manual review.

### Step 6.6: Responsive verification (if Playwright available)

If dev server is running and Playwright available:

1. Navigate to the local preview of generated components
2. Screenshot at desktop (1440px) and mobile (390px)
3. Screenshot source URL at same viewports
4. Compare: layout consistency, spacing proportions, element visibility
5. Flag differences: "Hero section stacks correctly but spacing is 2x source at mobile"

If dev server not running or Playwright unavailable, skip and note in the report.

### Step 7: Record to clone history

Append to `.claude/cache/clone-history.json`:

```json
{
  "date": "YYYY-MM-DD",
  "source_url": "https://...",
  "viewport": "desktop",
  "section": null,
  "components_generated": ["NavBar", "Hero", "FeatureGrid", "Footer"],
  "design_token_compliance": 85,
  "hardcoded_values": ["#3B82F6 in Hero.tsx:12", "24px in FeatureGrid.tsx:8"],
  "verification": null
}
```

### Step 8: Visual diff

Before reporting results, use Playwright to screenshot the generated components for visual comparison:

1. **Screenshot the source** at both viewports:
   ```
   browser_navigate → source URL
   browser_resize → 1440x900 (desktop)
   browser_take_screenshot → save to .claude/cache/clone-screenshots/[domain]-source-desktop.png
   browser_resize → 390x844 (mobile)
   browser_take_screenshot → save to .claude/cache/clone-screenshots/[domain]-source-mobile.png
   ```

2. **Screenshot generated components** (if dev server running):
   ```
   browser_navigate → local preview URL
   browser_resize → 1440x900 (desktop)
   browser_take_screenshot → save to .claude/cache/clone-screenshots/[domain]-local-desktop.png
   browser_resize → 390x844 (mobile)
   browser_take_screenshot → save to .claude/cache/clone-screenshots/[domain]-local-mobile.png
   ```

3. If dev server is not running, note "Start dev server for visual diff" and only capture source screenshots.

### Step 9: Report results

```
◆ clone — [url domain]

  ⎯⎯ capture ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  source: [url] → [screenshot dimensions]
  stack: [framework] + [styling] → [component directory]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  [N]%

  ⎯⎯ generated ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ NavBar        top navigation with links + CTA
  ✓ Hero          headline, subhead, two CTAs
  ✓ FeatureGrid   3-column feature cards
  ✓ Footer        links, social, copyright

  ⎯⎯ hardcoded values ([N] found) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ Hero.tsx:12        #3B82F6 → use text-blue-500
  ✓ NavBar.tsx          all tokens used correctly

  ⎯⎯ visual diff ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  screenshots saved:
    source  desktop: .claude/cache/clone-screenshots/[domain]-source-desktop.png
    source  mobile:  .claude/cache/clone-screenshots/[domain]-source-mobile.png
    local   desktop: .claude/cache/clone-screenshots/[domain]-local-desktop.png
    local   mobile:  .claude/cache/clone-screenshots/[domain]-local-mobile.png

  responsive match:
    desktop (1440px): ██████████████████░░  90%
    mobile  (390px):  ████████████░░░░░░░░  62%

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

/clone <url> verify    visual comparison dashboard
/clone <url> mobile    mobile-first clone
/eval taste            full visual eval
/feature [name]        define what this builds toward
```

---

## Route: verify

Visual comparison of generated components against the source URL. Use when you want to audit fidelity after a clone operation.

### Steps

1. **Parse URL** from `$ARGUMENTS` (strip `verify` suffix).

2. **Check clone history** — find the most recent clone of this URL in `.claude/cache/clone-history.json`. If no history, tell the founder: "No clone history for this URL. Run `/clone <url>` first."

3. **Screenshot the source** at both viewports:
   ```
   browser_navigate → source URL
   browser_resize → 1440x900 (desktop)
   browser_take_screenshot → desktop capture
   browser_resize → 390x844 (mobile)
   browser_take_screenshot → mobile capture
   ```

4. **Screenshot local preview** — if dev server is running, navigate to the local page containing the cloned components. Screenshot at both 1440px and 390px. If no dev server, skip and note it.

5. **Design token compliance scan** — re-scan all generated component files for hardcoded values. Report compliance % and list every hardcoded value with its file and line number.

6. **Visual comparison report** — study the source screenshots vs. local screenshots. For each component, report:
   - Layout match (structure, element order, grid/flex behavior)
   - Spacing match (gaps, padding, margins — proportional, not pixel-exact)
   - Typography match (hierarchy, weight, size relationships)
   - Color match (palette fidelity via tokens, not hex matching)
   - Responsive behavior (does it stack/reflow similarly at mobile?)

7. **Update clone history** — update the most recent entry for this URL with verification results.

### Output

Use `browser_take_screenshot` to capture source at 1440px and 390px, and local preview at the same viewports. Use `browser_resize` to switch between desktop (1440x900) and mobile (390x844). Save all screenshots to `.claude/cache/clone-screenshots/` for the founder to view directly.

```
◆ clone verify — [url domain]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  [N]%

  ⎯⎯ hardcoded values ([N] found) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ Hero.tsx:12        #3B82F6 → use text-blue-500
  ⚠ FeatureGrid.tsx:8  24px → use gap-6
  ✓ NavBar.tsx          all tokens used correctly
  ✓ Footer.tsx          all tokens used correctly

  ⎯⎯ visual comparison dashboard ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  screenshots:
    source  desktop: .claude/cache/clone-screenshots/[domain]-source-desktop.png
    source  mobile:  .claude/cache/clone-screenshots/[domain]-source-mobile.png
    local   desktop: .claude/cache/clone-screenshots/[domain]-local-desktop.png
    local   mobile:  .claude/cache/clone-screenshots/[domain]-local-mobile.png

                        source    local     delta
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  layout (desktop)      ----      ----      ✓ match
  layout (mobile)       ----      ----      ⚠ stacks but gap 2x
  spacing               16/24px   24/32px   ⚠ 1.5x source
  typography            3 levels  3 levels  ✓ match
  color palette         tokens    tokens    ✓ via design system
  touch targets (390)   ----      44px+     ✓ accessible
  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  responsive match:
    desktop (1440px): ██████████████████░░  90%
    mobile  (390px):  ████████████░░░░░░░░  62%

  ⎯⎯ issues ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ mobile spacing 2x source — adjust gap-8 → gap-4
  ✗ footer links not visible at 390px — overflow hidden

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

/clone <url> mobile         fix mobile issues
/eval taste                 full visual eval
/calibrate design-system    document tokens
```

---

## Route: mobile

Clone specifically for mobile viewport (390x844). Generates mobile-first components with responsive breakpoints going up.

### Steps

1. **Parse URL** from `$ARGUMENTS` (strip `mobile` suffix).

2. **Check clone history** — same as default route. If previously cloned at desktop, note it and ask: "Desktop clone exists. Generate mobile variants, or replace?"

3. **Capture at mobile viewport**:
   ```
   browser_navigate → URL
   browser_resize → 390x844
   browser_wait_for → networkidle (or 3s timeout)
   browser_take_screenshot → full page capture at mobile
   browser_snapshot → accessibility tree
   ```

4. **Also capture desktop** for reference:
   ```
   browser_resize → 1440x900
   browser_take_screenshot → desktop reference
   ```

5. **Detect stack** — same as default route (Step 3).

6. **Decompose for mobile** — identify components from the mobile layout. Mobile often differs: hamburger nav instead of horizontal, stacked sections instead of grids, hidden elements. Decompose what mobile actually shows, not what desktop shows.

7. **Generate mobile-first components** — write components with:
   - Base styles for mobile (390px)
   - `sm:` / `md:` / `lg:` breakpoints scaling up to desktop
   - Touch targets at 44px minimum
   - No horizontal scroll at any viewport
   - Stack-first layouts (single column base, grid at breakpoints)

8. **Design token compliance** — same as Step 6.5 in default route.

9. **Record to clone history** — with `"viewport": "mobile"`.

10. **Report results** — same format as default route, with mobile-specific notes:

```
◆ clone mobile — [url domain]

  ⎯⎯ capture ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  source: [url] → 390x844 (mobile-first)
  stack: [framework] + [styling] → [component directory]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  [N]%

  ⎯⎯ generated (mobile-first) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ MobileNav      hamburger menu, slide-out drawer
  ✓ Hero           stacked headline + CTA, full-width image
  ✓ FeatureList    single column, expandable cards
  ✓ Footer         stacked links, simplified

  ⎯⎯ responsive breakpoints ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ 390px   base (mobile)        ██████████████████████  verified
  ✓ 640px   sm (tablet portrait)  ████████████████░░░░░░  interpolated
  ✓ 1024px  lg (desktop)          ████████████████░░░░░░  interpolated

  ⎯⎯ visual diff ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  screenshots saved:
    source  mobile:  .claude/cache/clone-screenshots/[domain]-source-mobile.png
    source  desktop: .claude/cache/clone-screenshots/[domain]-source-desktop.png
    local   mobile:  .claude/cache/clone-screenshots/[domain]-local-mobile.png

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

/clone <url> verify    compare against source
/clone <url>           desktop clone
/eval taste            full visual eval
```

---

## Route: section

Clone just one section from the page. Faster, more focused. Good for borrowing a specific pattern (a pricing table, a nav pattern, a hero layout).

### Steps

1. **Parse URL and section name** from `$ARGUMENTS`. Expected format: `<url> section <name>`. Section name is freeform — hero, nav, footer, pricing, features, testimonials, cta, etc.

2. **Capture the full page** — same as Step 2 in default route. You need the full page to locate the section.

3. **Identify the target section** — from the screenshot and accessibility tree, find the section matching the requested name. If ambiguous (e.g., multiple "features" sections), ask the founder which one. If not found, list what sections exist and ask.

4. **Detect stack** — same as default route (Step 3).

5. **Generate the section** — create one or more component files for just this section. Follow all the same rules: design tokens, naming convention, placeholder content, proper imports.

6. **Design token compliance** — same scan, but only on the generated section files.

7. **Record to clone history** — with `"section": "<name>"`.

8. **Report**:

```
◆ clone section — [section name] from [url domain]

  ⎯⎯ capture ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  source: [url] → isolated [section name]
  stack: [framework] + [styling] → [component directory]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ██████████████████░░  92%

  ⎯⎯ generated ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ PricingTable   3 tiers, toggle annual/monthly
  ✓ PricingCard    individual tier card (reusable)

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

/clone <url>              full page clone
/clone <url> section nav  clone another section
/clone <url> verify       visual comparison dashboard
```

---

## Route: history

Show past clone operations.

### Steps

1. Read `.claude/cache/clone-history.json`. If it doesn't exist, report "No clone history yet."

2. Display each entry with: date, source URL domain, viewport, section (if applicable), component count, token compliance %, and verification status.

### Output

```
◆ clone history — [N] operations

  ⎯⎯ recent clones ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  2026-03-16  example.com       4 components  ████████████████░░░░  85%  verified
  2026-03-15  competitor.io     2 components  ██████████████████░░  92%
  2026-03-14  landing-ref.com   6 components  █████████████░░░░░░░  67%  ⚠ 8 hardcoded

  ⎯⎯ compliance trend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  03-14  █████████████░░░░░░░  67%
  03-15  ██████████████████░░  92%  +25
  03-16  ████████████████░░░░  85%  -7

  avg: 81%   trend: improving

  ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

/clone <url>                clone a new page
/clone <url> verify         audit existing
/calibrate design-system    improve compliance
```

---

## Clone History Protocol

After every clone operation (any route except `history`), append to `.claude/cache/clone-history.json`. Create the file and `.claude/cache/` directory if they don't exist.

Schema:

```json
{
  "clones": [
    {
      "date": "2026-03-16",
      "source_url": "https://example.com",
      "viewport": "desktop|mobile",
      "section": null,
      "components_generated": ["NavBar", "Hero", "FeatureGrid", "Footer"],
      "design_token_compliance": 85,
      "hardcoded_values": ["#3B82F6 in Hero.tsx:12", "24px in FeatureGrid.tsx:8"],
      "verification": null
    }
  ]
}
```

Before cloning a URL, check clone-history.json: if this URL was cloned before, show what was generated last time and ask if this is a re-clone or new section.

The `verify` route updates the most recent entry for that URL, setting `"verification"` to a summary object:

```json
{
  "verified_date": "2026-03-16",
  "compliance_at_verify": 92,
  "issues": ["mobile spacing 2x source", "footer links not visible at 390px"]
}
```

---

## Anti-rationalization checks

Run these checks silently during every clone operation. If any trigger, surface them in the report.

- **"Generated without reading design-system.md"** — if the project has a documented design system (from /calibrate), it MUST be used. Clone without tokens = technical debt from line 1. If `.claude/design-system.md` exists and wasn't consulted, flag: "Generated components without design system. Re-run with tokens."

- **"Hardcoded values in generated code"** — report exact count. >5 hardcoded values = flag in report: "⚠ [N] hardcoded values. Run `/clone <url> verify` to audit."

- **"No visual verification"** — if Playwright is available and dev server running, MUST run Step 6.6. Skipping verification when tools are available = shipping blind. Flag: "Visual verification skipped despite available tools."

- **"Pixel-perfect obsession"** — if founder pushes for exact replication, flag: "Exact copy creates maintenance debt. Match the PATTERN, not the pixels. Use your design tokens."

- **"Cloning without understanding"** — if the founder has cloned 3+ URLs (check history) without defining features for the generated components, flag: "Cloned components need a home. `/feature new [name]` to track them."

---

## What you never do

- Copy brand-specific text verbatim — always replace with placeholder content
- Hardcode hex colors, pixel values, or font stacks — use design tokens
- Generate one massive file — decompose into real components
- Install dependencies — work with what's already in the project
- Modify crown jewels (score.sh, taste.mjs, eval.sh, self.sh)
- Skip the screenshot — visual context is essential for accurate decomposition
- Skip reading design-system.md when it exists — tokens are non-negotiable
- Skip clone history check — always check for previous clones of the same URL

---

## If something breaks

### Degraded modes

- **No Playwright** — use WebFetch for source page HTML + CSS. Note: "Visual capture unavailable — generating from HTML structure only. Quality will be lower. Ensure the Playwright MCP server is running for full fidelity."
- **No design-system.md** — detect tokens from tailwind config or CSS variables. Note: "No design system documented. Run `/calibrate design-system` for better token compliance."
- **No existing components** — default to React + Tailwind. Ask founder to confirm framework before generating.
- **No package.json** — ask founder for stack preference before proceeding.
- **Private/auth-gated URL** — "Only works on public pages. Try WebFetch as fallback for HTML-only clone." WebFetch may retrieve HTML even when Playwright can't render the auth gate.
- **Dev server not running** — skip responsive verification (Step 6.6). Note: "Start dev server for visual comparison. Run `/clone <url> verify` after."
- **No clone-history.json** — create `.claude/cache/clone-history.json` with empty `{"clones": []}`. Note: "First tracked clone operation."
- **URL won't load** — try with `browser_wait_for` timeout of 5s, then report the error. If repeated failure, fall back to WebFetch.
- **No components directory found** — ask the founder where components should go.

$ARGUMENTS
