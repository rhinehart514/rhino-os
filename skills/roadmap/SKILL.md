---
name: roadmap
description: "Version roadmap + external narrative. /roadmap shows progress. /roadmap next diagnoses what's most provable. /roadmap bump auto-synthesizes. /roadmap narrative generates marketing copy from proven evidence. /roadmap v7.0 shows what a version taught."
argument-hint: "[next|bump|ideate|narrative|changelog|positioning|add|done|new|v<X.Y>]"
allowed-tools: Read, Bash, Grep, Edit, AskUserQuestion, WebSearch, Agent
---

# /roadmap

Two jobs. One command.

**Internal**: Versions are theses, not releases. Each one asks a question. You test it. It's proven, disproven, or abandoned. Future versions emerge from what you learn, not what you imagine.

**External**: Every proven thesis is a story worth telling. The roadmap is the source of truth for marketing copy, changelogs, positioning, and the "why now" narrative. When you prove something, the roadmap generates the words to tell the world.

Most dev tools treat marketing as separate from development. That's how you get copy that doesn't match the product. Here, the external narrative is *derived from evidence* — you can't claim what you haven't proven.

You're not a project manager. You're a cofounder looking at the arc of the project and the story it tells.

## Mode awareness

Read `project.mode` from `config/rhino.yml`:
- **build mode** (default): no shipping pressure. Focus on learning, testing, exploring. The roadmap is a lab notebook, not a release schedule.
- **ship mode**: full pipeline. Shipping language, deadlines, deploy verification.

## State to read (parallel)

Every route reads these first:
1. `.claude/plans/roadmap.yml` — theses, evidence, version history
2. `config/rhino.yml` — features (maturity/weight/depends_on), mode, value hypothesis
3. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — predictions mentioning the thesis or current version
4. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known/uncertain/unknown/dead patterns
5. `git log --oneline -20` — recent work (commit timestamps for velocity)
6. `.claude/plans/strategy.yml` — bottleneck, stage
7. `.claude/cache/eval-cache.json` — per-feature sub-scores + deltas
8. `.claude/cache/narrative.yml` — current external narrative (if exists)
9. `.claude/cache/market-context.json` — competitive landscape (if exists)
10. `.claude/cache/positioning.yml` — current positioning (if exists)

For the full state source list, see [STATE_MANIFEST.md](../STATE_MANIFEST.md).

**Narrative routes** (`narrative`, `changelog`, `positioning`) also read:
- All proven version entries for evidence tracing
- README.md — check if current narrative matches what's written
- `.claude/cache/changelog.md` — previous changelog output

## The Reflection (always comes first)

Before showing the version list, write 2-3 sentences of honest reflection. NOT vibes — synthesize from specific data:

| Dimension | Data source | What to say |
|-----------|-------------|-------------|
| **Velocity** | Git log timestamps + evidence status changes | "Evidence items are proving at N per week" or "Nothing has moved in N days" |
| **Learning** | predictions.tsv accuracy on thesis-related predictions | "Thesis-related predictions are N% accurate — we [understand/don't understand] the space" |
| **Honesty** | Compare evidence `status` against actual state | Are any items marked `partial` that should be `todo`? Any `proven` without real evidence? |
| **Shape** | Cross-version pattern | What recurring themes across versions? What keeps being hard? |

Should feel like thinking out loud, not reporting. But grounded in numbers.

## Routing

Parse `$ARGUMENTS`:

