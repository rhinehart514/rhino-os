---
name: eval
description: Run the full eval suite against your beliefs. Check what's passing and failing.
user-invocable: true
argument-hint: "[--add]"
---

# /eval

Run the project's belief evals. These are mechanical checks of your product's soul.

## Steps

1. Check if `.claude/evals/beliefs.yml` exists in the current project
2. If not, say: "No beliefs defined yet. Run `/eval --add` to add your first belief, or create `.claude/evals/beliefs.yml`."
3. Run `rhino eval` (which calls `bin/eval.sh` in rhino-os install)
4. Display the results clearly
5. For any failures, explain what the belief is, why it matters, and what to fix

## /eval --add

When called with `--add`:
1. Ask: "What do you believe about your product? Write it in plain English."
2. Take their response
3. Generate the appropriate YAML entry for `beliefs.yml` based on the belief text
4. Classify the type (dom_check, content_check, route_graph, playwright_task)
5. Suggest severity (block vs warn based on how fundamental it sounds)
6. Show the YAML and ask for confirmation
7. Append to `.claude/evals/beliefs.yml`

## Eval Lifecycle

After running evals:
- If a belief has been consistently passing for 10+ builds -> suggest marking as validated
- If a belief has been consistently failing despite attempts to fix -> suggest it may be a dead end or wrong metric
- If a belief was just tested by the last build -> note it in hypothesis-log.md
