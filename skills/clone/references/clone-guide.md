# Clone Guide

How /clone works, what makes a good clone, and where it breaks. Read on demand when generating components.

## What makes a good clone

A good clone captures the **pattern**, not the **pixels**. You're stealing the information architecture, layout strategy, and visual rhythm — not making an exact replica.

### Do steal
- Layout structure (grid/flex patterns, content flow)
- Visual hierarchy (what's big, what's small, what's bold, what's muted)
- Spacing rhythm (consistent gaps, padding relationships)
- Component boundaries (where one section ends and another begins)
- Responsive behavior (how things stack, collapse, or hide at breakpoints)

### Don't steal
- Brand colors (use YOUR design tokens)
- Exact pixel measurements (use YOUR spacing scale)
- Font choices (use YOUR typography tokens)
- Copy/content (use realistic placeholder text)
- Brand-specific imagery (use generic or no images)

## Decomposition strategy

When looking at a page screenshot + accessibility tree:

1. **Identify landmarks first**: nav, main, footer. These are your top-level components.
2. **Find repeated patterns**: Cards, list items, table rows. These become reusable sub-components.
3. **Respect semantic boundaries**: A "pricing section" is one component even if it contains 3 cards. The cards are sub-components.
4. **Name using founder conventions**: Check existing components for naming patterns (PascalCase, kebab-case, barrel exports).

## Token compliance

After generation, every component must use design system tokens:

| Hardcoded | Should be |
|-----------|-----------|
| `#3B82F6` | `text-blue-500` or `theme.primary` |
| `24px` | `gap-6` or `space-6` |
| `font-family: Inter` | `font-sans` |
| `border-radius: 8px` | `rounded-lg` |
| `16px` / `32px` | `p-4` / `p-8` |

Compliance target: 80%+. Below 80%: auto-fix with closest token match.

Sources for tokens (in priority order):
1. `.claude/design-system.md` (from /calibrate)
2. `tailwind.config.*` (theme extensions)
3. CSS variables in global stylesheet
4. Existing component patterns (what tokens do other components use?)

## Responsive approach

- **Desktop clone**: Start with desktop layout, add mobile breakpoints going down
- **Mobile clone**: Start with mobile (390px), add breakpoints going up with `sm:`, `md:`, `lg:`
- **Touch targets**: Minimum 44x44px on any interactive element at mobile
- **No horizontal scroll**: At any viewport. If the source has horizontal scroll at mobile, fix it.

## Limitations

- **Auth-gated pages**: Playwright can't get past login screens. Use WebFetch for HTML-only fallback.
- **Heavy JS pages**: SPA content that loads after JavaScript may not appear in initial screenshot. Use `browser_wait_for` with a longer timeout.
- **Dynamic content**: Animations, carousels, and interactive state won't clone. You get the static state visible at capture time.
- **Fonts**: The source's custom fonts won't be available. Map to the closest token in the founder's type system.
- **Images**: Don't download or hotlink source images. Use placeholder divs with appropriate aspect ratios, or placeholder image services.

## When to use /clone vs building from scratch

Use /clone when:
- You want a proven layout pattern (landing page, pricing table, dashboard layout)
- The source page has good information architecture you want to learn from
- Speed matters more than originality

Build from scratch when:
- The design is highly custom or interactive
- The source doesn't match your product's information architecture
- You need to rethink the layout, not replicate it
