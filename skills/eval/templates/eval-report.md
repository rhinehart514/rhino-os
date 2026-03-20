# Eval Report Templates

## Full eval output

```
◆ eval — N features

  feature_name     ████████░░░░░░░░░░░░  42  d:48 c:35  ↓3
    one-line gap description

  feature_name     ██████████░░░░░░░░░░  58  d:62 c:50
    one-line gap description

  beliefs: 61/76 passing

▾ outside-in
  journey: [stage] has [N] surfaces — [implication]
  unmet: [need] — no feature addresses this
  market: [signal] — opportunity not captured
  risk: [concentration warning if applicable]

▾ system check
  bottleneck: **feature** at N — why
  strategy: confirms/contradicts — one sentence
  plan: aligned/misaligned — one sentence
  roadmap: advances/blocks — one sentence
  todos: relevant open items

/command arg         reason
/command arg         reason
```

**Rules:**
- Features sorted worst-to-best — worst score first, always
- One line per feature: name, bar, score, sub-scores (d:N c:N), delta arrow. Viability scored by /score, not /eval.
- Gap line indented below — the specific problem, not a verdict label
- No DELIVERS/PARTIAL/MISSING labels — the score IS the verdict
- Beliefs are one summary line — pass count only
- Outside-in section shows opportunity cost: journey gaps, unmet needs, market signals. NOT a score — a lens. Surface-agnostic (don't assume CLI is the fix).
- System check section cross-references strategy, plan, roadmap, todos
- Bold the bottleneck feature name
- Bottom: 2-3 next commands routed to specific actions

## Scoped eval output

```
◆ eval — feature_name

  delivery  ██████████████░░░░░░  68/100
    ✓ what works with file:line
    ✓ what works with file:line
    · what's missing or broken with file:line

  craft     ████████████░░░░░░░░  50/100
    ✓ what works with file:line
    · what's broken with file:line
    · system design issue

  total     █████████████░░░░░░░  58/100
  delta     ↑4 vs previous (54)
  rubric    anchored — feature.json last updated YYYY-MM-DD
```

## Blind eval output

```
◆ eval blind — N features

  feature     85  aligned
    code: what the code actually does
    claim: what delivers: says
    ✓ code matches claim closely

  feature     38  inflated
    code: what the code actually does
    claim: what delivers: says
    · specific discrepancy

  overall alignment: N/100
  N aligned, N inflated, N deflated, N disconnected
```

## Coverage audit output

```
◆ eval coverage

  feature     N assertions  tier N  ████████████████░░░░
    file_check: N  content_check: N  command_check: N  llm_judge: N
    · assessment of signal quality

  ideal: 30% mechanical, 50% content/command, 20% llm_judge
  flag: features with shallow coverage relative to weight
```

## Trend output

```
◆ eval trend

  stable pass  (N): list...
  stable fail  (N): list...
  flapping     (N): list...
    · diagnosis per flapping assertion
  recent change (N): list...

  diagnosis: pattern explanation
  recommendation: what to do about it
```

## Slop report output

```
◆ eval slop — feature

  slop score: N% human-quality

  ▾ slop found (N instances)
    · file:line — what's wrong

  ▾ clean code (good examples)
    · file:line — what's good

/go feature    fix the slop
```

## Cache format

Write to `.claude/cache/eval-cache.json` (merge with existing):

```json
{
  "feature_name": {
    "score": 58,
    "delivery_score": 62,
    "craft_score": 50,
    "gaps": ["specific problem with file:line"],
    "strengths": ["what works well"],
    "evidence": "one sentence overall judgment",
    "delta": "better",
    "delta_vs": 54,
    "cached_at": "2026-03-16T12:00:00Z"
  }
}
```
