---
name: discover
description: "Product discovery and systems ideation. What should this product be? What systems does it need? What's the shape of the thing? Heavy on ideation — from 'I have an idea' to 'here are the systems, here's what matters, here's what to build first.' Works on new products AND existing ones."
argument-hint: "[new \"idea\"|systems|wild|vs|invert|feature|\"topic\"]"
allowed-tools: Read, Bash, Grep, Glob, Edit, AskUserQuestion, WebSearch, Agent
---

# /discover — Product Discovery & Systems Ideation

The question isn't "what's broken?" — it's **"what should this product be made of?"**

/discover is the ideation engine. It figures out what systems a product needs, what the product should look like, what to build and in what order. It works on:

- **New products**: "I have an idea for X" → here are the systems, the user journey, the MVP scope, the first thing to build
- **Existing products**: "What should we add?" → here are the missing systems, the underweight areas, the next layer of value
- **Product reshaping**: "This isn't working" → here's what the product should become instead

**This is not gap analysis.** This is a cofounder whiteboarding what the product should be. Systems thinking, not bug hunting.

**What makes this skill intelligent:**
- **Systems decomposition** — breaks any product idea into the systems that make it work
- **Parallel agents** — explorer + market-analyst research simultaneously while you think
- **Live product analysis** — playwright sees the actual product, not just code
- **Market-grounded ideation** — knows what exists, what's table stakes, what's novel
- **Dependency mapping** — which systems enable which, what's the critical path
- **Velocity calibration** — sizes everything to the team's actual shipping speed
- **Anti-sycophancy** — tells the founder when an idea is bad, not just when it's good
- **Self-improving memory** — tracks which recommendations got built and worked

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) | Full discovery — what should this product be/become? |
| `new "idea"` | New product ideation — decompose an idea into systems |
| `systems` | Systems audit — what systems exist, what's missing, what's next |
| Feature name | Scoped — what should this feature become? |
| `wild` | Moonshot — riskier systems, bigger bets, <30% confidence |
| `vs` | Competitive — what systems do competitors have that we don't? |
| `invert` | Inversion — what systems would prevent this product from failing? |
| `[any text]` | Constrained ideation around a topic or question |

---

## Phase 0: Context (parallel, fast)

Launch SIMULTANEOUSLY:

### Thread A: State

Read in parallel:
1. `config/rhino.yml` — value hypothesis, user, features, weights
2. `.claude/cache/eval-cache.json` — **per-feature scores + sub-scores (d/c/v)**. This is the ground truth for system maturity. A feature scoring 42 with quality:35 is a DIFFERENT problem than 42 with value:35.
3. `.claude/plans/roadmap.yml` — current thesis and evidence
4. `.claude/plans/strategy.yml` — current bottleneck, market diagnosis, competitors
5. `.claude/plans/todos.yml` — backlog items
6. `~/.claude/evals/discovery-history.tsv` — past recommendations and outcomes
7. `~/.claude/evals/discovery-learnings.md` — accumulated discovery intelligence
8. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`)
9. `git log --oneline -30` — recent work velocity

Compute: product map, product completion %, bottleneck, shipping velocity (commits/30 days).

**Eval grounding:** Every system in the map should reference its eval score if it maps to a feature. A system without a score is a hypothesis. A system with a score is a measurement. Discovery recommendations that ignore eval scores are ungrounded.

### Thread B: Live Product (if dev server running)

If playwright available AND dev server running:
1. Navigate, snapshot, screenshot
2. Walk 2-3 key routes
3. Note: what's the first-time experience? Where's the value? Where does it end?

### Thread C: Market (1 query max)

1. Reuse `~/.claude/evals/taste-market.json` or `~/.claude/cache/market-context.json` if <7 days old
2. If stale: WebSearch `"best [category] tools 2026"` (ONE query)
3. Extract: what systems do top products have? What's table stakes? What's nobody doing?

### Thread D: Backfill (if history exists)

Check past recommendations: built? succeeded? Update discovery-history.tsv.

---

## Stage 1: Understand (10% of effort)

Quick orientation — not deep diagnosis. Just enough to ideate well.

### 1A: What is this product?

One paragraph. Who it's for, what it does, what stage it's at. If `new` mode, this comes from the founder's description.

### 1B: What systems exist?

Map current systems from features in rhino.yml + eval-cache sub-scores:

```
systems:
  ✓ [system] — [maturity], weight:[N], eval:[score] (d:[N] c:[N] v:[N])
  ✓ [system] — [maturity], weight:[N], eval:[score] (d:[N] c:[N] v:[N])
  · [system] — planned, weight:[N], no eval data
