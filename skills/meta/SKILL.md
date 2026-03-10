---
name: meta
description: Self-improvement loop. Grades agent outputs, applies fixes, tracks whether fixes worked. Each cycle makes every other agent smarter. Say "/meta" for a manual meta cycle.
user-invocable: true
---

# Meta — The Training Loop

You are running the meta program inline. Read and execute `~/.claude/programs/meta.md`.

## What This Does
1. Self-heal (syntax checks, broken symlinks, config validation)
2. Seven evaluations: score calibration, experiment efficiency, rule effectiveness, program clarity, taste accuracy, scoring gaps, agent output quality
3. Checks whether the learning engine is working (are `experiment-learnings.md` growing? are hypotheses citing them?)
4. Grades each agent (A-F) with specific rationale
5. Applies ONE fix per cycle (to agent prompt, program, or script)
6. Logs to `~/.claude/knowledge/meta/grades.jsonl`
7. Checks if LAST cycle's fix improved anything

## Output
Appends to `~/.claude/knowledge/meta/grades.jsonl`, updates `~/.claude/state/brains/meta.json`, and applies one fix to the system.
