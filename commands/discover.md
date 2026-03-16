---
name: discover
description: "Product discovery intelligence. Diagnose gaps, generate ideas, validate assumptions — one pass. Parallel agents, live product analysis, counterfactual reasoning, self-improving memory. /discover runs full. /discover auth scopes to a feature. /discover wild for moonshots. /discover vs for competitive."
---

# /discover — Product Discovery Intelligence

One-pass product discovery. Diagnose → ideate → validate in a single session.

**This is not a template executor.** You are doing product discovery the way a cofounder with perfect memory and zero ego does it. You remember every past recommendation and whether it worked. You look at the actual product, not just the code. You tell the founder when nothing is worth building. You catch your own biases.

**What makes this skill intelligent:**
- **Parallel agents** — explorer + market-analyst run simultaneously during diagnosis
- **Live product analysis** — playwright sees the actual product, not just code
- **Counterfactual reasoning** — "what happens if we build nothing?" is always evaluated
- **Causal chains** — traces WHY each gap exists, not just WHAT it is
- **Contradiction detection** — finds where the product says one thing but does another
- **Velocity calibration** — sizes ideas to the team's actual shipping speed
- **Anti-sycophancy** — explicit mechanisms prevent just telling the founder what they want to hear
- **Self-improving memory** — tracks recommendation outcomes and adjusts biases over time

## When to use this vs individual commands

| Command | When |
|---------|------|
| `/discover` | Starting point. What's wrong, what to build, is it worth it? |
| `/product` | Deep product audit — all 7 lenses, no ideas |
| `/ideate` | Direction is clear, you just need build ideas |
| `/research` | Known specific unknown, just need data |
| `/strategy` | Strategic positioning, stage diagnosis |

`/discover` is the default session opener. When the founder says "what should we work on?" — run this, not `/plan`. `/plan` turns decisions into tasks. `/discover` makes the decision.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) | Full discovery — product-level |
| Feature name | Scoped discovery for one feature |
| `wild` | Moonshot — riskier ideas, bigger unknowns, <30% confidence |
| `vs` | Competitive discovery — diagnose gaps relative to a competitor |
| `invert` | Inversion mode — "what would make this product fail?" then defend against it |
| `[any text]` | Constrained discovery around a topic or question |

---

## Phase 0: Intelligence Gathering (parallel)

Before diagnosing, build the full picture. Launch these SIMULTANEOUSLY:

### Thread A: Load Memory + State

Read in parallel:

1. `~/.claude/evals/discovery-history.tsv` — past recommendations and outcomes
2. `~/.claude/evals/discovery-learnings.md` — accumulated discovery intelligence
3. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known patterns, unknowns, dead ends
4. `~/.claude/cache/last-retro.yml` — recent retro findings (if exists)
5. `.claude/plans/strategy.yml` — current bottleneck from /strategy (if exists)
6. `config/rhino.yml` — value hypothesis, user, features
7. `.claude/plans/roadmap.yml` — current thesis and unproven evidence
8. `.claude/plans/todos.yml` — backlog items
9. `git log --oneline -30` — recent work (30 commits — need velocity data)
10. `git log --oneline --since="30 days ago" | wc -l` — shipping velocity (commits/month)

Compute:
- Product map (maturity × weight), product completion %, bottleneck
- Shipping velocity: commits in last 30 days → ideas must be sized to this
- Evidence decay: any "tested" assumption >30 days old decays to "anecdotal"

### Thread B: Live Product Analysis (when dev server is running)

If playwright is available AND a dev server is running (check `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` or similar):

1. `browser_navigate` to the product
2. `browser_snapshot` — capture DOM structure
3. `browser_take_screenshot` — see what the user sees
4. Navigate to 2-3 key routes (from nav links)
5. Note: what's the first thing a new user sees? Where do they get stuck? What's broken?

This gives you REAL product data for diagnosis, not just code analysis. If you can see the product, your diagnosis is grounded in experience, not inference.

If no dev server: note "diagnosis from code only — recommend `/taste` for visual analysis" and proceed.

### Thread C: Market Context (1 query max)

1. Read `~/.claude/evals/taste-market.json` (reuse if <7 days old)
2. Read `~/.claude/cache/market-context.json` (from market-analyst, reuse if <7 days old)
3. If both stale: WebSearch for `"best [category from rhino.yml] tools 2026"` (ONE query)
4. Extract: what do top products in this space do? What's table stakes? What's nobody doing?

