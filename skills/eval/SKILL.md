---
name: eval
description: "Use when the user asks 'evaluate code', 'run assertions', 'how's the code?', or wants delivery + craft scores per feature. Reads code, judges system design, scores 0-100. Gets smarter with rubrics and accumulated knowledge."
argument-hint: "[feature|blind|coverage|trend|slop]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebFetch, Agent, TaskCreate
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, d: .value.delivery_score, c: .value.craft_score, score: .value.score}) | from_entries' 2>/dev/null || echo "no cache"
!cat .claude/cache/product-value.json 2>/dev/null | jq '{model: .product_model, loop: .value_loop[:5]}' 2>/dev/null || true
!cat ~/.claude/knowledge/experiment-learnings.md 2>/dev/null | head -60 || echo "no knowledge model"

# /eval

You are a top 0.01% product engineer. You read the code to judge both VALUE DELIVERY and SYSTEM DESIGN. The number IS the verdict.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/quick-eval.sh [feature]` — mechanical assertion score, no LLM (zero context cost)
- `scripts/variance-check.sh <feature> <proposed_score>` — catch dangerous score drift vs rubric. Run before publishing any score.
- `scripts/rubric-status.sh` — which features have rubrics, last scores, known gaps
- `scripts/eval-history.sh [feature]` — score trends over time
- `scripts/outside-in.sh [project-dir]` — reads intelligence caches to surface what the product is MISSING
- `references/scoring-guide.md` — dimensions, scale, honesty rules, anti-inflation checks
- `references/rubric-guide.md` — how rubrics work, how to write good ones
- `templates/rubric-template.json` — structure for feature rubrics
- `templates/eval-report.md` — output formatting templates for all eval modes
- `gotchas.md` — real failure modes. **Read before scoring.**

## Routing

Parse `$ARGUMENTS`. Exact keyword wins, then feature name, then free-form.

| Argument | Mode |
|----------|------|
| (none) | Score all active features, parallel evaluators |
| `<feature>` | Deep eval of one feature, inline |
| `blind` | Cold-read code vs claims, score alignment |
| `coverage` | Assertion type distribution, signal quality |
| `trend` | Classify assertions: stable, flapping, changed |
| `slop` | Scan for LLM-generated code patterns |
| `execute` | Run commands, check runtime behavior, then score with evidence |
| `taste` / `vs <url>` | Redirect to `/taste` |

## The eval model

**Formula:** `delivery * 0.60 + craft * 0.40`

### Delivery (60%)

Does this feature deliver real value to its target user? Read the `delivers:` field (the promise) and `for:` field (who it promises to) from rhino.yml. Then read ALL the code. Judge: is this complete, useful, worth someone's time?

**Delivery includes user understanding.** Code that works but confuses the user caps at 69. Evaluate the product surface:
- **5-second test**: Would someone encountering this cold understand it? If not, cap at 69.
- **Value moment**: Steps from first encounter to value. One step = potential 90+. Five steps = cap at 70.
- **Next action clarity**: After the feature runs, does the user know what to do next? No next action = cap at 75.
- **Error communication**: Generic errors or silent failures = delivery penalty.

**Hard rule:** Delivery > 80 requires evidence the product surface communicates clearly. Cite the specific output/UI/response.

### Craft (40%)

Is this well-made — both the code AND the experience? Code craft (error handling, architecture) + product surface craft (output formatting, consistency).

**Hard rules:**
- craft > 70 requires zero critical unhandled error paths
- craft > 80 requires evidence of intentional product surface design

### Viability — NOT scored by /eval

Viability is scored by `/score` using agent-backed research. This prevents LLM self-assessment bias.

### Journey-aware weighting

Features at entry positions (from topology.json) get a 1.2x delivery multiplier. Core = 1.1x. Leaf = 1.0x. This makes delivery count MORE for features that gate user value.

## How to evaluate

### Read state (parallel)

- `config/rhino.yml` — features, claims, code paths
- `config/product-spec.yml` — grounds scoring in what the product claims to deliver
- `.claude/cache/eval-cache.json` — previous scores for delta comparison
- `.claude/cache/rubrics/<feature>.json` — anchoring rubrics per feature
- `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`)
- `.claude/plans/strategy.yml`, `roadmap.yml`, `plan.yml`, `todos.yml`
- `.claude/cache/customer-intel.json`, `market-context.json`, `product-value.json`, `topology.json` (if they exist)

Read `gotchas.md` — calibrate before scoring.

### Full eval (no arguments)

For each active feature in rhino.yml:

1. **Read ALL files** in `code:` paths — no skimming, no shortcuts
2. **Check rubric** — `.claude/cache/rubrics/<feature>.json`. If it exists, anchor to it. Same code should get same score.
3. **Judge delivery** — read the `delivers:` claim. Does the code actually deliver it? Where are the gaps? What would a user experience? Cite file:line evidence.
4. **Judge craft** — error handling, architecture, product surface quality. Zero critical unhandled paths for >70. Cite file:line evidence.
5. **Apply journey weighting** — check topology.json for position. Entry features: `delivery * 0.72 + craft * 0.28`. Core: `delivery * 0.66 + craft * 0.34`. Leaf: standard `0.60/0.40`.
6. **Verify score** — run `bash scripts/variance-check.sh <feature> <score>` before publishing. If drift >15 from rubric, re-examine.
7. **Check claim-in-output** — run `bash skills/shared/claim-verify.sh [project-dir] [feature]` to mechanically verify the feature's commands produce output matching its `delivers:` claim. Low match = delivery gap.

Run `bash scripts/quick-eval.sh` for mechanical belief results alongside.

**Parallel evaluator spawning (full eval only):** For 3+ features, spawn one evaluator per feature:
```
For each feature with status: active:
  Agent(subagent_type: "rhino-os:evaluator", prompt: "Deep eval '[name]'. Read ALL code in [paths]. Score delivery/craft 0-100 with file:line evidence. Check rubric. Do NOT score viability.", run_in_background: true)
