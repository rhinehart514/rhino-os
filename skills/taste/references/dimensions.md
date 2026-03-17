# Taste Dimensions — Scoring Anchors & What Moves Each

Read on demand during Phase 4 (scoring). Each dimension includes what it measures, concrete anchors at key score bands, and what changes actually move the score.

---

## Gate Dimensions

These cap the overall score at 30 if either scores below 30. Fix the skeleton before decorating.

### layout_coherence

Does the layout have a system? Same grid, same spacing logic, same component sizing across pages.

| Score | Anchor |
|-------|--------|
| 90-100 | Every element sits on a visible grid. Spacing is mathematical. Cross-page consistency is flawless. (Linear, Stripe) |
| 70-89 | Clear grid system with occasional breaks. Spacing feels intentional. Pages share a skeleton. |
| 50-69 | Some alignment consistency but gaps visible. Mix of spacing values. Some pages feel different. |
| 30-49 | Elements float independently. Spacing is ad-hoc. Pages don't feel related. |
| 0-29 | No discernible system. Random placement. Different layout logic per page. |

**What moves this score:**
- Consistent spacing scale (4/8/16/24/32px, not arbitrary values)
- Shared layout components (same header/sidebar/content grid across routes)
- Alignment: elements that should align, do
- Removing one-off spacing overrides

**What doesn't move this score:**
- Color changes, font changes, adding decoration
- New features on existing layout (neutral unless they break the grid)

---

### information_architecture

Can you describe the organizing principle in one sentence? Does nav reach all destinations?

| Score | Anchor |
|-------|--------|
| 90-100 | Crystal clear mental model. Nav is complete. You always know where you are and where everything else is. (Notion, GitHub) |
| 70-89 | Strong organizing principle. Most pages reachable from nav. Occasional dead end. |
| 50-69 | Organization exists but isn't obvious. Some orphan pages. Nav has gaps. |
| 30-49 | Hard to describe the structure. Multiple orphan routes. Nav feels incomplete. |
| 0-29 | No coherent organization. Can't find things. Pages exist without nav access. |

**What moves this score:**
- Complete navigation that reaches all routes
- Breadcrumbs or location indicators
- Consistent content grouping (all settings in one place, not scattered)
- Removing orphan pages or linking them into the nav