```

**The eval score IS the system maturity.** Not a label — the actual score from the judge. A feature scoring 42 is not mature regardless of any label. Use eval scores to ground every system assessment.

### 1C: What's the user journey?

Trace the path a user takes through the product. Where do systems connect? Where are dead ends? Where does value happen?

```
journey: discover → [system A] → [system B] → value moment → [return trigger?]
dead ends: [where the journey stops with no next step]
value moment: [where the user gets what they came for]
```

### 1D: One contradiction (if any)

The single most important place where the product says one thing but does another. Just one — this isn't a diagnosis tool.

---

## Stage 2: Ideate Systems (70% of effort)

This is the core. **What systems should this product have?**

### Cross-reference /strategy

If `strategy.yml` exists, read it. Strategy knows the market — discover should build ON that:
- **Strategy bottleneck** → discover should prioritize systems that unblock it
- **Strategy stage** → discover should size recommendations appropriately (stage one = small, fast systems)
- **Strategy competitors** → discover should check which systems competitors have that we lack
- **Strategy "you're avoiding"** → discover should confront the same avoidance, not route around it

If strategy says the bottleneck is "first-loop" and discover recommends a growth system, that's a contradiction. Name it.

### 2A: The Systems Map

Think about the product holistically. Not "what feature to add next" but "what are ALL the systems this product needs to deliver its value hypothesis?"

Categories of systems to consider:

- **Core value systems** — the things that deliver the primary value. Without these, no product.
- **Enabler systems** — things that make core systems work better (auth, data, config)
- **Growth systems** — things that bring users back or bring new users (notifications, sharing, onboarding)
- **Intelligence systems** — things that make the product smarter over time (analytics, learning, personalization)
- **Trust systems** — things that make users feel safe (security, reliability, transparency)

For each system, think about:
- What does this system DO for the user?
- What other systems does it depend on?
- What other systems depend on it?
- How hard is it to build? (S/M/L)
- Is this table stakes or differentiating?

### 2B: Generate the Full Map

Produce **5-8 systems** the product should have. Mix of:
- Systems that already exist (with maturity assessment)
- Systems that are missing but critical
- Systems that don't exist anywhere in the market (novel)
- Systems that should be killed or merged

For each:

```
▸ **[System Name]** — [core|enabler|growth|intelligence|trust]
  does: [what the user gets from this system — one sentence]
  eval: [score] (d:[N] c:[N] v:[N]) — or "no code" if missing
  weakest: [which sub-score drags it down and why — from eval evidence]
  depends on: [other systems]
  enables: [what breaks or is weaker without this]
  market: [table stakes | differentiating | novel]
  size: [S/M/L]
  priority: [1-5] — based on dependency order + value delivery
```

### 2C: The Critical Path

From the systems map, identify the build order:

```
critical path:
  1. [system] — must exist first, everything depends on it
  2. [system] — unlocks the core value moment
  3. [system] — makes value repeatable (return trigger)
  4. [system] — growth/intelligence layer
  ...