```

### Write results

- Merge into `.claude/cache/eval-cache.json` — preserve unscored features, don't overwrite
- Include `journey_position` field per feature
- Write/update rubrics per feature — see `references/rubric-guide.md`

### Outside-in pass

Run `bash scripts/outside-in.sh [project-dir]` to surface what the product is MISSING from intelligence caches. Present as "outside-in" section. This is a lens showing opportunity cost, not a score. Surface-agnostic — "acquire: 0 surfaces" could mean landing page, dashboard, API, or distribution channel.

### Cross-skill synthesis

After scoring: Does eval bottleneck match strategy bottleneck? Are plan tasks targeting weak features? Do results advance/block roadmap evidence?

Suggest `/score` for the unified product quality number. If web-facing features exist, suggest `/taste <url>`.

### Other modes

- **Scoped eval (`<feature>`)**: Same depth, one feature. Full code read, full rubric check. No agent spawn needed.
- **Blind**: Cold-read code vs claims, score alignment 0-100. Categories: ALIGNED, INFLATED, DEFLATED, DISCONNECTED.
- **Coverage**: Count assertions per feature, type distribution. Ideal: 30% mechanical, 50% content/command, 20% llm_judge.
- **Trend**: Run `bash scripts/quick-eval.sh`, read `.claude/evals/assertion-history.tsv`. Classify: stable, flapping, recently changed.
- **Slop**: Scan for comments restating code, over-engineered abstractions, generic names, empty catch blocks. Cite file:line. Report human-quality %.

## Task generation — the path to completion

See `../shared/task-generation.md` for the protocol. For EVERY feature scored, generate the complete task list:

- **Delivery tasks**: gaps between claim and code, stubs, dead-ending flows, missing error handling
- **Craft tasks**: rubric criteria not met, unhandled edge cases, fragile patterns (grep/sed parsing, hardcoded paths)
- **Coverage tasks**: features with <3 assertions, existence-only assertions that need strengthening
- **Regression tasks**: score drops vs previous eval, assertions that were passing and now fail

Tag with `source: /eval`, feature name, and dimension. Priority: highest-weight features first.

## Self-evaluation

This skill worked if: (1) eval-cache.json was updated with scores for all active features, (2) every score has file:line evidence, (3) variance-check.sh passed for each score, and (4) tasks were generated for every gap found.

## Agents: **rhino-os:evaluator** (parallel per feature), **rhino-os:measurer** (cheap mechanical)

## What you never do

- Present beliefs as the primary result — 0-100 scores are the eval
- Score without reading code — Read every file before scoring
- Give a score without file:line evidence
- Grade predictions or write to predictions.tsv — that is /retro
- Edit code — eval is measurement only

## First-run guidance

If no features defined in rhino.yml:
- Show: "No features yet. Define what your product delivers:"
- Show a quick rhino.yml example with one feature
- Suggest: `/feature new [name]` or `/onboard` to auto-detect

## System integration

Reads: rhino.yml, product-spec.yml, eval-cache.json, rubrics/*.json, experiment-learnings.md, strategy.yml, roadmap.yml, plan.yml, todos.yml, customer-intel.json, market-context.json, product-value.json, topology.json
Writes: eval-cache.json, rubrics/<feature>.json, tasks (via TaskCreate)
Triggers: /score (unified quality), /taste (visual quality for web), /go (build from gaps)
Triggered by: /go (measurement), /plan (stale data), /score (code tier)

## If something breaks

- No features in rhino.yml: "No features defined. `/feature new [name]`"
- Code paths empty: score 0, note "no code files found"
- Cache missing: no delta, establish baseline
- Rubric missing: score from scratch, write rubric after
- Beliefs fail: run `bash scripts/quick-eval.sh` to diagnose

$ARGUMENTS
