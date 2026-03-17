# /clone Reference — Output Templates

Loaded on demand. Steps and routing are in SKILL.md.

---

## Clone output (default)

```
◆ clone — [url domain]

  ⎯⎯ capture ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  source: [url] → [screenshot dimensions]
  stack: [framework] + [styling] → [component directory]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  85%

  ⎯⎯ generated ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ NavBar        top navigation with links + CTA
  ✓ Hero          headline, subhead, two CTAs
  ✓ FeatureGrid   3-column feature cards
  ✓ Footer        links, social, copyright

  ⎯⎯ hardcoded values ([N] found) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ Hero.tsx:12        #3B82F6 → use text-blue-500
  ✓ NavBar.tsx          all tokens used correctly

  ⎯⎯ visual diff ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▾ screenshots
    source  desktop: .claude/cache/clone-screenshots/[domain]-source-desktop.png
    source  mobile:  .claude/cache/clone-screenshots/[domain]-source-mobile.png
    local   desktop: .claude/cache/clone-screenshots/[domain]-local-desktop.png
    local   mobile:  .claude/cache/clone-screenshots/[domain]-local-mobile.png

  responsive match:
    desktop (1440px): ██████████████████░░  90%
    mobile  (390px):  ████████████░░░░░░░░  62%

/clone <url> verify    visual comparison dashboard
/clone <url> mobile    mobile-first clone
/taste                 full visual eval
```

## Verify output

```
◆ clone verify — [url domain]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  85%

  ⎯⎯ hardcoded values ([N] found) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ Hero.tsx:12        #3B82F6 → use text-blue-500
  ⚠ FeatureGrid.tsx:8  24px → use gap-6
  ✓ NavBar.tsx          all tokens used correctly
  ✓ Footer.tsx          all tokens used correctly

  ⎯⎯ comparison ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▾ screenshots
    source  desktop: .claude/cache/clone-screenshots/[domain]-source-desktop.png
    source  mobile:  .claude/cache/clone-screenshots/[domain]-source-mobile.png
    local   desktop: .claude/cache/clone-screenshots/[domain]-local-desktop.png
    local   mobile:  .claude/cache/clone-screenshots/[domain]-local-mobile.png

  dimension        source    local     delta
  layout (desktop)    --        --      ✓ match
  layout (mobile)     --        --      ⚠ stacks but gap 2x
  spacing           16/24px   24/32px   ⚠ 1.5x source
  typography        3 levels  3 levels  ✓ match
  color palette     tokens    tokens    ✓ via design system
  touch targets     --        44px+     ✓ accessible

  responsive match:
    desktop (1440px): ██████████████████░░  90%
    mobile  (390px):  ████████████░░░░░░░░  62%

  ⎯⎯ issues ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ⚠ mobile spacing 2x source — adjust gap-8 → gap-4
  ✗ footer links not visible at 390px — overflow hidden

/clone <url> mobile         fix mobile issues
/taste                      full visual eval
/clone <url> section hero   refine one section
```

## Mobile output

```
◆ clone mobile — [url domain]

  ⎯⎯ capture ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  source: [url] → 390x844 (mobile-first)
  stack: [framework] + [styling] → [component directory]

  ⎯⎯ token compliance ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  compliance: ████████████████░░░░  88%

  ⎯⎯ generated (mobile-first) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ MobileNav      hamburger menu, slide-out drawer
  ✓ Hero           stacked headline + CTA, full-width image
  ✓ FeatureList    single column, expandable cards
  ✓ Footer         stacked links, simplified

  ⎯⎯ responsive breakpoints ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ 390px   base (mobile)         verified
  ✓ 640px   sm (tablet portrait)  interpolated
  ✓ 1024px  lg (desktop)          interpolated

/clone <url> verify    compare against source
/clone <url>           desktop clone
/taste                 full visual eval
```

## Section output

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

/clone <url>              full page clone
/clone <url> section nav  clone another section
/clone <url> verify       visual comparison
```

## History output

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

/clone <url>                clone a new page
/clone <url> verify         audit existing
/taste                      visual eval
```

## Formatting rules

- Header: `◆ clone — [url domain]` or `◆ clone verify`, `◆ clone mobile`, `◆ clone section`
- Labeled dividers for subsections: capture, token compliance, generated, visual diff
- Generated components: `✓` prefix with component name + brief description
- Compliance: bold %, 20-char bar
- Hardcoded values: `⚠` for violations, `✓` for clean files
- Screenshots: file paths indented under `▾ screenshots`
- Comparison: column-aligned with `✓`/`⚠`/`✗` delta indicators
- Responsive match: bars per viewport
- Bottom: exactly 3 next commands
