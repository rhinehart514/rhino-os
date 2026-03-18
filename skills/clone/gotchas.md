# Clone Gotchas

Built from real failure modes. Update this when /clone produces bad output.

## Capture failures
- **Screenshot without wait**: Pages that load content via JavaScript need `browser_wait_for` with networkidle or a specific selector. Screenshotting immediately gets a blank or half-rendered page.
- **Missing accessibility tree**: The `browser_snapshot` gives semantic structure that screenshots miss. Skip it and you'll misidentify component boundaries, miss interactive elements, and generate non-accessible HTML.

## Decomposition failures
- **Cloning aesthetics without understanding**: Copying visual style without understanding information architecture. The source page is designed for THEIR users. Serve YOUR users — the layout pattern is what you're stealing, not the product decisions.
- **One massive component**: Generating a single 200-line component instead of decomposing. Each section should be its own file. Reusable patterns (cards, buttons) should be extracted.
- **Responsive breakpoint guessing**: Mobile behavior doesn't map cleanly to standard sm/md/lg breakpoints. The source might switch layout at 768px, not 640px. Check the actual breakpoint behavior in the source.

## Token compliance failures
- **Hardcoding hex colors**: The #1 failure. Every hex color should map to a design token. If no exact match exists, use the closest one and note it.
- **Pixel values instead of spacing tokens**: `padding: 24px` should be `p-6`. `gap: 16px` should be `gap-4`. If the spacing doesn't map cleanly to the token scale, round to the nearest token.
- **Font stack hardcoding**: `font-family: 'Inter', sans-serif` should be `font-sans`. The source's font choice is irrelevant — use your own.
- **Ignoring design-system.md**: If `.claude/design-system.md` exists (from /calibrate), it MUST be read and used. Generating components without reading the documented tokens is technical debt from line 1.

## Content failures
- **Copying brand copy verbatim**: "Acme Corp helps you..." must become placeholder text. Use realistic but generic copy that demonstrates the same content type and length.
- **Lorem ipsum in context-dependent places**: A hero headline needs realistic text to evaluate layout behavior. "Lorem ipsum dolor sit amet" doesn't tell you if the headline wraps correctly at mobile.

## Type safety failures
- **Missing TypeScript types**: If the project uses TypeScript, generated components need proper interfaces for props. Don't generate untyped JSX in a typed codebase.
- **Wrong import patterns**: Check existing components for named exports vs default exports, barrel files, path aliases. Match what exists.
