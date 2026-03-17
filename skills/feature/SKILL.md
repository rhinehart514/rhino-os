---
name: feature
description: "Use when defining, viewing, or detecting features and their maturity"
argument-hint: "[name|new|detect] [name]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion, WebSearch, Agent
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, delivery: .value.delivery_score, craft: .value.craft_score, viability: .value.viability_score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"

# /feature

Features are named parts of your product. Each has assertions, pass rates, sub-scores (delivery/craft/viability), weights, and dependencies.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/feature-map.sh` — shows all features with scores, weights, dependencies, maturity (run first for list views)
- `scripts/feature-health.sh [name]` — per-feature health: score trend, assertion pass rate, todo count, last touched
- `scripts/dependency-graph.sh` — dependency chain visualization, blocked feature detection
- `references/feature-lifecycle.md` — maturity stages and what moves each transition
- `references/feature-design.md` — how to define a good feature, common mistakes
- `templates/feature-template.yml` — copy-paste template for rhino.yml
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read before creating or killing features.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Action |
|----------|--------|
| (none) | Run `scripts/feature-map.sh` → format per `reference.md` → bottleneck opinion |
| `[name]` | Run `scripts/feature-health.sh [name]` → detail view with sub-scores, deps, verdict |
| `[name] [name]...` | Multi-feature: health for each, identify weakest |
| `new [name]` | AskUserQuestion for delivers/for/code/weight/depends_on → write to rhino.yml → baseline eval |
| `detect` | Glob/Grep scan → cross-ref rhino.yml → AskUserQuestion to confirm → write |
| `[name] status [value]` | Lifecycle transition: active/proven/killed/archived |
| `[name] ideate` | Weakest sub-score → 3-4 improvement ideas via AskUserQuestion |
| `[name] research` | WebSearch + codebase scan → findings + recommendations |

**Ambiguity rule:** exact keyword > feature name match > free-form lookup. Never ask "did you mean?" — just act.

**Status filter:** only show `active` and `proven` features. Skip `killed`/`archived` unless explicitly requested.

## State to read (parallel)

1. `config/rhino.yml` — feature definitions
2. `.claude/cache/eval-cache.json` — sub-scores, deltas
3. `.claude/cache/rubrics/<feature>.json` — per-feature rubric (detail view)
4. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — relevant predictions
5. `.claude/plans/roadmap.yml` — thesis evidence references

## Tools

- **Bash**: run scripts, `rhino feature`, `rhino eval . --feature [name]`
- **Read**: rhino.yml, eval-cache, rubrics, predictions
- **Grep/Glob**: codebase scanning for `detect` and `research`
- **Edit**: write feature entries to rhino.yml
- **AskUserQuestion**: `new` interviews, `detect` confirmation, `ideate` selection
- **WebSearch**: `research` route external context

## What you never do

- Output raw CLI output without formatting — use `reference.md` templates
- Create features without asking what they deliver
- Skip baseline eval after creating a new feature
- Show scores without sub-score breakdown when eval-cache has them
- Let maturity labels diverge from eval scores (read `references/feature-lifecycle.md`)

## If something breaks

- `rhino feature` fails → read rhino.yml directly, list `features:` section
- No eval-cache.json → run `rhino eval .` first
- Scripts fail → fall back to reading state files directly and formatting manually

$ARGUMENTS