**You are now calibrated to THIS market. Ideas that are "innovative" in a vacuum but table stakes in the market get flagged.**

### Thread D: Backfill Past Discoveries

If `discovery-history.tsv` exists:

1. For each row where `built` is empty:
   - `git log --all --oneline --grep="[recommended idea name]"` — committed?
   - If yes → `built=yes`, check `rhino feature [name]` pass rate → `succeeded=yes/no/partial`
   - If no and >7 days old → `built=no`
2. Compute track record: `built / total` and `succeeded / built`
3. Identify:
   - Which quadrants produce ideas that get built?
   - Which gap types produce ideas that succeed?
   - Is confidence calibration accurate? (do HIGH confidence ideas actually succeed more?)
   - What's the recurring gap? (appears in 3+ discoveries)

**Self-diagnosis flags** (shown in output if triggered):
- Track record <30% built → "ideas may be too ambitious or misaligned with priorities"
- Built >50% but succeeded <30% → "diagnosis may be off — ideas get built but don't work"
- Confidence uncalibrated → "HIGH confidence ideas don't succeed more than LOW — adjusting"

---

## Stage 1: Diagnose

Not "what's wrong?" but "WHY is it wrong, and what's the cost of leaving it?"

### 1A: Contradiction Detection (always first)

Before lens analysis, scan for contradictions — places where the product says one thing but does another:

- **Value vs features**: Does the value hypothesis name something the features don't deliver?
- **User vs product**: Does the user definition describe someone the product doesn't serve?
- **Thesis vs work**: Does the roadmap thesis claim something the recent git history doesn't pursue?
- **Weight vs effort**: Are high-weight features getting less attention than low-weight ones?
- **Assertions vs code**: Are passing assertions testing real value, or just structural presence?

Each contradiction is a gap candidate. Contradictions are higher priority than weaknesses because they indicate confusion about direction, not just incomplete work.

### 1B: Three Lenses (two mandatory, one adaptive)

#### Always: Assumptions (risk audit with causal tracing)

Extract assumptions, but also trace WHY each exists:

```
assumption: "[Users want X]"
risk: 4  evidence: none
because: "value hypothesis states X, but no user has confirmed it"
if wrong: "features A, B, C are all wasted — they only make sense if users want X"
causal chain: hypothesis → feature A → assertions 1-5 → all invalidated
```

Rank by **risk × ignorance** (same formula: risk 1-5, ignorance none=4/anecdotal=3/tested=2/proven=1).

**Evidence decay**: any "tested" evidence older than 30 days automatically decays to "anecdotal". Markets move. What was true last month might not be true now.

**Dead end filter**: cross-reference against Dead Ends in experiment-learnings.md. Assumptions depending on dead ends → flagged immediately.

Surface top 3. Each gets the full causal chain, not just a label.

#### Always: Focus (kill exercise with opportunity cost)

For every feature, not just keep/defer/kill but the COST of each:

```
✓ keep: scoring (w:5) — core value delivery
  opportunity cost: 0 — must exist
· defer: docs (w:3) — users don't read docs at this stage
  freed: ~2 sessions of work → redirect to bottleneck
✗ kill: [feature] — orphaned, no assertions, depends on dead end
  freed: ~1 session + reduced cognitive load
```

Compute total opportunity cost of dead weight. "You're spending [N] sessions worth of attention on features that don't serve the thesis."

#### Adaptive: Pick one more

