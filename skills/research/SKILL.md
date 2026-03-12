---
name: research
description: "When you're stuck. Researches taste dimensions, market landscape, ideas, or eval engineering. Say /research [topic] to dig in."
user-invocable: true
argument-hint: "[topic / ideas / eval [concept]]"
---

# Research — When You're Stuck

## Research Budget Rule

Every research session has a budget (default 30 minutes). When the budget is reached OR the session ends, output MUST include:

### Research Output (required)
```
Hypothesis: [specific, testable belief about users/product/market]
Evidence: [what was found — links, data, quotes, observations]
Confidence: low / medium / high
Build implication: [exactly what to build, deprioritize, or not build as a result]
Time spent: [N min]
```

If this template cannot be filled, research produced no value. Say so explicitly.
Research without a hypothesis is reading, not research.

## Input

Arguments: $ARGUMENTS

## Setup

1. Read `~/.claude/knowledge/experiment-learnings.md` — what's already known
2. Read `.claude/rules/hypotheses.md` — current beliefs

## Route the Request

| Input | Mode |
|-------|------|
| `/research` (no args) | Auto-detect weakest taste dimension or current blocker |
| `/research [taste dimension]` | Taste research for that dimension |
| `/research [market topic]` | Market/landscape research |
| `/research ideas` | Ideation — brainstorm options across build/messaging/landscape |
| `/research eval [concept]` | Eval engineering — convert subjective concept to measurable eval |
| `/research [question]` | General research — WebSearch + synthesize |

Taste dimension names: `hierarchy`, `breathing_room`, `contrast`, `polish`, `emotional_tone`, `information_density`, `wayfinding`, `distinctiveness`, `scroll_experience`, `layout_coherence`, `information_architecture`

## Mode: Taste Research

1. WebSearch for patterns, exemplars, anti-patterns for the dimension
2. WebFetch top 3-5 results, extract specific mechanisms
3. Synthesize -> write to `~/.claude/knowledge/taste-knowledge/{dimension}.md`

## Mode: Market Research

1. WebSearch for the topic — competitors, trends, evidence
2. WebFetch top results, extract opinionated positions (not trends)
3. Synthesize findings into actionable knowledge
4. Write to `~/.claude/knowledge/research/{topic-slug}.md`

## Mode: Eval Engineering

Convert subjective concept into a runnable eval:

1. WebSearch for measurement methods (validated scales, heuristic frameworks, design principles)
2. Extract: what it measures, how, what the output looks like, can an LLM assess it from code?
3. Write eval to `~/.claude/knowledge/evals/{topic-slug}.md`
4. Register in `~/.claude/knowledge/evals/_index.md`

## Mode: Ideation

1. Read product-map.yml — identify weak pyramid layers and loop links
2. Read hypotheses.md — current beliefs to challenge
3. WebSearch for products solving similar problems
4. Generate 5 options across build / messaging / landscape layers
5. Write to `~/.claude/knowledge/research/ideation-[date].md`

## Mode: General Research

1. WebSearch for the question/topic
2. WebFetch top 3-5 results
3. Synthesize into actionable knowledge
4. Write to `~/.claude/knowledge/research/{topic-slug}.md`

## Output

Always ends with:

```
## Research Complete

**Topic**: [what was researched]
**Key finding**: [one actionable insight]
**Saved to**: [file path]
**Next step**: [what to do with this — usually "run /build"]
```

Update `.claude/rules/hypotheses.md` if research validates or kills a hypothesis.
