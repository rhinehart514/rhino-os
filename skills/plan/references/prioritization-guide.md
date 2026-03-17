# Prioritization Guide

## Bottleneck-first rule
Always target the lowest eval_score among highest-weight active features. This is the earliest broken link in the value chain.

## When multiple features compete
Pick the one where the model is most uncertain (Unknown Territory in experiment-learnings). That's where you learn the most.

## Stage-appropriate work
- **mvp/one**: One feature, full depth. Don't spread across 3 features.
- **early/some**: Retention over acquisition. Polish existing over building new.
- **growth/many**: Distribution and onboarding. Features are secondary.

## Thesis alignment
Every proposed task should connect to a roadmap evidence item. If it doesn't, either the task is wrong or the thesis needs updating.

## Research before building
If the bottleneck feature has entries in Unknown Territory, research first. One experiment in unknown territory teaches more than ten in known territory.

## Anti-patterns

- **Comfort zone building**: Working on the feature you understand best instead of the one that matters most.
- **Score chasing**: Picking the task that moves a number fastest instead of the task that delivers the most value.
- **Infinite planning**: Reading a 9th data source when the bottleneck is already clear. Cap planning at 10 minutes.
- **Same plan, different words**: Proposing the same approach that stalled last session with slightly different framing. If it didn't work, change the approach.
