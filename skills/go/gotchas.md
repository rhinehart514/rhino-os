# Go Gotchas — Autonomous Build Loop Failure Modes

These are specific to the /go build loop, not generic build problems.

## Assertion gaming
Builder can make assertions pass by testing the wrong thing — checking existence instead of behavior, or testing the happy path while ignoring edge cases. The reviewer catches this but costs 2x tokens. Write assertions with falsification conditions to make gaming harder.

## Speculative branching overkill
2 parallel builders for a config change is wasteful. Only speculate for genuinely uncertain approaches where the two paths are meaningfully different. One builder for deterministic work.

## Prediction grading subjectivity
"Improve error handling" is ungradable. Predictions must have numeric targets: "raise scoring from 42 to 55." The grader agent can't grade vibes — it needs a number to compare against.

## Plateau blindness
3 flat moves = stop is the rule, but sometimes the 4th move would break through. Know when to push: if the approach changed on move 3, give it one more. If the same approach produced 3 flat results, stop — it's exhausted.

## Revert trigger-happiness
Assertion regressed → revert is automatic and correct. But sometimes a temporary regression leads to a bigger win 2 commits later. The rule is still correct — revert, then build the bigger change as a single atomic commit that doesn't regress.

## Session log gaps
If /go crashes or is interrupted, session.yml never gets written. Lost learning. The session state should be written incrementally after each move, not only at the end.

## Worktree agent limitation
Builder in worktree can't spawn sub-agents (fork + Agent are mutually exclusive). Falls back to safe mode silently — doing all work itself instead of delegating. This is correct behavior but means worktree builds are slower.

## Hard gate fatigue
Founder approving every move gets tired and starts rubber-stamping. The gate's value degrades over a long session. Front-load risky moves when attention is highest.