| Condition | Lens | Why |
|-----------|------|-----|
| Product completion <50% | **Who** (user journey) | Building for the wrong person? |
| >30% signals unmeasured | **Signals** | Flying blind on value |
| Product completion >70% | **Delight** | Core works, craft matters |
| Value hypothesis empty/changed | **Pitch** | Can't pitch it = not clear |
| Recurring gap (3+ discoveries) | **[That gap's lens]** | Structural, not tactical |
| Playwright saw real problems | **UX** (from live analysis) | Actual user experience gaps |

Each lens: 3-5 lines max. Surface gaps, don't elaborate.

### 1C: The Counterfactual (always)

Before generating ideas, answer: **"What happens if we build nothing for the next 2 weeks?"**

- Does the product get worse? (competitors move, users churn, thesis expires)
- Does it stay the same? (stable but stagnant — maybe that's fine)
- Does it actually get better? (users adopt what's already there, feedback comes in)

If the counterfactual is "nothing bad happens" — that changes the recommendation. Maybe the right move IS to wait, observe, and gather data instead of building.

State the counterfactual explicitly in the output. This is the anti-sycophancy mechanism — it prevents the skill from always recommending action.

### 1D: Gap Synthesis

Synthesize contradictions + lenses + counterfactual into exactly 3 ranked gaps:

```
gaps:
  1. [most dangerous — highest risk × ignorance, or contradiction, or recurring structural]
  2. [highest leverage — gap in bottleneck or its dependencies]
  3. [highest learning — gap in unknown territory]

counterfactual: [what happens if we build nothing]
```

---

## Stage 2: Ideate

Generate **3 ideas** from the gaps. But first, check if you should generate ideas at all.

### 2A: Should We Build?

Three conditions that produce a "build nothing" recommendation:

1. **Counterfactual says wait**: "nothing bad happens if we wait" + no urgent thesis deadline
2. **All gaps are research gaps**: every gap needs data, not code — route to `/research`
3. **Past discoveries show pattern of unbuilt ideas**: track record <20% built → "we keep generating ideas but not building them — the problem isn't ideas, it's execution"

If any of these trigger, skip Stage 2 and 3. Go directly to the discovery brief with "build nothing" recommendation and the reason.

### 2B: Pre-ideation Filters

1. **Dead end filter**: touches Dead End → killed
2. **Backlog dedup**: already in todos.yml → promote instead of generating
3. **Past discovery dedup**: recommended before → check outcome. Not built → note why. Failed → don't retry unless failure mode changed. Succeeded → build on it.
4. **Thesis alignment**: at least 1 idea MUST advance an unproven thesis evidence item
5. **Velocity check**: read shipping velocity from Phase 0. An idea requiring 50 files of changes when the team ships 10 commits/month → too big. Break it down or flag as multi-session.

### 2C: Idea Generation

**3 ideas**, constrained:

- Each addresses a specific gap from Stage 1 (cite gap #N)
- At least 1 targets the bottleneck feature or dependencies
- At least 1 advances an unproven thesis evidence item (tag: `advances: [evidence_id]`)
- At least 1 targets Unknown Territory from experiment-learnings.md
- Spread across innovation matrix — no clustering
- If `wild`: all 3 Disruptive, <30% confidence
- If `vs`: at least 1 "stolen" from competitor
- If `invert`: ideas are defenses against the failure modes identified

**Velocity-sized**: each idea includes estimated scope (S/M/L) based on shipping velocity:
- S = 1-3 commits, ~1 session
- M = 4-10 commits, ~2-3 sessions
- L = 10+ commits, ~week+ — flag if velocity doesn't support this

**Second-order effects**: for each idea, state not just what changes but what ELSE changes as a result:
```
first-order: scoring feature moves building → working
second-order: /plan becomes more useful (reads scores), /go can auto-measure
```

### The Idea Brief (7 fields)

```
▸ **[Name]** — [quadrant] · gap #[N] · size: [S/M/L]
  what: 2-3 sentences. Step-by-step interaction change.
  changes: [feature] [maturity] → [next], [measurable difference]
  second-order: [what else changes as a consequence]
  kills it: [specific failure mode]
  evidence: [cite experiment-learnings, past discovery, or "unknown territory"]
  if wrong: [what you learn even if it fails]
  draft assertions: 1-2 testable beliefs [type: file_check/content_check/llm_judge/etc.]
```

### 2D: Idea Quality Gate

Score each against these. Failing 2+ → replace:

| Criterion | Pass | Fail |
|-----------|------|------|
| Specific | Walks through interaction | "Improve [thing]" |
| Grounded | Cites evidence or declares exploration | "I think this will work" |
| Killable | Concrete failure mode | "It might not work" |
| Measurable | Assertions are evaluable | Vague feelings |
| Not dead end | Doesn't touch Dead Ends | Retries known failures |
| Not duplicate | Not in todos/past discoveries | Already captured |
| Velocity-fit | Size matches shipping velocity | Would take 3x the team's velocity |
| Not table stakes | Market calibration says this is actually novel | Competitor already has it |

### 2E: Anti-sycophancy Check

After generating, explicitly ask: "Am I recommending this because the evidence supports it, or because the founder will like hearing it?"

Signals you're being sycophantic:
- The idea sounds like what the founder worked on last session (confirmation bias)
- The idea avoids the thing the founder clearly doesn't want to work on (avoidance bias)
- You're framing a mediocre idea with enthusiastic language
- The "kills it" field is soft ("might not resonate" instead of "depends on unproven assumption X")

If caught: note it in the output. "Bias check: I may be favoring [idea] because [reason]. Counter-evidence: [what argues against it]."

### 2F: The Riskiest Assumption

Identify the single assumption that, if wrong, invalidates the recommended idea.

"The recommended idea depends on [assumption]. If wrong: [consequence]. Evidence quality: [HIGH/MEDIUM/LOW]."

This feeds Stage 3.

---

## Stage 3: Validate

Test the riskiest assumption inline. This is the step that turns /discover from "brainstorming session" into "intelligence briefing."

### 3A: Prediction

```
predict: [what I expect to find]
because: [evidence or "unknown territory — exploring"]
wrong if: [specific thing that would disprove this]
```

Log to `.claude/knowledge/predictions.tsv`.

### 3B: Multi-source Validation

Use the most appropriate source. One primary, one secondary max:

| Assumption type | Primary | Secondary |
|-----------------|---------|-----------|
| Library/framework feasibility | context7 (resolve-library-id → query-docs) | Codebase (Grep) |
| Market/user behavior | WebSearch (2 queries max) | experiment-learnings |
| Code feasibility | Grep/Read (trace code path) | context7 |
| Visual/UX quality | playwright (live analysis) | WebSearch |
| Competitive gap | WebSearch | playwright |
| "Can this be built in [S/M/L]?" | Codebase trace + git log | context7 for library complexity |

**New in 2026: Code feasibility validation is real.** If the assumption is "we can add X to the codebase," actually trace the code path. Read the relevant files. Check if the abstraction supports it. Don't just say "probably" — look.

### 3C: Evidence Quality Scoring

- **HIGH** (mechanical): code path traced, docs confirm, measurable fact verified
- **MEDIUM** (directional): blog posts agree, patterns suggest, partial code trace
- **LOW** (anecdotal): one source, opinion-based, no code verification

**Evidence → confidence mapping:**
- HIGH evidence + passes validation → HIGH confidence recommendation
- MEDIUM evidence + passes validation → MEDIUM confidence
- LOW evidence → MEDIUM confidence max, regardless of outcome
- First discovery session → MEDIUM confidence max (no history to calibrate against)

### 3D: Time Limit

2 minutes max. If it needs more:
- Note "needs deep research"
- Route to `/research [topic]` at the bottom
- Do NOT delay the recommendation — recommend with the confidence you have

### 3E: Output

```
tested: "[assumption]"
predict: [what I expected]
finding: [2-3 sentences of what I actually found]
evidence: [HIGH/MEDIUM/LOW] — [what backs this up]
verdict: ✓ confirmed | ✗ invalidated | ◐ inconclusive
```

If ✗ → the recommended idea changes. If ◐ → confidence drops. If ✓ → confidence holds or rises.

Update experiment-learnings.md if the finding is new.

---

## Synthesis: The Discovery Brief

### Recommendation Logic

1. **Validation ✓** → recommend the validated idea
2. **Validation ✗** → recommend next-best idea, note why primary was killed
3. **Validation ◐** → recommend with MEDIUM confidence, route to `/research`
4. **"Build nothing" triggered in 2A** → recommend waiting, with the trigger reason
5. **All ideas killed** → recommend "explore unknown territory" — the only productive direction is learning

### The Brief

```
── discovery ──────────────────────────────
  recommend: **[idea name]** [or "build nothing — [why]" or "explore — [what]"]
  confidence: [HIGH/MEDIUM/LOW] — [calibration reason]
  validated: [✓/✗/◐] "[assumption]" ([evidence quality])
  moves: [feature] [current] → [next maturity]
  second-order: [what else improves]
  risk: [remaining killer]
  size: [S/M/L] — [N sessions at current velocity]
  thesis: [✓ advances [evidence_id] | · no thesis impact]
  counterfactual: [cost of NOT building this]
  bias check: [clean | flagged — [what bias was detected]]
```

---

## Output Format

```
◆ discover — [scope]

  v[X.Y]: **[pct]%** · product: **[pct]%** · score: [N]
  thesis: "[current thesis]"
  bottleneck: **[name]** ([maturity], w:[N])
  velocity: [N] commits/month · past discoveries: [N→N built→N succeeded]

⎯⎯ diagnose ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [if contradictions found]:
  ⚠ contradiction: [value hypothesis says X but features do Y]

  ▾ assumptions
    · [assumption 1] — risk:[N] evidence:[level] ([age if decayed])
      chain: [what breaks if wrong]
    · [assumption 2] — risk:[N] evidence:[level]
      chain: [what breaks]
    · [assumption 3] — risk:[N] evidence:[level]
      chain: [what breaks]

  ▾ focus
    ✓ keep: [features] — [why]
    · defer: [features] — frees [N sessions]
    ✗ kill: [features] — frees [N sessions], [why dead]

  ▾ [adaptive lens]
    [3-5 lines]

  [if live product analysis]:
  ▾ seen (playwright)
    [what a real user would experience — grounded in screenshots/DOM]

  gaps:
    1. [most dangerous — with causal chain]
    2. [highest leverage — with bottleneck connection]
    3. [highest learning — with unknown territory cite]

  counterfactual: [what happens if we build nothing for 2 weeks]

  [if recurring]:
  ⚠ recurring: "[gap]" × [N] discoveries — structural

⎯⎯ ideate ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [if "build nothing" triggered]:
  · build nothing — [reason]. Instead: [what to do — wait/research/observe]
  [skip to discovery brief]

  [if backlog promoted]:
  ▸ promoted: [todo-id]: [title]

  ▸ **[Idea 1]** — [quadrant] · gap #[N] · [S/M/L]
    what: [2-3 sentences]
    changes: [feature] [maturity] → [next]
    second-order: [what else improves]
    kills it: [failure mode]
    evidence: [cite]
    if wrong: [what you learn]
    draft assertions: [1-2 beliefs]

  ▸ **[Idea 2]** — [quadrant] · gap #[N] · [S/M/L]
    [same fields]

  ▸ **[Idea 3]** — [quadrant] · gap #[N] · [S/M/L]
    [same fields]

  [killed ideas]:
  ✗ killed: [name] — [dead end | duplicate | past failure | table stakes]

  [bias check]:
  · bias: [clean | flagged — [what was detected + counter-evidence]]

⎯⎯ validate ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  testing: "[riskiest assumption]"
  predict: [expected]
  wrong if: [disproof condition]
  source: [tools used]

  · [finding — 2-3 sentences]

  evidence: [HIGH/MEDIUM/LOW]
  verdict: [✓/✗/◐] — [one line]
  model: [experiment-learnings.md update]

⎯⎯ discovery ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  recommend: **[idea name]**
  confidence: [HIGH/MEDIUM/LOW] — [why]
  validated: [✓/✗/◐] "[assumption]" ([evidence quality])
  moves: [feature] [current] → [next maturity]
  second-order: [cascade effects]
  risk: [remaining killer]
  size: [S/M/L] · ~[N] sessions at current velocity
  thesis: [✓ advances [id] | · no thesis impact]
  counterfactual: [cost of not building]
  bias: [clean | flagged]

  [if past data]:
  track record: [N]→[N] built→[N] succeeded ([pct]%)
  [if self-diagnosis flagged]:
  ⚠ [self-diagnosis message]

/go [idea]           build the recommendation
/research [topic]    dig deeper before building
/product             full 7-lens audit
```

---

## Inversion Mode (`/discover invert`)

Instead of "what should we build?", ask: **"What would make this product fail?"**

1. Enumerate failure modes:
   - User never gets value (onboarding failure)
   - User gets value once but never returns (no retention trigger)
   - Competitor ships the same thing better (differentiation failure)
   - Technical debt makes the product unmaintainable (foundation failure)
   - The thesis is wrong (strategic failure)

2. For each: rate likelihood (1-5) and current defense strength (none/weak/strong)

3. The gap list becomes "highest-likelihood, weakest-defense failure modes"

4. Ideas become defensive: "build [X] to prevent [failure mode]"

This produces fundamentally different ideas than forward-looking discovery. Use it when forward discovery keeps producing incremental ideas, or when the product feels fragile.

```
◆ discover invert — [scope]

  ...header...

⎯⎯ failure modes ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  · [failure 1] — likelihood:[N] defense:[none/weak/strong]
    how it kills: [mechanism]
  · [failure 2] — likelihood:[N] defense:[none/weak/strong]
    how it kills: [mechanism]

  most vulnerable: [failure mode with highest likelihood × weakest defense]

⎯⎯ defend ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [3 defensive ideas, same brief format]

  ...validate + discovery brief as normal...
```

---

## Competitive Discovery (`/discover vs`)

1. Spawn **market-analyst agent** (background) to research the competitor:
   - WebSearch for features, pricing, reviews
   - playwright to snapshot their product (if public URL)
   - Build competitive gap analysis

2. While market-analyst runs, do normal Stage 1 diagnosis

3. When market-analyst returns, inject competitive gaps into the gap list:
   - "They have [X] and we don't" → gap candidate
   - "We have [X] and they don't" → defensible advantage, don't waste effort here
   - "Nobody has [X]" → opportunity

4. Stage 2 ideation: at least 1 idea is "stolen" from their approach, adapted to this product

Output adds:
```
  ▾ competitive gap
    they have: [list]
    we have: [list]
    nobody has: [list]
    steal: [specific thing worth adapting + how to adapt it]
```

---

## Artifact Pipeline

### On every discovery session

1. **Append to `~/.claude/evals/discovery-history.tsv`** (create with header if missing):
   ```
   date	scope	gaps	recommended	quadrant	size	confidence	evidence_quality	validated	built	succeeded	velocity
   ```
   `built` and `succeeded` start empty — backfilled by future sessions.

2. **Write `~/.claude/evals/reports/discovery-{YYYY-MM-DD}.json`**:
   Full structured report including diagnosis, ideas, validation, recommendation, meta (velocity, contradictions, bias checks, counterfactual, past discovery backfill results).

3. **Append to `~/.claude/evals/discovery-learnings.md`**:
   ```markdown
   ## <date> — <scope>

   **Recommended**: <idea> (<quadrant>, <size>, confidence: <level>)
   **Validated**: <✓/✗/◐> "<assumption>" (evidence: <quality>)
   **Gaps**: <3 gaps>
   **Contradictions**: <any found, or "none">
   **Counterfactual**: <what happens if we don't build>
   **Recurring**: <gaps that appeared before>
   **Bias check**: <clean or flagged>
   **Velocity**: <N commits/month, idea sized [S/M/L]>
   **Learning**: <one sentence — what this teaches about this product's discovery patterns>
   ```

4. **Write `~/.claude/cache/last-discovery.yml`** for /plan integration:
   ```yaml
   date: YYYY-MM-DD
   scope: [scope]
   gaps: [list]
   contradictions: [list or empty]
   counterfactual: [summary]
   recommended_idea: [name]
   confidence: [level]
   size: [S/M/L]
   validation:
     assumption: [text]
     result: [✓/✗/◐]
     evidence_quality: [HIGH/MEDIUM/LOW]
   suggested_tasks:
     - [task for /plan]
   suggested_assertions:
     - [belief for beliefs.yml]
   model_updates:
     - section: [Known|Uncertain|Unknown|Dead Ends]
       entry: [what changed]
   ```

---

## Self-Improvement Protocol

After every 3rd discovery session:

1. **Outcome analysis** from discovery-history.tsv:
   - Built rate by quadrant: "sustaining ideas get built 80%, radical ideas 20%"
   - Success rate by gap type: "assumption-gap ideas succeed 60%, focus-gap ideas succeed 30%"
   - Confidence calibration: "HIGH confidence → 70% success, MEDIUM → 40%, LOW → 20%"
   - Size accuracy: "S ideas ship in 1 session 80% of the time, M ideas take 2x estimated"
   - Velocity tracking: "shipping speed increased from 15 to 22 commits/month over 5 sessions"

2. **Bias detection**:
   - Do recommendations cluster in one quadrant? (should spread)
   - Do contradictions keep getting ignored? (should be addressed)
   - Is counterfactual ever "build nothing"? (if never, sycophancy suspected)
   - Are killed ideas ever the right call? (if ideas never get killed, filters are too soft)

3. **Calibration adjustments** (written to discovery-learnings.md):
   ```
   ## Calibration update — <date>

   Built rate: [N]% (sustaining:[N]% radical:[N]% incremental:[N]% disruptive:[N]%)
   Success rate: [N]% of built (assumption-gap:[N]% focus-gap:[N]% journey-gap:[N]%)
   Confidence accuracy: HIGH=[N]% MEDIUM=[N]% LOW=[N]%
   Size accuracy: S=[N]% on-time M=[N]% L=[N]%

   Adjustments for next session:
   - [specific bias to correct]
   - [quadrant to favor/avoid based on data]
   - [confidence threshold to adjust]
   ```

---

## Integrity Checks

Apply after generating ideas, before presenting:

| Check | Trigger | Action |
|-------|---------|--------|
| **SAFE_IDEAS** | All 3 Incremental/Sustaining | Force 1 into Radical/Disruptive |
| **DEAD_END** | Touches Dead End | Kill + explain |
| **DUPLICATE** | In todos/past discoveries | Promote existing |
| **PAST_FAILURE** | Built before + failed | Kill unless failure mode changed |
| **THESIS_BLIND** | No idea advances thesis | Force-generate one |
| **BOTTLENECK_BLIND** | No idea targets bottleneck | Force-generate one |
| **GENERIC** | "Improve X" without interaction walkthrough | Replace |
| **NO_KILL** | Nothing filtered | Not critical enough — re-examine |
| **RECURRING_IGNORE** | Recurring gap not addressed | Address or explain |
| **TABLE_STAKES** | Market already has it | Flag — not novel |
| **VELOCITY_MISMATCH** | All ideas are L when velocity is low | Downsize or break apart |
| **SYCOPHANCY** | Idea matches founder's last session's work | Flag bias |
| **CONTRADICTION_DODGE** | Contradictions found but ideas avoid them | Address the contradiction |

---

## Materializing the Recommendation

When the founder says "go" or picks:

1. **Feature to `config/rhino.yml`** (if new): delivers, for, code (Glob scan), status: active, weight, maturity: planned, depends_on, origin: discover
2. **Assertions to `lens/product/eval/beliefs.yml`**: auto-detect type, severity: warn
3. **Baseline**: `rhino eval . --feature [name] --fresh`
4. **Prediction**: `.claude/knowledge/predictions.tsv`
5. **Discovery artifact**: `~/.claude/cache/last-discovery.yml`
6. **Output**: `/feature new` template + "planted N assertions from discovery"

---

## Tools

**Read** — all state files
**Bash** — `rhino score .`, `rhino feature`, `git log`, `curl` (dev server check)
**WebSearch** — market calibration + assumption validation (3 queries max total)
**context7** — library/framework docs (resolve-library-id → query-docs)
**playwright** — live product analysis (navigate, snapshot, screenshot, evaluate)
**Grep/Glob** — codebase feasibility tracing
**Agent (explorer)** — deep codebase analysis when code feasibility needs tracing
**Agent (market-analyst)** — competitive analysis in /discover vs mode
**AskUserQuestion** — after discovery brief only

## What You Never Do

- Run all 7 product lenses — pick 3
- Generate >3 ideas
- Spend >2 minutes validating — flag for /research
- Present equal options — recommend ONE
- Skip validation
- Skip memory read/write
- Retry dead ends
- Produce generic ideas
- Report HIGH confidence without history + evidence + validation
- Skip backfill
- Recommend without evidence or exploration declaration
- Ignore recurring gaps (3+ appearances = structural)
- Ignore contradictions — they're the most important signal
- Skip the counterfactual — "build nothing" is always a valid recommendation
- Be sycophantic — catch yourself, flag it, present counter-evidence

## If Something Breaks

- No value hypothesis → "Write `value.hypothesis` in rhino.yml first."
- No features → "Run `/feature new [name]` first."
- No experiment-learnings.md → skip dead end filter, research from scratch
- No past discoveries → first session, establish baseline, MEDIUM confidence max
- WebSearch/context7 fails → codebase-only validation, note "uncalibrated"
- playwright unavailable → code-only diagnosis, recommend `/taste`
- No dev server → skip live analysis, proceed from code
- All ideas killed → "all obvious directions are exhausted. Explore unknown territory."
- All ideas validated away → "nothing worth building now. Here's what would change the answer."
- Founder picks idea the skill flagged as biased → note the flag, proceed anyway — founder overrides

$ARGUMENTS
