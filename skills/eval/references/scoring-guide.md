# Scoring Guide

## Score Scale

| Range | Label | Meaning |
|-------|-------|---------|
| 0-29 | broken | Feature doesn't work or barely exists |
| 30-49 | building | Partially implemented, major gaps |
| 50-69 | working | Core functionality present, rough edges |
| 70-89 | polished | Well-executed, minor improvements possible |
| 90+ | proven | Excellent with external validation |

## Three Dimensions

**Formula:** `delivery * 0.50 + craft * 0.30 + viability * 0.20`

- **Delivery (50%)** — Does the feature do what it claims? Code exists, tests pass, user gets value.
- **Craft (30%)** — Is it well-made? Error handling, edge cases, documentation, UX quality.
- **Viability (20%)** — Does it matter? Market fit, differentiation, user demand evidence.

Delivery dominates because nothing else matters if the feature doesn't work.

## Honesty Rules

1. Score what EXISTS in code, not what's planned or documented
2. Cite specific file:line evidence for every sub-score
3. Missing functionality = 0 on that criterion, not "partial credit"
4. Compare against rubric history — same code should get same score
5. Stage-appropriate expectations — MVP at 75+ needs justification
6. When uncertain, score lower — inflation is harder to fix than underscoring

## Maturity Mapping

Maturity is computed from eval score, not declared:
- 0-29 = planned
- 30-49 = building
- 50-69 = working
- 70-89 = polished
- 90+ = proven

## Anti-Inflation Checks

Before publishing any score:
- [ ] Every sub-score >80 has file:line evidence
- [ ] No dimension scored higher than what the code actually delivers
- [ ] Rubric variance check passed (delta <15 from last score)
- [ ] Stage ceiling respected (MVP features shouldn't average 75+)
- [ ] Delivery score reflects actual user value, not code completeness
