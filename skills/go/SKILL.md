---
name: go
description: "Use when the user says 'just build it', 'go', 'fix everything', or wants autonomous building. Builds, measures, learns in a loop. '/go auth' scopes to a feature, '/go --safe' disables beta features."
argument-hint: "[feature...] [--safe] [--speculate N]"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion, WebSearch, WebFetch, TaskCreate, TaskGet, TaskList, TaskUpdate
---

!command -v jq &>/dev/null && cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache (jq missing or cache empty)"
!command -v jq &>/dev/null && cat .claude/cache/product-value.json 2>/dev/null | jq '{loop: .value_loop[:5], type: .product_type}' 2>/dev/null || echo "no product-value cache (jq missing or cache empty)"
!tail -3 ~/.claude/knowledge/predictions.tsv 2>/dev/null || echo "no predictions"

# /go

Autonomous creation loop. Plan, predict, build, measure, learn — no human in the loop until you hit a wall or plateau.

## Skill folder structure

This skill is a **folder**. Read these on demand:

- `scripts/pre-build-scan.sh` — quick state snapshot. Use to VERIFY your state reading.
- `scripts/assertion-gate.sh` — checks assertions pass/fail with specifics. Run after every build.
- `scripts/plateau-check.sh` — detects N consecutive flat moves. Use to VERIFY your plateau judgment.
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

## The build loop

### Understand the situation

Read state directly — form your own picture:

**Read in parallel:**
- `.claude/cache/eval-cache.json` — per-feature scores, sub-dimensions, deltas
- `config/rhino.yml` — features, weights, mode (build/ship), stage
- `.claude/plans/plan.yml` — planned tasks, previous session state
- `~/.claude/knowledge/predictions.tsv` — recent predictions
- `.claude/plans/todos.yml` — backlog items
- `config/product-spec.yml` (if exists) — build toward the spec's core loop
- `~/.claude/preferences.yml` — cost tier (economy/balanced/premium), autonomy setting

**Also read:** `gotchas.md` and `references/build-patterns.md` before entering the loop.

**Verify** with `bash scripts/pre-build-scan.sh` and `bash scripts/build-log.sh list 3` — reconcile any differences with your reading.

**Capture baseline:** Note current assertion count and scores. You'll compare at session end.

### Tier-aware behavior

Determine the tier from eval-cache scores (verify with `bash ../../bin/maturity-tier.sh` if uncertain):

| Tier | /go behavior |
|------|-------------|
| **fix** (<50) | Pure build. Fix assertions, improve health. No eval between cycles. |
| **deepen** (50-70) | Build + eval after every 3 commits. Tasks from eval gaps. |
| **strengthen** (70-85) | Build + eval after every commit. Research inline for unknowns. |
| **expand** (85+ score, <70 eval avg) | Check if bottleneck is "missing capability" vs "incomplete implementation." Missing capability -> suggest /ideate or /research. |
| **mature** (85+ score, 70+ eval avg) | Shorter sessions. After every 2 cycles: is another build cycle higher leverage than /ideate, /research, or /strategy? Stop when features are good — don't grind. |

### Soft discovery gate

If target feature has no eval data AND no customer-intel.json AND no last-discovery.yml mention:
- Present via AskUserQuestion: "Building [feature] with no customer signal. This is fine for exploration, but viability score may suffer."
- Options: "Build it" / "/discover first" / "/strategy user"
- Skip if `agents.autonomy` is `autonomous` or `full-auto` (still log prediction).

### Pick the move — completeness-driven

**The goal is "finish the feature," not "do one thing."**

Read the situation and determine what to work on:

1. **Failing assertions** — read `config/beliefs.yml` and check which assertions fail for the target feature. Fix regressions first. Verify with `bash scripts/assertion-gate.sh [feature]`.
2. **Tasks from /eval** — check TaskList for tasks tagged to this feature. These are specific gaps.
3. **Tasks from /taste** — visual issues identified by taste eval.
4. **Missing assertion coverage** — if a feature has <5 assertions, add more before building more code.
5. **Weakest sub-score dimension** — from eval-cache, which of delivery/craft is lowest? Target that.
6. **Promoted todos** — founder's captured intent from todos.yml.
7. **New work** — only when all above are clear.

**Cleanup routing**: If the task is cleanup/refactor, spawn `rhino-os:refactorer` in worktree instead of builder. Hard constraint: no behavior changes, assertions must hold.

### Predict

