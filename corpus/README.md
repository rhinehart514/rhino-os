# Corpus — Top 0.1% Examples

The corpus is a curated database of exceptional work used to calibrate rhino-os evals. It sets the quality bar.

## What's Here

```
corpus/
  ui/
    saas/        Linear, Vercel, Stripe, Raycast
    consumer/    Duolingo, Superhuman, Arc
    developer/   Warp, GitHub, Railway
  copy/
    landing/     Stripe, Basecamp, 37signals
    onboarding/  Duolingo, Notion, Figma first-run
  code/
    patterns/    Exemplary readability and structure
```

## How Examples Are Added

1. **AI discovery** — `/corpus update [category]` searches reputation signals (Awwwards, Product Hunt, designer consensus) and admits exceptional examples via multi-model consensus
2. **Manual** — `/corpus add [url or description]` for specific examples you've found

## Admission Criteria

- Multi-model consensus score >= 8.0 (average across Claude, GPT-4V, Gemini)
- Score variance < 0.5 (controversial != exceptional)
- "Good" or "above average" -> rejected. Only genuinely exceptional work is admitted.

## Contributing a Community Pack

1. Curate examples in your category
2. Run `/corpus update` to validate quality
3. Publish as a pack for the community

The corpus compounds. More users running discovery loops = better taste database = better output for everyone.
