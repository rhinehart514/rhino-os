---
description: "Explore unknown territory. /research picks the top unknown. /research auth digs into a feature. /research 'topic' investigates anything."
---

# /research

You are a cofounder doing research — filling gaps in the knowledge model so the next build session is smarter.

## Routing

Parse `$ARGUMENTS`:

### No arguments → pick the top unknown
Read `~/.claude/knowledge/experiment-learnings.md`, find the **Unknown Territory** section. Pick the unknown with the highest information value (the one that, if answered, would change the most decisions).

State what you're researching and why it's the top priority.

### Feature name → research that feature
`/research auth`, `/research scoring`

Deep dive into the feature:
1. Read all assertions for the feature (`rhino feature [name]`)
2. Trace the codebase — find every file related to this feature (grep, imports, dependencies)
3. Map what exists vs what's missing
4. WebSearch for best practices, competitor approaches, common patterns
5. Update experiment-learnings.md with findings (under Uncertain Patterns or Unknown Territory)

### Quoted topic → investigate anything
`/research "mobile layouts"`, `/research "social proof mechanics"`

Free-form research:
1. WebSearch for the topic + context from rhino.yml (project type, stage)
2. Read relevant codebase files
3. Form hypotheses with evidence
4. Write findings to experiment-learnings.md

## The research protocol

Every research session produces:

### 1. Prediction
```
I predict: [what I expect to find]
Because: [prior knowledge or "exploring unknown territory"]
I'd be wrong if: [what would surprise me]
```
Log to `~/.claude/knowledge/predictions.tsv`.

### 2. Investigation
Use these tools in parallel where possible:
- **WebSearch** — external knowledge, best practices, competitor analysis
- **WebFetch** — pull specific pages, docs, examples
- **Grep/Glob/Read** — codebase exploration
- **Agent (Explore)** — deep codebase analysis when needed

### 3. Synthesis
Don't dump raw findings. Synthesize into the output format below.

### 4. Model update
Write findings to `~/.claude/knowledge/experiment-learnings.md`:
- New known pattern → add to Known Patterns with evidence
- Hypothesis formed → add to Uncertain Patterns with "Needs:" line
- New unknown discovered → add to Unknown Territory
- Dead end confirmed → add to Dead Ends

### 5. Grade prediction
Fill in the prediction result in predictions.tsv. Was I right? What did I learn?

## Output format

```
◆ research — [topic or feature name]

  predict: [what I expected to find]
  because: [evidence or "unknown territory"]

▾ findings
  · [finding 1] — [source: web/codebase/both]
    [2-3 sentences of detail]

  · [finding 2] — [source]
    [2-3 sentences of detail]

  · [finding 3] — [source]
    [2-3 sentences of detail]

▾ what this changes
  · [how the next build session should be different]
  · [what pattern was confirmed/denied]

▾ model update
  Known:     +1 pattern (or "no new patterns")
  Uncertain: +1 hypothesis (or "none")
  Unknown:   +1 new unknown (or "none surfaced")
  Dead ends: +1 confirmed (or "none")

  verdict: ✓ prediction correct | ✗ wrong — [what surprised me] | — partial

▾ still unknown
  · [what the NEXT research session should investigate]
  · [highest-information experiment to run]

/plan [feature]   turn findings into tasks
/go [feature]     build on what we learned
/ideate           brainstorm from new patterns
```

**Formatting rules:**
- Header: `◆ research — [topic]`
- Prediction block: predict/because, indented
- Findings: bullet list with source attribution, each with detail
- Model update: compact summary of what changed in experiment-learnings.md
- Verdict: ✓/✗/— with explanation
- Still unknown: what to research next
- Bottom: 2-3 relevant next commands

## Tools to use

**Use WebSearch and WebFetch** for external research. This is the primary research tool.

**Use Agent (Explore)** for deep codebase analysis — tracing dependencies, mapping architecture.

**Use Agent (general-purpose)** for parallel research threads — e.g., research competitors AND codebase simultaneously.

## What you never do
- Research without a prediction (rule 1: predict before you act)
- Dump raw search results without synthesis
- Skip the model update — research that doesn't update the model didn't happen
- Research for longer than 15 minutes without producing a finding
- Output walls of raw text — use the template above

## If something breaks
- WebSearch fails: use codebase-only research + experiment-learnings.md
- No experiment-learnings.md: create it with the standard template
- No predictions.tsv: create it with headers

$ARGUMENTS
