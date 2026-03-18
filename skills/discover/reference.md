# /discover Reference — Output Templates

Loaded on demand. The main pipeline logic is in SKILL.md. Mode-specific output formats are in templates/discovery-report.md.

---

## Spec schema reference

The product spec schema lives at `skills/onboard/templates/product-spec-template.yml`. Key sections:

| Section | Purpose | Quality signal |
|---------|---------|----------------|
| `who` | Specific person + situation + evidence | Not a category |
| `change` | Before/after/one sentence | Measurable |
| `core_loop` | Trigger/action/reward/frequency | Loop runs often |
| `first_experience` | Steps 1-3 + time to value | Under 10 min |
| `return_trigger` | Mechanism/data lock-in/habit cue | Has pull |
| `not_building` | Kill list (min 3, target 5+) | Courage to cut |
| `competitors` | Name/what/how differ | Honest gaps |
| `signals` | Behavior-based metrics | Measurable |
| `pricing` | Model/why/free tier | Not empty |
| `why_now` | Market shift/window/tech | 2026-specific |
| `pivot_triggers` | Signal/response with numbers | Specific thresholds |

## Auto-wiring map

After spec approval, /discover creates:

| Spec section | Wires to | Config file |
|-------------|----------|-------------|
| `change.in_one_sentence` | Roadmap thesis | `.claude/plans/roadmap.yml` |
| `signals` | Roadmap evidence items | `.claude/plans/roadmap.yml` |
| `core_loop` | Core feature (weight: 5) | `config/rhino.yml` |
| `first_experience` | Onboarding feature (weight: 4) | `config/rhino.yml` |
| `return_trigger` | Retention feature (weight: 4) | `config/rhino.yml` |
| `signals` | Mechanical assertions | `config/beliefs.yml` |
| `pivot_triggers` | Monitoring assertions | `config/beliefs.yml` |
| `competitors` | Competitive landscape | `.claude/plans/strategy.yml` |
| `why_now` | Market timing | `.claude/plans/strategy.yml` |
| `who` + `change` | Value section | `config/rhino.yml` |

## Agent spawning

Define mode spawns 3 agents in parallel:

```
Agent(subagent_type: "rhino-os:customer", prompt: "...", run_in_background: true)
Agent(subagent_type: "rhino-os:market-analyst", prompt: "...", run_in_background: true)
Agent(subagent_type: "rhino-os:explorer", prompt: "...")  # only if repo has code
```

Compare (vs) mode spawns market-analyst.

All agents have persistent memory (memory: user) — they accumulate knowledge across sessions.

## Script reference

| Script | Purpose | When |
|--------|---------|------|
| `discovery-scan.sh` | Full state scan | Start of every session |
| `spec-quality.sh` | Grade spec 0-100 | After generating/refining spec |
| `spec-wire.sh` | Compute wiring gaps | Before auto-wiring |
