---
description: "Brainstorm possibilities. /ideate generates product ideas. /ideate auth brainstorms for a feature. /ideate wild goes high-risk."
---

# /ideate

Creative divergence. Generate ideas, explore directions, imagine what could be. This is the opposite of /plan — no convergence, no tasks, no commitment. Just possibilities with enough detail to actually evaluate them.

## Innovation Matrix

Every idea lives somewhere on two axes:

```
                    IMPACT ON PRODUCT
                         HIGH
                          |
           Sustaining     |     Disruptive
           Proven tech,   |     New approach,
           big UX lift    |     rewrites the rules
                          |
    LOW ------------------+------------------ HIGH
                          |               NOVELTY
           Incremental    |     Radical
           Small wins,    |     New tech,
           known patterns |     unknown outcome
                          |
                         LOW
```

- **Incremental** (low novelty, low impact): polish, optimization, known patterns applied to known problems. Low risk, low learning.
- **Sustaining** (low novelty, high impact): proven approaches applied where they'd make a big difference. Best ROI.
- **Radical** (high novelty, low impact): new technique or technology, applied to a contained area. High learning.
- **Disruptive** (high novelty, high impact): new approach that changes how the product fundamentally works. High risk, high reward.

Use this matrix to ensure ideation sessions don't cluster in one quadrant.

## Routing

Parse `$ARGUMENTS`:

### No arguments → product-level ideation

Read the current state:
1. `rhino feature` — what features exist, what's their state
2. `~/.claude/knowledge/experiment-learnings.md` — Unknown Territory section
3. `config/rhino.yml` — value hypothesis, user definition
4. Recent git history — what's been built recently
5. Current scores if available (`rhino score .`)

Generate **4 ideas**, one per quadrant.

### Feature name → feature-level ideation
`/ideate auth`, `/ideate scoring`

Focused brainstorm scoped to that feature. Read the feature's assertions, code, pass rate. Generate 4 ideas using the matrix.

### `wild` → high-risk ideation
Moonshot mode. Generate 3 ideas that are all **Disruptive quadrant**:
- Have <30% chance of working
- Would be transformative if they did work
- Are in Unknown Territory (highest information value)

### `[any text]` → constrained ideation
`/ideate "what if we dropped auth entirely"`, `/ideate "mobile-first redesign"`

Take the constraint/prompt and generate 3-4 ideas within that frame. Map each to a quadrant.

## The Idea Brief

Every idea must be a **brief**, not a bullet point. Each contains:

- **What**: 3-5 sentences describing what the user sees and does differently. Walk through the interaction step by step.
- **Why now**: What evidence or current state makes this the right moment? Cite experiment-learnings.md, current scores, recent history.
- **Who benefits**: Name the specific human and their specific situation.
- **What changes**: The measurable difference. What assertion would pass after this ships?
- **What kills it**: The failure mode. Be specific.
- **What you'd learn**: Even if the idea fails, what does the attempt teach you?
- **Assertions** (draft): 2-3 testable beliefs, previewed but NOT committed.

## Output format

```
◆ ideate — [scope or "product"]

  reading: 6 features · score 92 · 3 unknowns in model

▸ **Auto-grade predictions** — sustaining
  what: Session start hook reads predictions.tsv, checks git log for
        outcomes, fills in result/correct automatically. Founder sees
        "3 predictions graded since last session" on boot.
  why now: 16 predictions logged, only 8 graded. Manual grading is
           the bottleneck in the learning loop.
  who: the system itself — compounds over sessions
  changes: learning feature 48→65+ (prediction grading is #1 gap)
  kills it: predictions too vague to grade mechanically
  learns: whether mechanical grading is possible or needs human judgment
  draft assertions:
    - predictions with filled result columns are auto-graded on session start
    - grading accuracy matches human judgment >80% of the time

▸ **Visual score timeline** — incremental
  what: `rhino score .` appends to history.tsv (already does). New
        `/eval timeline` shows a sparkline of last 20 scores inline.
        Founder sees the trajectory, not just the number.
  why now: history.tsv has 1957 entries but no visualization
  who: solo founder checking if changes helped
  changes: scoring feature 58→65+ (trend visualization is PARTIAL)
  kills it: sparklines in terminal look bad at small widths
  learns: whether visual trends change founder behavior

▸ **Lens marketplace** — radical
  what: `rhino lens install github.com/user/lens-name` pulls a lens
        from any git repo. Lenses have a manifest.yml declaring what
        they measure. Community can build domain-specific measurement.
  why now: lens system is 80% of a registry (research confirmed)
  who: developer who wants rhino-os for their specific stack
  changes: install feature — makes rhino-os extensible
  kills it: no community yet. Marketplace without suppliers is empty
  learns: whether the lens abstraction is good enough for external use

▸ **Kill the CLI** — disruptive
  what: Remove bin/ entirely. Everything happens through slash commands.
        Score, eval, taste — all invoked as /eval, /score, not rhino eval.
        The product IS the Claude Code experience, not a CLI wrapper.
  why now: founder said "transform from CLI to within Claude Code"
  who: any Claude Code user — zero install friction
  changes: install feature goes to 100 (nothing to install)
  kills it: loses CI/script integration. Some users need CLI.
  learns: whether Claude Code commands can fully replace a CLI

[Present with AskUserQuestion — which direction interests you?]

/feature new [name]   define the chosen idea
/go [feature]         build it
/research [topic]     validate before building
```

**Formatting rules:**
- Header: `◆ ideate — [scope]`
- Context line: what was read (feature count, score, unknowns)
- Each idea: `▸ **[Name]** — [quadrant]` with brief fields indented
- Brief fields: what/why now/who/changes/kills it/learns/draft assertions
- No more than 5 ideas (paradox of choice)
- AskUserQuestion at the end — which direction?
- Bottom: 2-3 relevant next commands

## What makes good ideation

- **Specific, not generic.** "Add social features" is garbage. Walk through the interaction.
- **Grounded in evidence.** Cite experiment-learnings.md, scores, git history.
- **Includes the failure mode.** Every idea must include why it might not work.
- **Generates assertions.** An idea that can't be expressed as a testable belief isn't concrete enough.
- **Covers the matrix.** If all ideas cluster in one quadrant, push into the others.

## Tools to use

**Use AskUserQuestion** for every decision point. Ideation is collaborative.

**Use WebSearch** when an idea needs external validation.

**Use Read** to check codebase state before proposing changes.

## What you never do
- Converge too early — this is divergence time, not planning
- Write code — ideation produces assertions and directions, not implementations
- Skip the failure mode — every idea must include why it might not work
- Generate thin ideas — a sentence is not an idea, a brief is an idea
- Cluster in one quadrant — spread across the innovation matrix
- Generate more than 5 ideas — paradox of choice kills momentum

## If something breaks
- No features defined: ideate at the product level, suggest `/feature new [name]`
- No experiment-learnings.md: ideate from codebase and config/rhino.yml only
- AskUserQuestion not available: present ideas as numbered list, ask for selection

$ARGUMENTS
