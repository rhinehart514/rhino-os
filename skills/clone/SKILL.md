---
name: clone
description: "Use when reproducing a design from a URL using your framework and design tokens"
argument-hint: "<url>"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, WebFetch
---

# /clone

Screenshot a public URL, decompose the page into components, generate them in your stack using your conventions and design tokens. Never copy verbatim — placeholder content replaces brand-specific copy.

## Steps

### 1. Parse URL

Extract the URL from `$ARGUMENTS`. If no URL provided, use AskUserQuestion to ask for one.

### 2. Capture the page

Use Playwright MCP tools in sequence:

```
browser_navigate → URL
browser_wait_for → networkidle (or 3s timeout)
browser_take_screenshot → full page capture
browser_snapshot → accessibility tree (component structure)
```

Study both the screenshot and the accessibility tree. The screenshot shows visual design — layout, spacing, color, typography. The snapshot shows semantic structure — headings, landmarks, interactive elements.

### 3. Detect the founder's stack

Read these files in parallel to understand the codebase conventions:

- `package.json` — framework, dependencies, UI libraries
- Tailwind config (`tailwind.config.*`, `postcss.config.*`) — design tokens, theme
- 3 existing components (glob `src/components/**/*.{tsx,jsx,vue,svelte}` or `app/components/**/*`) — naming, structure, patterns

Determine:
- **Framework**: React/Next.js/Vue/Svelte/etc.
- **Styling**: Tailwind/CSS modules/styled-components/etc.
- **Component directory**: where components live
- **Naming convention**: PascalCase files? kebab-case? barrel exports?
- **Design tokens**: colors, spacing, fonts from tailwind config or theme

If no codebase exists (empty repo, no package.json): default to React + Tailwind, note it to the founder.

### 4. Decompose the page

From the screenshot and accessibility tree, identify component boundaries:

- Navigation (nav, header)
- Hero / above-the-fold section
- Content sections (features, testimonials, pricing, etc.)
- Footer
- Reusable elements (cards, buttons, CTAs)

Name each component using the founder's naming convention.

### 5. Ask what to generate

Use AskUserQuestion:

> Found N components: [list them]. Generate all, or pick specific ones?

### 6. Generate components

For each selected component:

1. Create the file in the founder's component directory
2. Use the founder's framework and styling approach
3. Use design tokens from tailwind config — never hardcode hex colors, pixel values, or font names
4. Replace brand-specific copy with placeholder content (realistic but generic)
5. Import patterns match existing components (named exports, default exports, etc.)
6. Props interface if TypeScript

Each component is its own file. No monolithic page dump.

### 7. Report results

```
◆ clone — [url domain]

captured: [url] → [screenshot dimensions]
stack: [framework] + [styling] → [component directory]

generated:
  ✓ NavBar — top navigation with links + CTA
  ✓ Hero — headline, subhead, two CTAs
  ✓ FeatureGrid — 3-column feature cards
  ✓ Footer — links, social, copyright

/eval taste        compare quality
/feature [name]    define what this builds toward
/plan              plan next work
```

## What you never do

- Copy brand-specific text verbatim — always replace with placeholder content
- Hardcode hex colors, pixel values, or font stacks — use design tokens
- Generate one massive file — decompose into real components
- Install dependencies — work with what's already in the project
- Modify crown jewels (score.sh, taste.mjs, eval.sh, self.sh)
- Skip the screenshot — visual context is essential for accurate decomposition

## If something breaks

- Playwright not available: tell the founder to ensure the Playwright MCP server is running
- URL won't load: try with `browser_wait_for` timeout of 5s, then report the error
- No components directory found: ask the founder where components should go
- Private/auth-gated URL: tell the founder this only works on publicly accessible pages

$ARGUMENTS
