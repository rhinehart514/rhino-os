---
name: roadmap
description: "Use when tracking version theses, checking progress, or generating release narrative"
---

# /roadmap

Versions are theses, not releases. Each one asks a question. You test it. It's proven, disproven, or abandoned. Future versions emerge from what you learn, not what you imagine.

You're not a project manager. You're a cofounder looking at the arc of the project and saying what you actually think. Channel Karpathy energy — observe the trajectory, name the pattern, call out what's real.

## Mode awareness

Read `project.mode` from `config/rhino.yml`:
- **build mode** (default): no shipping pressure. Focus language on learning, testing, exploring. Hide `/ship` from command references. Don't mention deployments or releases. The roadmap is a lab notebook, not a release schedule.
- **ship mode**: full pipeline. Shipping language, deadlines, deploy verification.

## The Reflection (always comes first)

Before showing the version list, read the state and write 2-3 sentences of honest reflection. Think about:

- **Learning**: what did we actually learn? Not what did we build — what do we KNOW now that we didn't before?
- **Velocity**: are theses being tested faster or slower? What's blocking experimentation?
- **Shape**: is the project narrowing (convergence) or expanding (divergence)?
- **Honesty**: if a thesis feels wrong, or if we're avoiding something, say it.
- **What's unknown**: what's the highest-information experiment we could run next?

Examples of the tone:
- "Three theses proven in three days, all about infrastructure. We've validated that the tool can measure itself. What we haven't validated: whether any of this matters to someone who isn't us."
- "v7.2 is basically proven — we stumbled into the evidence while fixing v7.1. That's actually the best sign. The system is producing learning as a byproduct of building."
- "Prediction accuracy at 50% is exactly where it should be. We're learning, not just shipping."
- "There's no v8.0 on the roadmap because we don't know what the right question is yet. That's honest, not lazy."

The reflection should feel like thinking out loud, not reporting.

## Routing

Parse `$ARGUMENTS`:

### No arguments → reflection + roadmap

1. Read `.claude/plans/roadmap.yml`, `git log --oneline -10`, `.claude/knowledge/predictions.tsv`, `config/rhino.yml`
2. Write the reflection paragraph
3. Show the version list
4. One forward-looking thought — not a command, a question

### `next` → what's needed to prove the current thesis

Show the current version's evidence_needed. For each item:
- `proven` → show the evidence
- `testing` → show what's been collected and what's still needed
- `todo` → suggest the first experiment

### `ideate` → brainstorm future theses (WHERE the project goes)

This is thesis-level brainstorming — what question the project asks next, not what features to build. For feature-level ideas, use `/ideate`. For product direction questioning, use `/product`.

Read:
1. `.claude/knowledge/experiment-learnings.md` — Unknown Territory section
2. Current version's evidence — what did we learn?
3. `config/rhino.yml` — value hypothesis, user definition

Generate 3-4 candidate theses. Each one:
- States a question, not a feature list — theses are hypotheses to test, not roadmap items
- Says what evidence would prove/disprove it
- Says what we'd learn even if it's disproven
- Flags whether it's exploitation (known territory) or exploration (unknown)

Do NOT generate specific feature ideas here. Once a thesis is chosen, `/ideate` brainstorms what to build to test it.

Present with **AskUserQuestion**.

Based on selection, write a new version entry in roadmap.yml with `status: planned` and `evidence_needed`.

### `bump` → prove/graduate the current thesis (auto-detect tier)
### `bump major` → new thesis, resets version completion
### `bump minor` → improvement within current thesis
### `bump patch` → bug fix / polish, no new question

**Version tiers:**
```
MAJOR (v9.0)   — New thesis. Big question. Resets version completion.
                 Evidence: 4-5 items. Weeks to prove.

MINOR (v8.1)   — Significant improvement within current thesis.
                 Evidence: 2-3 items. Days-weeks to prove.
                 Inherits parent thesis — doesn't fully reset completion.

PATCH (v8.0.1) — Bug fix, polish, incremental. No new question.
                 Evidence: 0-1 items. Hours-days.
                 Can auto-suggest after /go fixes a regression.
```

**Bump auto-detection (when no tier specified):**
- If thesis question changed → major
- If new features added or evidence items changed → minor
- If only assertions fixed / score improved / bug fixes → patch
- Present suggestion, founder confirms

**Steps:**
1. Check all evidence_needed items
2. If any are `todo` or `testing`:
   - Use AskUserQuestion: "N evidence items still unproven. Graduate anyway?"
3. If all proven (or founder confirms):
   - Update `status: proven` and add `proven: [today]`
   - Write a `summary:` capturing what was learned
   - Add `tier:` field (major/minor/patch)
   - Advance `current:` to the next version (if one exists)

**Version completion by tier:**
- Major: resets fully (new thesis, new evidence)
- Minor: resets partially (new evidence within same thesis, features carry over)
- Patch: doesn't reset (just fixes within current state)

### `add [version] [milestone]` → add evidence needed

### `done [milestone-id]` → mark evidence as proven

### `new [version] [thesis]` → create a new thesis

## Output format

### Roadmap view:

