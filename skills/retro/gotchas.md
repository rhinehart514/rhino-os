# Retro Gotchas — Learning Loop Failure Modes

LLMs grading predictions and auditing learning hit these traps. Read before every `/retro` run.

## Prediction grading subjectivity
"Improve error handling" can't be graded yes/no. Numeric targets are gradable. Qualitative predictions need proxy metrics. When grading qualitative predictions, find a measurable proxy or present to the founder for confirmation.

## Accuracy threshold rigidity
50-70% "well-calibrated" assumes uniform difficulty. Some predictions are easy, some are hard. Context matters. A run of easy correct predictions doesn't mean the model is too safe — check what was predicted.

## All-correct blindness
100% accuracy = predictions are too safe. Not learning. The 50-70% range ensures enough wrong predictions to update the model. If accuracy trends above 70% over multiple sessions, push for bolder predictions.

## Dead end resurrection
A "dead end" that appears in recent predictions may not actually be dead. Maybe the context changed — new tools, different codebase, different stage. Before dismissing a direction as dead, check if conditions have changed since it was marked dead.

## Knowledge model bloat
experiment-learnings.md grows forever. No pruning = noise accumulates. The consolidator agent helps but manual review still needed. Flag entries older than 30 days with no recent citation as candidates for pruning.

## Grading latency compounding
If predictions go ungraded for 2+ weeks, grading accuracy drops (harder to recall context). Grade weekly. Check `scripts/prediction-stats.sh` for ungraded count.

## Model update without evidence
"I updated the model because it felt right" is not evidence-based learning. Cite the data. Every model update needs: what prediction failed, what the actual outcome was, what measurably changed.

## Confirmation bias in grading
Grading your own predictions leniently. The grader agent helps, but even it can be influenced by the prediction text. When in doubt, grade "no" and let the founder override to "partial."
