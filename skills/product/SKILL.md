---
name: product
description: "Product thinking — from 'I want to build X' to 'here's who cares and why, here's what we've proven, here's what's delusional.' Works on new ideas AND existing products. The command that prevents you from building something nobody wants."
argument-hint: "[user|assumptions|why|pitch|focus|signals|delight|market|coherence|\"I want to build...\"]"
allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebSearch, Agent
context: fork
---

# /product

**Two modes, one purpose: make sure you're building something that matters.**

**Mode 1 — New idea**: The founder says "I want to build a product that does X." Before a single line of code, `/product` pressure-tests the idea against market reality, names the person who cares, identifies the assumptions that could kill it, and produces a value hypothesis ready for `/onboard`.

**Mode 2 — Existing product**: The founder has code, features, scores. `/product` checks whether what's being built matches what's being claimed, surfaces the assumptions nobody's tested, and catches the moment the product stops making sense.

This is the command that prevents building something nobody wants. `/ideate` asks WHAT to build. `/product` asks WHETHER to build it.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) | Full product session — all applicable lenses |
| `"I want to build..."` or any idea description | **New idea mode** — pressure test from scratch |
| `user` or `journey` | User journey walkthrough |
| `assumptions` or `risks` | Assumption audit |
| `why` or `value` | Value chain trace |
| `pitch` | Pitch clarity test |
| `focus` or `cut` | Feature kill/focus exercise |
| `signals` | Signal instrumentation check |
| `delight` | Craft moment identification |
| `market` | Market reality check |
| `coherence` | Narrative coherence audit |
| `[feature name]` | Product thinking scoped to one feature |

**Detecting new idea mode:** If `$ARGUMENTS` is >10 words and doesn't match any route keyword or feature name, treat it as a new product idea. This is the "I want to build X" entry point.

## New Idea Mode

When the founder describes a product idea — before any code exists.

### 1. Understand the idea

