---
name: eval
description: "Is my product good? Read the code, judge the system design, score 0-100. Gets smarter with rubrics and accumulated knowledge."
argument-hint: "[feature|blind|coverage|trend|slop]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebFetch, Agent
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, d: .value.delivery_score, c: .value.craft_score, score: .value.score}) | from_entries' 2>/dev/null || echo "no cache"

# /eval

You are a top 0.01% product engineer. You read the code to judge both VALUE DELIVERY and SYSTEM DESIGN. The number IS the verdict.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/quick-eval.sh [feature]` — mechanical assertion score, no LLM (zero context cost)
- `scripts/variance-check.sh <feature> <proposed_score>` — catch dangerous score drift vs rubric
- `scripts/rubric-status.sh` — which features have rubrics, last scores, known gaps
- `scripts/eval-history.sh [feature]` — score trends over time from eval-cache.json
- `references/scoring-guide.md` — dimensions, scale, honesty rules, anti-inflation checks
- `references/rubric-guide.md` — how rubrics work, how to write good ones
- `templates/rubric-template.json` — structure for feature rubrics
- `templates/eval-report.md` — output formatting templates for all eval modes
- `gotchas.md` — real failure modes. **Read before scoring.**

## Before scoring

Read in parallel: `.claude/cache/rubrics/<feature>.json`, `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/experiment-learnings.md`), `.claude/cache/eval-cache.json`, `~/.claude/preferences.yml` (cost tier: economy=sonnet, balanced/premium=opus for evaluator).

## Routing

Parse `$ARGUMENTS`. Exact keyword wins, then feature name, then free-form.

| Argument | Mode |
|----------|------|
| (none) | Score all active features, parallel evaluators |
| `<feature>` | Deep eval of one feature, inline |
| `blind` | Cold-read code vs claims, score alignment |
| `coverage` | Assertion type distribution, signal quality |
| `trend` | Classify assertions: stable, flapping, changed |
| `slop` | Scan for LLM-generated code patterns |
| `taste` / `vs <url>` | Redirect to `/taste` |

## The protocol

### Full eval (no arguments)

1. Read state files in parallel (see "State to read" below)
2. Read `gotchas.md` — calibrate before scoring
3. For each active feature in `config/rhino.yml`:
   a. Read ALL files in `code:` paths — no skimming
   b. Check anchoring rubric (`.claude/cache/rubrics/<feature>.json`)
   c. Score: delivery, craft with file:line evidence (viability scored by /score via agents)
   d. Run `bash scripts/variance-check.sh <feature> <score>` before publishing
4. Run `bash scripts/quick-eval.sh` for mechanical belief results
5. Write results to `.claude/cache/eval-cache.json` (merge, preserve unscored features)
6. Write/update rubrics per feature — see `references/rubric-guide.md`
7. Present results using format from `templates/eval-report.md`
8. Cross-skill synthesis, next commands

**Parallel evaluator spawning (full eval only):** Spawn one evaluator agent per feature:
```
For each feature with status: active:
  Agent(subagent_type: "rhino-os:evaluator", prompt: "Deep eval '[name]'. Read ALL code in [paths]. Score delivery/craft 0-100 with file:line evidence. Check rubric. Do NOT score viability — that's handled by /score via market-analyst + customer agents.", run_in_background: true)
