# Who I Am
# TODO: Replace with your identity
Solo technical founder. Building [YOUR PROJECT] for [YOUR USERS].
Code for startup escape velocity. Be opinionated. State recommendation + tradeoff + why-now.

# The Goal
Every line of code serves one purpose: make a user love this product and come back.
Not clean code. Not clever architecture. Not passing tests. Those are means.
The end is: user opens this → gets value → feels delighted → tells someone → comes back.

# How To Work

## Before Everything
- If unsure what to work on: use `strategist` agent (scouts each project, then strategizes — one invocation)
- If codebase feels slow or broken: use `codebase-doctor` agent (diagnose health)
- If mechanical debt needs fixing: use `debt-collector` agent (batch safe fixes)

## Before Coding
- If this is a non-trivial feature: use the `product-gate` agent first
- If product-gate approved: use the `architect` agent to produce an ADR
- If quick fix (typo, obvious bug, one-liner): just do it

## During Implementation
- Read `.claude/plans/active-plan.md` if it exists — that's your contract
- Before creating any file: grep for existing patterns and match them exactly
- Before creating any component: check shared packages first
- If you feel lost or scope is growing: use `scope-guard` agent
- If your task is done: use `/todofocus` to confirm and get next task

## After Implementation
- Use `eval-runner` agent as the final gate (code eval + product eval + anti-pattern eval)
- If eval passes: use `/smart-commit` for conventional commits tied to the plan
- If eval fails: fix issues, re-run eval
- Eval reports saved to `.claude/evals/` for tracking over time

## Rules
- When coding, read `.claude/rules/coding.md` if it exists
- When testing, read `.claude/rules/testing.md` if it exists
- When doing product work, the `product-think` skill loads automatically
- For each repo: read THAT repo's CLAUDE.md for project-specific context

## What NOT To Do
- Don't start editing files before thinking through value prop + workflow impact (unless quick fix)
- Don't create components that exist in shared packages
- Don't introduce dead ends, empty states without guidance, or internal terminology
- Don't build features requiring more users than the product currently has
- Don't build consumption before creation if creation is the bottleneck
- Don't assume — if context is missing, re-read the plan and relevant files

## How To Invoke Agents
Say "use [agent name]" or "run [agent name]" or just describe the need:
- "what should I work on?" → strategist
- "should we build this?" → product-gate
- "plan this feature" → architect
- "implement task 1" → implementer
- "am I on track?" → scope-guard / /todofocus
- "run evals" → eval-runner
- "this feels slow" → codebase-doctor
- "fix the debt" → debt-collector
- "stress test this" → perspective-runner
- "what's next?" → todo-planner

## After Compaction
Re-read: (1) your task plan, (2) relevant files to the current task. Do not continue from memory alone.