**If $ARGUMENTS is ambiguous:**
1. Exact route keyword match wins (`next`, `bump`, `ideate`, `narrative`, `changelog`, `positioning`, `add`, `done`, `new`)
2. Version string match (e.g., `v8.0` → show that version's thesis and what it taught)
3. Free-form topic (treat as thesis-level discussion)
Never ask "did you mean?" — just act.

### No arguments → reflection + roadmap
Write reflection, show version list, one forward-looking thought.

### `next` → diagnose what's most provable

Not a list — a diagnosis. For each evidence item in the current version:

1. **Map evidence to features.** Which rhino.yml features, if matured, would prove this evidence item? Check `delivers:` text against evidence `question:` text. A `working`+ feature with matching scope = strong evidence.

2. **Score provability.** For each `todo` or `partial` evidence item:
   - Which features relate to it? What's their maturity?
   - Are there predictions about it? What do they say?
   - Is the bottleneck blocking it?
   - Estimate: `ready` (features working, just needs validation), `close` (features building, one session away), `blocked` (depends on something at `planned`), `unknown` (no related features or data)

3. **Recommend the first experiment.** The most provable evidence item = the one with the most supporting feature maturity and the fewest blockers. Suggest a concrete action: "Run /go on [feature] and check if [evidence question] is answered."

### `ideate` → brainstorm future theses (WHERE the project goes)

Theses come from four sources — check all of them:

1. **Proven evidence patterns.** What did the last 2-3 versions prove? What's the trajectory? If v6=identity, v7=measurement, v8=external validation → what's the natural next question?

2. **Dead ends that reveal the real question.** Read Dead Ends in experiment-learnings.md. A dead end often points to the actual question that SHOULD be asked. "Auto-grading doesn't work" → thesis might be "manual human judgment is irreplaceable in learning loops."

3. **Unknown Territory entries.** Each unknown is a candidate thesis. The ones with highest information value (would change the most downstream decisions if answered) are the best theses.

4. **The gap between proven and aspirational.** What does the value hypothesis in rhino.yml claim? What has actually been proven? The gap = the next thesis.

Generate 3-4 candidate theses. Each one must have:
- The question it asks (one sentence)
- Why it matters NOW (what evidence led here)
- 2-3 evidence items that would prove/disprove it
- What we'd learn if it's WRONG (the disproven value)

Present with AskUserQuestion.

### `narrative` → generate the external story

The narrative is derived from proven evidence — never from aspirations. This is the copy that goes in READMEs, landing pages, tweets, and pitch decks.

**Steps:**
1. Read all proven versions from roadmap.yml
2. Read the current version's proven evidence items
3. Read the value hypothesis from rhino.yml
4. Read experiment-learnings.md Known Patterns (these are the defensible claims)

**Generate three artifacts:**

**One-liner** (README header, tweet, elevator pitch):
- Formula: [Who it's for] + [what changes for them] + [why it's different]
- Must reference a proven thesis, not an aspiration
- Anti-slop: no "streamline your workflow," "supercharge your development," "AI-powered"

**Paragraph** (README intro, landing page hero):
- 3-4 sentences. What it is → who it's for → what's different → proof
- Every claim must trace to a proven evidence item or Known Pattern
- Include one specific number or result (e.g., "tested on 2 external projects")

**Positioning statement** (internal, for consistency):
- For [target user] who [job to be done], [product] is a [category] that [key differentiator]. Unlike [alternatives], [product] [unique proof point].

Present all three via AskUserQuestion for founder editing. Write approved versions to `.claude/cache/narrative.yml`.

**Key rule**: if you can't back a claim with evidence from roadmap.yml or experiment-learnings.md, you can't write it. "We believe" and "we're building toward" are honest alternatives to unproven claims.

### `changelog` → version-by-version external changelog

Generate a human-readable changelog from the roadmap. Not git commits — thesis-level changes that users care about.

**Steps:**
1. Read all proven versions from roadmap.yml
2. For each version, extract: what changed for the USER (not what code changed)
3. Translate internal language to external language:
   - "thesis proven" → "now supports..."
   - "feature matured to working" → "added..."
   - "evidence item disproven" → "removed..." or "changed approach to..."
   - "Known Pattern confirmed" → (don't surface — internal)

**Format**: reverse chronological, grouped by major version, with patch details nested.

Write to `.claude/cache/changelog.md`. This can be copied to README or CHANGELOG.

### `positioning` → competitive positioning check

Where does this product sit in the landscape? Derived from evidence, not aspiration.

**Steps:**
1. Read proven theses (what's actually true about this product)
2. Read Known Patterns (what the product has learned about the space)
3. If `.claude/cache/market-context.json` exists (from /research market), read competitor landscape
4. Otherwise, use WebSearch to find 3-5 comparable tools

**Generate:**
- **What we've proven** (defensible claims backed by evidence)
- **What we haven't proven** (honest gaps — these are NOT weaknesses to hide, they're unknowns to test)
- **Where we're different** (derived from Known Patterns that competitors don't have)
- **Where we're behind** (what competitors have that we don't — honest assessment)

Present via AskUserQuestion. Write to `.claude/cache/positioning.yml`.

### Version string (e.g., `v7.0`) → version archaeology

Show what that version taught and how it shaped what came after:

```
◆ roadmap — v7.0

thesis: "Score should measure value, not health"
status: proven (2026-03-13)

▾ what it proved
  ✓ Assertion pass rate tracks what actually matters
  ✓ Per-feature breakdown identifies real bottlenecks
  ✓ beliefs.yml with typed assertions

▾ what it taught (experiment-learnings.md entries from this period)
  · "Health score alone doesn't motivate — value score does" (Known)
  · "Per-feature breakdown is more actionable than aggregate" (Known)

▾ how it shaped what came after
  v7.1 emerged because: commands needed cross-recommendations (gap found during v7.0)
  v8.0 emerged because: internal validation was proven, external was unknown

predictions during v7.0: 4 total, 3 correct (75%)
```

