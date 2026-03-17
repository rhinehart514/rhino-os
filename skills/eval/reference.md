# /eval Reference — Output Templates

## Full eval output

```
◆ eval — N features

  learning         ████████░░░░░░░░░░░░  42  d:48 c:35 v:40  ↓3
    predictions log but never auto-grade. knowledge model is a static file.

  scoring          ██████████░░░░░░░░░░  58  d:62 c:50 v:55
    no trend visualization. onboarding guidance generic.

  commands         ██████████████░░░░░░  72  d:75 c:65 v:68  ↑2
    output formatting inconsistent across 3 commands.

  beliefs: 61/76 passing

▾ system check
  bottleneck: **learning** at 42 — predictions log but never auto-grade
  strategy: confirms — first-loop depends on learning compounding
  plan: no active tasks target learning (misaligned)
  roadmap: v8.2 evidence blocked — learning must work for "skills self-improve"
  todos: auto-grade (open), prune-stale (open)

/go learning               fix the worst score
/todo promote auto-grade   addresses the gap directly
/eval learning             scoped eval first
```

**Formatting rules:**
- Features sorted worst-to-best — worst score first, always
- One line per feature: name, bar, score, sub-scores (d:N c:N v:N), delta
- Gap line indented below — the specific problem, not a verdict label
- No DELIVERS/PARTIAL/MISSING labels — the score IS the verdict
- Beliefs are one summary line — pass count + notable failures only
- System check section — cross-references strategy, plan, roadmap, todos
- Bold the bottleneck feature name
- Bottom: 2-3 next commands routed to specific actions

## Scoped eval output

```
◆ eval — scoring

  delivery  ██████████████░░░░░░  68/100
    ✓ score.sh computes weighted total (bin/score.sh:45)
    ✓ health gate blocks broken builds (bin/score.sh:12)
    · no trend visualization (claimed but missing)

  craft     ████████████░░░░░░░░  50/100
    ✓ error handling: build check failures caught (bin/score.sh:30)
    · 4 unhandled paths: file I/O at :520, :535 without fallback
    · 2>/dev/null at :531 swallows real errors
    · system design: scoring pipeline is linear, no extension points

  viability ████████████████░░░░  55/100
    ✓ output: score bar visualization clear
    · penalty reasons too terse for new users

  total     █████████████░░░░░░░  58/100
  delta     ↑4 vs previous (54)
  rubric    anchored — scoring.json last updated 2026-03-16
```

## Blind eval output

```
◆ eval blind — N features

  scoring     85  aligned
    code: computes weighted score with health gate, outputs bar + penalties
    claim: "honest number that tells a founder if their product improved"
    ✓ code matches claim closely

  learning    38  inflated
    code: logs predictions to TSV, no auto-grading, static knowledge file
    claim: "a model that gets smarter every session"
    · "gets smarter" implies auto-improvement — code is manual/static

  overall alignment: 62/100
  2 features aligned, 1 inflated, 0 disconnected
```

## Coverage audit output

```
◆ eval coverage

  scoring     8 assertions  tier 2  ████████████████░░░░
    file_check: 3  content_check: 2  command_check: 2  llm_judge: 1
    · 38% file_check — acceptable but could use more value assertions

  learning    4 assertions  tier 1  ████████░░░░░░░░░░░░
    file_check: 3  llm_judge: 1
    · 75% file_check — low signal, needs content/command checks

  ideal: 30% mechanical, 50% content/command, 20% llm_judge
  flag: learning has shallow coverage for weight-4 feature
```

## Trend output

```
◆ eval trend

  stable pass  (12): score-runs, value-hypothesis-exists, ...
  stable fail  (3):  learning-complete, auto-grade-works, ...
  flapping     (2):  learning-compounds, prediction-accuracy
    · learning-compounds: llm_judge type — expected high variance
  recent change (1): scoring-trend — PASS→FAIL after bin/score.sh refactor

  diagnosis: 2 flapping assertions are both llm_judge on learning feature
  recommendation: rewrite as command_check or content_check for stability
```

## Slop report output

```
◆ eval slop — scoring

  slop score: 78% human-quality (instances without slop / total instances)

  ▾ slop found (4 instances)
    · bin/score.sh:45 — comment restates code
    · bin/score.sh:120 — generic variable name: `result`
    · bin/eval.sh:88 — unnecessary wrapper
    · bin/eval.sh:650 — boilerplate error handling

  ▾ clean code (good examples)
    · bin/eval.sh:584 — specific prompt construction
    · bin/score.sh:200 — domain-specific logic

/go scoring    fix the slop
```

## Rubric format

After scoring, write/update rubric to `.claude/cache/rubrics/<feature>.json`:

```json
{
  "feature": "scoring",
  "last_score": 58,
  "last_scored": "2026-03-16T12:00:00Z",
  "delivery_criteria": [
    "computes weighted score from multiple dimensions",
    "health gate prevents broken builds from scoring",
    "outputs clear visualization with penalties"
  ],
  "craft_criteria": [
    "error paths handled for file I/O",
    "system design: pipeline extensibility",
    "no swallowed errors (2>/dev/null)"
  ],
  "viability_criteria": [
    "output is actionable for founders",
    "penalty reasons explain what to fix"
  ],
  "known_gaps": [
    "no trend visualization",
    "4 unhandled error paths"
  ],
  "score_history": [54, 58]
}
```

Rubrics persist across runs and anchor future scores. If a rubric exists, use its criteria as the starting point — add/remove criteria based on code changes, but don't reinvent the scoring frame each time.
