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
- `scripts/feature-ideate.sh [project] [name]` — gathers ALL context for a feature's improvement: eval, taste, flows, market, customer, backlog, predictions, dead ends, code history
- `scripts/dependency-graph.sh` — dependency chain visualization, blocked feature detection
- `references/feature-lifecycle.md` — maturity stages and what moves each transition
- `references/feature-design.md` — how to define a good feature, common mistakes
- `references/improvement-protocol.md` — full method for feature improvement ideation (read for `[name] ideate`)
- `templates/feature-template.yml` — copy-paste template for rhino.yml
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read before creating, killing, or improving features.**

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
| `[name] ideate` | Context-aware improvement engine — reads scores, taste, code, market, intel → specific prescriptions |
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

## Ideate protocol — the feature improvement engine

When `[name] ideate` is triggered, this is NOT a lightweight brainstorm. It's a context-aware improvement engine that reads everything the system knows about this feature and produces specific, buildable prescriptions.

**Read `references/improvement-protocol.md` for the full method.** Summary:

1. **Gather context** (parallel): Run `scripts/feature-ideate.sh [project] [feature]` → structured evidence. Also read the feature's actual code files (from rhino.yml `code:` field).
2. **Check accumulated intelligence**: Run `skills/plan/scripts/intelligence-query.sh [project] [feature]` → past research, market context, customer intel, past ideas for this feature.
3. **Diagnose the gap**: Name what's broken — delivery (doesn't work), craft (works but rough), or viability (works but who cares?). Cite sub-scores.
4. **Generate 3-5 improvement prescriptions**: Each uses the improvement brief structure (see `references/improvement-protocol.md`). Specific element, specific change, 2+ options, predicted impact on sub-scores, reference to best-in-class products.
5. **Kill list**: What should be removed or simplified in this feature? Complexity that serves no user.
6. **Present + materialize**: AskUserQuestion → founder picks → write todos, log predictions.

**Agent usage for ideate:**
- **Agent (rhino-os:explorer)** — trace the feature's code path when the code list is large or complex
- **Agent (rhino-os:market-analyst)** — spawn in background to research how best-in-class products handle this feature type. Write findings to `.claude/cache/feature-research-[name].json`.

## Tools

- **Bash**: run scripts, `rhino feature`, `rhino eval . --feature [name]`
- **Read**: rhino.yml, eval-cache, rubrics, predictions, feature code, accumulated intelligence
- **Grep/Glob**: codebase scanning for `detect`, `research`, and `ideate` code tracing
- **Edit**: write feature entries to rhino.yml
- **AskUserQuestion**: `new` interviews, `detect` confirmation, `ideate` selection
- **WebSearch**: `research` and `ideate` competitor context
- **Agent**: `ideate` deep code tracing (explorer) and market research (market-analyst)

## Task generation — the path to feature completion

See `../shared/task-generation.md` for the task generation protocol. /feature generates tasks for:

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

Tag with `source: /feature`, feature name, and gap type (blocked/maturity/coverage/weight/lifecycle). Priority: highest-weight features with lowest scores first.

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
