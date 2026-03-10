# Score Integrity Reference

Scores are diagnostic instruments, not goals. This document is the single source of truth for how scores must be treated across all rhino-os programs, skills, and agents.

## The Core Rule

**Goodhart's Law**: When a measure becomes a target, it ceases to be a good measure.

Every score in rhino-os exists to REVEAL reality so you can act on it. The moment you optimize FOR the score instead of the thing it measures, the score becomes noise and you've lost your signal.

## What This Means in Practice

### For any agent, program, or skill that reads or produces scores:

1. **"Get the score to X" is never a valid instruction.** Translate to: "improve the weakest dimension through real quality changes." If a human asks to hit a number, say so and redirect.

2. **Prefer tool-measured scores over self-assessment.** `rhino score` and `rhino taste` are more honest than any agent reading its own output and deciding it's good. When you must self-assess: if you're unsure between two scores, pick the LOWER one. You are biased toward your own work.

3. **Integrity warnings are blocking.** If `rhino score` emits COSMETIC-ONLY, INFLATION, or PLATEAU warnings, stop and address them before continuing any loop. These warnings mean the scoring signal is compromised.

4. **Scores can go down.** A recalibrated lower score is more valuable than a stale high one. Never anchor to previous scores — evaluate fresh every time.

5. **Small deltas are real.** A +3 that reflects genuine improvement is worth more than a +20 from cleanup. Celebrate honest incremental progress.

## Stage Ceilings (from rhino.yml)

Expected ranges by project stage. Scores above the ceiling are suspicious, not celebratory.

| Stage  | score.sh  | taste (1-5) |
|--------|-----------|-------------|
| MVP    | 30 – 65   | 1.5 – 3.0   |
| Early  | 45 – 80   | 2.0 – 3.5   |
| Growth | 60 – 90   | 3.0 – 4.0   |
| Mature | 70 – 95   | 3.5 – 4.5   |

A score at the ceiling = excellent for its stage.
A score above the ceiling = verify before trusting.
100/100 or 5/5 = extraordinary claim requiring extraordinary evidence. Even Linear/Notion/Discord don't hit 5/5 on every dimension.

## Runtime Integrity Detectors (score.sh)

These fire automatically and appear in both visual and JSON output:

- **COSMETIC-ONLY**: Score rose but only hygiene improved (structure/build flat). Removing console.logs without fixing underlying issues is not improvement.
- **INFLATION**: Score jumped >15 in one run. Real quality improvement is incremental. Big jumps are usually gaming.
- **PLATEAU**: Score unchanged across last 5 runs. Incremental changes aren't working — fundamentally different approach needed.

## Taste Eval Integrity (taste.mjs)

The taste rubric includes these rules for the evaluating model:

- DO NOT be generous. DO NOT round up. If unsure between 2 and 3, pick 2.
- Expected distribution: mostly 2s and 3s, maybe one 4, 5s are exceptional.
- A 4+ overall requires dimension-by-dimension justification against real products (Notion, Linear, Discord).
- Previous scores don't anchor — evaluate fresh from screenshots.

## Eval Integrity (/eval, /product-eval)

- Ceiling tests SHOULD score low on some dimensions. That's signal, not failure.
- A 0.7 ceiling average is a good score. If everything is 0.9+, the eval is too lenient.
- Scores across evals must be comparable: same rubric, same rigor. A 0.6 today must mean the same thing as a 0.6 last week.

## Who Enforces This

- **score.sh**: Runtime detectors (COSMETIC-ONLY, INFLATION, PLATEAU)
- **taste.mjs**: Rubric integrity rules baked into the evaluation prompt
- **build.md**: Anti-sycophancy preamble, integrity warnings are blocking
- **experiment skill**: SUSPECT status when integrity warnings fire alongside improvement
- **session_context.sh**: Integrity warnings injected into every Claude session
- **meta agent**: Reviews score trends, flags systematic inflation, calibrates agents

## When to Reference This Document

Any time you:
- Read a score and decide what to do next
- Produce a score (eval, taste, experiment)
- Keep or discard a change based on score delta
- Report scores to the human
- Set a target or goal involving a score
