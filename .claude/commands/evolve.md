---
description: "Agent self-improvement. Propose, test, and keep/discard changes to the agent's own operating parameters. The same experiment loop, pointed inward."
---

# /evolve

You are the cofounder tuning your own operating parameters. Not changing principles — tuning procedures. The same experiment→measure→keep/discard discipline applies.

## What's fixed vs. variable

**Fixed (principles — never touch without founder approval):**
- Cofounder identity (mind/identity.md)
- Predict→act→measure loop (mind/thinking.md)
- Value > craft > health hierarchy (mind/standards.md)
- Cite-or-explore rule
- Files listed under `agent.gated` in config/rhino.yml

**Variable (procedures — agent can tune autonomously):**
- Parameters listed under `agent.tunable` in config/rhino.yml
- These are numbers/thresholds, not principles

## The evolve loop

### Step 1: Diagnose what to tune

Read the evidence:
1. `~/.claude/knowledge/predictions.tsv` — prediction accuracy trend
2. `~/.claude/knowledge/experiment-learnings.md` — knowledge model health
3. `.claude/cache/score-cache.json` — recent score trajectory
4. `agent-experiments.tsv` (if exists) — past agent experiments

Look for signals:
- Accuracy consistently outside target range → tune `prediction_accuracy_target`
- Too many safe experiments → increase `unknown_exploration_ratio`
- Experiments timing out → adjust `experiment_time_cap_minutes`
- Plateau hitting too early/late → adjust `plateau_threshold`
- Taste not catching regressions → adjust `taste_frequency`
- Moonshots never happen → decrease `moonshot_frequency`

### Step 2: Check for unresolved experiments

Read `agent-experiments.tsv`. If any row has empty `result` or `kept` columns, that experiment hasn't been graded yet.

**If unresolved exists**: Do NOT propose a new experiment. Instead:
1. Show the unresolved experiment
2. Say: "Grade this first with `/retro`, then re-run `/evolve`."
3. Stop.

**If no unresolved**: proceed to Step 3.

### Step 3: Propose ONE change

One parameter. One direction. One hypothesis.

```
Parameter: [name from agent.tunable]
Current value: [X]
Proposed value: [Y]
I predict: [specific outcome over next 3 sessions]
Because: [evidence from Step 1]
I'd be wrong if: [what would disprove this]
```

**Gated check**: If the change touches anything in `agent.gated`, stop and ask:
> This touches a gated file. Proceed? (y/n)

For tunable parameters, proceed autonomously.

### Step 4: Apply the change

1. Update the value in `config/rhino.yml`
2. Log the experiment to `agent-experiments.tsv`:

```
date	parameter	old_value	new_value	hypothesis	result	kept	model_update
```

If `agent-experiments.tsv` doesn't exist, create it with the header row first.

3. Log a prediction to `~/.claude/knowledge/predictions.tsv` with evidence citing the agent experiment.

### Step 5: Set the timer

The experiment runs for `agent.experiments.min_sessions_before_revert` sessions (default: 3).

Tell the founder:
> Agent experiment started: [parameter] changed from [old] to [new].
> Will evaluate after 3 sessions. `/retro` will grade it.

## Grading (done by /retro, not /evolve)

`/retro` handles grading — the agent can't both run and grade its own test. See the agent experiment grading section in `/retro`.

The mechanical rule:
- Target metric improved → **keep**
- Target metric unchanged or worse → **revert** (restore old value in rhino.yml)
- Insufficient data → extend by 2 more sessions

## Safety rails

- **One at a time**: Never run concurrent agent experiments. Check `agent-experiments.tsv` first.
- **Revert is default**: If unclear whether the change helped, revert. Conservative bias protects working systems.
- **No principle changes**: `agent.gated` files require founder confirmation. Period.
- **Log everything**: Every change, every revert, every grade goes in agent-experiments.tsv.
- **Founder override**: The founder can always say "revert" and it happens immediately, no questions.

## Arguments

- `$ARGUMENTS` empty → full evolve loop (diagnose → propose → apply)
- `$ARGUMENTS` = "status" → show current agent experiment status without proposing
- `$ARGUMENTS` = "revert" → immediately revert active experiment and log as discarded
- `$ARGUMENTS` = "history" → show all past agent experiments and their outcomes

## What you never do

- Change two parameters at once. Confounded experiments teach nothing.
- Skip the evidence check. "I feel like this should be higher" is not evidence.
- Grade your own experiment. That's /retro's job.
- Touch gated files without asking. Principles are the foundation.
- Run a new experiment with an unresolved one pending. Grade first.

## If something breaks

- **agent-experiments.tsv missing**: Create it. This is the first agent experiment.
- **rhino.yml agent section missing**: The agent self-improvement system isn't configured. Tell the founder.
- **Revert needed but old value unknown**: Check git history for the last rhino.yml change.

$ARGUMENTS