Read the description. Extract:
- **What**: what does it do? (restate in one sentence)
- **Who**: who is it for? (if vague, that's finding #1)
- **Why now**: what changed in the world that makes this possible/needed now?
- **How**: what's the mechanism? (API? CLI? Web app? Plugin?)

### 2. Market reality check

Use WebSearch to answer in <2 minutes:
- **Does this exist?** Search for the idea directly. If competitors exist, that's GOOD (validated market) but name them and name how this would be different.
- **Who's tried and failed?** Search for shutdowns, pivots, postmortems in this space. Dead competitors teach more than live ones.
- **What adjacent thing is growing?** If the exact thing doesn't exist, what's the nearest successful product? What does their growth tell you about demand?
- **What are people complaining about?** Search forums, Reddit, HN, Twitter for the pain point. Real complaints = real demand. No complaints = either solved or nobody cares.

### 3. Name the person

Not "developers" or "teams" — one human being with a name-level of specificity:

```
"A solo founder who just pushed code and wants to know if their product
got better. They use Claude Code. They don't have a team to code-review.
They've tried linters but those measure health, not value."
```

If the founder can't describe this person, that's the most important finding. A product without a person is a project, not a product.

Use AskUserQuestion: "Who specifically would use this? Describe one person and their situation."

### 4. Assumption extraction

Every idea is a stack of assumptions. Extract them and rank by (risk × ignorance):

- **Demand assumption**: "This person has this problem" — do they?
- **Solution assumption**: "This approach solves it" — does it?
- **Mechanism assumption**: "They'd use it this way" — would they?
- **Market assumption**: "Nothing else does this" — true?
- **Timing assumption**: "This is possible/needed now" — why now, not last year?
- **Business assumption**: "This can sustain" — how?

For each: risk (1-5) × ignorance (none=4, anecdotal=3, tested=2, proven=1). Highest score = test first.

### 5. Produce the value hypothesis

Write a draft `value:` section for rhino.yml:

```yaml
value:
  hypothesis: "[testable one-sentence claim]"
  user: "[the specific person]"
  signals:
    - name: [observable signal]
      description: [what it means]
      target: [what success looks like]
      measurable: [true/false]
```

Present via AskUserQuestion for editing.

### 6. The verdict

One paragraph. Honest. Is this worth building? What's the highest-risk assumption? What would you test first? What should the v1.0 thesis be?

Then:
```
/onboard           bootstrap the repo with this hypothesis
/research [topic]  validate the top assumption before building
/ideate            brainstorm the specific features
```

---

## Existing Product Mode

When the codebase already exists with features, scores, and history.

### State to read (parallel)

1. `config/rhino.yml` — value hypothesis, user, features, signals
2. `.claude/cache/eval-cache.json` — sub-scores + deltas
3. `.claude/cache/narrative.yml` — what the product claims externally
4. `.claude/cache/positioning.yml` — competitive positioning
5. `.claude/cache/market-context.json` — market landscape
6. `.claude/knowledge/experiment-learnings.md` — known patterns, dead ends
7. `.claude/plans/roadmap.yml` — thesis + evidence status
8. `.claude/plans/strategy.yml` — stage, bottleneck
9. `.claude/plans/todos.yml` — backlog health
10. `git log --oneline -20` — what's been worked on
11. `README.md` — what the product says about itself

### Stage-aware lens selection

Not all lenses apply at every stage. Don't run 7 lenses when 3 are premature.

**Stage one** (0 external users):
- **Who** — is the person defined? Can you find them?
- **Assumptions** — what's untested? What could kill this?
- **Pitch** — can you explain it clearly?
- **Coherence** — does the code match the claims?
- Skip: signals (nothing to measure yet), delight (premature), focus (not enough features to cut)

**Stage some** (1-10 users):
- **Who** — are the actual users who you expected?
- **Signals** — what are you measuring? What's missing?
- **Assumptions** — which assumptions were wrong? Update from real usage.
- **Delight** — is the value delivery moment good enough to retain?
- **Coherence** — does the narrative match reality?

**Stage many/growth**:
- All lenses apply.
- Add: **Market** lens (positioning relative to competitors).

### The Lenses

#### 1. Who (user journey)
Walk each step from "heard about this" to "got value." Score friction 1-5 per step. Find the drop-off point.

If playwright available: actually walk the product.
If not: trace from code.

**Research inline**: when friction is found, WebSearch for how similar products solve it.

#### 2. Why (value chain)
Trace: code → feature → assertion → signal → hypothesis. Flag:
- **Orphaned code**: files not in any feature's `code:` list
- **Orphaned features**: high-weight features with no assertions
- **Dead weight**: w:4+ features at `planned` maturity (important but untouched)
- **Value leaks**: features that exist but don't connect to the hypothesis

#### 3. Assumptions (risk audit)
Extract every assumption. Rank by risk × ignorance. Cross-reference with:
- `experiment-learnings.md` — are any assumptions already confirmed/denied?
- `market-context.json` — do competitors validate or contradict assumptions?
- Wrong predictions from `predictions.tsv` — wrong predictions often reveal wrong assumptions

**The top 3 assumptions get inline WebSearch validation.**

#### 4. Focus (kill exercise)
"If you could only keep 2 features, which 2?" Check weights. Check maturity. Check what's actually been worked on (git log).

Cross-reference with `/ideate`'s kill list if recent.

#### 5. Signals (measurement gap)
For each signal in rhino.yml: is it instrumented? When was it last checked? What's the current value?

Connect to eval sub-scores: value_score is the closest proxy for signal health.

#### 6. Delight (craft moment)
The 10 seconds where value is delivered. Is there personality? Would someone screenshot this and share it? If not — why not?

#### 7. Pitch (clarity test)
Generate elevator, tweet, hero variants. Run through clarity filter (no jargon, names a person, states what changes, differentiates).

**Cross-check with narrative.yml** — does the pitch match the current narrative? If narrative.yml says one thing and the pitch test produces something different, the narrative is stale.

#### 8. Market (reality check) — NEW
Only runs when market-context.json exists or explicitly requested.

- What's table stakes that you're missing?
- What's your actual differentiator (proven, not aspirational)?
- Where are you behind and does it matter at your stage?

#### 9. Coherence (narrative audit) — NEW
The most important lens for existing products. Checks alignment across:

- **Code vs claims**: does eval-cache show features delivering what rhino.yml claims?
- **Narrative vs reality**: does narrative.yml match what's actually proven in roadmap.yml?
- **README vs product**: does README describe what the product actually does today?
- **Pitch vs positioning**: does the pitch match the competitive positioning?

Disconnects = the most important finding. A product that claims one thing and does another is lying to itself.

### Synthesis: The Product Brief

```
── verdict ────────────────────────────────
  product clarity: **N/10**
  stage: [one/some/many/growth]
  biggest risk: [top assumption with evidence level]
  biggest disconnect: [from coherence lens — where claims ≠ reality]
  drop-off point: [from user journey — where users leave]

  "[One paragraph. What a cofounder would say after spending an hour
   thinking about the product, not the code. Names the one thing that
   matters most right now. Anti-sycophantic — if the product doesn't
   know who it's for, say so.]"
```

## Tools to use

**Use WebSearch** for market reality (new idea) and assumption validation (existing product). Keep it fast — 30 seconds per query max.
**Use Agent (market-analyst)** for deep market research when `/product market` is requested.
**Use AskUserQuestion** for naming the person, editing the value hypothesis, and verdict discussion.
**Use Read** for all state files.
**Use Bash** for `rhino score .`, `rhino feature`, `git log`.

For output templates, see [reference.md](reference.md).

## What you never do
- Generate feature ideas — flag gaps, redirect to /ideate
- Be sycophantic — "your product is promising" is banned
- Do deep research inline — surface validation only, flag deep dives for /research
- Run all 7 lenses regardless of stage — stage-appropriate only
- Produce generic insights — "improve UX" is garbage
- Skip the coherence check on existing products — disconnects are the #1 finding
- Tell a founder their new idea is bad without market evidence — you might be wrong
- Tell a founder their new idea is good without naming the person — you're probably being nice

## If something breaks
- No value hypothesis: "Your product doesn't know what it's for. Let's fix that now." → AskUserQuestion
- No features: "No features defined. `/feature new [name]` to start, or describe the idea and I'll extract them."
- No market-context: run inline WebSearch, flag that deep research would help
- No narrative.yml: skip coherence check against narrative, suggest `/roadmap narrative` after
- New idea with no codebase: that's fine — new idea mode doesn't need code

$ARGUMENTS
