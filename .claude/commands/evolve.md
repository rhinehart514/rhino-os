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

## Skill creation mode

Beyond tuning parameters, `/evolve` can create new capabilities when it detects a gap.

### Detecting capability gaps

Gaps come from three sources:
1. **`/retro` findings**: Step 3.6 logs capability gaps. If 3+ sessions show the same gap, it's real.
2. **Repeated manual patterns**: you notice yourself doing the same multi-step process across sessions without a skill for it.
3. **Founder request**: "I wish there was a /competitive-analysis command."

### The sandbox → test → promote pipeline

```
1. IDENTIFY GAP — evidence of repeated need (retro logs, manual patterns, founder request)
2. DRAFT — write skill to .claude/experiments/skills/[name].md
3. TEST — run the skill on a real task, evaluate output quality
4. PROPOSE — present to founder with test output: "Promote to .claude/commands/?"
5. PROMOTE — founder approves → move to .claude/commands/[name].md
```

### Step 1: Identify the gap

```
Gap: [what capability is missing]
Evidence: [3+ sessions or founder request]
Value: [what changes for the user if this skill exists]
```

### Step 2: Draft the skill

Write to `.claude/experiments/skills/[name].md` using this template:

```markdown
---
description: "[what this skill does]"
gap: "[what repeated need this fills]"
evidence: "[sessions/tasks where this was needed]"
status: sandbox
---

# /[skill-name]

[Full skill instructions following the pattern of existing .claude/commands/ files]

$ARGUMENTS
```

Follow the conventions of existing commands:
- System awareness section (how this skill relates to others)
- Clear steps with parallel reads where possible
- "What you never do" section
- "If something breaks" section
- Arguments section

**Limit**: max `agent.tunable.max_sandbox_skills` (default 5) active sandbox skills. If at limit, discard the least-evidenced one before creating new.

### Step 3: Test

Run the drafted skill on a real task. Evaluate:
- Did it produce useful output?
- Did it follow the system's conventions (predict, cite evidence, update model)?
- Would the founder want this to run again?

### Step 4: Propose

Present to the founder:
```
New skill: /[name]
Gap it fills: [one sentence]
Test run: [summary of test output]
Recommendation: promote to .claude/commands/ / iterate / discard
```

The founder decides. Promotion = move to `.claude/commands/[name].md`. The `.claude/commands/` gate remains — agent cannot promote without approval.

### Step 5: Promote or iterate

- **Promote**: move file from `.claude/experiments/skills/` to `.claude/commands/`. Update the skill's `status` to `promoted`.
- **Iterate**: keep in sandbox, refine based on feedback.
- **Discard**: delete from sandbox. Log as dead end if the concept was fundamentally wrong.

## Arguments

- `$ARGUMENTS` empty → full evolve loop (diagnose → propose → apply)
- `$ARGUMENTS` = "skill" → skill creation mode (identify gap → draft → test → propose)
- `$ARGUMENTS` = "status" → show current agent experiment status + sandbox skills without proposing
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