```

The critical path answers: **"If you could only build 3 systems, which 3?"**

### 2D: The Missing System

The single most impactful system that doesn't exist yet. This is the primary recommendation.

```
▸ **[Missing System]** — the biggest gap
  why: [what the product can't do without it]
  user story: [walk through the interaction — what does the user experience?]
  changes: [what moves in the product map]
  second-order: [what else improves as a consequence]
  size: [S/M/L] — [N sessions at current velocity]
  kills it: [what would make this system fail]
  evidence: [market data, user behavior, codebase analysis, or "exploring"]
  draft features:
    - [feature 1] — [what it does]
    - [feature 2] — [what it does]
  draft assertions:
    - [testable belief about this system]
    - [another testable belief]
```

### 2E: Two More Ideas

Beyond the missing system, generate 2 more system-level ideas:

- **One ambitious**: a system nobody in this space has. Novel. Might not work. High learning value.
- **One practical**: a system that's table stakes but missing, or an existing system that needs to level up.

Same format as 2D but briefer (skip draft features).

### 2F: The Kill List

Systems or features that should die. Not "defer" — kill. They're consuming attention without delivering value.

```
✗ kill: [system/feature] — [why it should die]
  freed: [what resources/attention this releases]
```

### 2G: Anti-sycophancy Check

After generating, explicitly check:
- Am I recommending what the founder wants to hear?
- Am I avoiding the hard system (the one that's boring but critical)?
- Is the "ambitious" idea actually ambitious, or just shiny?
- Would a stranger looking at this product agree with the systems map?

If biased: flag it. "I may be favoring [X] because [reason]. The unsexy-but-correct answer might be [Y]."

---

## Stage 3: Validate (20% of effort)

Test the riskiest assumption behind the recommended system.

### 3A: Prediction

```
predict: [what I expect to find]
because: [evidence or "unknown territory — exploring"]
wrong if: [specific thing that would disprove this]
```

Log to `.claude/knowledge/predictions.tsv`.

### 3B: Quick Validation

2 minutes max. Use the most appropriate source:

| Assumption type | Source |
|-----------------|--------|
| Library/framework feasibility | context7 (resolve-library-id → query-docs) |
| Market/user behavior | WebSearch (2 queries max) |
| Code feasibility | Grep/Read (trace code path) |
| Visual/UX quality | playwright |
| Competitive gap | WebSearch + playwright |

### 3C: Verdict

```
tested: "[assumption]"
finding: [2-3 sentences]
evidence: [HIGH/MEDIUM/LOW]
verdict: ✓ confirmed | ✗ invalidated | ◐ inconclusive
```

If ✗ → recommendation changes. If ◐ → confidence drops, route to `/research`.

---

## Synthesis: The Discovery Brief

```
── discovery ──────────────────────────────
  recommend: **[system name]**
  type: [core|enabler|growth|intelligence|trust]
  confidence: [HIGH/MEDIUM/LOW] — [why]
  validated: [✓/✗/◐] "[assumption]" ([evidence quality])
  size: [S/M/L] · ~[N] sessions
  critical path position: [N of M]
  thesis: [✓ advances [id] | · no thesis impact]
  bias: [clean | flagged — [what]]
```

---

## Output Format

```
◆ discover — [scope]

  v[X.Y] · product: **[pct]%** · score: [N]
  thesis: "[current thesis]"
  velocity: [N] commits/month

⎯⎯ product ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [one paragraph: what this product is, who it's for, what stage]

  journey: [user path through the product]
  value moment: [where value happens]
  dead ends: [where journey stops]

  [if contradiction]:
  ⚠ [the one contradiction]

⎯⎯ systems ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [the full systems map — 5-8 systems]

  ▸ **[System]** — [type] · [exists?] · [market position] · [S/M/L]
    does: [one sentence]
    depends on: [systems]
    priority: [N]

  [repeat for each system]

  critical path:
    1. [system] — [why first]
    2. [system] — [why second]
    3. [system] — [why third]

  kill:
    ✗ [feature/system] — [why] · frees [what]

⎯⎯ recommend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ▸ **[Missing System]** — [type] · [S/M/L]
    why: [what the product can't do without it]
    user story: [the interaction]
    changes: [what moves]
    second-order: [cascade]
    kills it: [failure mode]
    evidence: [cite]
    draft features:
      · [feature 1]
      · [feature 2]
    draft assertions:
      · [belief 1]
      · [belief 2]

  ▸ **[Ambitious]** — [type] · [S/M/L]
    why: [novel, high learning value]
    kills it: [failure mode]

  ▸ **[Practical]** — [type] · [S/M/L]
    why: [table stakes or level-up]
    kills it: [failure mode]

  bias: [clean | flagged — [what + counter-evidence]]

⎯⎯ validate ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  testing: "[riskiest assumption]"
  finding: [2-3 sentences]
  evidence: [HIGH/MEDIUM/LOW]
  verdict: [✓/✗/◐]

⎯⎯ discovery ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  recommend: **[system]**
  confidence: [level] — [why]
  size: [S/M/L] · ~[N] sessions
  critical path: [position]
  thesis: [advances or not]

  [if past data]:
  track record: [N]→[N built]→[N succeeded]

/go [system]         build the recommendation
/research [topic]    dig deeper before building
/feature new [name]  register it as a feature
```

---

## New Product Mode (`/discover new "idea"`)

When the founder has a product idea but no code yet:

1. **Understand the idea**: ask clarifying questions if needed (AskUserQuestion)
   - Who specifically is this for?
   - What do they do today without this?
   - What's the one thing that makes them try it?

2. **Systems decomposition**: break the idea into 5-8 systems using the categories above

3. **MVP scope**: which 2-3 systems constitute a minimum loveable product?
   - Not minimum viable — minimum LOVEABLE. What's the smallest thing that delights?

4. **Critical path**: build order for the MVP systems

5. **Name the riskiest assumption**: the one thing that, if wrong, means this product shouldn't exist

6. **Validate it**: same as Stage 3

Output adds:
```
⎯⎯ new product ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  idea: "[founder's description]"
  for: [specific person]
  today: [what they do without this]
  hook: [why they'd try it]

  mvp systems (minimum loveable):
    1. [system] — [why essential]
    2. [system] — [why essential]
    3. [system] — [why essential]

  defer to v2:
    · [system] — [why not yet]

  riskiest assumption: [the one that kills it]
```

---

## Systems Audit Mode (`/discover systems`)

Deep audit of what systems exist vs what's needed:

1. Scan the entire codebase — not just rhino.yml features, but actual code structure
2. Map every system (explicit features + implicit infrastructure)
3. Rate each: maturity, weight, market position
4. Identify gaps: systems that SHOULD exist but don't
5. Identify bloat: systems that exist but shouldn't
6. Produce the full systems map + critical path + recommendation

This is the "step back and look at the whole board" mode.

---

## Inversion Mode (`/discover invert`)

**"What would make this product fail?"** → then build the systems to prevent it.

1. Enumerate failure modes (onboarding, retention, competition, tech debt, wrong thesis)
2. Rate: likelihood × defense strength
3. The most vulnerable failure mode → the missing defensive system
4. Ideas become systems that prevent failure

---

## Competitive Mode (`/discover vs`)

1. Spawn **market-analyst agent** to research competitor systems
2. Map their systems vs yours
3. Identify: they have / we have / nobody has
4. Recommend: steal (adapt their system) or leapfrog (build what nobody has)

---

## Artifact Pipeline

### On every session

1. **Append to `~/.claude/evals/discovery-history.tsv`**:
   ```
   date	scope	systems_mapped	recommended	type	size	confidence	validated	built	succeeded	velocity
   ```

2. **Write `~/.claude/evals/reports/discovery-{YYYY-MM-DD}.json`**: full report

3. **Append to `~/.claude/evals/discovery-learnings.md`**: one paragraph on what was learned

4. **Write `~/.claude/cache/last-discovery.yml`**: for /plan integration

---

## Self-Improvement

After every 3rd session: analyze outcomes, detect biases, calibrate. Write adjustments to discovery-learnings.md.

---

## Integrity Checks

| Check | Trigger | Action |
|-------|---------|--------|
| **NO_SYSTEMS** | Produced feature ideas instead of systems | Elevate to system level |
| **ALL_CORE** | No enabler/growth/intelligence systems | Force diversity |
| **NO_KILL** | Nothing killed | Not thinking critically enough |
| **TABLE_STAKES_ONLY** | All systems are table stakes | Where's the differentiation? |
| **NO_NOVEL** | No ambitious/novel system | Force one |
| **SYCOPHANCY** | Recommending what founder worked on last | Flag bias |
| **NO_USER_STORY** | Missing system has no interaction walkthrough | Add one |
| **VELOCITY_MISMATCH** | All systems are L when velocity is low | Break down or phase |

---

## Tools

**Read** — state files, codebase
**Bash** — `rhino score .`, `rhino feature`, `git log`, `curl`
**WebSearch** — market context (3 queries max)
**context7** — library/framework docs
**playwright** — live product analysis
**Grep/Glob** — codebase structure mapping
**Agent (rhino-os:explorer)** — deep codebase analysis, spawn with `Agent(subagent_type: "rhino-os:explorer", ...)`
**Agent (rhino-os:market-analyst)** — competitive systems analysis, spawn with `Agent(subagent_type: "rhino-os:market-analyst", ...)`
Spawn both in parallel for `vs` and `systems` modes. Named agents have persistent memory across sessions.
**AskUserQuestion** — for new product mode clarifications

## What You Never Do

- Spend more time diagnosing than ideating
- Produce feature-level ideas instead of system-level thinking
- Generate >3 system recommendations (1 primary + 2 alternatives)
- Skip the systems map — that's the whole point
- Present equal options — recommend ONE system to build
- Skip the kill list — something always needs to die
- Produce generic systems ("improve UX" is not a system)
- Be sycophantic — the founder needs to hear what's missing, not what's great
- Skip market calibration — systems that are table stakes aren't worth celebrating
- Ignore dependency order — building system C before system A is waste

## If Something Breaks

- No value hypothesis → ask what the product is for (AskUserQuestion)
- No features → perfect for `new` mode — start from scratch
- No codebase → also perfect for `new` mode
- No market data → proceed with codebase-only analysis, note "uncalibrated"
- playwright unavailable → code-only analysis, recommend `/taste`
- All systems exist and are mature → "product is complete for this thesis. Time for `/roadmap bump`."

$ARGUMENTS
