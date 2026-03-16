# Taste Skill — Reference

## Architecture Difference from taste.mjs

The old `taste.mjs` (1286 lines of Node) worked like this:
```
taste.mjs → manages Playwright → screenshots → calls `claude -p` → parses JSON → writes report
```

The new `/taste` skill works like this:
```
Claude Code → Playwright MCP (navigate, screenshot, snapshot) → Claude sees screenshots natively → evaluates in own reasoning → writes report
```

No subprocess. No Node dependency. No `claude -p`. Claude IS the runtime AND the evaluator.

## Key Files

- `skills/taste/SKILL.md` — the skill definition (this is the product)
- `commands/taste.md` — command routing
- `.claude/evals/reports/taste-*.json` — evaluation reports (written by skill)
- `.claude/evals/taste-history.tsv` — score history (appended by skill)
- `.claude/evals/taste-learnings.md` — accumulated intelligence (updated by skill)
- `.claude/evals/taste-market.json` — cached market research (written by skill)

## Relationship to /eval

`/eval taste` in the eval skill should delegate to `/taste`. The eval skill handles assertions, blind eval, coverage, and trend. Taste is its own skill because:
1. It needs Playwright MCP tools (eval doesn't)
2. It needs Write access (eval is read-only)
3. It's expensive and should run independently
4. It has its own memory and learning loop

## Score Mapping

Old taste.mjs used 1-5 scale internally, converted to 0-100 via `(score/5)*100`.
New /taste uses 0-100 natively. More granular, no conversion needed.

For compatibility with score.sh (which reads taste reports):
- `overall` field is 0-100
- `score_100` field is the same as `overall` (backward compat)
- Dimension scores are 0-100

## Memory Architecture

```
taste-market.json     — what "great" looks like (refreshed weekly)
taste-history.tsv     — score timeline (append-only)
taste-*.json          — full reports (one per eval)
taste-learnings.md    — knowledge model (updated after each eval)
```

The learnings file is the most important. It compounds:
- Which prescriptions worked and which didn't
- Which dimensions respond to CSS tweaks vs structural changes
- Product-specific patterns (e.g., "this product's distinctiveness comes from copy, not layout")
- Self-calibration (e.g., "I consistently overestimate breathing_room improvements")
