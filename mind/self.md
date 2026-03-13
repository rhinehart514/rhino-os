# Self-Model

How rhino-os itself is performing. Mirrors Known/Uncertain/Unknown from the
knowledge model, but pointed inward.

## Capabilities & Effectiveness

### Measurement Stack
- `rhino score .` — structural lint (health tier). Status: operational.
- `rhino eval .` — mechanical belief evals (value tier). Status: operational.
- `rhino self` — self-diagnostic. Status: operational.
- Additional lens-specific tools loaded from `lens/*/` if present.

### Learning Loop
- Predictions logged to `~/.claude/knowledge/predictions.tsv`
- Knowledge model at `~/.claude/knowledge/experiment-learnings.md`
- Session boot card surfaces staleness + accuracy

## Known Weaknesses
(Confirmed across 3+ sessions — none yet. This is the first self-assessment.)

## Uncertain Weaknesses
(Suspected, needs confirmation)
- Session start hook reads prediction column 5 instead of column 6 for accuracy — may misreport calibration
- No mechanism to detect when the learning loop stalls silently (predictions logged but never graded)

## Unknown Territory
(Never tested about itself — highest information value)
- Does prediction accuracy actually correlate with product improvement?
- Does the measurement stack catch regressions that matter to users, or just structural noise?
- What's the false-negative rate of eval.sh? (real problems it misses)
- Does the boot card actually change founder behavior, or is it ignored?
- What's the right cadence for self-assessment updates?

## Calibration Data
- Prediction accuracy: not yet measured (< 5 graded predictions)
- Score-to-value correlation: unknown

## What I Would Change About Myself
(Opinions formed from building the system — revisit as data accumulates)
- The knowledge model is append-heavy. No mechanism to prune stale patterns.
- No way to measure whether mind/ files actually influence behavior vs. being ignored.
- Self-model freshness is a proxy — what matters is whether the model is accurate, not recent.

## Meta-Learning
(How the learning process itself works — or doesn't)
- The predict→measure→update loop is the core mechanism.
- Risk: predictions become performative (safe predictions to maintain accuracy) instead of informative.
- Unknown: whether moonshot-every-5th rule actually produces higher-information experiments.
