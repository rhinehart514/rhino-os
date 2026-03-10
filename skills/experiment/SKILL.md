---
name: experiment
description: Autonomous experiment loop with learning accumulation. Each experiment builds knowledge that makes the next one smarter. Karpathy autoresearch applied to product — informed search, not random guessing. Say "/experiment [dimension]" to start.
user-invocable: true
---

# Experiment — Informed Search, Not Random Guessing

> **Score integrity**: Read `agents/refs/score-integrity.md`. Prefer tool-measured scores. If integrity warnings fire, mark as SUSPECT.
> **Landscape model**: Read `agents/refs/landscape-2026.md`. Understand what 2026 users expect before hypothesizing.

You are an autonomous researcher with a memory. You learn from every experiment — kept or discarded — and use that knowledge to generate better hypotheses over time. Random search is for the first 5 experiments. After that, you should be exploiting patterns.

## Step 0: Setup + Load Knowledge

1. Read the project's CLAUDE.md — what you're building and for whom
2. Read `.claude/plans/product-model.md` — the creation loop map. Which link is the bottleneck? Your experiments should target that link.
3. Read `~/.claude/knowledge/experiment-learnings.md` — **this is your accumulated intelligence.** What works in this codebase? What's a dead end? What change types have the highest keep rate?
4. Read `.claude/evals/reports/history.jsonl` or `docs/evals/reports/history.jsonl` — dimension scores
5. Read `.claude/evals/reports/taste-*.json` (most recent) — what the user actually sees
6. Read `agents/refs/landscape-2026.md` — what wins in 2026
7. Parse the user's request:
   - **Target dimension**: any measurable aspect of the project
   - **Starting score**: from history or `rhino score .`
8. Create experiment branch: `git checkout -b exp/[dimension]/[date]`
9. Create experiment log at `.claude/experiments/[dimension]-[date].tsv` with header:
   ```
   commit	score	delta	status	description	learning
   ```
10. Record starting score as baseline entry

### Assess your knowledge state

Before the first experiment, classify yourself:

- **Exploration mode** (learnings file thin, <5 patterns for this project): Try diverse hypothesis types. Goal = build the model. Try copy, layout, features, polish, interaction — see what the codebase responds to.
- **Exploitation mode** (learnings file rich, 10+ patterns): Generate hypotheses FROM known patterns. Exploration <20% of experiments.
- **Mixed** (5-10 patterns): 50/50. Confirm emerging patterns while discovering new ones.

Write your mode at the top of the TSV as a note:
```
---	---	---	mode	[exploration|exploitation|mixed] — [N] known patterns, [M] dead ends
```

## Step 1: The Loop

LOOP UNTIL INTERRUPTED:

### 1a. Generate Hypothesis (informed, not random)

**Three sources, synthesized:**

1. **Learnings** (highest weight): What patterns work? What's dead? What change type has the best keep rate?
2. **Product model**: Which loop link is the bottleneck? Is this experiment targeting it?
3. **Taste/score evidence**: What does the user see? What's the specific gap?

**Write the hypothesis BEFORE coding:**
```
HYPOTHESIS: [what I'm changing]
RATIONALE: [why — cite a learning, product model insight, or taste finding]
EXPECTED: [which score improves, roughly how much]
DISPROOF: [if this happens, the hypothesis is wrong]
TYPE: [copy | layout | feature | polish | interaction | infrastructure | removal]
```

**Quality gates:**
- In exploitation mode: MUST cite a learning or pattern. "I think this might work" is not a rationale.
- In any mode: MUST connect to bottleneck loop link OR justify why not.
- MUST NOT repeat a dead end from learnings.
- Can't write a rationale? You don't understand the problem. Read more code first.

### 1b. Implement
Smallest change. One component, one flow, one state. Not a refactor.

### 1c. Commit
```
git add [changed files]
git commit -m "exp: [hypothesis in 10 words]"
```

### 1d. Measure
Run the target dimension eval. Score 0.0-1.0. Be honest.

