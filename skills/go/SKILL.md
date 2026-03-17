---
name: go
description: "Use when you want autonomous building with measurement and prediction grading"
argument-hint: "[feature...] [--safe] [--speculate N]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion, WebSearch, WebFetch, TaskCreate, TaskGet, TaskList, TaskUpdate
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"
!tail -3 ~/.claude/knowledge/predictions.tsv 2>/dev/null || echo "no predictions"

# /go

Autonomous creation loop. Plan, predict, build, measure, learn — no human in the loop until you hit a wall or plateau.

**Status: BETA.** Speculative branching, adversarial review, and mechanical prediction grading are experimental. Use `--safe` to disable beta features and run the proven sequential loop.

## Modes

- **`/go`** — full beta loop with speculative branching + adversarial review
- **`/go --safe`** — proven sequential loop only (no beta features)
- **`/go --speculate N`** — force N parallel approaches (default: 2)
- **`/go [feature]`** — scope to a single feature
- **`/go [feature] --safe`** — scoped + safe mode

## Feature scoping

`$ARGUMENTS` can contain one or more feature names: `/go auth`, `/go auth scoring`.

**Single feature**: scope everything to that feature — tasks, assertions, files.
**Multiple features**: work sequentially, measuring after each.
**No features**: target the bottleneck feature from the product map.

## State to read at start (parallel)

