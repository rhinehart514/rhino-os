# /taste Reference — Architecture & Memory

Loaded on demand. Output templates are in `templates/taste-report.md`. Dimensions are in `references/dimensions.md`.

---

## Architecture

The `/taste` skill uses Claude Code natively — Playwright MCP for screenshots, Claude Vision for evaluation. No subprocess, no `claude -p`. Claude IS the runtime AND the evaluator.

## Key Files

| File | Purpose |
|------|---------|
| `skills/taste/SKILL.md` | Skill definition, routing, protocol |
| `skills/taste/scripts/dimension-summary.sh` | Latest scores, weakest/strongest, pending prescriptions |
| `skills/taste/scripts/taste-history.sh` | Score trends per dimension, trajectory classification |
| `skills/taste/scripts/calibration-check.sh` | Calibration state: profile, design system, dimension knowledge |
| `skills/taste/references/dimensions.md` | All 11 dimensions with scoring anchors |
| `skills/taste/references/calibration-guide.md` | Calibration protocol and traps |
| `skills/taste/templates/taste-report.md` | Output templates for all modes |
| `skills/taste/gotchas.md` | Real failure modes — read before every eval |

## Data Files (per-project)

| File | Purpose |
|------|---------|
| `.claude/evals/reports/taste-*.json` | Full evaluation reports |
| `.claude/evals/taste-history.tsv` | Score history (append-only) |
| `.claude/evals/taste-learnings.md` | Accumulated intelligence (max 5 entries) |
| `.claude/evals/taste-market.json` | Cached market research |
| `~/.claude/knowledge/founder-taste.md` | Founder preferences (from calibrate) |
| `.claude/design-system.md` | Project visual rules |
| `.claude/cache/calibration-history.json` | Calibration tracking |
| `lens/product/eval/knowledge/*.md` | Per-dimension research rubrics |

## Score Mapping

- 0-100 natively (no conversion from 1-5 scale)
- `overall` = mean(all 11 dimensions)
- Gate dimensions (layout_coherence, information_architecture) cap overall at 30 when either < 30
- `overall` and `score_100` fields are identical (backward compat with score.sh)

## Memory Architecture

```
taste-learnings.md    — knowledge model (updated after each eval, max 5 entries)
taste-history.tsv     — score timeline (append-only)
taste-*.json          — full reports (one per eval date)
taste-market.json     — what "great" looks like (refreshed on calibrate)
```

The learnings file compounds: which prescriptions worked, which dimensions respond to CSS tweaks vs structural changes, product-specific patterns, and self-calibration data.

## Calibration State

Run `scripts/calibration-check.sh` to see current state. Three independent sources:

1. **Founder profile** (`~/.claude/knowledge/founder-taste.md`) — weights dimensions by preference
2. **Design system** (`.claude/design-system.md`) — flags deviations as bugs
3. **Dimension knowledge** (`lens/product/eval/knowledge/*.md`) — per-dimension research rubrics

Partial calibration is better than none. See `references/calibration-guide.md` for full protocol.