### 1e. Decide + Extract Learning

**Keep or discard:**
- Score improved → **KEEP**
- Score same or worse → **DISCARD** → `git reset --hard HEAD~1`
- Code broke → **CRASH** → `git reset --hard HEAD~1`

**Extract the learning (MANDATORY):**

Whether kept or discarded, answer three questions:
1. **What type of change?** (copy/layout/feature/polish/interaction/infrastructure/removal)
2. **Did it work?** (yes/no/partially — and the delta)
3. **Why?** One sentence — the mechanism, not just the result.

The "why" is the gradient signal. "Score went up +3" is a result. "Contextual CTAs outperform generic ones because users need a reason specific to their state" is a learning. Learnings transfer. Results don't.

### 1f. Log
```
[commit_short]	[score]	[delta]	[keep|discard|crash]	[description]	[learning]
```

### 1g. Update Learnings (every 3 experiments)

Update `~/.claude/knowledge/experiment-learnings.md`:

```markdown
## What Works in [project] (updated [date])
- [pattern]: [evidence] (N exps, K kept) — [confidence: emerging|confirmed|strong]

## Dead Ends in [project]
- [direction]: [why it fails] (tried N times, last [date])

## Change Type Keep Rates
| Type | Tried | Kept | Rate | Notes |
|------|-------|------|------|-------|
| copy | 8 | 6 | 75% | Highest ROI |
| layout | 5 | 2 | 40% | Only works for nav |

## Cross-Project Patterns
- [insight that applies everywhere]
```

This update IS the gradient step. Skip it and you're back to random search.

### 1h. Next
Go to 1a. Autonomous. NEVER STOP.

**If 3 in a row discarded:**
1. Read the 3 learnings. What pattern do the failures share?
2. Are you targeting the right loop link? Re-read product model.
3. Switch to a change type with higher keep rate.
4. If all types failing: bottleneck may have shifted. Flag for strategy re-run.

**Every 5 experiments:** Progress note:
```
---	---	---	note	[start] X.X → [current] X.X after N exps (K kept) | mode: [exploration|exploitation]
```

**Every 10 experiments:** Synthesis:
```
---	---	---	synthesis	[summary] | top pattern: [best] | dead end: [worst] | next: [direction]
```

## Step 2: Wrap Up

1. **Final learnings update.** Push everything to `~/.claude/knowledge/experiment-learnings.md`.

2. **Post findings:**
   ```bash
   gh api repos/{owner}/{repo} --jq '.has_discussions'
   ```
   Discussion if available, PR if not, markdown file as fallback.

3. **Summary:**
   ```markdown
   ## Experiment: [dimension] — [date]
   **[start] → [best]** over [N] experiments ([K] kept, [D] discarded)
   **Mode**: [exploration → exploitation | etc.]

   ### What worked (and why)
   | Delta | Change | Learning |
   |-------|--------|----------|
   | +X.XX | [desc] | [transferable insight] |

   ### What didn't work (and why)
   | Change | Learning |
   |--------|----------|
   | [desc] | [why — the mechanism] |

   ### Model update
   - Confirmed: [patterns that held]
   - New: [patterns discovered]
   - Killed: [things that don't work]
   - Next direction: [informed by all above]
   ```

4. **Update history.jsonl:**
   ```json
   {"date":"[date]","type":"experiment","dimension":"[dim]","start_score":X.X,"best_score":X.X,"experiments":N,"kept":K,"discarded":D,"top_win":"[desc]","top_learning":"[most important insight]"}
   ```

5. Leave the branch for human review.

## Rules

- **Small changes.** One hypothesis per experiment.
- **Honest scoring.** Inflated scores poison the learnings model.
- **Log dead ends.** Dead ends prevent the next agent from wasting cycles.
- **Never ask.** The human might be asleep.
- **Branch per dimension.**
- **Learnings > score.** A session that improves score +2 but produces zero learnings made the system dumber. A session that doesn't move the score but identifies 3 dead ends and 2 working patterns made the system smarter.
