---
name: product
description: "Use when the user wants to pressure-test whether they're building the right thing — new ideas ('should we build this?'), existing products ('is this actually working?'), assumptions, user journey, pitch clarity, or product-market fit."
argument-hint: "[user|assumptions|why|pitch|focus|signals|delight|market|coherence|\"I want to build...\"]"
allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebSearch, Agent
---

# /product

**Two modes, one purpose: make sure you're building something that matters.**

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `references/product-thinking.md` — the 5 value questions, stage expectations, when to pivot, assumption stack.
- `references/pressure-tests.md` — specific pressure test questions per lens (user, market, technical, coherence, delight).
- `references/yc-readiness.md` — what YC looks for, mapped to rhino-os metrics.
- `templates/product-brief.md` — output format for both new idea and existing product modes.
- `gotchas.md` — real failure modes. **Read before generating output.**

Scripts exist as verification: `scripts/product-scan.sh`, `scripts/assumption-audit.sh`, `scripts/coherence-check.sh` — run these to cross-check your analysis if needed.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) | Full product session — all stage-appropriate lenses |
| `"I want to build..."` or >10 words not matching a route | **New idea mode** |
| `user` / `journey` | User journey walkthrough |
| `assumptions` / `risks` | Assumption audit |
| `why` / `value` | Value chain trace |
| `pitch` | Pitch clarity test |
| `focus` / `cut` | Feature kill/focus exercise |
| `signals` | Signal instrumentation check |
| `delight` | Craft moment identification |
| `market` | Market reality check |
| `coherence` | Narrative coherence audit |
| `yc` | YC readiness check — read `references/yc-readiness.md` |
| `[feature name]` | Product thinking scoped to one feature |

## State to read

Read `gotchas.md` first. Then read state directly — you are the product thinker, not a script runner:

**Value hypothesis** — read `config/rhino.yml`:
- Extract `value:` section (hypothesis, user, signals)
- Extract features list (names, weights, status)
- If no rhino.yml: "product has no value hypothesis — run /onboard"

**Eval scores** — read `.claude/cache/eval-cache.json`:
- Per-feature: score, delivery_score, craft_score, viability_score, delta
- Maturity labels: planned(<30), building(30-49), working(50-69), polished(70-89), proven(90+)
- **Delivery vs craft gap**: flag features where craft > delivery + 15 (polishing before delivering)

**Assumption audit** — reason about this yourself:
- Extract the hypothesis from rhino.yml. What assumptions does it make?
- Check evidence sources: eval-cache (feature scores as evidence), predictions.tsv (wrong predictions = disproven assumptions), experiment-learnings.md (known vs unknown), customer-intel.json (external signal)
- Per-feature assumption level: score < 30 = untested, < 50 = building, < 70 = working, >= 70 = well-supported
- Count evidence density: how many of 4 sources (eval, predictions, learnings, customer) exist?

**Coherence check** — reason about contradictions yourself:
- README.md vs rhino.yml features: are all features mentioned in README?
- Features vs beliefs.yml: do all features have assertions?
- Eval scores vs roadmap thesis: are high-weight features scoring low?
- narrative.yml vs roadmap: does narrative claim things evidence hasn't proven?
- Hypothesis vs features: does a hypothesis exist, and do features deliver it?

**Additional context:** `config/product-spec.yml`, `.claude/plans/strategy.yml` (stage), `.claude/cache/customer-intel.json`, `.claude/plans/roadmap.yml`, `README.md`, `git log --oneline -10`

## How to assess

**New idea mode** (no codebase or >10 word description): read `references/product-thinking.md` for the value questions and assumption stack. Use WebSearch for market reality. Produce a value hypothesis draft. Output per `templates/product-brief.md`.

**Existing product mode** — select lenses by stage:
- **Stage one** (0 users): who, assumptions, pitch, coherence
- **Stage some** (1-10): who, signals, assumptions, delight, coherence
- **Stage many/growth**: all lenses + market

For specific lens questions, read `references/pressure-tests.md` on demand.

**Agent enrichment** (existing product only):
- Spawn `rhino-os:customer` in background for customer signal
- Spawn `rhino-os:founder-coach` for failure mode detection against startup-patterns.md

Synthesize using `templates/product-brief.md`. Incorporate agent findings into the verdict. End with exactly 3 next commands.

## Tools

- **WebSearch**: market reality (new idea), assumption validation (existing). 30 seconds max per query. For deep research, suggest `/research market`.
- **AskUserQuestion**: naming the person, editing the value hypothesis, verdict discussion.
- **Read**: state files, references on demand.
- **Bash**: `scripts/*.sh`, `rhino score .`, `rhino feature`, `git log`.
- **Agent**: customer signal (rhino-os:customer), founder coaching (rhino-os:founder-coach).

## Task generation — the path to product-market fit

