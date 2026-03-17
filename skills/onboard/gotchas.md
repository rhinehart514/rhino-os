# Onboarding Gotchas

- **Placeholder generation**: Writing `delivers: "TODO"` or `for: "users"` defeats the purpose. Every field needs real content.
- **Feature over-detection**: Finding 10+ features in a small codebase means you're finding modules, not features. Features deliver user value.
- **Value hypothesis vagueness**: "Makes things better" is not a hypothesis. It must be testable and falsifiable.
- **Stage mis-assessment**: Code polish doesn't indicate maturity. A beautiful MVP with zero users is still stage one.
- **Framework detection failures**: Monorepos, custom frameworks, and non-standard project structures break auto-detection.
- **Assertion over-seeding**: Starting with 20 assertions when 5 good ones would be better. Quality over quantity.
- **Missing value.user**: The most common miss. If rhino.yml doesn't name a specific person, every downstream command suffers.
