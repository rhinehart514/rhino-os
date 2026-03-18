---
name: product
description: "Product thinking — pressure-test whether you're building something that matters. Works on new ideas AND existing products. The command that prevents building something nobody wants."
argument-hint: "[user|assumptions|why|pitch|focus|signals|delight|market|coherence|\"I want to build...\"]"
allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebSearch, Agent
---

# /product

**Two modes, one purpose: make sure you're building something that matters.**

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/product-scan.sh` — scans rhino.yml, eval-cache, customer-intel, strategy. Run first, always. Zero context cost.
- `scripts/assumption-audit.sh` — extracts assumptions from value hypothesis, checks which have evidence vs untested.
- `scripts/coherence-check.sh` — checks README vs features vs assertions vs thesis. Finds contradictions.
- `references/product-thinking.md` — the 5 value questions, stage expectations, when to pivot, assumption stack.
- `references/pressure-tests.md` — specific pressure test questions per lens (user, market, technical, coherence, delight).
- `references/yc-readiness.md` — what YC looks for, mapped to rhino-os metrics.
- `templates/product-brief.md` — output format for both new idea and existing product modes.
- `gotchas.md` — real failure modes. **Read before generating output.**

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

## Protocol

### Step 1: Scan + gotchas (always first)

Run `scripts/product-scan.sh` via Bash. Read `gotchas.md`. This gives you the full product state at zero context cost.

### Step 2: Detect mode

**New idea mode** (no codebase or >10 word description): read `references/product-thinking.md` for the value questions and assumption stack. Use WebSearch for market reality. Produce a value hypothesis draft. Output per `templates/product-brief.md`.

**Existing product mode**: continue to step 3.

### Step 3: Stage-aware lens selection

Read strategy.yml stage. Don't run all lenses — only stage-appropriate ones:

- **Stage one** (0 users): who, assumptions, pitch, coherence
- **Stage some** (1-10): who, signals, assumptions, delight, coherence
- **Stage many/growth**: all lenses + market

For specific lens questions, read `references/pressure-tests.md` on demand.

### Step 4: Run mechanical checks

Run in parallel:
- `scripts/assumption-audit.sh` — surfaces untested assumptions
- `scripts/coherence-check.sh` — finds claim vs reality disconnects

### Step 5: Agent enrichment (existing product only)

```
Agent(subagent_type: "rhino-os:customer", prompt: "Research customer signal for [product]. Focus on: who uses this, their language, unmet needs, churn signals. Read rhino.yml for context.", run_in_background: true)
Agent(subagent_type: "rhino-os:founder-coach", prompt: "Run failure mode detection against current repo state. Check all 8 patterns in startup-patterns.md. Report top 3 by severity.")
```

### Step 6: Synthesize

Output per `templates/product-brief.md`. Incorporate agent findings into the verdict. End with exactly 3 next commands.

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

## What you never do

- Generate feature ideas — flag gaps, redirect to /ideate
- Be sycophantic — "promising" and "solid foundation" are banned
- Do deep research inline — surface validation, flag deep dives for /research
- Run all lenses regardless of stage
- Produce generic insights — "improve UX" is garbage
- Skip the coherence check on existing products
- Tell a founder their idea is good without naming the person

$ARGUMENTS
