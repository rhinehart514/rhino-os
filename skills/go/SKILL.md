---
name: go
description: "Use when you want autonomous building with measurement and prediction grading. Builds, measures, learns in a loop. '/go auth' scopes to a feature, '/go --safe' disables beta features."
argument-hint: "[feature...] [--safe] [--speculate N]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion, WebSearch, WebFetch, TaskCreate, TaskGet, TaskList, TaskUpdate
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"
!tail -3 ~/.claude/knowledge/predictions.tsv 2>/dev/null || echo "no predictions"

# /go

Autonomous creation loop. Plan, predict, build, measure, learn — no human in the loop until you hit a wall or plateau.

## Skill folder structure

This skill is a **folder**. Read these on demand:

- `scripts/pre-build-scan.sh` — runs FIRST. Scans project state: score, failing assertions, plan tasks, recent predictions. One script, full context.
- `scripts/assertion-gate.sh` — checks assertions pass/fail with specifics. Run after every build.
- `scripts/plateau-check.sh` — detects N consecutive flat moves mechanically.
- `scripts/build-log.sh` — persistent session log across conversations. Uses `${CLAUDE_PLUGIN_DATA}`.
- `references/keep-revert-matrix.md` — when to keep vs revert. Read before first keep/revert decision.
- `references/build-patterns.md` — patterns that work and anti-patterns. Read before building.
- `templates/build-session.md` — template for session log entry.
- `templates/prediction.md` — template for a prediction before building.
- `gotchas.md` — real failure modes. **Read this before entering the loop.**
- `reference.md` — output formatting templates. Read when formatting output.

## Modes

| Argument | Behavior |
|----------|----------|
| `/go` | Full beta loop: speculative branching + adversarial review |
| `/go --safe` | Proven sequential loop only (no beta features) |
| `/go --speculate N` | Force N parallel approaches (default: 2) |
| `/go [feature]` | Scope to a single feature |

Feature scoping: `$ARGUMENTS` can name features. Single = scope everything. Multiple = work sequentially. None = target the bottleneck.

## The protocol

### Step 1: Scan state

Run `bash scripts/pre-build-scan.sh` — this reads all 8 sources in one shot. Also run `bash scripts/build-log.sh list 3` to see recent session history.

Read `config/product-spec.yml` if it exists — build toward the spec's core loop and first experience, not random improvements.

Read `gotchas.md` and `references/build-patterns.md` before entering the loop.

Check `~/.claude/preferences.yml` for `agents.cost` tier (economy/balanced/premium) and `agents.autonomy` setting.

### Step 2: Soft discovery gate

If target feature has no eval data AND no customer-intel.json AND no last-discovery.yml mention:
- Present via AskUserQuestion: "Building [feature] with no customer signal. This is fine for exploration, but viability score may suffer."
- Options: "Build it" / "/discover first" / "/strategy user"
- If `agents.autonomy` is `autonomous` or `full-auto`, skip gate (still log prediction).

### Step 3: Pick the move — completeness-driven

**The goal is not "do one thing." The goal is "finish the feature."**

A. Run `bash scripts/assertion-gate.sh [feature]` — see what's failing.
B. Check TaskList for ALL tasks tagged to this feature (from /eval, /taste, /todo, /ideate).
C. Check eval-cache for sub-scores — which dimension is weakest?
D. Check beliefs.yml for assertion coverage — what's not tested?

**Move selection priority:**
1. **Failing assertions** — fix these first. A regression blocks everything.
2. **Tasks from /eval** — these are the specific gaps identified by evaluation. Work through them.
3. **Tasks from /taste** — visual issues identified by taste eval.
4. **Missing assertion coverage** — if a feature has <5 assertions, add more before building more code.
5. **Weakest sub-score dimension** — delivery, craft, or viability. Target the lowest.
6. **Promoted todos** — founder's captured intent.
7. **New work** — only when all of the above are clear.

**Don't pick one move and stop.** Work through the task list systematically:
- After each build+measure cycle, check: are there more tasks for this feature?
- If yes: pick the next task, predict, build, measure, grade. Keep going.
- If no: run a quick inline eval to see if NEW gaps appeared. If they did, generate tasks for those too.
- Stop when: plateau (3 flat moves), all tasks done, or all assertions passing and sub-scores above target.

**After completing all tasks for a feature**, run a fresh eval to generate any NEW tasks that emerged. The loop is: build → measure → generate new tasks → build more → measure → until done.

