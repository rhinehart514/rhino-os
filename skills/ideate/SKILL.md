---
name: ideate
description: "Brainstorm WHAT to build. Evidence-weighted ideas with 9 creative techniques, persistent idea logging, and mandatory kill lists. Use when the founder says 'what should we build?', 'brainstorm', 'ideas', 'what could we build?', or 'feature ideas'."
argument-hint: "[feature|wild|kill|deep|technique-name|\"constraint\"]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion, WebSearch, Agent
---

# /ideate

A cofounder saying "here's what we should build next and here's what we should stop building." Every idea is backed by evidence. Ideas that survive become features. Ideas that don't get killed explicitly.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/evidence-scan.sh` — runs first, scans ALL project state, outputs structured evidence (zero context cost)
- `scripts/idea-log.sh` — persistent idea history across sessions (add, kill, commit, list, stats)
- `scripts/kill-audit.sh` — finds kill candidates (stale todos, always-passing assertions, stuck features)
- `techniques/` — 9 creative thinking modes, each a separate file. Read the relevant one based on the mode.
- `templates/idea-brief.md` — the structure for every idea brief
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes from past sessions. **Read this before generating ideas.**

## Routing

Parse `$ARGUMENTS`:

| Argument | Mode | What happens |
|----------|------|-------------|
| (none) | Evidence-weighted | Run evidence-scan.sh → generate from data → kill list → present |
| `[feature]` | Feature-level | Focus on one feature's weakest dimension |
| `wild` | High-conviction bets | 3 ideas that fundamentally change the product |
| `kill` | Pure kill exercise | Run kill-audit.sh → argue for killing things |
| `deep` | Full brainstorm | Run 3+ techniques from `techniques/` → converge → kill |
| `divergent` | Divergent thinking | Read `techniques/divergent.md` → 20+ raw ideas |
| `invert` | Inversion thinking | Read `techniques/inversion.md` → flip assumptions |
| `constraint` | Constraint thinking | Read `techniques/constraint.md` → artificial limits |
| `user` | User state thinking | Read `techniques/user-states.md` → emotional simulation |
| `combine` | Combination engine | Read `techniques/combination.md` → smash things together |
| `future` | Future-back thinking | Read `techniques/future-back.md` → endgame backward |
| `steal` | Pattern theft | Read `techniques/pattern-theft.md` → steal from winners |
| `cross` | Cross-domain | Read `techniques/cross-domain.md` → import from other fields |
| `yc` | YC lens | Read `techniques/yc-lens.md` → evaluate ideas like a YC partner |
| `market` | 2026 market context | Read `techniques/market-2026.md` → what's true NOW that changes what to build |
| `[any text]` | Constrained ideation | Ideas within a specific direction |

## The protocol

### Step 1: Evidence scan (always first)

Run `scripts/evidence-scan.sh` via Bash. This scans eval-cache, predictions, backlog, thesis, dead ends, customer intel, and git history. Outputs structured data at zero context cost — only the output enters the conversation.

Also read `config/product-spec.yml` if it exists — generate ideas that advance the spec. Ideas that contradict the spec need strong evidence.

Also run `scripts/idea-log.sh stats` to show ideation history.

### Step 2: Read gotchas

Read `gotchas.md` before generating. Every gotcha is a failure mode from a real session.

### Step 3: Generate ideas

**Default mode (no arguments or feature):** Follow evidence-weighted generation.

Sources ranked by signal strength:
1. **Wrong predictions** — failed predictions reveal real gaps
2. **Sub-score gaps** — eval-cache weak dimensions
3. **Market context** — proven patterns elsewhere (WebSearch if no market-context.json)
4. **Dead end rebounds** — failures that point to better approaches
5. **Backlog clusters** — 3+ todos on same topic = pattern
6. **Thesis gaps** — unproven roadmap evidence

**Technique modes (divergent, invert, etc.):** Read the corresponding file from `techniques/` and follow its method. These push thinking out of the default evidence-weighted mode into creative territory.

**Deep mode:** Pick 3 techniques, run each, then converge. Suggested flow:
1. `techniques/market-2026.md` — read market context first (grounds everything in reality)
2. `techniques/divergent.md` — generate volume (2 min)
3. `techniques/killer.md` — attack survivors (2 min)
4. `techniques/yc-lens.md` — score survivors on fundability
5. One of: inversion, constraint, user-states, combination, future-back, pattern-theft, cross-domain

**YC mode (`/ideate yc`):** Read `techniques/yc-lens.md` + `techniques/market-2026.md`. Every idea gets the 10 YC questions. Score 0-10 on fundability. Bottom ideas get killed.

**Market mode (`/ideate market`):** Read `techniques/market-2026.md`. Ideate against the 5 market gaps. Every idea must answer "why now?" with a 2026-specific signal.

Generate **3-5 ideas** (default) or **20+** (divergent). No filler. If only 2 have evidence, generate 2.

Every idea uses the structure from `templates/idea-brief.md`.

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
| `/roadmap ideate` | **WHERE** | Where does the project go after this thesis? |
| `/research` | **HOW** | What do we need to know before deciding? |
| `/feature new` | **DO** | Commit to building a named feature. |

## Agent usage

- **Agent (rhino-os:explorer)** — for deep codebase analysis when evidence-scan isn't enough
- **Agent (rhino-os:customer)** — spawn in background for customer signal: `Agent(subagent_type: "rhino-os:customer", prompt: "Research customer signal for [product/category]. Write to .claude/cache/customer-intel.json.", run_in_background: true)`

## Task generation — ideas and kills become tasks

See `../shared/task-generation.md` for the task generation protocol. /ideate generates tasks for:

**For EVERY committed idea, generate the full onramp:**
- Task: "Implement core of [feature] — [specific first step]"
- Task: "Add 3 assertions for [feature] — 1 file_check, 1 content_check, 1 command_check"
- Task: "Run /eval [feature] to establish baseline score"
- Task: "Log prediction about [feature]'s first eval score"
- Each dependency identified → task: "Feature [X] depends on [Y] — verify [Y] is ready"

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

## What you never do
- Generate filler ideas to hit a number
- Skip the kill list
- Write code — ideation produces features and assertions, not implementations
- Skip the failure mode — every idea includes what kills it
- Generate ideas with no evidence — "wouldn't it be cool if" is not ideation
- Ignore the backlog — existing todos are captured intent
- Use one technique every time — rotate through `techniques/`

$ARGUMENTS
