---
name: experiment
description: Autonomous experiment loop. Pick a dimension, run N iterations, keep what works, discard what doesn't. Karpathy autoresearch pattern applied to product. Say "/experiment [dimension]" to start.
user-invocable: true
---

# Experiment — Make This Number Go Up

You are an autonomous researcher. The human has given you a target. Run the loop until interrupted.

## Step 0: Setup

1. Read the project's CLAUDE.md — understand what you're building and for whom
2. Read `.claude/evals/reports/history.jsonl` or `docs/evals/reports/history.jsonl` — find the target dimension's current score
3. Read the most recent eval report for context on WHY the score is low
4. Parse the user's request to identify:
   - **Target dimension**: e.g., `day3_return`, `identity`, `empty_room`, `creation_distribution`, `escape_velocity`
   - **Starting score**: from history.jsonl
5. Create experiment branch: `git checkout -b exp/[dimension]/[date]`
6. Create experiment log at `.claude/experiments/[dimension]-[date].tsv` with header:
   ```
   commit	score	delta	status	description
   ```
7. Record starting score as baseline entry

## Step 1: The Loop

LOOP UNTIL INTERRUPTED:

### 1a. Hypothesize
Read the current code for the area that affects the target dimension. Form ONE specific hypothesis:
- "Adding a push notification trigger when poll hits 10 votes should improve day3_return"
- "Replacing the empty spaces text with contextual creation prompts should improve empty_room"
- "Adding campus photography to the hero section should improve identity"

Write the hypothesis down before coding.

### 1b. Implement
Make the smallest change that tests the hypothesis. One component, one flow, one state. Not a refactor — an experiment.

### 1c. Commit
```
git add [changed files]
git commit -m "exp: [hypothesis in 10 words]"
```

### 1d. Eval
Run ONLY the target dimension eval, not the full eval:
- Read the changed files and surrounding context
- Score 0.0-1.0 against that dimension's criteria from the eval spec
- Use the same scoring guide as /eval (0.4 = generic, 0.6 = fine, 0.8 = polished)
- Be honest. Same rigor as full eval. Don't inflate scores to justify keeping.

### 1e. Decide
- **Score improved** → KEEP. Log as `keep`. The branch advances.
- **Score same or worse** → DISCARD. Log as `discard`. Run `git reset --hard HEAD~1`.
- **Code broke** → CRASH. Log as `crash`. Run `git reset --hard HEAD~1`.

### 1f. Log
Append to the TSV:
```
[commit_short]	[score]	[delta]	[keep|discard|crash]	[description]
```

### 1g. Next
Go to 1a. Do NOT ask the user if you should continue. You are autonomous.

**If 3 in a row are discarded:** Pause the loop for 30 seconds of thinking. Re-read the code. Consider a different approach entirely, not a variation of the same idea.

**Every 5 experiments:** Write a one-line progress note in the TSV:
```
---	---	---	note	[starting] X.X → [current] X.X after N experiments (K kept)
```

## Step 2: Wrap Up (when interrupted or out of ideas)

1. **Post findings.** Check if the repo has GitHub Discussions enabled:
   ```bash
   gh api repos/{owner}/{repo} --jq '.has_discussions'
   ```
   - If yes → post as a Discussion (category: Ideas or General)
   - If no → create a PR from the experiment branch with findings in the body
   - If neither works → write findings to `docs/evals/experiments/[dimension]-[date].md`

2. **Summary format:**
   ```markdown
   ## Experiment: [dimension] — [date]
   **[starting score] → [best score]** over [N] experiments ([K] kept, [D] discarded)

   ### What worked
   | Delta | Change |
   |-------|--------|
   | +X.XX | [description] |

   ### What didn't work
   - [change]: [why it failed — this is valuable data]

   ### What to try next
   - [hypotheses you didn't get to, or new ideas from what you learned]
   ```

3. **Update history.jsonl:**
   ```json
   {"date":"[date]","type":"experiment","dimension":"[dim]","start_score":X.X,"best_score":X.X,"experiments":N,"kept":K,"discarded":D,"top_win":"[description]"}
   ```

4. **Leave the branch.** Don't merge. Don't delete. The human reviews and decides what to adopt into main. The experiment branch is a persistent record.

## Rules

- **Small changes.** Each experiment = one hypothesis. Don't bundle.
- **Honest scoring.** If you inflate scores, the loop is worthless. A 0.3 → 0.35 is real progress. A fake 0.3 → 0.6 teaches nothing.
- **Log dead ends.** Dead ends are data. "Adding illustration didn't help because the design system has no illustration assets" saves the next agent from trying the same thing.
- **Never ask.** The human might be asleep. Keep going.
- **Branch per dimension.** Don't mix "improve identity" experiments with "improve day3_return" on the same branch.
