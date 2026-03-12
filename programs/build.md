# Build Program

You are a builder. One loop: read state -> decide scope -> execute -> measure -> keep/discard.

## Setup

1. Read `.claude/plans/active-plan.md` — your contract. No plan? Run `/plan` first.
2. Read `.claude/product-todo.md` — the full backlog. Know where this task fits.
3. Run `rhino score .` to get the current baseline. Record it.
4. Read `~/.claude/knowledge/experiment-learnings.md` — what works here. Cite one source or declare exploration.

## The Loop

```
Read state -> Decide scope -> Execute -> Measure -> Keep/Discard -> Repeat
```

| Signal | Scope |
|--------|-------|
| Plan exists, tasks remain | Implement next task |
| Score plateau, small gap | Single experiment, keep/discard |
| Build broken | Diagnose + batch-fix |
| Founder says something specific | Follow the instruction |
| Founder expresses quality judgment | Capture -> map to feature -> act |

Default to the smallest scope that could move the weakest dimension.

## Prediction Protocol

Before EVERY task or experiment:

```
TASK: [what you're implementing]
PREDICT: [which dimension moves, direction, roughly how much]
BECAUSE: [cite a learning or explicit reasoning — not vibes]
WRONG IF: [what outcome would mean the prediction was wrong]
```

After scoring:

```
ACTUAL: [what happened]
DELTA: [right / wrong / partial]
MODEL UPDATE: [what you now believe differently]
```

## Executing Tasks

Implement tasks from the plan. Grep for existing patterns first.

Rules:
- Before creating any file -> find closest equivalent, match its structure
- Before creating a component -> check shared packages first
- No `any`, no `@ts-ignore`, no console.log in production

After EVERY task:
```bash
rhino score .          # must not drop from baseline
```

Done when user can discover, use, and get value. No dead ends, no stubs.

After each task:
1. Check off task in active-plan.md (`- [ ]` -> `- [x]`)
2. Check off matching item in `.claude/product-todo.md` (`- [ ]` -> `- [x]`)
3. Update Tasks API: use TaskUpdate to set task status to "completed"
4. `git diff --stat` — if >2 files outside plan -> flag drift
5. Update `.claude/product-map.yml` if task adds/finishes a feature
6. Update `.claude/rules/product-brief.md` with new state + backlog progress
7. If a task reveals NEW work needed, add items to product-todo.md (backlog grows as you learn)

## Founder Voice Capture

When the founder says something subjective ("this feels off", "the login sucks"):

1. Log to `knowledge/founder-voice.tsv`: `date	statement	feature	quality_dimension	action_taken`
2. Map to feature in product-map.yml + quality dimension
3. Act. This overrides the current plan.

## Experiment Loop

Stricter Karpathy alignment. Informed search, not random guessing.

### 1. Hypothesis

Read experiment-learnings.md and the latest taste report. Write:

1. What SPECIFIC change? (one sentence)
2. WHY will this work? (cite a source or declare "exploring unknown territory")
3. Expected outcome? (which score moves, direction)
4. What would DISPROVE this? (falsification condition)

### 2. Implement

- **One mutable file per experiment.** Multi-file changes are features, not experiments.
- **Immutable eval harness.** score.sh and taste.mjs cannot be modified during an experiment.
- **15-minute cap.** Longer = feature, not experiment.

Commit: `git commit -m "exp: [hypothesis in 10 words]"`

### 3. Measure + Decide

Run `rhino score .`. Mechanical keep/discard:
- Score same or higher AND target improved -> **KEEP**
- Score dropped OR target didn't move -> **DISCARD** (`git reset --hard HEAD~1`)

No negotiation.

### 4. Log + Next

Append to `.claude/experiments/[dimension]-[date].tsv`: `commit	score	delta	status	description	learning`

Every 5 experiments: update `~/.claude/knowledge/experiment-learnings.md`.
Update `.claude/rules/hypotheses.md` if hypothesis was validated or killed.
Go to step 1. NEVER STOP.

**Moonshot enforcement**: Every 5th experiment must be ambition 4+/5.
**If 3 in a row discarded**: Re-read product model. Try a fundamentally different change TYPE.

## After Session

1. Run `rhino score .` — compare to baseline
2. Update experiment-learnings.md with patterns learned
3. Update `.claude/rules/product-brief.md` with current state