**/product's job is not just assessment. It's generating EVERY task needed to close the gap between what you claim and what's true.** If /product finds a problem but doesn't create a task, the founder has a diagnosis but no action plan.

**For EVERY gap found, generate the complete task list:**

### Assumption tasks (from assumption-audit.sh)
- Each untested assumption in the value hypothesis → task: "Assumption '[X]' has no evidence — run experiment to test"
- Each assumption with contradicting evidence → task: "Assumption '[X]' contradicted by [evidence] — update hypothesis or pivot"
- Each assumption marked "critical" with no test plan → task to design a test

### Coherence tasks (from coherence-check.sh)
- README claims feature X but code doesn't deliver → task: "README says [X] but [reality] — fix code or fix claim"
- Value hypothesis doesn't match features list → task to align rhino.yml
- Thesis evidence doesn't match what's actually being built → task to update roadmap.yml
- Feature weights don't reflect stated priorities → task to re-weight

### User journey tasks
- Each friction point in the user journey → task with specific fix
- Each dead end (user completes action, nowhere to go) → task to add next step
- Each confusion point (requires prior context) → task to add guidance
- Missing first-time experience → task to build onboarding flow
- No return trigger identified → task to design one

### Pressure test failure tasks
- "Who gets value?" can't be answered → task: "Run /product user to name the person"
- "What changes?" is vague → task to make the value proposition concrete
- "Would they notice if it disappeared?" answer is no → task to reconsider feature
- Pitch fails clarity test → task to rewrite via /copy pitch

### Signal instrumentation tasks
- No way to know if users get value → task to add measurement
- No feedback mechanism → task to add a feedback path
- No usage tracking → task to instrument key flows
- Feature has no assertions → task to add via /assert

### Founder coaching tasks (from founder-coach agent)
- Each failure mode detected → task with intervention
- Each avoidance pattern named → task to address
- Each stage-inappropriate activity → task to redirect effort

**Write ALL tasks to /todo.** Tag with `source: /product`, the specific lens (user/assumptions/coherence/signals/delight), and severity. Priority: untested critical assumptions first.

**There is no cap on task count.** A product with 8 untested assumptions and 5 coherence violations might need 20 tasks. Generate all of them. /plan picks what to work on — /product's job is to make sure every gap between "what we claim" and "what's true" is captured.

After writing tasks, show: "Generated N tasks across M product gaps. Most critical: [gap] — [why it matters]."

## System integration

Reads: `config/rhino.yml`, `.claude/cache/eval-cache.json`, `config/product-spec.yml`, `.claude/plans/strategy.yml`, `.claude/plans/roadmap.yml`, `.claude/cache/customer-intel.json`, `.claude/cache/narrative.yml`, `config/beliefs.yml`, `README.md`, `.claude/knowledge/predictions.tsv`, `.claude/knowledge/experiment-learnings.md`
Writes: `.claude/plans/todos.yml`, `.claude/knowledge/predictions.tsv`
Triggers: `/ideate` (gaps need solutions), `/research` (assumptions need evidence), `/discover` (spec needs updating), `/copy pitch` (pitch fails clarity test)
Triggered by: `/plan` (product-market fit questions), `/strategy` (is the product working?), `/discover refine` (spec pressure-test)

## What you never do

- Generate feature ideas — flag gaps, redirect to /ideate
- Be sycophantic — "promising" and "solid foundation" are banned
- Do deep research inline — surface validation, flag deep dives for /research
- Run all lenses regardless of stage
- Produce generic insights — "improve UX" is garbage
- Skip the coherence check on existing products
- Tell a founder their idea is good without naming the person

## Self-evaluation

/product succeeded if:
- Every untested assumption is surfaced with a task to test it
- Coherence check ran and every disconnect has a task
- The founder knows the biggest gap between "what we claim" and "what's true"
- At least one pressure test question made the founder uncomfortable

## Cost note

This skill spawns 2 agents:
- `customer` (sonnet, background) — customer signal research
- `founder-coach` (opus) — failure mode detection against startup-patterns.md
- Agents only spawn in existing product mode (not new idea mode). Cost tier from `~/.claude/preferences.yml`.

## When to use

Use `/product` when you need to pressure-test whether you're building the right thing — for new ideas ("should we build this?") or existing products ("is this actually working?"). Use `/ideate` instead when you already know the direction and need specific feature ideas. Use `/research` when you need evidence before making a product decision. Use `/strategy` when the question is about competitive positioning or stage, not product-market fit.

## If something breaks

- product-scan.sh returns empty: `config/rhino.yml` may not exist — run `/onboard` first
- assumption-audit.sh finds zero assumptions: the value hypothesis in rhino.yml is too vague — flesh out the `value:` section with specific claims
- coherence-check.sh reports false mismatches: README may describe aspirational features — update README to match current state or mark features as `planned`
- founder-coach agent times out: the startup-patterns check is running against a large repo — this is informational only, skip and proceed with other lenses

$ARGUMENTS
