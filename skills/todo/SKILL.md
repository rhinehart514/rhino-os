---
name: todo
description: "Use when the user wants to manage backlog items — capture, tag, prioritize, promote, decay, or review backlog health"
argument-hint: "[add \"title\"|done <id>|promote <id>|active|health|decay]"
allowed-tools: Read, Bash, Edit, Grep, Glob, AskUserQuestion
---

!cat .claude/plans/todos.yml 2>/dev/null | grep -c 'status: backlog' 2>/dev/null || echo "0"
!cat .claude/plans/todos.yml 2>/dev/null | grep -c 'status: active' 2>/dev/null || echo "0"

# /todo

A living backlog. Decays stale items, graduates recurring todos to assertions, surfaces the right item based on what the product needs.

Storage: `.claude/plans/todos.yml`

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `references/todo-lifecycle.md` — captured→tagged→prioritized→promoted/killed, decay rules, graduation criteria
- `references/todo-sources.md` — where todos come from: /ideate, /eval, /go, manual, agents
- `templates/todo-template.yml` — valid fields for a todo item
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read before any batch operation.**

Scripts (`todo-stats.sh`, `todo-decay.sh`, `todo-promote.sh`) exist as verification — run to cross-check your analysis, not as the primary path.

## State

Read these directly — synthesize, don't delegate:

| File | What it tells you |
|------|-------------------|
| `.claude/plans/todos.yml` | The backlog: id, title, status, feature, source, created_at, done_count |
| `config/rhino.yml` | Feature names for validation + auto-tagging |
| `.claude/cache/eval-cache.json` | Sub-scores — identifies bottleneck feature for smart promote |
| `lens/product/eval/beliefs.yml` | Existing assertions — for graduation dedup |

**You can read todos.yml directly.** Count items by status. Compute ages from created_at timestamps. Find clusters by feature. Identify stale items (>7d, >14d, >30d). Check for orphans (no feature tag). This is YOUR analysis work — scripts verify it.

## Routing

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| (no args) or `show` | Read todos.yml → list items by status → check for stale items → smart promote if 0 active |
| `add "title"` | Capture to backlog. Auto-tag if feature/version detected in title. |
| `done <id>` | Mark complete. Check if recurring (done 3+ times) → suggest graduation to assertion. |
| `promote <id>` | Activate for session |
| `active` | Show active only |
| `tag <id> <feature>` | Tag to feature (validated against rhino.yml) |
| `tag <id> v8.0` | Tag to version |
| `feature [name]` | Filter by feature |
| `version [tag]` | Filter by version |
| `health` | Full backlog diagnostic: counts, ages, clusters, orphans, type distribution. Verify with `todo-stats.sh`. |
| `decay` | Surface all items >7d. Force decisions: promote, kill, or refresh. Verify with `todo-decay.sh`. |
| `all` | Show all including done |
| (plain text) | Quick capture: treat as `add "$ARGUMENTS"` |

## Core behaviors

**Decay**: On every show, check item ages. Surface stale items (>7d warning, >14d urgent, >30d critical). Never auto-delete.

**Graduation**: On `done`, check if this todo has recurred 3+ times (done_count field). If so, suggest converting to assertion in beliefs.yml. Needs founder confirmation via AskUserQuestion.

**Smart promote**: When 0 active items, read eval-cache to find the bottleneck feature, then suggest the highest-leverage todo for that feature.

**Auto-tag**: On `add`, scan title for feature names from rhino.yml, version refs, file paths. Confirm with founder.

**Cross-skill capture**: Skills and agents write todos via `todo:` prefixed SendMessage. See `references/todo-sources.md`.

For lifecycle details: `references/todo-lifecycle.md`
For output templates: `reference.md`

## Task generation — meta-tasks for backlog health

**/todo is the central nervous system. It also needs to generate tasks about its OWN health.** Stale items need decisions. Clusters need features. Orphans need tags. The backlog itself is a product that needs maintenance.

**On every show/health run, generate meta-tasks:**

### Stale item tasks (from todo-decay.sh)
- Each item >14d with no activity → task: "Todo [id] is [N]d stale — promote, kill, or refresh"
- Each item >30d → task: "Todo [id] is [N]d old — force decision: kill or escalate"
- Cluster of 3+ stale items on same feature → task: "Feature [X] has [N] stale todos — batch review needed"

### Cluster tasks
- 3+ todos on same topic → task: "Cluster detected: [N] todos about [topic] — consider creating a feature"
- 3+ todos from same source → task: "Source [X] generated [N] open todos — batch work session needed"
- 5+ todos on same feature → task: "Feature [X] has [N] todos — run /go [feature] to work through them"

### Graduation tasks (from todo-promote.sh)
- Each recurring todo (done 3+ times) → task: "Todo [id] keeps recurring — graduate to assertion"
- Each todo that matches a belief pattern → task: "Todo [id] looks like an assertion — evaluate graduation"
- Each done todo with recurring pattern → task: "Pattern from [id] — should this be a permanent check?"

### Orphan tasks
- Todos with no feature tag → task: "Orphan todo [id] — tag to a feature or kill"
- Todos tagged to killed features → task: "Todo [id] tagged to killed feature [X] — reassign or kill"
- Todos tagged to features not in rhino.yml → task: "Todo [id] references unknown feature [X] — fix tag"

### Balance tasks
- 0 active items → task: "No active work — run /plan to pick next move"
- >20 backlog items → task: "Backlog bloat ([N] items) — batch decay review needed"
- All todos from one source → task: "Backlog dominated by [source] — other skills not generating tasks"

**Write ALL meta-tasks to /todo itself.** Tag with `source: /todo` and type (stale/cluster/graduation/orphan/balance). Priority: stale clusters first.

**There is no cap.** A backlog with 30 items might need 10 meta-tasks. Generate them.

After showing the backlog, show: "Backlog health: N meta-tasks generated. [summary of worst issue]."

## Self-evaluation

The skill worked if:
- **Add**: item was written to todos.yml with auto-tags and no duplicate ids
- **Done**: graduation check ran and meta-tasks were generated if patterns detected
- **Show/health**: decay check ran, stale items were surfaced, smart promote fired when 0 active items
- **All modes**: meta-tasks were generated for every backlog health issue found

## System integration

**Reads:** todos.yml, rhino.yml, eval-cache.json, beliefs.yml
**Writes:** `.claude/plans/todos.yml` (add/done/promote/tag/decay)
**Triggers:** /assert graduate (recurring patterns), /plan (0 active items), /go (active work items), /feature (cluster → new feature)
**Triggered by:** "backlog", "todo", "capture this", /ideate outputs, /eval gap tasks, /go builder reports, /assert coverage tasks, agent `todo:` messages

## What you never do

- Auto-delete stale items — decay surfaces, founder decides
- Auto-promote items — suggest, don't act
- Show done items unless `all` or `version` specified
- Graduate to assertion without founder confirmation

## If something breaks

- No todos.yml → create it on first `add`
- Invalid subcommand → show routing table
- No eval-cache for smart promote → skip, show basic list
- No beliefs.yml for graduation → create it with the graduated assertion

$ARGUMENTS
