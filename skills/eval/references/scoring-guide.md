# Scoring Guide

## Score Scale

| Range | Label | Meaning | Evidence bar |
|-------|-------|---------|-------------|
| 90-100 | proven | Genuinely excellent. You'd show this as an example. | External validation, named users, measurable outcomes |
| 70-89 | polished | Solid. Ships and works. Rough edges but nothing embarrassing. | Full error handling, tested edge cases, clear architecture |
| 50-69 | working | Works but not proud of it. Ships because it has to. | Core loop complete, known gaps documented |
| 30-49 | building | Half-built. Skeleton without real delivery. | Partial implementation, major paths missing |
| 0-29 | planned | Does not exist or fundamentally broken. | Little or no functional code |

## Three Dimensions

**Formula:** `delivery * 0.50 + craft * 0.30 + viability * 0.20`

### Delivery (50%)

Does this feature deliver real value to its target user? Not "does code exist" but "would a human care?"

Read the `delivers:` field (the promise) and `for:` field (who it promises to). Then read ALL the code. Judge: is this complete, useful, worth someone's time?

**Scoring anchors:**
- 90+: A user would notice and complain if this disappeared
- 70-89: Core promise fulfilled, some secondary paths missing
- 50-69: Basic loop works, but gaps visible in first use
- 30-49: Skeleton exists, but a user couldn't get value from it
- 0-29: Claim exists, code doesn't deliver it

### Craft (30%)

Is this well-made AS A SYSTEM? Two layers:

**Code craft:** Error handling, architecture, code taste. When this breaks at 3am, will you know? Are errors swallowed? Is state managed cleanly?

**System design:** Is the information architecture sound? Do routes/data flows/component hierarchy serve the user's mental model? Are layout decisions intentional or accidental? Does the abstraction level match the problem?

**Scoring anchors:**
- 90+: Elegant. You'd study this code to learn from it.
- 70-89: Solid engineering. Zero critical unhandled error paths.
- 50-69: Works but fragile. Known gaps in error handling.
- 30-49: Functional but messy. Would cause incidents under load.
- 0-29: Hacked together. No error handling strategy.

**Hard rule:** craft > 70 requires zero critical unhandled error paths.

### Viability (20%)

Would this succeed in the world? Who are the alternatives? Is this novel enough to matter? If you were betting money on adoption, what odds?

When `.claude/cache/customer-intel.json` exists, use customer signal: demand signals raise viability, churn signals and unmet needs lower it.

**Scoring anchors:**
- 90+: Clear market pull, named competitors beaten on specific dimension
- 70-89: Differentiated approach, plausible adoption path. Must name competitors.
- 50-69: Useful but undifferentiated. Would work but why this over alternatives?
- 30-49: Unclear market. No evidence of demand.
- 0-29: No market awareness. Building in a vacuum.

**Hard rule:** viability > 70 requires naming specific competitors and explaining differentiation.

## Honesty Rules

1. Score what EXISTS in code, not what's planned or documented
2. Cite specific file:line evidence for every sub-score
3. Missing functionality = 0 on that criterion, not "partial credit"
4. Compare against rubric history — same code should get same score
5. Stage-appropriate expectations — MVP at 75+ needs justification
6. When uncertain, score lower — inflation is harder to fix than underscoring
7. Any sub-score > 80 requires extraordinary evidence
8. Early-stage code averaging 75+ is suspicious. Be honest about the stage.
9. If you find zero problems, say so explicitly and justify

## Anti-Inflation Checklist

Run this mentally before publishing any score:

- [ ] Every sub-score >80 has file:line evidence of excellence
- [ ] No dimension scored higher than what the code actually delivers
- [ ] Rubric variance check passed (delta <15 from last score)
- [ ] Stage ceiling respected (MVP features shouldn't average 75+)
- [ ] Delivery score reflects actual user value, not code completeness
- [ ] craft > 70 means zero critical unhandled error paths
- [ ] viability > 70 means competitors named and differentiation explained

## Maturity Mapping

Maturity is computed from eval score, not declared:
- 0-29 = planned
- 30-49 = building
- 50-69 = working
- 70-89 = polished
- 90+ = proven