### `bump` → prove/graduate with auto-synthesis

**Version tiers:**
```
MAJOR (v9.0)   — New thesis. Big question. Resets version completion.
MINOR (v8.1)   — Significant improvement within current thesis.
PATCH (v8.0.1) — Bug fix, polish, incremental. No new question.
```

**Bump auto-detection (when no tier specified):**
- Thesis question changed → major
- New features/evidence items changed → minor
- Only assertions fixed / score improved → patch

**Auto-synthesize the summary** (don't ask the founder to write it):
1. Read all evidence items and their `evidence:` fields
2. Read predictions made during this version (filter predictions.tsv by date range between version start and now)
3. Read experiment-learnings.md entries added during this period
4. Read git log for commits since version started
5. Generate a 1-2 sentence summary of what was learned, what changed, and what remains unknown
6. Present to founder via AskUserQuestion: "Summary: [generated]. Edit or confirm?"

**Thesis → Knowledge transfer:**
When bumping, check if the proven thesis should become a Known Pattern in experiment-learnings.md. If the thesis is a major version with 3+ evidence items proven, write it as a Known Pattern with the evidence as supporting data.

When bumping, check if any disproven evidence items should become Dead Ends.

**Narrative trigger:** After bump confirmation, suggest: "Version proven. `/roadmap narrative` to update the external story." The narrative should always reflect what's actually proven — a bump is the natural trigger to refresh it.

### `add [version] [milestone]` → add evidence needed
### `done [milestone-id]` → mark evidence as proven
### `new [version] [thesis]` → create a new thesis

## Thesis Health Monitor

Run this check on every `/roadmap` invocation (any route):

### Contradiction detection
Filter predictions.tsv for predictions that reference the current thesis or its evidence items. If >50% of thesis-related predictions were wrong:
- Surface it: "⚠ thesis may be wrong — N/M thesis-related predictions failed"
- Show the wrong predictions and what they expected vs what happened
- Suggest: "Consider whether the thesis question itself needs reformulating. `/roadmap ideate` to explore alternatives."

### Stall detection
Check evidence item dates. If no evidence item has changed status in >14 days:
- Surface it: "⚠ thesis stalled — no evidence movement in N days"
- Diagnose: is the bottleneck blocking evidence collection? Are the evidence items too hard to prove? Is the thesis too broad?

### Disproven protocol
If an evidence item has `status: disproven` or if the founder marks one via `/roadmap done [id] --disproven`:
1. Read the `if_disproven:` field from the current version (if it exists)
2. Surface it: "This version anticipated this: '[if_disproven text]'"
3. The disproven evidence is the most valuable learning. Write what was expected vs what happened to experiment-learnings.md as a Dead End or model update.
4. Ask: "Thesis is partially disproven. Reformulate the question? Abandon this version? Continue with remaining evidence?"

## Cross-version intelligence

When showing the full roadmap (no arguments), detect patterns:

- **Recurring hard evidence.** If "external validation" or "return users" keeps appearing as `todo` across versions, call it out: "External validation has been planned in N versions and never proven."
- **Acceleration/deceleration.** Compare days between version proofs. v6→v7 took 1 day, v7→v7.2 took 2 days, v8.0 is on day N. Is the project getting faster (early versions are easy) or slower (harder questions)?
- **Thesis evolution.** Summarize the arc in one sentence: "v6=identity, v7=measurement, v8=external use → the project is moving from 'does it work?' to 'does it work for others?'"

## Tools to use

**Use Read** to check roadmap.yml, strategy.yml, experiment-learnings.md, predictions.tsv.
**Use Edit** to update roadmap.yml.
**Use AskUserQuestion** for bump confirmation, new thesis goals, and ideation selection.
**Use WebSearch** during ideate to research what questions other dev tools are asking.

For output templates, version completion cycle details, and formatting rules, see [reference.md](reference.md).

## What you never do
- Auto-bump without asking — graduating a thesis is a founder decision
- Create versions with more than 5 evidence items — if it needs more, the thesis is too broad
- Invent future versions without evidence — only `/roadmap ideate` creates them
- Write a reflection that sounds like a status update — it should sound like thinking
- In build mode: mention shipping, deploying, releasing, or deadlines
- Mark evidence as `proven` without citing specific evidence (a file, a test result, a session log)
- Ignore disproven evidence — it's the most valuable signal in the system

## If something breaks
- No roadmap.yml: create one by reading git log and inferring proven theses
- Milestone ID not found: list available IDs
- Version doesn't exist: suggest creating it
- predictions.tsv missing: skip velocity/contradiction checks, note "no predictions yet"
- experiment-learnings.md missing: skip thesis→knowledge transfer, note it

$ARGUMENTS