**What doesn't move this score:**
- Visual styling of nav elements (that's polish)
- Adding new content without adding it to nav (actually hurts)

---

## Visual Dimensions

Scored primarily from screenshots.

### hierarchy

Do I know what this is and where to look? Clear primary element per screen, one primary action per view.

| Score | Anchor |
|-------|--------|
| 90-100 | Eye goes exactly where intended. Primary action unmistakable. Supporting elements clearly subordinate. (Apple product pages) |
| 70-89 | Clear primary element. Good size/weight differentiation. Minor competing elements. |
| 50-69 | Can find the primary element but it doesn't command attention. Multiple elements compete. |
| 30-49 | Everything same visual weight. No clear starting point. Multiple "loud" elements. |
| 0-29 | Visual chaos. Can't determine what matters. |

**What moves this score:**
- Size contrast between primary and secondary elements (2x+ difference)
- Reducing visual weight of secondary elements (lighter color, smaller text)
- One CTA per viewport, clearly distinguished
- Heading hierarchy (h1 > h2 > h3 with visible size steps)

### breathing_room

Does this feel calm or chaotic? Whitespace that aids comprehension.

| Score | Anchor |
|-------|--------|
| 90-100 | Generous, intentional whitespace. Every element has room to breathe. Content sections clearly separated. (Stripe docs) |
| 70-89 | Good spacing between sections. Some tight areas but nothing cramped. |
| 50-69 | Adequate spacing but doesn't feel generous. Some areas feel busy. |
| 30-49 | Cramped. Elements crowd each other. Little separation between sections. |
| 0-29 | Wall of content. No breathing room. Hostile density. |

**What moves this score:**
- Increasing section padding (24px to 48px between major sections)
- Line height on body text (1.5+ for readability)
- Margin between cards/list items
- Reducing content per viewport (progressive disclosure instead of showing everything)

### contrast

Can I tell what's clickable? Color and weight contrast between interactive and static elements.

| Score | Anchor |
|-------|--------|
| 90-100 | Instantly clear what's interactive. Links, buttons, inputs all visually distinct from text. Hover states confirm expectations. |
| 70-89 | Most interactive elements distinguishable. Good color contrast. Minor ambiguity. |
| 50-69 | Can figure out what's clickable but requires scanning. Some low-contrast text. |
| 30-49 | Frequently confused about what's interactive. Low contrast text. Links blend with body. |
| 0-29 | Can't distinguish interactive from static. Fails WCAG contrast. |

**What moves this score:**
- Color differentiation for interactive elements (not just underlines)
- WCAG AA contrast ratios (4.5:1 for text, 3:1 for large text)
- Hover/focus states on all interactive elements
- Consistent interactive element styling (all links look like links)

### polish

Does this feel like someone cared? Pixel-level refinement.

| Score | Anchor |
|-------|--------|
| 90-100 | Every detail is intentional. Consistent radius, aligned icons, proper line heights, no visual glitches. (Linear, Raycast) |
| 70-89 | High overall quality with rare imperfections. Consistent component styling. |
| 50-69 | Serviceable but generic. Some inconsistencies in radius, spacing, or icon sizing. |
| 30-49 | Visible shortcuts. Misaligned elements, inconsistent component styling, default browser UI leaking through. |
| 0-29 | Unfinished. Broken layouts, unstyled defaults, placeholder content visible. |

**What moves this score:**
- Consistent border-radius across all components
- Aligned icons (same size, same visual weight)
- Proper line-height and letter-spacing
- Eliminating default browser UI (unstyled scrollbars, default focus rings)
- Consistent shadow and elevation system

### emotional_tone

Would I tell a friend about this? Does the visual design match the product's personality?

| Score | Anchor |
|-------|--------|
| 90-100 | The design has a clear personality. You could describe the vibe in one word. It matches the product's purpose perfectly. (Notion: calm productivity. Linear: precise engineering.) |
| 70-89 | Personality visible. Design choices feel deliberate. Tone is consistent. |
| 50-69 | Neutral. Professional enough but no personality. Could be any product. |
| 30-49 | Mixed signals. Some elements say "fun" while others say "enterprise." Incoherent tone. |
| 0-29 | Design actively undermines the product's purpose (playful UI for security product, corporate for creative tool). |

**What moves this score:**
- Color palette that matches the product's personality
- Microcopy with voice (not generic "Welcome to your dashboard")
- Illustration or visual elements that reinforce tone
- Consistency — one personality, not a committee

### distinctiveness

Would I recognize this tomorrow? Or does it look like every other app?

| Score | Anchor |
|-------|--------|
| 90-100 | Instantly recognizable. Unique visual language that only makes sense for this product. (Figma, Arc, Superhuman) |
| 70-89 | Notable design choices. Would recognize in a screenshot lineup. Some borrowed patterns. |
| 50-69 | Clean but generic. Could be any SaaS app. Tailwind/shadcn energy. |
| 30-49 | Template-based. No element that's specific to this product. |
| 0-29 | Default framework output. AI-generated landing page energy. |

**What moves this score:**
- One element that only makes sense for THIS product (domain-specific visualization, unique interaction)
- Custom color palette (not shadcn defaults)
- Microcopy with personality (not "Sign up for free")
- A visual signature (specific shape, pattern, or layout unique to this product)

**Slop rule applies here:** If the page could be generated by prompting an AI with "build me a [category] page" — cap at 30.

### scroll_experience

Does below-the-fold content reward scrolling? Not just more of the same.

| Score | Anchor |
|-------|--------|
| 90-100 | Scrolling reveals new information types, not just more cards. Content density changes. Scroll position feels intentional. |
| 70-89 | Good content progression. Some variety below fold. Clear sections. |
| 50-69 | Content continues but doesn't surprise. Same pattern repeating. |
| 30-49 | Long scroll with no new information type. Card grid extending forever. |
| 0-29 | Nothing below the fold worth seeing. Or excessive scroll for minimal content. |

**What moves this score:**
- Content type variety (text section, then visual, then testimonial — not card, card, card)
- Section-level visual breaks (background color changes, full-width elements)
- Progressive information disclosure (overview first, detail as you scroll)
- Sticky elements that contextualize scroll position

---

## System Dimensions

Scored from code + screenshots combined.

### wayfinding

Do I know what to do next? Can I get back? Requires understanding the nav model + data flow.

| Score | Anchor |
|-------|--------|
| 90-100 | Always know where you are, how you got here, and where you can go. Back navigation always works. Next action is obvious. |
| 70-89 | Good orientation. Active states in nav. Most flows have clear next steps. Rare dead ends. |
| 50-69 | Can navigate but requires thinking. Some dead ends after completing actions. |
| 30-49 | Frequently lost. Dead ends after key actions. No active state in nav. |
| 0-29 | Can't find your way. No back button logic. Stranded after actions. |

**What moves this score:**
- Active states in navigation (user knows where they are)
- After every action, clear next step or return path
- Breadcrumbs for deep hierarchies
- Removing dead ends (every page leads somewhere)

### information_density

Am I informed or overwhelmed? Right amount for the task. Requires understanding what data is shown and why.

| Score | Anchor |
|-------|--------|
| 90-100 | Every piece of visible information serves the current task. Dense when needed (dashboards), sparse when needed (onboarding). Perfect match. |
| 70-89 | Good density calibration. Most information is relevant. Minor clutter or gaps. |
| 50-69 | Acceptable but not optimized. Some screens too sparse, others too dense. |
| 30-49 | Mismatch between content and purpose. Dashboard that's empty. Settings page that's overwhelming. |
| 0-29 | Hostile density (wall of text) or hostile sparsity (page with one button and no context). |

**What moves this score:**
- Progressive disclosure (show summary, expand for detail)
- Empty states with guidance (not blank pages)
- Density matched to task (data-heavy screens can be dense, onboarding should be sparse)
- Removing information that doesn't serve the current view's purpose
