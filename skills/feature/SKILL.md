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
2. `config/product-spec.yml` — features should map to spec sections. Core loop = weight 5. First experience = weight 4.
3. `.claude/cache/eval-cache.json` — sub-scores, deltas
4. `.claude/cache/rubrics/<feature>.json` — per-feature rubric (detail view)
5. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — relevant predictions
6. `.claude/plans/roadmap.yml` — thesis evidence references

## Tools

- **Bash**: run scripts, `rhino feature`, `rhino eval . --feature [name]`
- **Read**: rhino.yml, eval-cache, rubrics, predictions
- **Grep/Glob**: codebase scanning for `detect` and `research`
- **Edit**: write feature entries to rhino.yml
- **AskUserQuestion**: `new` interviews, `detect` confirmation, `ideate` selection
- **WebSearch**: `research` route external context

## Task generation — the path to feature completion

**/feature's job is not just showing scores. It's generating EVERY task needed to unblock features and reach maturity.** If a feature is stuck, the tasks to unstick it should be in the backlog. If a feature has no assertions, that's a task. If a dependency is blocking, that's a task.

**For EVERY feature analyzed, generate the complete task list:**

### Blocked feature tasks
- Each feature blocked by a dependency scoring <50 → task: "Feature [X] blocked by [Y] scoring [Z] — fix [Y] first"
- Each feature with status `active` but no code paths → task: "Feature [X] defined but has no code — implement or kill"
- Each feature with broken dependency chain → task: "Feature [X] depends on [Y] which depends on [Z] — unblock from bottom"

### Maturity gap tasks
- Each feature scoring <30 (planned) with weight >2 → task: "High-weight feature [X] at [score] — needs implementation"
- Each feature scoring 30-49 (building) → tasks for specific delivery gaps from eval-cache sub-scores
- Each feature scoring 50-69 (working) → tasks for craft improvements from eval-cache
- Each feature at 70+ but with viability dragging → task: "Feature [X] works but viability is [V] — run /research to validate"

### Assertion coverage tasks
- Each feature with 0 assertions → task: "Feature [X] has no assertions — run /assert suggest [X]"
- Each feature where all assertions pass but score is <50 → task: "Feature [X] passes all assertions but scores [N] — assertions are too weak"
- Each feature with no eval data → task: "Feature [X] never evaluated — run /eval [X]"

### Weight/priority tasks
- Feature weights don't match thesis priorities → task: "Feature [X] weight [W] doesn't match thesis — re-weight"
- High-weight features with lowest scores → task: "Bottleneck: feature [X] (w:[W]) scoring [S] — highest leverage fix"
- Features with no weight assigned → task: "Feature [X] has no weight — assign based on thesis"

### Lifecycle tasks
- Features stuck at same maturity for >14d → task: "Feature [X] stuck at [maturity] for [N]d — diagnose via /eval [X]"
- Features with declining scores → task: "Feature [X] regressed from [old] to [new] — investigate"
- Features that should be killed (no progress, low weight, no thesis connection) → task: "Consider killing feature [X] — run /ideate kill"

**Write ALL tasks to /todo.** Tag with `source: /feature`, feature name, and gap type (blocked/maturity/coverage/weight/lifecycle). Priority: highest-weight features with lowest scores first.

**There is no cap on task count.** A project with 7 features at various maturity levels might need 20+ tasks. Generate all of them.

After writing tasks, show: "Generated N tasks across M features. Bottleneck feature: [name] (w:[W]) at [score] needs [X] tasks."

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