1. TaskList — existing tasks
2. `rhino todo active` — promoted todos (founder's priority)
3. `.claude/plans/strategy.yml` — current bottleneck, stage
4. `.claude/plans/roadmap.yml` — current thesis
5. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known patterns, dead ends
6. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — recent predictions
7. `.claude/cache/eval-cache.json` — per-feature scores + sub-scores (baseline)
8. `config/rhino.yml` features section — weight, depends_on
9. `~/.claude/preferences.yml` — agent cost tier and autonomy settings. Map `agents.cost` to model overrides:
   - economy: builder=sonnet, evaluator=sonnet, explorer=haiku, grader=haiku, debugger=haiku, refactorer=haiku, measurer=haiku, reviewer=haiku
   - balanced: builder=opus, evaluator=opus, explorer=sonnet, grader=sonnet, debugger=sonnet, refactorer=sonnet, measurer=haiku, reviewer=haiku (default)
   - premium: builder=opus, evaluator=opus, explorer=opus, grader=opus, debugger=opus, refactorer=opus, measurer=sonnet, reviewer=sonnet
   When spawning agents, pass `model: "<resolved_model>"` parameter. If no preferences.yml, use balanced defaults.

**Compute the product map** → bottleneck, dependency order. If no tasks/plan exist, target the bottleneck.

---

## The Loop

```dot
digraph go_loop {
  rankdir=TB;
  node [shape=box, style=rounded];
  read [label="Read state\n(8 sources)"];
  pick [label="Pick move\n(bottleneck-first)"];
  predict [label="Predict\n(log to predictions.tsv)"];
  gate [label="HARD-GATE\n(present plan, wait)" shape=diamond];
  speculate_q [label="Speculate?" shape=diamond];
  build_safe [label="Build (safe)\n(atomic commits)"];
  build_spec [label="Build (speculate)\n(N worktrees)"];
  measure [label="Measure\n(rhino eval .)"];
  spec_review [label="Stage 1: Spec\ncompliance" shape=diamond];
  quality_review [label="Stage 2: Code\nquality" shape=diamond];
  decision [label="Keep / Revert?" shape=diamond];
  grade [label="Grade prediction"];
  plateau_q [label="3 moves\nno improvement?" shape=diamond];
  next [label="Next move"];
  stop [label="Stop + report"];
  read -> pick -> predict -> gate;
  gate -> speculate_q [label="approved"];
  speculate_q -> build_safe [label="clear approach"];
  speculate_q -> build_spec [label="uncertain"];
  build_safe -> measure;
  build_spec -> measure;
  measure -> spec_review [label="beta"];
  measure -> decision [label="safe"];
  spec_review -> build_safe [label="FAILS_SPEC\n(retry x2)"];
  spec_review -> quality_review [label="MEETS_SPEC"];
  quality_review -> decision;
  decision -> grade [label="keep or revert"];
  grade -> plateau_q;
  plateau_q -> next [label="no"];
  plateau_q -> stop [label="yes"];
  next -> pick;
}
```

```
Read state → Pick move → Predict → <HARD-GATE> → Build → Measure → Spec review → Quality review → Keep/revert → Grade → Next
```

### 1. Pick the move
A move = a feature-level intent. Not a single-file tweak. TaskList for existing tasks. Promoted todos = founder's explicit priority.

#### Cleanup/Refactor Routing

If the next task is a cleanup or slop-reduction task (identified by todo source containing 'evaluator' or 'slop', or tagged as cleanup/refactor), spawn the refactorer instead of the builder:

```
Agent(subagent_type: "rhino-os:refactorer", isolation: "worktree", prompt: "[cleanup task description]. Hard constraint: all assertions must pass before AND after changes. Score must not drop.")
```

The refactorer works in a worktree and has a constraint the builder does not: no behavior changes allowed. It can restructure, simplify, delete dead code, and reduce complexity — but the product must behave identically. Assertions are the verification gate. If assertions change (even improving), the refactorer overstepped — that is builder work, not refactorer work.

### 2. Predict
```
I predict: [specific outcome, with numbers]
Because: [cite experiment-learnings.md entry or declare exploring]
I'd be wrong if: [falsification condition]
```
Log to `.claude/knowledge/predictions.tsv`.

### 2.5 HARD-GATE — Approval before build

<HARD-GATE>
Do NOT write code, create files, or take any implementation action until the move plan is presented and the founder acknowledges it.
</HARD-GATE>

Present via AskUserQuestion:
- The move (what you're building, which feature)
- The prediction (expected outcome)
- The approach (safe vs speculate, and why)
- Files you expect to touch

Options: "Build it" / "Adjust" / "Skip to next move"

In `--safe` mode: present inline but don't block (founder can interrupt).
In beta mode: MANDATORY. Wait for response.
If `agents.autonomy` is `autonomous` or `full-auto` in `~/.claude/preferences.yml`, skip the HARD-GATE approval step (present the plan but don't wait for response).

### 3. Build

**Safe mode** (`--safe`): Build directly. Atomic git commits. Measure after each.

**Beta mode** (default): Speculative branching.

#### BETA: Speculative Branching (worktree lifecycle)

1. Identify 2 approaches
2. Spawn each with worktree isolation:
   ```
   Agent(subagent_type: "rhino-os:builder", isolation: "worktree", prompt: "[approach + acceptance criteria + 'run rhino eval . --feature X --fresh --samples 1']")
   ```
3. Claude Code handles worktree creation automatically
4. When both complete: compare scores, keep winner, discard loser (automatic)
5. If worktree fails: fall back to safe mode, log, continue loop

**When to speculate vs build direct:**
- Speculate: unfamiliar territory, multiple plausible approaches, Unknown Territory in experiment-learnings
- Build direct: clear approach, Known Pattern, simple fix
- Never speculate on: config changes, file renames, assertion additions

**Cost**: 2x agent tokens per speculative move. Worth it when the move is high-risk. Not worth it for mechanical fixes.

### 4. Measure
Run `rhino eval . --feature [name] --fresh` after each commit.

**Read the sub-scores, not just the total.** The eval judge is a top engineer — trust the sub-score breakdown to understand WHAT changed:

- **Assertion regressed** (was passing, now failing) → revert. No negotiation.
- **Assertion progressed** (was failing, now passing) → keep.
- **Sub-score awareness**: which dimension were you targeting? If you targeted quality and quality went up but ux went down, that might be fine. If the dimension you targeted didn't move, the approach isn't working.
- **Value regression is worse than quality regression.** Value means the feature stopped delivering. Quality means it got more fragile. At stage one, value regression = revert, quality regression = maybe acceptable.
- **Score dropped but assertions held** → keep (value > health).
- **Score flat after 3 commits** → stop. The approach is exhausted. Read the eval evidence field — it tells you WHY the score isn't moving.

### 5. BETA: Two-Stage Review

**Stage 1: Spec compliance** — does code satisfy acceptance criteria?

Spawn code-reviewer agent with ONLY: acceptance criteria + diff. No session history.
Verdict: MEETS_SPEC / FAILS_SPEC
- FAILS_SPEC → loop back to build (max 2 retries, then revert)
- MEETS_SPEC → proceed to stage 2

**Stage 2: Code quality** — is the code good?

Spawn code-reviewer agent with ONLY: diff + product-standards.md.
Check: regressions, silent failures, assertion gaming, slop, UX checklist.
Verdict: KEEP / REVERT / KEEP_WITH_FIXES
- Same keep/revert matrix as before
- Reviewer can't block if assertions improved

Skip both stages in `--safe` mode.

### 6. Keep/revert decision

```
assertions improved + reviewer KEEP    → keep (best case)
assertions improved + reviewer REVERT  → keep (measurement wins)
assertions stable + reviewer KEEP      → keep
assertions stable + reviewer REVERT    → revert (no value gained, reviewer found problems)
assertions regressed                   → revert (always, regardless of reviewer)
```

#### Regression Debugging

When assertions regress, BEFORE reverting, spawn the debugger to investigate:

```
Agent(subagent_type: "rhino-os:debugger", prompt: "Score dropped from [before] to [after] after commit [hash]. Assertion [name] regressed. Investigate root cause. Check git diff, trace the failing code path, form hypotheses.", run_in_background: true)
```

The debugger runs in background while /go reverts and continues. Its findings arrive as SendMessage with root cause analysis and a suggested fix todo. The debugger has memory — it remembers past regressions and their causes. Pattern: if the same assertion regresses twice, the debugger's second analysis is sharper because it already has context from the first failure.

### 7. BETA: Mechanical Prediction Grading

**The prediction MUST be graded before moving to the next move.** This is not optional.

Spawn the grader agent to handle prediction grading:
```
Agent(subagent_type: "rhino-os:grader", prompt: "Grade the prediction I just made: [prediction text]. The build result was: [measurement result]. Check git log and eval cache for evidence.")
```

The grader agent fills in:
- `result` column: what actually happened (specific, measurable)
- `correct` column: `yes`, `no`, or `partial`
- `model_update` column: what changed about the model (required when wrong, empty when right)

If wrong, the grader also updates experiment-learnings.md — moving patterns between Known/Uncertain/Unknown/Dead Ends.

The grader agent has memory — it learns what "correct" and "wrong" mean for this project across sessions.

A prediction that was never graded = a prediction that taught nothing. The learning loop breaks here more than anywhere else.

### 8. Update model + next move
TaskUpdate → completed. Pick next move. Loop.

---

## Plateau Handling

3 consecutive moves without assertion improvement:
1. Stop building — current approach is exhausted
2. Research inline (read experiment-learnings.md Unknown Territory, WebSearch)
3. If research produces hypothesis → create task, continue with prediction
4. If no hypothesis → stop the loop, report what was tried

## Crash Recovery

- **Trivial** (syntax error, missing import): fix inline, retry once
- **Fundamental** (missing package, design flaw): spawn debugger for diagnosis before skipping:
  ```
  Agent(subagent_type: "rhino-os:debugger", prompt: "Build crashed on [task]. Error: [error message]. Diagnose whether this is fixable or a fundamental blocker. Check dependencies, imports, and design assumptions.", run_in_background: true)
  ```
  Skip the task, log why. The debugger's findings inform whether to retry later.
- **3 consecutive crashes**: stop the loop, ask founder
- **Worktree failure**: fall back to building in main working tree (safe mode behavior)

## Agent Routing

Not every step needs the same model or agent:

| Step | Agent/Model | Why |
|------|------------|-----|
| State read | direct (haiku-speed) | Just reading files |
| Pick move | direct (main context) | Needs full session context |
| Predict | direct (main context) | Needs experiment-learnings |
| Build (safe) | direct | Single-agent, main worktree |
| Build (speculate) | rhino-os:builder per approach, isolated worktrees | Parallel, independent, has memory |
| Measure | rhino-os:measurer or Bash (`rhino eval .`) | Mechanical, sonnet-cheap |
| Adversarial review | rhino-os:reviewer | Independent, honest, haiku-cheap |
| Prediction grading | rhino-os:grader | Has memory, learns grading patterns across sessions |
| Regression debugging | rhino-os:debugger (background) | Runs async during revert, has memory of past regressions |
| Cleanup/refactor | rhino-os:refactorer (worktree) | No behavior changes allowed, assertions must hold |
| Model update | direct (main context) | Needs experiment-learnings |

## Session Log

When the loop ends, write to `.claude/sessions/YYYY-MM-DD-HH.yml`:

```yaml
date: 2026-03-16T02:30:00Z
scope: scoring
mode: beta  # or safe
moves: 3
kept: 2
reverted: 1
speculated: 1  # moves that used speculative branching
adversarial_overrides: 0  # times reviewer was overruled by measurement
score_before: 58
score_after: 66
delta: +8
predictions:
  - text: "error boundary hardening will raise craft_score from 50 to 65+"
    correct: partial
    model_update: "craft improved +8 but error paths in subprocess calls still unhandled"
features_changed:
  scoring: {before: 58, after: 66, delivery: [62,68], craft: [50,58], viability: [60,65]}
learnings:
  - "speculative branching produced 2 viable approaches — winner was +4 over loser"
  - "adversarial review caught a silent failure at eval.sh:720 that measurement missed"
```

Create `.claude/sessions/` if it doesn't exist.

For output templates, see [reference.md](reference.md).
For maturity transition criteria, see [STATE_MANIFEST.md](../STATE_MANIFEST.md).
For output format rules, see [OUTPUT_FORMAT.md](../OUTPUT_FORMAT.md).

## What you never do
- Skip the prediction step
- Skip prediction grading (the whole point of the learning loop)
- Continue past plateau without researching
- Modify score.sh, eval.sh, taste.mjs, or skills/taste/SKILL.md during the loop (immutable eval harness)
- Speculate on trivial moves (waste of tokens)
- Let the reviewer block a keep when assertions improved
- Output walls of unformatted text — use the output templates
- Skip the HARD-GATE — every move gets presented before building

## Anti-Rationalization Guide

| Excuse | Reality |
|--------|---------|
| "I'll grade the prediction later" | You won't. Grade NOW, before next move. The loop breaks here. |
| "This move is too simple to predict" | Simple moves have clearest outcomes. 10 seconds. |
| "Score didn't change but the code is better" | If measurement can't see it, it didn't happen. |
| "The reviewer is wrong, the code is fine" | Assertions flat + reviewer says REVERT → revert. |
| "One more move will fix the plateau" | 3 moves without improvement = approach exhausted. Research. |
| "I'll skip the HARD-GATE, obvious move" | "Obvious" moves have highest skip-regret rate. Present it. |
| "Speculative branching isn't worth it here" | Unknown Territory = exactly when you need options. |

## Red Flags — STOP

- Prediction column empty on 2+ recent moves
- 3 consecutive keeps with <2pt improvement each
- Reviewer verdict ignored when assertions flat
- Building outside the bottleneck without founder redirect
- Modifying eval harness (score.sh, eval.sh, taste.mjs, skills/taste/SKILL.md)

**All of these mean: stop the loop and re-read state. No exceptions.**

## If something breaks
- `rhino eval .` fails: check config/rhino.yml features section exists
- Worktree creation fails: fall back to `--safe` mode, log the failure
- Adversarial reviewer crashes: skip review, proceed with measurement-only decision
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting
- strategy.yml missing: use feature pass rates as priority
- experiment-learnings.md missing: create with standard template
- predictions.tsv missing: create with header row

## BETA Notes

These features are experimental. Tracking what we don't know:

- **Speculative branching**: Does trying 2 approaches actually produce better outcomes than picking the best approach up front? Unknown. First experiment should compare speculative vs direct on the same move.
- **Adversarial review**: Does the reviewer catch real problems that measurement misses? Or does it add friction without value? Track `adversarial_overrides` in session log.
- **Mechanical prediction grading**: Does forcing grading actually improve prediction accuracy over sessions? Compare accuracy before/after enforcement.
- **Token cost**: Speculative branching + adversarial review = ~3-4x tokens per move vs safe mode. Is the quality improvement worth it?

Log findings to experiment-learnings.md under "go-loop" patterns. These beta features get promoted to default, tuned, or killed based on evidence.

$ARGUMENTS
