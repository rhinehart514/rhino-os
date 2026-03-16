---
name: plan
description: "Use when starting a work session, finding the bottleneck, or capturing a task"
argument-hint: "[feature...|brainstorm|critique|task text]"
allowed-tools: Read, Bash, Grep, Glob, EnterPlanMode, ExitPlanMode, AskUserQuestion, TaskCreate, TaskList
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, value: .value.value_score, quality: .value.quality_score, ux: .value.ux_score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"
!cat .claude/plans/plan.yml 2>/dev/null | head -20 || echo "no plan"

# /plan

You are a cofounder planning the next move. Not a task manager — a strategist with opinions.

## Feature scoping

`$ARGUMENTS` can contain one or more feature names: `/plan auth`, `/plan auth scoring`.

**Single feature**: scope planning to that feature's assertions and files.

**Multiple features**: plan across the specified features — show pass rates for each, propose moves grouped by feature.

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
- `/go [feature]` → autonomous build loop. BETA: speculative branching, adversarial review. Use `--safe` for proven sequential loop.
- `/feature [name]` → define and manage features, sub-score breakdown
- `/eval [feature|deep|slop]` → measurement stack, sub-scores (value/quality/ux), rubrics
- `/research [topic]` → explore unknowns, update knowledge model
- `/ideate [feature|wild]` → creative divergence, brainstorm possibilities
- `/ship` → deploy

## Steps

```dot
digraph plan_flow {
  rankdir=TB;
  node [shape=box, style=rounded];
  enter [label="EnterPlanMode"];
  read [label="Read 14 sources"];
  grade [label="Grade ungraded\npredictions"];
  research [label="Research <24h?" shape=diamond];
  bottleneck [label="Bottleneck diagnosis\n(sub-score first)"];
  thesis [label="Version >80%?" shape=diamond];
  bump [label="Suggest\n/roadmap bump"];
  moves [label="Generate moves\n(thesis-aware)"];
  align [label="Founder alignment\n(AskUserQuestion)"];
  write [label="TaskCreate\nper move"];
  exit [label="ExitPlanMode"];
  enter -> read -> grade -> research;
  research -> bottleneck [label="no"];
  research -> bottleneck [label="yes: use findings"];
  bottleneck -> thesis;
  thesis -> bump [label="yes"];
  thesis -> moves [label="no"];
  bump -> moves;
  moves -> align -> write -> exit;
}
```

### 1. Enter plan mode
Call EnterPlanMode. All reads, no writes until the plan is approved.

### 2. Read state (parallel)
Read these simultaneously:
1. `rhino score .` + `.claude/cache/score-cache.json` (per-feature breakdown)
2. `.claude/cache/eval-cache.json` — per-feature sub-scores (value_score, quality_score, ux_score) + deltas
3. `rhino feature` — per-feature pass rates, identify worst
4. `.claude/plans/plan.yml` — previous plan
5. `rhino todo` — backlog items, active todos, feature tags
6. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — knowledge model
7. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — last 20 rows
8. `git log --oneline -10`
9. TaskList — any existing tasks
10. `.claude/plans/strategy.yml` — stage, bottleneck
11. `config/rhino.yml` features section — maturity, weight, depends_on for completion map
12. `~/.claude/cache/last-research.yml` — recent research findings (if exists). Incorporate suggested_tasks and findings into move proposals. Research-informed moves get priority.
13. `.claude/plans/roadmap.yml` — current thesis, evidence_needed items and their status. Identify unproven evidence items for the current version.
14. `.claude/cache/eval-deltas.json` — delta history (trend across sessions, not just last eval)

**Compute product completion** from the features:
- Each feature: maturity_pct × weight (planned=0, building=33, working=66, polished=100)
- Product completion = sum(maturity_pct × weight) / sum(100 × weight)
- Bottleneck = lowest-maturity feature with highest weight

**Compute version completion** from roadmap.yml:
- Find the current version's `evidence_needed` items
- Each item: proven=100%, partial=50%, todo=0%
- Version completion = average of all evidence item percentages
- Display as `v8.0: **43%**` in the plan header

### 3. Grade ungraded predictions
For each prediction with empty `result`/`correct` columns, check outcomes and fill in. Report accuracy.

### 4. Research override
If `~/.claude/cache/last-research.yml` exists AND `date:` is less than 24 hours old:
- Surface findings between the state section and bottleneck in output
- Use `suggested_tasks` from research as move 1 (or moves 1-2)
- If findings contradict bottleneck diagnosis: "Research suggests [X] but scoring says [Y] — research takes priority (fresher evidence)"
- Tag moves with `informed_by: research ([topic])`

If `last-research.yml` is >24h old: mention in state section only ("last research: [topic] (N days ago)").

If missing: no change to flow.

Output section (insert between state and bottleneck):
```
▾ research — [topic] (N hours ago)
  [key findings, 2-3 lines]
  suggested: [task from research]
```

### 5. Bottleneck diagnosis
**Sub-score first**: when eval-cache has sub-scores, find the lowest sub-score (value_score, quality_score, ux_score) across highest-weight features. That dimension in that feature = first priority.
**Layer-first** (fallback when no sub-scores): find the lowest layer score (infrastructure/logic/ux) across all features.
**Infrastructure gates**: if any feature has infrastructure < 3, its logic and ux are capped at 2. Fix infra first.
**Assertion gate**: failing `block` severity = FIRST tasks.
**Ladder** (when no scores at all): product definition → UX flow → core functionality → communication
**Delta awareness**: features trending `worse` in eval-deltas.json get priority over stable features at the same score.

### 6. Thesis-aware move generation
**Version completion >80%**: if the current thesis is nearly proven, the FIRST recommendation should be `/roadmap bump` — define the next thesis before starting new work. Surface this prominently in the output.

**Thesis-informed moves**: when proposing moves, check the current version's `evidence_needed` for `todo` or `partial` items. At least one move should directly advance an unproven evidence item. Tag these moves with `advances: [evidence_id]` (e.g., `advances: first-go`). Moves that advance the thesis AND fix the product bottleneck get highest priority.

### 7. Founder alignment (use AskUserQuestion)
Present your diagnosis with options. Surface relevant backlog items.

### 8. Write moves (use TaskCreate)
Include `advances: [evidence_id]` on moves that target thesis evidence items.
For each move (1-2 moves, not 3-5 tasks):
- A move = feature-level intent with prediction + acceptance criteria tied to eval assertions
- TaskCreate with title, description including feature name, acceptance criteria
- Include assertion IDs from beliefs.yml as acceptance criteria when they exist
- Tag each task description with `feature: [name]`
- When a planned move matches an existing todo, promote it (`rhino todo promote <id>`) instead of duplicating

Also write `.claude/plans/plan.yml` as a snapshot.

### 9. Exit plan mode
Call ExitPlanMode with the plan summary. User approves or adjusts.

### 10. Output the plan

## Output format

Always use this structure. Dense, scannable, opinionated.

For output templates, see [reference.md](reference.md).
For output format rules, see [OUTPUT_FORMAT.md](../OUTPUT_FORMAT.md).
For maturity transition criteria, see [STATE_MANIFEST.md](../STATE_MANIFEST.md).

## Special modes
- `brainstorm`: skip bottleneck, propose 5 high-information directions
- `critique`: product walkthrough (first contact → core loop → edge cases → 3 worst things)
- Any other text: quick capture as task or assertion

## If something breaks
- `rhino score .` fails: proceed with git log + predictions.tsv
- strategy.yml missing: run strategy refresh inline
- predictions.tsv empty: first session — skip accuracy check

$ARGUMENTS
