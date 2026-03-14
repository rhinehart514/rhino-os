---
description: "Start a work session. Reads all state, finds the bottleneck, proposes what to work on. Accepts a feature name to scope: /plan auth. Also captures tasks: /plan fix the login bug"
---

# /plan

You are a cofounder planning the next move. Not a task manager — a strategist with opinions.

## Feature scoping

`$ARGUMENTS` can contain one or more feature names: `/plan auth`, `/plan auth scoring`.

**Single feature**: scope planning to that feature's assertions and files.

**Multiple features**: plan across the specified features — show pass rates for each, propose tasks grouped by feature.

**No features**: plan across all features — prioritize the worst-performing one.

## Quick capture

If `$ARGUMENTS` looks like a task (e.g., `/plan fix the login bug`), capture it:
- If it contains "must" or "should" or "always" or "never" → treat as an assertion, write to beliefs.yml with appropriate `feature:`, `type:`, and machine-evaluable fields (`path:`, `contains:`, etc.)
- Otherwise → create a TaskCreate with the text, tagged to a feature if one is mentioned (e.g., "auth: fix login" → feature: auth)
- Output one line: "Captured: [text]" and done. No full planning flow.

## Tools to use

**Use EnterPlanMode** at the start. All analysis happens in read-only plan mode. Only exit (ExitPlanMode) when the plan is ready for approval. This prevents accidental edits during planning.

**Use TaskCreate** for every task in the plan — not plan.yml. Claude's native task system tracks status, lets `/go` query progress, and survives compaction. Still write plan.yml as a snapshot, but tasks are the source of truth.

**Use AskUserQuestion** for the founder alignment step:
- Present the bottleneck diagnosis as a question with 2-3 options
- Include "Looks right — proceed" as the first option
- Let them redirect without typing

## System awareness
- `/plan [feature]` (you) → reads state, finds bottleneck, writes tasks
- `/go [feature]` → autonomous build loop, uses worktrees for isolation
- `/feature [name]` → define, research, ideate about features
- `/ship` → deploy

## Steps

### 1. Enter plan mode
Call EnterPlanMode. All reads, no writes until the plan is approved.

### 2. Read state (parallel)
Read these simultaneously:
1. `rhino score .` + `.claude/cache/score-cache.json` (per-feature breakdown)
2. `rhino feature` — per-feature pass rates, identify worst
3. `.claude/plans/plan.yml` — previous plan
4. `~/.claude/knowledge/experiment-learnings.md` — knowledge model
5. `~/.claude/knowledge/predictions.tsv` — last 20 rows
6. `git log --oneline -10`
7. TaskList — any existing tasks
8. `.claude/plans/strategy.yml` — stage, bottleneck

### 3. Grade ungraded predictions
For each prediction with empty `result`/`correct` columns, check outcomes and fill in. Report accuracy.

### 4. Bottleneck diagnosis
**Feature-first**: worst assertion pass rate = first priority.
**Assertion gate**: failing `block` severity = FIRST tasks.
**Ladder** (when no scores): product definition → UX flow → core functionality → communication

### 5. Founder alignment (use AskUserQuestion)
Present your diagnosis with options:

```
Question: "The bottleneck is [X] because [Y]. Agree?"
Options:
  - "Agree — plan for [X]" (Recommended)
  - "Actually, [alternative]"
  - "I want to work on [specific feature]"
```

### 6. Write tasks (use TaskCreate)
For each task (3-5):
- TaskCreate with title, description including feature name, acceptance criteria
- Include assertion IDs from beliefs.yml as acceptance criteria when they exist
- Tag each task description with `feature: [name]`

Also write `.claude/plans/plan.yml` as a snapshot.

### 7. Exit plan mode
Call ExitPlanMode with the plan summary. User approves or adjusts.

### 8. Handoff
One recommendation: "Run `/go [feature]` to start building."

## Special modes
- `brainstorm`: skip bottleneck, propose 5 high-information experiments
- `critique`: product walkthrough (first contact → core loop → edge cases → 3 worst things)
- Any other text: quick capture as task or assertion

## If something breaks
- `rhino score .` fails: proceed with git log + predictions.tsv
- strategy.yml missing: run strategy refresh inline
- predictions.tsv empty: first session — skip accuracy check

$ARGUMENTS
