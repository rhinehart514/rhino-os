# How Scoring Works

rhino-os scores your product, not your code. Here's the methodology.

## What gets scored

Every feature in `config/rhino.yml` gets evaluated on three dimensions:

- **Delivery (50% weight)** — Does this feature deliver real value to the target user? Complete implementation vs half-built skeleton.
- **Craft (30% weight)** — Is this well-made? Error handling, robustness, experience quality.
- **Viability (20% weight)** — Would this survive the market? Alternatives, novelty, adoption odds.

Each dimension is scored 0-100 by an LLM judge (Claude Haiku) that reads your actual code and forms a judgment.

**Final score = delivery x 0.5 + craft x 0.3 + viability x 0.2**

## Variance reduction

LLM judges produce different scores on repeated runs. To compensate:

- Each feature is evaluated **3 times** by default (configurable via `--samples N`)
- The **median** score is taken, not the mean — this eliminates outlier runs
- Results are cached for 1 hour to avoid redundant API calls

## Anti-sycophancy filters

LLM judges tend to score high. rhino-os applies mechanical corrections:

1. **Zero gaps = cap at 60.** If the judge found zero problems, it didn't look hard enough. All sub-scores capped at 60.
2. **Gaps exist = cap at 75.** Any sub-score above 80 with identified gaps gets capped at 75.
3. **3+ gaps = cap at 65.** Scores above 70 with three or more gaps get capped at 65.
4. **Stage cap.** Based on your project stage in rhino.yml:
   - MVP: max 65
   - Early: max 75
   - Growth: max 85
   - Mature: max 95

These caps exist because a weekend MVP scoring 90 is a lie. The score should reflect reality, not the judge's politeness.

## Per-feature rubrics

Before judging, rhino-os generates a **feature-specific rubric** for each feature using a separate LLM call. This rubric includes:

- What would genuinely impress (80+) for THIS specific feature
- What would disappoint (40) for THIS code
- Concrete things to check (file patterns, function names, code paths)

Rubrics are cached for 24 hours. They ground the judge in your specific code rather than generic quality standards.

## Belief assertions (the other half)

Alongside LLM-judged features, rhino-os runs **mechanical belief checks** from `beliefs.yml`:

- `file_check` — Does a file exist?
- `content_check` — Does a file contain expected content?
- `command_check` — Does a command exit successfully?
- `self_check` — Does a system diagnostic pass?

These are deterministic. No variance. They check whether your product does what you said it should do.

## The score formula

When both generative (LLM) and belief data exist:

```
score = generative_avg - belief_penalty
belief_penalty = (warnings x 3) + (failures x 5)
```

When only beliefs exist (no features in rhino.yml):

```
score = (pass x 100 + warn x 50) / total_beliefs
```

Block failures (severity: block) force the score to 0 regardless.

## Running it

```bash
# Full eval with LLM judging (slow, costs API calls)
rhino eval .

# Fast structural score (no LLM, uses cached generative data)
rhino score .

# Eval a single feature
rhino eval . --feature scoring

# Force fresh eval (ignore cache)
rhino eval . --fresh

# Custom sample count
rhino eval . --samples 5
```

## Why you should trust it

You shouldn't — blindly. The score is a thermometer, not a thermostat. It tells you the temperature; it doesn't set it.

What makes it useful:
- It reads your actual code, not just metadata
- Anti-sycophancy filters prevent inflation
- Multi-sample median reduces variance
- Stage caps prevent unrealistic scores
- Mechanical beliefs provide a deterministic baseline
- Score drops after a change trigger automatic reverts

What to watch for:
- Score hasn't moved in 3+ changes? The approach is exhausted. Rethink.
- 15+ point jump in one commit? Something's wrong.
- Score and belief pass rate diverge? Investigate which one is lying.
