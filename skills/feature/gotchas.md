# Feature Gotchas

Real failure modes from past sessions. Read before creating, killing, or evaluating features.

## Definition failures

- **Generic "for" field**: `for: "developers"` makes viability scoring meaningless. /eval can't judge if you delivered value to "developers" — that's everyone and no one. Name the situation: "new contributor running the project for the first time."

- **Solution-as-delivers**: `delivers: "dashboard"` is an implementation, not value. When the delivers field describes a UI component instead of what changes for the user, eval scores drift because there's nothing to judge against.

- **Weight inflation**: Founders overweight features they enjoy. Symptom: 3+ features at weight 4-5. Ask "would the user notice if this disappeared?" — if not, it's weight 1-2.

- **Zombie weight-1 features**: A feature at weight 1 says "this barely matters." If it barely matters, kill it. Weight 1 is where features go to avoid being killed.

## Detection failures

- **Utility-as-feature**: `/feature detect` finds modules, not features. A `utils/` directory is not a feature. A feature delivers value to a named person. Utility code supports features but is not one.

- **Overlapping code paths**: Two features claiming the same file confuses eval. If `bin/eval.sh` is listed under both `scoring` and `learning`, which feature gets credit for improvements? Keep code paths distinct.

## Lifecycle failures

- **Maturity wishful thinking**: Calling a feature "working" when eval says 35. Maturity is COMPUTED from eval scores, never manually set. The score is the label. If you disagree with the label, improve the score.

- **Skipping baseline eval**: Creating a feature without running `rhino eval . --feature [name] --fresh` means you have no starting point. You can't measure improvement without a baseline.

- **Kill avoidance**: Three sessions targeting a feature with no score movement. Kill it or fundamentally rethink the approach. Continuing to iterate on a stuck feature is the most common time waste.

- **Killed feature guilt**: Killing a feature feels like wasted work. It's not. A killed feature with a clear `killed_reason:` is data. It tells future sessions what didn't work and why.

## Dependency failures

- **Undeclared dependencies**: Feature B can't work without Feature A, but `depends_on` is missing. /go wastes cycles building B while A is broken. Run `scripts/dependency-graph.sh` to catch this.

- **Dependency cycles**: A depends on B depends on A. This blocks the build loop entirely. The dependency graph script detects cycles — break them by identifying which feature is truly upstream.

- **Building downstream first**: Working on a feature that depends on a broken upstream feature. Check the dependency graph before starting a /go session. Fix upstream first.

## Scoring failures

- **Ignoring sub-score breakdown**: Total score 55 could mean d:70 c:40 v:55 (craft is the problem) or d:45 c:65 v:55 (delivery is the problem). The fix is completely different. Always check sub-scores.

- **Score-chasing without prediction**: Improving a feature score without logging a prediction means no learning. "I predict craft_score will reach 60 because X" — then measure. Wrong predictions are the valuable ones.
