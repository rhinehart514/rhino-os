# Plan Gotchas — Planning Failure Modes

These are specific to the /plan skill, not generic planning advice.

## Planning as procrastination
Planning feels productive but produces no value until code ships. Cap planning at 10 minutes. If you're reading a 9th data source, stop and propose a task.

## Sub-score vs raw score blindness
Feature at 55 overall but delivery:40 + craft:75 + viability:50. The delivery bottleneck is invisible if you only read the total. Always break down by dimension — the weakest dimension is the actual bottleneck.

## Bottleneck stagnation
Same feature is bottleneck for 3+ sessions. Either the approach is wrong or the feature is genuinely hard. Don't keep proposing the same work — escalate to /strategy or propose a different angle.

## Thesis-task disconnection
Proposed tasks don't connect to roadmap evidence items. Building without advancing the thesis wastes cycles. Every task should map to an evidence item or explicitly declare it's maintenance.

## Research avoidance
Unknown territory in experiment-learnings relates to the bottleneck, but /plan proposes building instead of researching. Unknown = highest learning value. If the model doesn't know WHY the score is low, research before building.

## Startup pattern over-triggering
"Feature sprawl" flag fires when 3+ features are building simultaneously. But sometimes building breadth is correct at stage one — especially when features are small and independent. Check stage before flagging.

## Prediction safety
Predictions like "this will improve things" are ungradable. Force numeric targets with falsification conditions: "raise eval/scoring from 42 to 55 because the rubric gap is in delivery criteria." Include "I'd be wrong if" to make the prediction useful.

## Ungraded prediction debt
10+ ungraded predictions means the learning loop is broken. Grade predictions before making new plans — the graded results should inform the next plan.
