# State Manifest — What to Read and When

Skills read project state to make informed decisions. This manifest documents the sources and which skills should read them.

## Source Tiers

### T1 — Always Read (core identity)
- `config/rhino.yml` — value hypothesis, features (weight/depends_on), mode, stage
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

## Maturity Threshold Rubric

Feature maturity is computed from eval scores, not manually declared:

| Eval Score | Maturity | Meaning |
|------------|----------|---------|
| 0-29 | planned | Does not exist or fundamentally broken |
| 30-49 | building | Half-built, skeleton is there |
| 50-69 | working | It works, delivers on claim |
| 70-89 | polished | Solid, ships and works well |
| 90+ | proven | Genuinely excellent, externally validated |

**Maturity is a computed label, not a manual field.** Run `/eval` to update scores. The maturity label follows automatically.

**Reference this rubric from**: /eval (score→maturity mapping), /rhino (dashboard maturity labels), /plan (bottleneck diagnosis), /feature (maturity display), /ship (pre-flight check).
