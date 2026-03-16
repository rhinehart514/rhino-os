# State Manifest — What to Read and When

Skills read project state to make informed decisions. This manifest documents the sources and which skills should read them.

## Source Tiers

### T1 — Always Read (core identity)
- `config/rhino.yml` — value hypothesis, features (maturity/weight/depends_on), mode, stage
- `.claude/plans/roadmap.yml` — current thesis, version, evidence_needed
- `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — predictions, accuracy

### T2 — Measurement (current state)
- `.claude/cache/score-cache.json` — per-feature scores, overall score
- `rhino feature` (CLI) — feature pass rates
- `git log --oneline -10` — recent work context

### T3 — Planning (session context)
- `.claude/plans/plan.yml` — active plan snapshot
- `.claude/plans/strategy.yml` — stage, bottleneck, loop health
- `.claude/plans/todos.yml` — backlog items, active todos
- TaskList — Claude-native task tracking

### T4 — Learning (model state)
- `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known/uncertain/unknown/dead patterns
- `.claude/scores/history.tsv` — score trajectory

### T5 — Cross-Command (artifacts from other skills)
- `~/.claude/cache/last-research.yml` — recent research findings + suggested tasks
- `~/.claude/cache/last-retro.yml` — recent retro results + model updates

## Maturity Transition Rubric

Features move through four maturity stages. Criteria are consistent across all skills:

### planned → building
Code exists for the feature. At least one file in the feature's `code:` paths contains implementation (not just scaffolding or empty exports).

### building → working
- >50% of the feature's assertions pass
- Core user flow is functional end-to-end
- No crash-level bugs in the happy path

### working → polished
- 100% of the feature's assertions pass
- Edge cases handled (error states, empty states, loading states)
- No TODO/FIXME markers in feature code
- Code is reviewed or self-reviewed against standards

### polished → proven
- External validation: someone other than the author has used it successfully
- OR: 3+ sessions without regression (assertions stayed green)
- The feature delivers measurable value (not just "it works")

**Reference this rubric from**: /retro (step 6), /strategy (graduation criteria), /ship (pre-flight maturity check), /feature (status transitions), /go (maturity updates in session summary).
