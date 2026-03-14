---
description: "Version roadmap. /roadmap shows progress. /roadmap next shows what's needed for the next version. /roadmap bump marks current version shipped."
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

1. Read `.claude/plans/roadmap.yml`, `git log --oneline -10`, `~/.claude/knowledge/predictions.tsv`, `config/rhino.yml`
2. Write the reflection paragraph
3. Show the version list
4. One forward-looking thought — not a command, a question

### `next` → what's needed to prove the current thesis

Show the current version's evidence_needed. For each item:
- `proven` → show the evidence
- `testing` → show what's been collected and what's still needed
- `todo` → suggest the first experiment

### `ideate` → brainstorm future theses

This is the creative space for what comes after the current version. Read:
1. `~/.claude/knowledge/experiment-learnings.md` — Unknown Territory section
2. Current version's evidence — what did we learn?
3. `config/rhino.yml` — value hypothesis, user definition

Generate 3-4 candidate theses. Each one:
- States a question, not a feature list
- Says what evidence would prove/disprove it
- Says what we'd learn even if it's disproven
- Flags whether it's exploitation (known territory) or exploration (unknown)

Present with **AskUserQuestion**.

Based on selection, write a new version entry in roadmap.yml with `status: planned` and `evidence_needed`.

### `bump` → prove/graduate the current thesis

1. Check all evidence_needed items
2. If any are `todo` or `testing`:
   - Use AskUserQuestion: "N evidence items still unproven. Graduate anyway?"
3. If all proven (or founder confirms):
   - Update `status: proven` and add `proven: [today]`
   - Write a `summary:` capturing what was learned
   - Advance `current:` to the next version (if one exists)

### `add [version] [milestone]` → add evidence needed

### `done [milestone-id]` → mark evidence as proven

### `new [version] [thesis]` → create a new thesis

## Output format

### Roadmap view:

```
◆ roadmap

[2-3 sentence reflection in the tone described above]

✓ **v6.0** — "Identity + measurement > prescribed workflows"
  proven 2026-03-12 · cut 3,700 lines to ~2,000

✓ **v7.0** — "Score = value, not health"
  proven 2026-03-13 · assertions are the score, features as units

✓ **v7.1** — "Every workflow needs a command"
  proven 2026-03-14 · 9 commands with cross-recommendations

▸ **v7.2** — "The loop works on itself"
  ✓ rhino-beliefs — 25 assertions, all running
  ✓ self-loop — score 85→89 in one session
  · prediction-accuracy — 63%, need 2 more graded

  **v8.0** — "Someone who isn't us can complete a loop"
  planned · 4 evidence items

[forward-looking thought — a question, not a recommendation]

/roadmap next     what's needed to prove v7.2
/roadmap bump     graduate current thesis
/roadmap ideate   brainstorm what comes after
```

### Next view:

```
◆ roadmap next — v7.2: "The loop works on itself"

  ✓ rhino-beliefs
    Can rhino-os define assertions about itself?
    evidence: 25 assertions in beliefs.yml, all running

  ✓ self-loop
    Does /plan → /go → /eval produce a score improvement?
    evidence: score 85→89 in one session

  · prediction-accuracy
    Are predictions calibrated (50-70% accuracy)?
    collected: 16 graded, 63% accurate
    needed: 2 more graded predictions

gap: **1 evidence item** remaining · `/go` to generate predictions, then grade

/plan             work toward proving this
/roadmap bump     graduate (if ready)
```

### Bump:

```
◆ roadmap bump — v7.2 → proven

  thesis: "The loop works on itself"
  proven: 2026-03-14
  summary: rhino-os can define assertions about itself, improve its own
           score through the /plan → /go → /eval loop, and maintain
           calibrated predictions (63% accuracy, target 50-70%)

  current → **v8.0**: "Someone who isn't us can complete a loop"

/roadmap next     see what v8.0 needs
/plan             start working toward v8.0
```

**Formatting rules:**
- Header: `◆ roadmap` (or `◆ roadmap next`, `◆ roadmap bump`)
- Reflection: 2-3 sentences, thinking-out-loud tone, before the version list
- Versions: ✓ for proven, ▸ for testing, · for planned
- Evidence items: indented under version, ✓/· prefix
- Forward thought: one sentence at the bottom, italicized or plain
- Bottom: 2-3 relevant next commands

## How versions relate to other state

- **roadmap.yml** = theses being tested (months-level thinking)
- **strategy.yml** = current bottleneck (weeks-level thinking)
- **plan.yml** = current session tasks (hours-level thinking)
- **experiment-learnings.md** = the causal model (permanent)

Proven theses feed into experiment-learnings.md as Known Patterns. Disproven theses become Dead Ends.

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