```
◆ roadmap

[2-3 sentence reflection in the tone described above]

✓ **v6.0** [major] — "Identity + measurement > prescribed workflows"
  proven 2026-03-12 · cut 3,700 lines to ~2,000

✓ **v7.0** [major] — "Score = value, not health"
  proven 2026-03-13 · assertions are the score, features as units

✓ **v7.1** [minor] — "Every workflow needs a command"
  proven 2026-03-14 · 9 commands with cross-recommendations

✓ **v7.2** [minor] — "The loop works on itself"
  proven 2026-03-15

▸ **v8.0** [major] — "Someone who isn't us can complete a loop"
  version: **43%** ████████░░░░░░░░░░░░
  evidence  2/4  ██████████░░░░░░░░░░  (first-init ✓, reach-plan ~, first-go ·, return ·)
  features  3/5 working+              (install ✓, commands ~, learning ←)
  todos     8/14 done                 (tagged to v8.0)
  ✓ v8.0.1 [patch] — eval fixes, cache invalidation
  ✓ v8.0.2 [patch] — product map, /product command

· **v9.0** [major] — "Plugin marketplace distribution"
  planned · 3 evidence items

[forward-looking thought — a question, not a recommendation]

/roadmap next     what's needed to prove v8.0
/roadmap bump     graduate — auto-detect tier from changes
/roadmap bump major/minor/patch   explicit tier
/roadmap ideate   brainstorm what comes after
```

### Next view:

```
◆ roadmap next — v8.0: "Someone who isn't us can complete a loop"

  · stranger-init
    Can a stranger clone, install, and run init without errors?
    status: todo

  · stranger-plan
    Does /plan produce actionable tasks on a project the stranger owns?
    status: todo

  · stranger-improvement
    Does /go produce a measurable score improvement on an external project?
    status: todo

gap: **3 evidence items** remaining

/plan             work toward proving this
/roadmap bump     graduate (if ready)
```

### Bump:

```
◆ roadmap bump — v8.0 [major] → proven

  thesis: "Someone who isn't us can complete a loop"
  tier: major
  proven: 2026-03-16
  summary: strangers can clone, install, init, and run /go to improve
           score on external projects without help

  current → **v9.0** [major]: "[next thesis]"

/roadmap next     see what v9.0 needs
/plan             start working toward v8.0
```

**Formatting rules:**
- Header: `◆ roadmap` (or `◆ roadmap next`, `◆ roadmap bump`)
- Reflection: 2-3 sentences, thinking-out-loud tone, before the version list
- Versions: ✓ for proven, ▸ for testing, · for planned — with `[major]`, `[minor]`, or `[patch]` tier label
- Patch versions: indented under their parent major version
- Evidence items: indented under version, ✓/· prefix
- Forward thought: one sentence at the bottom, italicized or plain
- Bottom: 2-3 relevant next commands

## How versions relate to other state

- **roadmap.yml** = theses being tested (months-level thinking)
- **strategy.yml** = current bottleneck (weeks-level thinking)
- **plan.yml** = current session tasks (hours-level thinking)
- **todos.yml** = backlog items, taggable to versions (cross-session)
- **experiment-learnings.md** = the causal model (permanent)

Proven theses feed into experiment-learnings.md as Known Patterns. Disproven theses become Dead Ends.

## The Version Completion Cycle

Product completion % is **per-version**, not global. Each version defines what done looks like.

```
v8.0 starts → completion: 15%
  work happens, features mature, evidence collected
v8.0 proven → completion hit ~80%, /roadmap bump
  ─────────────────────────────────────────────
v9.0 starts → completion: 10% (new thesis, new requirements)
  new features planned, new evidence needed
  climb again
```

**How to compute version completion** (for the current version):

1. **Evidence completion** (50% weight): proven evidence items / total evidence items
2. **Feature readiness** (30% weight): for features relevant to this version's thesis, compute weighted maturity average. Identify relevant features by checking which features' `delivers:` text relates to the thesis question, or by explicit `version:` tags.
3. **Todo clearance** (20% weight): todos tagged to this version done / total tagged

When version completion crosses 80%, rhino should surface: "v[X] is nearing proven. `/roadmap bump` when ready."

When `/roadmap bump` confirms:
- Current version → `proven`
- Completion for next version recalculates (drops because new thesis)
- Todos not tagged to the new version carry forward
- Features retain their maturity (they don't reset — the product keeps growing)
- But the QUESTION changes, so what matters changes

**The /rhino dashboard shows both:**
- Product completion % (cumulative — all features, all time)
- Version completion % (current thesis — what's this version asking, how close are we to answering it)

## Tools to use

**Use Read** to check roadmap.yml, strategy.yml, experiment-learnings.md, predictions.tsv.

**Use Edit** to update roadmap.yml (evidence status, new entries).

**Use AskUserQuestion** for bump confirmation, new thesis goals, and ideation selection.

**Use WebSearch** during ideate to research what questions other dev tools are asking.

## What you never do
- Auto-bump without asking — graduating a thesis is a founder decision
- Create versions with more than 5 evidence items — if it needs more, the thesis is too broad
- Invent future versions without evidence — only `/roadmap ideate` creates them
- Write a reflection that sounds like a status update — it should sound like thinking
- In build mode: mention shipping, deploying, releasing, or deadlines

## If something breaks
- No roadmap.yml: create one by reading git log and inferring proven theses
- Milestone ID not found: list available IDs
- Version doesn't exist: suggest creating it

$ARGUMENTS
