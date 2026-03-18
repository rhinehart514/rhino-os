---
name: discover
description: "Product discovery pipeline. Takes 'I want to build X' to a complete product-spec.yml with auto-wired features, assertions, roadmap, and strategy. Also refines, pivots, and pressure-tests existing specs. The skill that figures out WHAT to build and WHY."
argument-hint: "[new \"idea\"|refine|pivot|vs|systems|wild|invert]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion, WebSearch, WebFetch
---

!bash scripts/discovery-scan.sh 2>/dev/null || echo "no existing spec"

# /discover — Product Discovery Pipeline

From "I have an idea" to a wired-up project in one session. Or: pressure-test an existing product until the weak spots show.

## Skill folder structure

This skill is a **folder**. Read these on demand:

- `scripts/discovery-scan.sh` — runs FIRST. Scans existing product-spec.yml + eval-cache + market data. Outputs structured state.
- `scripts/spec-wire.sh` — reads product-spec.yml, outputs what needs to be created (features, assertions, roadmap entries).
- `scripts/spec-quality.sh` — grades product-spec.yml completeness and quality. Empty fields, vague claims, missing evidence.
- `references/discovery-guide.md` — how the pipeline works, what makes a good spec.
- `references/refinement-guide.md` — how to refine/pivot/kill. The ruthless questions.
- `references/market-2026.md` — 2026 market context. Read on every session.
- `templates/discovery-report.md` — output format for discovery sessions.
- `gotchas.md` — real failure modes. **Read before starting.**

The product spec template lives at `skills/onboard/templates/product-spec-template.yml`. That's the schema. Discover GENERATES it.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode | What happens |
|-------|------|-------------|
| `new "idea"` | **Define** | Full pipeline: agents research, founder answers questions, spec generated, project wired |
| (none) | **Define** | Same as `new` but for existing product — reads codebase, generates/updates spec |
| `refine` | **Refine** | Pressure-test existing spec. Attack every claim. Make it sharper. |
| `pivot` | **Pivot** | Spec isn't working. Read evidence, propose specific changes. |
| `vs` | **Compare** | Compare spec against competitors. Find real differentiator. |
| `systems` | **Systems** | Deep systems audit — what exists, what's missing, build order |
| `wild` | **Wild** | Moonshot mode — riskier ideas, <30% confidence, high learning value |
| `invert` | **Invert** | What would kill this product? Build defenses. |

---

## Mode: Define (`/discover new "idea"` or `/discover`)

This is the main pipeline. Three phases: Research, Define, Wire.

### Phase 1: Research (parallel agents + founder questions)

Launch ALL simultaneously:

**Agent A: Customer signal (background)**
```
Agent(subagent_type: "rhino-os:customer", prompt: "Research customer signal for [idea/product]. Focus on: who has this pain, what language they use, where they congregate, demand signals, willingness to pay. Write findings to .claude/cache/customer-intel.json.", run_in_background: true)
```

**Agent B: Market landscape (background)**
```
Agent(subagent_type: "rhino-os:market-analyst", prompt: "Research competitive landscape for [idea/product]. Include 2026 players (Amplitude agents, LinearB, Salesforce Agentforce, etc). Pricing norms. Who's winning and why. Write to .claude/cache/market-context.json.", run_in_background: true)
```

**Agent C: Codebase analysis (if repo has code)**
```
Agent(subagent_type: "rhino-os:explorer", prompt: "Analyze this codebase. Map: what exists, what's the architecture, what features are built, what's the user journey. Write to .claude/cache/codebase-analysis.json.")
```

**While agents research**: Walk founder through product questions via AskUserQuestion.

Read `references/discovery-guide.md` for the question sequence. The core questions:

1. **Who specifically has this pain?** Not "developers." A person in a situation.
2. **What do they do today without this?** The current workaround IS the competition.
3. **What changes for them?** Before/after in one sentence.
4. **What's the core loop?** The thing they do repeatedly. Trigger → action → reward.
5. **What makes them try it?** The hook. First 5 minutes.
6. **What brings them back?** The return trigger. No pull = no product.
7. **What are you NOT building?** The kill list. Minimum 3 items.
8. **Why now?** Must cite a 2026-specific signal. Read `references/market-2026.md`.
9. **When do you pivot?** Specific triggers with specific responses.