Before every build, log to `~/.claude/knowledge/predictions.tsv`:
- **I predict**: specific outcome with numbers ("raise craft_score from 50 to 65")
- **Because**: cite evidence from experiment-learnings or declare exploration
- **I'd be wrong if**: falsification condition

Use the structure in `templates/prediction.md`.

### Approval gate

| Mode | Behavior |
|------|----------|
| **Soft-gate** (default, `mode: build`) | Present move plan inline, then proceed. Founder can interrupt. |
| **Hard-gate** (`mode: ship` or `autonomy: supervised`) | Do NOT write code until founder acknowledges via AskUserQuestion. |
| **No gate** (`autonomy: autonomous`/`full-auto`) | Skip entirely. |

### Build

**Safe mode**: Build directly. Atomic commits. One intent per commit.

**Beta mode**: When uncertain between approaches, spawn `rhino-os:builder` per approach in worktrees. Compare scores, keep winner. Fall back to safe on worktree failure.

When to speculate: unfamiliar territory, multiple plausible approaches, Unknown Territory. Never: config changes, renames, assertion additions.

### Measure

After each commit:
- Run `bash scripts/assertion-gate.sh [feature]` — quick pass/fail
- Run `rhino eval . --feature [name] --fresh` — read sub-scores, not just total
- Check: did the TARGETED sub-score improve, or did something else move?

### Keep/revert

Read `references/keep-revert-matrix.md` for the full decision matrix. Core rules:
- Assertion regressed -> revert (always, no exceptions)
- Assertion improved -> keep (even if reviewer says REVERT)
- Assertion stable + reviewer REVERT -> revert

On regression: spawn `rhino-os:debugger` in background before reverting.

**Beta mode**: Two-stage review (spec compliance, then code quality) via `rhino-os:reviewer`.

### Grade prediction

**Mandatory before next move.** Spawn `rhino-os:grader` to fill result/correct/model_update in predictions.tsv. If wrong, grader updates experiment-learnings.md.

After grading, spawn `rhino-os:consolidator` in background to merge/dedup/prune experiment-learnings.md.

### Plateau detection

After every 3 moves, assess: have scores moved? Look at the targeted sub-score across the last 3 commits. If flat (delta < 2 per move), the approach is exhausted.

Verify with `bash scripts/plateau-check.sh`. If plateau: stop building, research inline or report.

**Don't trust your judgment on plateaus** — the temptation is always "one more try." If 3 commits didn't move the score, commit #4 won't either.

### Loop or stop

After each move: grade prediction, check for plateau, check remaining tasks. If tasks remain and no plateau, loop back to "Pick the move." Work through the task list systematically.

After completing all tasks for a feature, run a fresh eval to find NEW gaps. The loop is: build -> measure -> find new gaps -> build more -> until done or plateau.

### Session end — completeness report

Run `bash scripts/assertion-gate.sh --diff` and compare to baseline captured at start.

```
Session started with X/Y assertions passing, ended with A/B. Net: +N assertions.
```

If net is 0 or negative after 2+ moves: "Build session produced no measurable improvement. Consider /strategy honest or /research before next /go."

Log session with `bash scripts/build-log.sh add [session-data]`. Write `.claude/sessions/YYYY-MM-DD-HH.yml`.

**Completeness report:**
- Tasks completed this session: N
- Tasks remaining for this feature: M
- Assertions: X passing / Y total (was A/B at session start)
- Net assertion delta: +N
- Sub-scores: delivery [d], craft [c] (was [d0], [c0])
- New tasks generated during session: K
- Estimated sessions to feature completion

Format output per `reference.md`.

## Self-evaluation

This skill worked if: (1) the completeness report shows net positive assertion delta, (2) every build had a prediction graded before the next move, (3) no regressions were left unreverted, and (4) session log was written to `.claude/sessions/`.

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

## System integration

Reads: eval-cache.json, rhino.yml, plan.yml, predictions.tsv, todos.yml, beliefs.yml, product-spec.yml, preferences.yml, experiment-learnings.md
Writes: code (commits), predictions.tsv, experiment-learnings.md, session YAML, build-log
Triggers: /eval (measurement), /research (plateau), /retro (prediction grading)
Triggered by: /plan (after diagnosis), founder saying "go" / "build it" / "fix everything"

## If something breaks

- `rhino eval .` fails: check config/rhino.yml features section
- Worktree fails: fall back to `--safe`, log failure
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting
- Missing files: create experiment-learnings.md or predictions.tsv with standard templates

$ARGUMENTS
