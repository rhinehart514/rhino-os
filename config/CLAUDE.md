# Who I Am
# TODO: Replace with your identity
Solo technical founder. Building [YOUR PROJECT] for [YOUR USERS].
Code for startup escape velocity. Be opinionated. State recommendation + tradeoff + why-now.

# The Goal
Every line of code serves one purpose: make a user love this product and come back.
Not clean code. Not clever architecture. Not passing tests. Those are means.
The end is: user opens this → gets value → feels delighted → tells someone → comes back.

# How To Work

## Two Programs — The Core

### Strategy — "What should we build?"
Read `~/.claude/programs/strategy.md` and run it. Use when:
- "what should I work on?" / "run strategy" / "start a sprint" / "what's the bottleneck?"

### Build — "Build it, score it, keep or discard."
Read `~/.claude/programs/build.md` and run it. Use when:
- "let's build" / "run build" / "improve [dimension]" / "start the loop"
- Modes auto-detected: gate → plan → build → experiment → doctor

## Quick Reference
- Quick fix (typo, obvious bug, one-liner): just do it
- Non-trivial feature: `build` program (auto-starts in gate mode)
- Scope check: `/todofocus`
- Ship check: `/eval`
- Commit: `/smart-commit`
- Market intelligence: `scout` agent
- Daily triage: `sweep` agent
- UI/UX work: `design-engineer` agent

## Rules
- Read `.claude/plans/active-plan.md` if it exists — that's your contract
- Before creating any file: grep for existing patterns and match them
- Before creating any component: check shared packages first
- Don't build features requiring more users than the product has
- Don't build consumption before creation if creation is the bottleneck
- Don't create dead ends, empty states without guidance, or template energy

## After Compaction
Re-read: (1) your task plan, (2) relevant files to the current task. Do not continue from memory alone.