**Cleanup routing**: If the task is cleanup/refactor (source contains 'evaluator' or 'slop', tagged cleanup/refactor), spawn `rhino-os:refactorer` in worktree instead of builder. Hard constraint: no behavior changes, assertions must hold identically.

### Step 4: Predict

Log to `.claude/knowledge/predictions.tsv` using the structure in `templates/prediction.md`.

### Step 5: Approval gate

The gate mode depends on project configuration:

**SOFT-GATE (default in build mode):**
Present the move plan inline — the move, prediction, approach, files to touch — then proceed to build. The founder can interrupt at any time. This is the default when `config/rhino.yml` has `mode: build`.

**HARD-GATE (ship mode or explicit supervision):**
Do NOT write code until the founder acknowledges. Present via AskUserQuestion with options: "Build it" / "Adjust" / "Skip to next move". Active when `mode: ship` in rhino.yml OR `agents.autonomy` is explicitly `supervised`.

**No gate:** Skip entirely if `agents.autonomy` is `autonomous`/`full-auto`.

### Step 6: Build

**Safe mode**: Build directly. Atomic commits. Run `bash scripts/assertion-gate.sh [feature]` after each.

**Beta mode**: Speculative branching when uncertain. Spawn `rhino-os:builder` per approach in worktrees. Compare scores, keep winner. Fall back to safe on worktree failure.

When to speculate: unfamiliar territory, multiple plausible approaches, Unknown Territory. Never: config changes, renames, assertion additions.

### Step 7: Measure

Run `rhino eval . --feature [name] --fresh` after each commit. Read sub-scores, not just total.

Run `bash scripts/assertion-gate.sh [feature]` for quick pass/fail. Run `bash scripts/plateau-check.sh` every 3 moves.

### Step 8: Keep/revert

Read `references/keep-revert-matrix.md` for the full decision matrix. Core rules:
- Assertion regressed -> revert (always, no exceptions)
- Assertion improved -> keep (even if reviewer says REVERT)
- Assertion stable + reviewer REVERT -> revert

On regression: spawn `rhino-os:debugger` in background before reverting.

**Beta mode**: Two-stage review (spec compliance, then code quality) via `rhino-os:reviewer`. See `references/keep-revert-matrix.md` for details.

### Step 9: Grade prediction

**Mandatory before next move.** Spawn `rhino-os:grader` to fill result/correct/model_update in predictions.tsv. If wrong, grader updates experiment-learnings.md.

### Step 10: Next move or stop

Run `bash scripts/plateau-check.sh`. If plateau: stop, research inline, report. Otherwise: pick next move, loop back to Step 3.

### Step 11: Session end — completeness report

Log session with `bash scripts/build-log.sh add [session-data]`. Write `.claude/sessions/YYYY-MM-DD-HH.yml`.

**Completeness report (mandatory at session end):**
- Tasks completed this session: N
- Tasks remaining for this feature: M
- Assertions: X passing / Y total (was A/B at session start)
- Sub-scores: delivery [d], craft [c], viability [v] (was [d0], [c0], [v0])
- New tasks generated during session: K
- Estimated sessions to feature completion: [based on velocity this session]

If tasks remain: "Feature [name] is [%] complete. [M] tasks remain. Next session: start with task [first remaining]."

Format output per `reference.md`.

## Agent routing

| Step | Agent | Why |
|------|-------|-----|
| Build (safe) | direct | Single-agent, main worktree |
| Build (speculate) | rhino-os:builder x N | Parallel, isolated worktrees |
| Build (cleanup) | rhino-os:refactorer | No behavior changes allowed |
| Measure | rhino-os:measurer or Bash | Mechanical, cheap |
| Review (beta) | rhino-os:reviewer | Independent, honest, cheap |
| Grade | rhino-os:grader | Has memory, learns grading |
| Debug regression | rhino-os:debugger (bg) | Async during revert |

## What you never do

- Skip the prediction step
- Skip prediction grading
- Continue past plateau without researching
- Modify score.sh, eval.sh, taste.mjs, or skills/taste/SKILL.md (immutable eval harness)
- Speculate on trivial moves
- Let the reviewer block a keep when assertions improved
- Skip presenting the move plan (soft-gate still shows the plan, just doesn't block)

## If something breaks

- `rhino eval .` fails: check config/rhino.yml features section
- Worktree fails: fall back to `--safe`, log failure
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting
- Missing files: create experiment-learnings.md or predictions.tsv with standard templates

$ARGUMENTS