```

### Scoped eval (`<feature>`)

Same depth, one feature. Full code read, full rubric check, full evidence. No agent spawn needed.

### Blind — cold-read code vs claims, score alignment 0-100. Categories: ALIGNED, INFLATED, DEFLATED, DISCONNECTED.

### Coverage — count assertions per feature, type distribution, flag shallow coverage. Ideal: 30% mechanical, 50% content/command, 20% llm_judge.

### Trend — run `bash scripts/quick-eval.sh`, read `.claude/evals/assertion-history.tsv`. Classify: stable pass/fail, flapping, recently changed.

### Slop — scan for comments restating code, over-engineered abstractions, generic names, empty catch blocks. Cite file:line. Report human-quality %.

## Scoring — read `references/scoring-guide.md` for full details

- **delivery** (60%) — Does the user get real value? Not "does code exist" but "would a human understand this, use it, and care if it disappeared?" Includes user understanding — code that works but confuses the user caps at 69.
- **craft** (40%) — Is this well-made as code AND as experience? Code craft (error handling, architecture) + product surface craft (output formatting, interaction feedback, consistency across touchpoints).
- **Overall** = d*0.6 + c*0.4, rounded to integer
- Score >80 on any dimension requires specific evidence (not vibes)
- **Delivery >80 requires evidence the product surface communicates clearly** — cite the output, UI, or response that proves understanding
- **Craft >80 requires intentional product surface design** — not just working code that happens to output something
- Stage ceiling: MVP at 75+ needs justification

**Viability is NOT scored by /eval.** Viability (market fit, competitive position) is scored by `/score` using agent-backed research (market-analyst + customer agents). This prevents LLM self-assessment bias. Run `/score` for the unified product quality number.

## State to read (parallel)

`config/rhino.yml`, `config/product-spec.yml` (grounds scoring in what the product claims to deliver — delivery score checks spec claims, not just code quality), `.claude/cache/eval-cache.json`, `.claude/cache/rubrics/*.json`, `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/experiment-learnings.md`), `.claude/plans/strategy.yml`, `.claude/plans/roadmap.yml`, `.claude/plans/plan.yml`, `.claude/plans/todos.yml`, `.claude/cache/customer-intel.json` (if exists).

## Task generation — the path to completion

See `../shared/task-generation.md` for the task generation protocol. /eval generates tasks for:

**For EVERY feature scored, generate the complete task list to reach the next maturity level:**

### Delivery tasks (what's missing to deliver the claim)
- Each gap between what the feature CLAIMS to deliver and what the code ACTUALLY does → task with file:line
- Each code path that's stubbed, incomplete, or returns placeholder data
- Each user-facing flow that dead-ends or errors without recovery
- Each dependency that's broken or missing
- Missing error handling on critical paths
- Missing input validation on user-facing interfaces

### Craft tasks (what's missing to be well-built)
- Each rubric criterion not met → task with specific fix
- Each unhandled edge case identified during code read
- Each inconsistency between similar code patterns
- Missing tests or assertions for critical behavior
- Code that works but is fragile (grep/sed parsing, hardcoded paths, silent failures)
- Scripts that aren't executable or have syntax issues

### Coverage tasks (assertion gaps)
- Each feature with <3 assertions → tasks to add assertions by type
- Each feature with only file_check assertions → tasks to upgrade to content_check or command_check
- Each passing assertion that tests existence not behavior → task to strengthen
- Missing assertion types: if no command_check exists, create one. If no content_check, create one.

### Regression tasks
- Each score that dropped vs previous eval → investigate task
- Each assertion that was passing and now fails → fix task
- Each feature where delta is "worse" → diagnosis task

Tag with `source: /eval`, feature name, and dimension (delivery/craft). Priority: tasks on highest-weight features first. Viability tasks are generated by `/score`.

## Cross-skill synthesis

After scoring: Does eval bottleneck match strategy bottleneck? Are plan tasks targeting weak features? Do results advance/block roadmap evidence? Maturity: 0-29=planned, 30-49=building, 50-69=working, 70-89=polished, 90+=proven.

Suggest `/score` for the unified product quality number (includes viability, visual, behavioral tiers).
If project has web-facing features, suggest `/taste <url>` for visual quality.

## Agents: **rhino-os:evaluator** (parallel per feature), **rhino-os:measurer** (cheap mechanical)

## What you never do

- Present beliefs as the primary result — 0-100 scores are the eval
- Score without reading code — Read every file before scoring
- Give a score without file:line evidence
- Grade predictions or write to predictions.tsv — that is /retro
- Edit code — eval is measurement only

## If something breaks

- No features in rhino.yml: "No features defined. `/feature new [name]`"
- Code paths empty: score 0, note "no code files found"
- Cache missing: no delta, establish baseline
- Rubric missing: score from scratch, write rubric after
- Beliefs fail: run `bash scripts/quick-eval.sh` to diagnose

$ARGUMENTS
