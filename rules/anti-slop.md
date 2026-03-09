---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.css"
  - "**/*.svelte"
  - "**/*.vue"
---

# Anti-Slop — What AI-Generated UI Gets Wrong

AI-generated UIs converge because the training data converges. You are the AI. This rule exists to make you fight your own defaults.

## The Slop Stack (if you're producing all of these, you're slopping)

**Layout slop:**
- Sidebar + main content for everything
- Uniform card grid (same size, same shape, same gap)
- Hero → feature grid → testimonials → CTA (every landing page ever)
- Modal for every interaction that could be inline
- Settings = stacked form sections
- Dashboard = 4 metric cards on top, table below

**Component slop:**
- shadcn defaults with zero customization (the gray/blue palette everyone has)
- Lucide icons on every label (decorative filler, not functional wayfinding)
- Inter/Geist font because that's what the template came with
- `rounded-lg p-4 shadow-sm border` on everything
- Placeholder copy: "Welcome back!", "Get started", "No items yet"

**Interaction slop:**
- No hover states on clickable things
- No transitions — elements snap in/out of existence
- No loading states — blank screen until data arrives
- No empty state personality — just "Nothing here yet"
- Alert/confirm dialogs instead of inline feedback
- Toast for everything, even things that don't need confirmation

**Color slop:**
- Blue primary + gray secondary (the "SaaS palette")
- No accent color
- No dark mode consideration
- Hardcoded hex values instead of design tokens

## What To Do Instead

You don't need to be avant-garde. You need ONE distinctive choice per product:

1. **Pick ONE layout that breaks the pattern** — command palette, bento grid, split pane, timeline, kanban. Not every page, just one key page.
2. **Pick ONE visual signature** — a non-default font, an unexpected accent color, a micro-animation on the primary action, a branded empty state illustration.
3. **Match density to user** — students on mobile ≠ admins on desktop. Thumb-zone nav for mobile. Dense tables for power users. Don't use the same layout for both.
4. **Make empty states invitations** — personality, specific action, context about what WILL be here. Not "No items" with a + button.
5. **Add feedback to the ONE action that matters most** — the core loop action (post, create, share, deploy) should feel satisfying. Confetti, a sound, a transition, a success state that lingers.

## The Check

Before shipping any UI, ask:
- If I hid the logo, would I know which product this is? (distinctiveness)
- Does the most important action on this page POP visually? (hierarchy)
- Is there anything a user's phone would make unusable? (mobile)
- Would a screenshot of this page look identical to a Vercel/shadcn template? (slop)

If the answer to the last one is yes — change one thing. Just one. That's enough to start.

## What This Is NOT

This is not "don't use shadcn" or "don't use Tailwind." These tools are fine. The problem is using every default without a single intentional choice. The bar isn't "custom everything" — it's "at least one thing that only makes sense for THIS product."