Use AskUserQuestion for each. Don't dump all at once — one question at a time, react to answers, follow threads.

**2026 market awareness (mandatory):** Read `references/market-2026.md` before asking "why now?" Apply YC lens questions (from `skills/ideate/techniques/yc-lens.md`) throughout — especially #2 (evidence of demand), #4 (why now), #6 (first 10 users).

### Phase 2: Synthesize into product-spec.yml

Collect:
- Founder's answers from Phase 1
- Customer agent output (`.claude/cache/customer-intel.json`)
- Market analyst output (`.claude/cache/market-context.json`)
- Codebase analysis (`.claude/cache/codebase-analysis.json`) if applicable

Generate `config/product-spec.yml` following the schema at `skills/onboard/templates/product-spec-template.yml`. Every field filled. No empty strings.

**Quality gate:** Run `bash scripts/spec-quality.sh` on the generated spec. If score < 70, iterate — ask founder to strengthen weak sections.

Present the full spec to founder via AskUserQuestion for approval/editing. "Here's what I heard. What's wrong?"

### Phase 3: Auto-wire (after founder approves spec)

Run `bash scripts/spec-wire.sh` to compute what needs creating. Then wire:

**3A: Roadmap** — Create/update `.claude/plans/roadmap.yml`:
- Version thesis derived from spec's `change.in_one_sentence`
- Evidence items from spec's `signals` + `pivot_triggers`
- Relevant features from spec's `core_loop`

**3B: Features** — Create features in `config/rhino.yml` from:
- `core_loop` → the main feature (weight: 5)
- `first_experience` → onboarding feature (weight: 4)
- `return_trigger` → retention feature (weight: 4)
- Each item in `not_building` → documented exclusion

**3C: Assertions** — Generate `config/beliefs.yml` entries from:
- Each `signals` item → mechanical assertion (prefer `grep`, `file_exists`, `command` over `llm_judge`)
- Each claim in spec → testable belief
- Each `pivot_triggers` item → monitoring assertion

**3D: Strategy** — Populate `.claude/plans/strategy.yml` from:
- `competitors` → competitive landscape
- `why_now` → market timing
- `who` → user segment

**3E: rhino.yml** — Write `config/rhino.yml` value section from spec's `who`, `change`, `core_loop`

Show summary: "Project configured. N features, M assertions, thesis set. Run `/plan` to start building."

---

## Mode: Refine (`/discover refine`)

Read `references/refinement-guide.md` for the attack patterns.

1. Run `bash scripts/spec-quality.sh` — get the quality grade
2. Read `config/product-spec.yml`
3. Read `.claude/cache/eval-cache.json` — what's the product actually doing?
4. Read `~/.claude/knowledge/predictions.tsv` — what predictions failed?

Attack every section:

- **who**: "Is this a real person or a category? Can you name three humans who match this description?"
- **change**: "Is the before/after measurable? How would you KNOW the change happened?"
- **core_loop**: "How often does the loop actually run? Is the reward strong enough to trigger repeat?"
- **not_building**: "Only N items. You haven't killed enough. What else should die?"
- **competitors**: "You listed N. There are more. What about [X]?"
- **pivot_triggers**: "These are too soft. 'If users don't come back' — how many users? After how many days? Be specific."
- **why_now**: "Does this cite a 2026 signal? 'AI is growing' is not specific enough."
- **pricing**: "No price? Revenue avoidance. A price forces clarity even if you change it."

Use AskUserQuestion for each weak section. Update spec in place.

Re-run `bash scripts/spec-quality.sh` after refinement. Show delta.

---

## Mode: Pivot (`/discover pivot`)

The spec isn't working. What should change?

1. Run `bash scripts/discovery-scan.sh` — full state scan
2. Read failing assertions, wrong predictions, stale thesis evidence
3. Read `references/refinement-guide.md` for pivot patterns

