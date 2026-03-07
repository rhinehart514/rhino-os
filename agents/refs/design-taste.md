# Design Taste Framework

Subjective evaluation criteria for UI/UX. Not about correctness — about whether it *feels* right.

## The 8 Taste Dimensions

### 1. Hierarchy (does the eye know where to go?)
- **5/5**: Clear visual order. Primary action dominates. Supporting content recedes. The page "reads" naturally.
- **3/5**: Some hierarchy exists but competing elements. Two things fighting for attention.
- **1/5**: Everything is the same size, weight, and color. Flat information with no priority signal.

**How to check in code:**
- Look at font sizes used on a page — is there meaningful range? (e.g., text-3xl → text-base → text-sm)
- Look at font weights — is bold used sparingly or on everything?
- Look at colors — is there a clear primary vs secondary text color?
- Count CTAs per screen — more than 2 primary buttons = hierarchy failure

### 2. Breathing Room (does the layout breathe?)
- **5/5**: Whitespace is intentional. Groups are separated. Nothing feels cramped. Spacious but not empty.
- **3/5**: Adequate spacing but uniform. Everything has the same gap. No rhythm.
- **1/5**: Elements crammed together. No padding. Borders touching. Walls of content.

**How to check in code:**
- Look at padding/gap values — is there a spacing rhythm? (e.g., 4 → 6 → 8 → 12)
- Section spacing should be larger than element spacing (macro > micro whitespace)
- Container max-widths — is content going edge-to-edge or contained?

### 3. Contrast & Emphasis (do important things pop?)
- **5/5**: Primary actions unmissable. Clear difference between interactive and static. Active states obvious.
- **3/5**: Some contrast but could be stronger. Links don't quite stand out from text.
- **1/5**: Everything blends together. Can't tell what's clickable. No visual weight differences.

**How to check in code:**
- Button prominence — is the primary button visually distinct from secondary/ghost?
- Color contrast between bg and interactive elements
- Active/selected states — do tabs, nav items, toggles show state clearly?

### 4. Polish Signals (does it feel alive?)
- **5/5**: Hover states on everything interactive. Smooth transitions. Loading feedback. Micro-animations that add delight.
- **3/5**: Some hover states. Transitions exist but inconsistent. Loading states present.
- **1/5**: Dead clicks. No hover feedback. Jarring state changes. Elements appear/disappear without transition.

**How to check in code:**
- Search for `hover:` — how many interactive elements have it?
- Search for `transition` / `duration-` / `animate-` — any motion at all?
- Do modals/dropdowns animate in or just appear?
- Does button click have feedback (active state, loading spinner)?

### 5. Emotional Tone (does it match the product?)
- **5/5**: The UI feels like the product's personality. A playful app feels playful. A serious tool feels serious.
- **3/5**: Neutral. Not offensive but not distinctive. Could be any product.
- **1/5**: Mismatch. A creative tool that looks like a tax app. A social product that feels corporate.

**Product type → Expected tone:**
- Developer tools → Precision, density, utility (dark mode, monospace accents, compact)
- Consumer/social → Warmth, approachability, playfulness (rounded, colorful, generous spacing)
- Finance/enterprise → Trust, sophistication, restraint (serif accents, muted palette, structured)
- Creative tools → Boldness, expressiveness (distinctive typography, unexpected color, asymmetry)
- Productivity → Clarity, efficiency, calm (clean lines, purposeful color, information-forward)

### 6. Information Density (right amount per screen?)
- **5/5**: Goldilocks — enough content to be useful, not so much it overwhelms. Scannable.
- **3/5**: Slightly off — either a bit sparse (lots of scrolling for little info) or a bit dense (need to concentrate).
- **1/5**: Extreme — either wastefully empty (a paragraph floating in a sea of white) or a wall of text/data.

**How to check in code:**
- Count distinct "sections" or "cards" per page — 3-7 is usually right
- Check for max-width constraints on text (prose should max at ~65 characters per line)
- Data tables — do they have pagination/scrolling or dump everything?

### 7. Flow & Wayfinding (can users navigate without thinking?)
- **5/5**: Next action is always obvious. Breadcrumbs/context present. Navigation is consistent. No dead ends.
- **3/5**: Navigation works but has dead ends or unclear "what next?" moments. Some pages lack back navigation.
- **1/5**: Users would get lost. No clear path. Navigation inconsistent between pages. Dead-end screens everywhere.

**How to check in code:**
- Pages with no outbound links or CTAs = dead ends
- Forms with no redirect after submit
- Empty states with no guidance on what to do
- Modals with no close button or escape handler
- Check that all pages are reachable from the main navigation

### 8. Distinctiveness (is this memorable?)
- **5/5**: You'd recognize this product in a lineup. It has a visual identity — not just a framework's defaults.
- **3/5**: Competent but generic. Could be any product in this category.
- **1/5**: Pure framework defaults. Looks like the Tailwind tutorial template.

**What makes products distinctive (pick at least ONE):**
- A non-default font choice (Google Fonts has 1600+ options, not just Inter/Geist)
- An unexpected accent color (not blue, not purple)
- A unique layout approach (not just stacked cards)
- A micro-interaction that surprises (a clever loading animation, a satisfying toggle)
- A brand illustration style (even a simple one)
- An unconventional information pattern (bento grid, timeline, kanban)

---

## Recommendation Patterns

When suggesting improvements, match these to the product type:

### For SaaS Dashboards
- Bento grid layouts (varied card sizes create rhythm)
- Data visualization accents (even simple bar sparklines add sophistication)
- Compact, scannable tables with row hover states
- Status indicators with color coding
- Keyboard shortcuts badge UI

### For Consumer/Social Products
- Avatar-forward design (user identity visible everywhere)
- Feed patterns with varied content types
- Empty states with personality (illustration + witty copy)
- Pull-to-refresh / infinite scroll done well
- Reaction/emoji UIs

### For Landing Pages / Marketing
- Hero with clear hierarchy (headline > subhead > CTA > social proof)
- Section transitions (background color shifts, not just padding)
- Testimonials with photos and names (not anonymous quotes)
- Feature grids with icons that actually communicate
- Pricing table with the recommended plan highlighted

### For Developer Tools
- Code block styling with syntax highlighting
- Terminal/CLI-inspired UI elements
- Documentation-style navigation (sidebar + content + right TOC)
- Monospace accents in headers or badges
- Copy-to-clipboard on every code snippet

### For Mobile-First / PWA
- Bottom navigation (thumb zone)
- Swipe actions on list items
- Pull-down to refresh
- 44px minimum touch targets
- App-like transitions between views

---

## Anti-Slop Checklist

Score 0 (bad) or 1 (good) for each. Total < 5 = high slop risk.

- [ ] Uses a non-default font (not Inter, not system-ui alone)
- [ ] Has at least one color that isn't blue or gray
- [ ] Spacing varies intentionally (not p-4 on everything)
- [ ] Has at least one page layout that isn't "cards in a grid"
- [ ] Interactive elements have hover/active states
- [ ] At least one micro-animation exists (transition, not just `hidden`/`block`)
- [ ] Empty states have personality (not just "No items")
- [ ] Error states give guidance (not just "Something went wrong")
- [ ] Loading states match content shape (not a generic spinner)
- [ ] The product would be recognizable with the logo hidden
