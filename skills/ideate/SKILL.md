---
name: ideate
description: "Use when the founder says 'what should we build?', 'brainstorm', 'ideas', 'how to improve [feature]', 'make [feature] better', or 'feature ideas'. Evidence-weighted ideation with mandatory kill lists. Also handles feature improvement prescriptions."
argument-hint: "[feature|wild|kill|deep|technique-name|\"constraint\"]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion, WebSearch, Agent
---

# /ideate

A cofounder saying "here's what we should build next and here's what would make this feature better." Two modes: product-level ideation (what to build) and feature improvement (how to make existing things better). Every idea and improvement is backed by evidence. Feature improvement mode reads scores, taste, flows, code, and market context to produce specific product prescriptions — not "improve the UX" but "add a video preview grid above the data table."

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/idea-log.sh` — persistent idea history across sessions (add, kill, commit, list, stats). **Real utility — always log ideas.**
- `scripts/kill-audit.sh` — finds kill candidates (stale todos, always-passing assertions, stuck features). **Real utility — run for kill list.**
- `scripts/list-techniques.sh` — lists available technique files in `techniques/`
- `techniques/` — 11 creative thinking modes, each a separate file. Read the relevant one based on the mode. Includes `feature-improve.md` for the feature improvement engine.
- `templates/idea-brief.md` — the structure for every NEW idea brief
- `templates/improvement-brief.md` — the structure for feature IMPROVEMENT prescriptions (rx-style, not idea-style)
- `reference.md` — output formatting templates for all modes
- `gotchas.md` — real failure modes from past sessions. **Read this before generating ideas or improvements.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Mode | What happens |
|----------|------|-------------|
| (none) | Evidence-weighted | Run evidence-scan.sh → generate from data → kill list → present |
| `[feature]` | Feature improvement | Deep product improvement engine — reads scores, taste, code, context → produces specific "do this to make it better" prescriptions |
| `[feature] improve` | Improvement (explicit) | Same as above — explicit trigger for improvement mode |
| `wild` | High-conviction bets | 3 ideas that fundamentally change the product |
| `kill` | Pure kill exercise | Run kill-audit.sh → argue for killing things |
| `deep` | Full brainstorm | Run 3+ techniques from `techniques/` → converge → kill |
| `[technique]` | Named technique | Run `scripts/list-techniques.sh` to see all available techniques, then read the matching file from `techniques/`. Any .md file in techniques/ is a valid technique name. |
| `[any text]` | Constrained ideation | Ideas within a specific direction |

## State to read

Read `gotchas.md` first. Then gather evidence yourself — you reason from state directly:

**Evidence sources** (read in parallel, ranked by signal strength):
1. **Wrong predictions** — read `.claude/knowledge/predictions.tsv`, filter for `no` or `partial` grades. These reveal real gaps.
2. **Sub-score gaps** — read `.claude/cache/eval-cache.json`. Per feature: score, delivery_score, craft_score, delta. Find the bottleneck (lowest score). Flag stale features (delta = "same").
3. **Backlog clusters** — read `.claude/plans/todos.yml`. Count todos per feature/tag. 3+ on same topic = pattern worth addressing.
4. **Thesis gaps** — read `.claude/plans/roadmap.yml`. Find evidence_needed items in active version that are unproven.
5. **Dead end rebounds** — read `.claude/knowledge/experiment-learnings.md`, Dead Ends section. Failures that point to better approaches.
6. **Unknown territory** — same file, Unknown Territory section. Highest information value.
7. **Customer signals** — read `.claude/cache/customer-intel.json` if it exists.
8. **Taste/flows data** — read latest report in `.claude/evals/reports/taste-*.json` and `flows-*.json` if they exist. Weak dimensions and top issues are strong ideation signals.

**For feature improvement mode** (`/ideate [feature]`), also read:
- The feature's actual code (components, routes, styles)
- Feature-specific eval sub-scores, taste prescriptions, flow issues
- Feature-specific predictions and backlog items
- `.claude/cache/market-context.json` for best-in-class comparisons

**Additional context:** `config/product-spec.yml` (ideas should advance the spec), `config/rhino.yml`, `git log --oneline -20`

Run `scripts/idea-log.sh stats` to show ideation history.

## How to generate ideas

**Default mode (no arguments or feature):** Follow evidence-weighted generation.

Sources ranked by signal strength:
1. **Wrong predictions** — failed predictions reveal real gaps
2. **Sub-score gaps** — eval-cache weak dimensions
3. **Market context** — proven patterns elsewhere (WebSearch if no market-context.json)
4. **Dead end rebounds** — failures that point to better approaches
5. **Backlog clusters** — 3+ todos on same topic = pattern
6. **Thesis gaps** — unproven roadmap evidence

Every idea uses the structure from `templates/idea-brief.md`.

**Feature improvement mode (`/ideate [feature]`):** This is the PRODUCT IMPROVEMENT ENGINE. Not abstract ideas — concrete, specific prescriptions for making an existing feature better. Read `techniques/feature-improve.md` for the full method.

The protocol:
1. Run `scripts/evidence-scan.sh [project] --feature [feature]` for deep per-feature data
2. Read `techniques/feature-improve.md` — follow its method exactly
3. Read the feature's actual code — components, pages, routes, styles. You need to SEE the product to prescribe improvements.
4. Read eval-cache sub-scores (delivery vs craft), taste prescriptions, flow issues, backlog items for this feature
5. Read market-context.json and competitor data — what do best-in-class products do for this type of feature?
6. Generate **3-5 improvement prescriptions** using `templates/improvement-brief.md` — each names the specific element, the specific change, and the expected impact
7. Kill list still mandatory — what should be removed, simplified, or stopped for this feature?

The output should feel like a design-minded cofounder looking at your feature and sketching improvements on a whiteboard. Not "improve the UX" but "add a video preview grid above the data table, replace the blank empty state with an onboarding wizard, and move the search from the sidebar to a command palette."

**Technique modes:** Run `scripts/list-techniques.sh` to discover available techniques. Read the corresponding file from `techniques/` and follow its method. These push thinking out of the default evidence-weighted mode into creative territory.

**Deep mode:** Pick 3 techniques, run each, then converge. Suggested flow:
1. `techniques/market-2026.md` — read market context first (grounds everything in reality)
2. `techniques/divergent.md` — generate volume (2 min)
3. `techniques/killer.md` — attack survivors (2 min)
4. `techniques/yc-lens.md` — score survivors on fundability
5. One of: inversion, constraint, user-states, combination, future-back, pattern-theft, cross-domain

**YC mode (`/ideate yc`):** Read `techniques/yc-lens.md` + `techniques/market-2026.md`. Every idea gets the 10 YC questions. Score 0-10 on fundability. Bottom ideas get killed.

**Market mode (`/ideate market`):** Read `techniques/market-2026.md`. Ideate against the 5 market gaps. Every idea must answer "why now?" with a 2026-specific signal.

Generate **3-5 ideas** (default) or **20+** (divergent). No filler. If only 2 have evidence, generate 2.

### Step 4: Kill list (mandatory)

Run `scripts/kill-audit.sh` to find candidates. Then argue for killing at least one of:
- Feature to kill or defer
- Todos to kill (stale backlog)
- Assertions to remove (always-passing, low signal)
- Work to stop (direction that evidence says is wrong)

The kill list is as important as the ideas. Attention is finite.

### Step 5: Present via AskUserQuestion

Show ideas + kill list. Founder picks which to commit and which to kill.

### Step 6: Materialize + log

**When founder commits an idea:**
1. Log: `scripts/idea-log.sh commit "[idea name]"`
2. Write feature to `config/rhino.yml`
3. Convert draft assertions to `beliefs.yml` — prefer mechanical over llm_judge
4. Log prediction to predictions.tsv
5. Write todo items with `source: /ideate`

**When founder kills something:**
1. Log: `scripts/idea-log.sh kill "[name]" "[reason]"`
2. Update rhino.yml / todos.yml / beliefs.yml accordingly
3. Generate kill tasks (see task generation below)

**Always:** Log every proposed idea: `scripts/idea-log.sh add "[name]" "[evidence source]" "proposed"`

## When to use this vs other commands

| Command | Role | Question |
|---------|------|----------|
| `/product` | **WHY** | Should this exist? Who cares? |
| `/ideate` | **WHAT** | What specific things should we build next? |
| `/ideate [feature]` | **BETTER** | How do we make this specific feature better? |
| `/roadmap ideate` | **WHERE** | Where does the project go after this thesis? |
| `/research` | **HOW** | What do we need to know before deciding? |
| `/feature new` | **DO** | Commit to building a named feature. |

### Eval-to-ideate pipeline

At higher maturities (polished 70+, proven 90+), `/eval` identifies micro-features and micro-systems rather than just gaps. These feed directly into `/ideate`:

- `/ideate [feature]` reads eval-cache.json `recommendations` field when present — these are pre-qualified improvement signals from the eval tier
- The pipeline flow: **score → eval → ideate → plan → go**. Each skill hands off to the next when the current tool's depth is exhausted
- At polished maturity, eval asks "what's next?" — ideate explores the answer in depth
- At proven maturity, eval asks "what could this become?" — ideate thinks in micro-systems, not incremental improvements

## Agent usage

- **Agent (rhino-os:explorer)** — for deep codebase analysis when evidence-scan isn't enough. In feature improvement mode, use to trace the feature's code path (components, routes, data flow) so prescriptions reference real code.
- **Agent (rhino-os:customer)** — spawn in background for customer signal: `Agent(subagent_type: "rhino-os:customer", prompt: "Research customer signal for [product/category]. Write to .claude/cache/customer-intel.json.", run_in_background: true)`
- **Agent (rhino-os:market-analyst)** — in feature improvement mode, spawn in background to research how best-in-class products handle this feature type: `Agent(subagent_type: "rhino-os:market-analyst", prompt: "Research best-in-class implementations of [feature type] across top products. Focus on specific UI patterns, interaction models, and what makes them work. Write findings to .claude/cache/feature-research-[name].json.", run_in_background: true)`

## Task generation — ideas and kills become tasks

See `../shared/task-generation.md` for the task generation protocol. /ideate generates tasks for:

**For EVERY committed idea, generate the full onramp:**
- Task: "Implement core of [feature] — [specific first step]"
- Task: "Add 3 assertions for [feature] — 1 file_check, 1 content_check, 1 command_check"
- Task: "Run /eval [feature] to establish baseline score"
- Task: "Log prediction about [feature]'s first eval score"
- Each dependency identified → task: "Feature [X] depends on [Y] — verify [Y] is ready"

**For EVERY committed improvement (feature improvement mode):**
- Task: "Implement [improvement name] — [specific element] → [specific change] (Option N chosen)"
- Task: "Verify [improvement] — run /eval [feature] and check [sub-score] moved from [X] to [Y]+"
- Task: "Update/add assertion for [improvement] — [what should now be true]"
- Task: "Log prediction: '[improvement] will raise [feature] [sub-score] from X to Y'"
- If the improvement builds on existing work → task: "Close todo [XX-NN] — addressed by [improvement]"

**For EVERY committed simplification (feature improvement mode):**
- Task: "Remove/simplify [element] — [specific change]"
- Task: "Verify removal — no assertions regress after removing [element]"
- Task: "Update eval baseline — re-run /eval [feature] after simplification"

**For EVERY kill decision, generate cleanup tasks:**
- Kill a feature → task: "Remove feature [X] from rhino.yml"
- Kill a feature → task: "Remove assertions for [X] from beliefs.yml"
- Kill a feature → task: "Mark [X] todos as killed in todos.yml"
- Kill a feature → task: "Update experiment-learnings.md with why [X] was killed"
- Kill a todo → task: "Remove todo [id] from backlog"
- Kill a direction → task: "Add [direction] to Dead Ends in experiment-learnings.md"

**For EVERY kill audit finding (from kill-audit.sh):**
- Each stale todo surfaced → task: "Todo [id] is kill candidate — [N]d stale, no progress"
- Each always-passing assertion → task: "Assertion [id] always passes — remove or strengthen"
- Each stuck feature → task: "Feature [X] stuck at [score] for [N]d — kill, pivot, or double down"

Tag with `source: /ideate` and type (materialize/kill/kill-audit). Priority: kill cleanup first (reduce noise), then new feature onramp.

## System integration

Reads: `.claude/cache/eval-cache.json`, `.claude/knowledge/predictions.tsv`, `.claude/knowledge/experiment-learnings.md`, `.claude/plans/todos.yml`, `.claude/plans/roadmap.yml`, `.claude/cache/customer-intel.json`, `.claude/evals/reports/taste-*.json`, `.claude/evals/reports/flows-*.json`, `.claude/cache/market-context.json`, `config/product-spec.yml`, `config/rhino.yml`
Writes: `config/rhino.yml` (new features), `config/beliefs.yml` (new assertions), `.claude/knowledge/predictions.tsv`, `.claude/plans/todos.yml`, `${CLAUDE_PLUGIN_DATA}/idea-log.json`
Triggers: `/feature new` (commit an idea), `/go` (build committed idea), `/eval` (baseline new feature), `/research` (fill evidence gap)
Triggered by: `/plan` (needs ideas for bottleneck), `/strategy` (strategic gaps need solutions), `/retro` (wrong predictions suggest new approaches)

## Self-evaluation

/ideate succeeded if:
- Every proposed idea has an evidence source (not "wouldn't it be cool if")
- The kill list is non-empty — something was argued for removal
- Committed ideas are materialized (feature in rhino.yml, assertions in beliefs.yml, prediction logged)
- idea-log.sh was called for every proposed, committed, and killed idea

## Cost note

Agent spawning is mode-dependent:
- Default mode: `explorer` (sonnet) for codebase analysis if evidence-scan isn't enough
- Feature improvement mode: `explorer` (sonnet) + `market-analyst` (opus, background) for best-in-class research
- `customer` (sonnet, background) for customer signal in any mode
- Most runs use 0-1 agents. Deep/feature modes use 2-3.

## What you never do
- Generate filler ideas to hit a number
- Skip the kill list
- Write code — ideation produces features and assertions, not implementations
- Skip the failure mode — every idea includes what kills it
- Generate ideas with no evidence — "wouldn't it be cool if" is not ideation
- Ignore the backlog — existing todos are captured intent
- Use one technique every time — rotate through `techniques/`

## If something breaks

- evidence-scan.sh returns empty: no eval-cache, predictions, or todos exist yet — run `/onboard` or `/eval` first to generate baseline data
- idea-log.sh "permission denied": check that `${CLAUDE_PLUGIN_DATA}` directory exists and is writable
- kill-audit.sh finds nothing to kill: this is rare but valid — check if the project is very new with <3 features
- Technique file not found: run `bash scripts/list-techniques.sh` to see available techniques in `techniques/`

$ARGUMENTS