Propose SPECIFIC pivots (not "maybe consider"):
- "Change WHO from X to Y because [evidence Z]"
- "Kill core_loop A, replace with B because [evidence C]"
- "Your why_now expired — [market shift D] changed the landscape"
- "Pivot trigger E already fired — here's the evidence"

Each pivot includes:
- What changes in the spec
- What downstream wiring changes (features, assertions, roadmap)
- What you lose by pivoting
- What you gain

Use AskUserQuestion: "Which pivot, if any? Or propose your own." Then re-wire.

---

## Mode: Compare (`/discover vs`)

1. Spawn **market-analyst agent** to research competitor product definitions
2. Read existing `config/product-spec.yml`
3. Compare across every spec dimension:

```
they have / we don't:
  · [capability] — [competitor] · table stakes or differentiating?

we have / they don't:
  · [capability] — real advantage or just different?

nobody has:
  · [capability] — novel opportunity

our differentiator: [one sentence — if the answer is "we use AI" that's not a differentiator in 2026]
```

Be brutal. Most "differentiators" aren't.

---

## Mode: Systems (`/discover systems`)

Deep systems audit. Inherits the systems thinking from the original /discover. Read the full systems map approach from `references/discovery-guide.md` section on systems decomposition.

---

## Mode: Wild (`/discover wild`)

Moonshot ideas. <30% confidence. High learning value. Same as original `wild` mode — riskier systems, bigger bets.

---

## Mode: Invert (`/discover invert`)

What would kill this product? Map failure modes, rate likelihood x defense, recommend the missing defensive system. See `references/discovery-guide.md`.

---

## Task Generation (ALL modes)

After EVERY /discover session, generate tasks. Read current `.claude/plans/todos.yml` first to avoid duplicates.

Scan for:
- Each undefined/empty spec section → task to fill it
- Each weak claim (no evidence) → task to gather evidence
- Each competitor gap → task to address or document why not
- Each missing feature in the wiring → task to create it
- Each assertion gap → task to write it
- Each stale thesis evidence item → task to prove/disprove

Format tasks for `/todo add`:
```
todo:add "[task description]" feature:[relevant feature] source:/discover
```

Output the task list at the end of every session.

---

## Prediction

Before generating the spec (define mode) or attacking it (refine mode):

```
predict: [specific outcome]
because: [evidence]
wrong if: [what would disprove]
```

Log to `~/.claude/knowledge/predictions.tsv`.

---

## Integrity Checks

| Check | Trigger | Action |
|-------|---------|--------|
| **EMPTY_SPEC** | Generated spec has >3 empty fields | Iterate with founder |
| **VAGUE_WHO** | `who.person` is a category not a person | Push back |
| **NO_EVIDENCE** | `who.evidence` is empty | Flag — building on assumption |
| **WEAK_NOT_BUILDING** | <3 items in kill list | "You haven't killed enough" |
| **NO_WHY_NOW** | Missing 2026-specific signal | Reject — timing matters |
| **SOFT_PIVOTS** | Pivot triggers lack specific numbers | Push for specifics |
| **NO_PRICING** | Pricing section empty at stage some+ | Revenue avoidance warning |
| **UNWIRED** | Spec approved but wiring incomplete | Complete auto-wire |

---

## Output

Use the format in `templates/discovery-report.md`. Key sections:

- State bar (version, completion, score)
- Spec summary (who/what/why)
- Quality grade from spec-quality.sh
- Wiring status (what was created)
- Tasks generated
- Next commands

Bottom of every output — exactly 3 next commands contextual to mode.

---

## What You Never Do

- Generate a spec without founder input (agents research, founder decides)
- Skip the quality gate on generated specs
- Leave the project unwired after spec approval
- Accept vague answers ("users", "developers", "it's better")
- Skip market-2026 context on any session
- Be sycophantic — the spec needs to be attacked, not praised
- Generate tasks without checking existing todos for duplicates

$ARGUMENTS
