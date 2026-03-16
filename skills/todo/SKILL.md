---
name: todo
description: "Use when managing backlog items — capture, tag, prioritize, promote, decay"
argument-hint: "[add \"title\"|done <id>|promote <id>|active|health|decay]"
allowed-tools: Read, Bash, Edit, Grep, Glob, AskUserQuestion
---

!cat .claude/plans/todos.yml 2>/dev/null | grep -c 'status: backlog' 2>/dev/null || echo "0"
!cat .claude/plans/todos.yml 2>/dev/null | grep -c 'status: active' 2>/dev/null || echo "0"

# /todo

A living backlog. Not a graveyard of ideas — a system that decays stale items, graduates recurring todos to assertions, and surfaces the right item at the right time based on what the product actually needs.

Storage: `.claude/plans/todos.yml`

## Routing

Parse `$ARGUMENTS` and route:

| Input | Action |
|-------|--------|
| (no args) or `show` | List items + run decay check + smart promote suggestion |
| `add "title"` | Capture to backlog. Auto-tag if feature/version detected. |
| `done <id>` | Mark complete. Check for graduation to assertion. |
| `promote <id>` | Activate for session |
| `active` | Show active only |
| `tag <id> <feature>` | Tag to feature (validated against rhino.yml) |
| `tag <id> v8.0` | Tag to version |
| `feature [name]` | Filter by feature |
| `version [tag]` | Filter by version |
| `health` | Backlog health report |
| `decay` | Force decay check — surface stale items |
| `all` | Show all including done |
| (plain text) | Quick capture: `rhino todo add "$ARGUMENTS"` |

---

## The Living Backlog

### 1. Decay — nothing rots silently

Every time `/todo` is shown, run a decay check:

- **>7 days in backlog, untagged**: flag as `⚠ untagged — tag or kill`
- **>14 days in backlog**: flag as `⚠ stale — promote, kill, or needs /research?`
- **>30 days in backlog**: auto-suggest kill with reason prompt via AskUserQuestion: "This has been sitting for 30 days. Kill it, promote it, or convert to a research question?"

Decay is computed from the `created_at` field in todos.yml. If missing, use file mtime of todos.yml as fallback.

Decay doesn't auto-delete. It surfaces and forces a decision. A backlog with zero stale items = healthy. A backlog with 5+ stale items = founder is capturing but not deciding.

### 2. Graduation — recurring todos become assertions

When marking a todo `done`, check:
- Has a todo with similar text been completed before? (fuzzy match on title keywords)
- Has this feature regressed since the todo was last done? (check eval-cache delta)

If either is true, suggest graduating to an assertion:

```
This is the 2nd time you've fixed something in learning's error handling.
Graduate to assertion? → learning: error handling covers all file I/O paths
```

If the founder agrees, write to `lens/product/eval/beliefs.yml` with:
- `type: file_check` or `content_check` if mechanical
- `type: llm_judge` if it needs judgment
- `feature:` from the todo's tag
- Remove the todo (it's now an assertion — permanently tracked)

This is how the backlog feeds the measurement system. Todos are temporary. Assertions are permanent.

### 3. Smart promote — bottleneck-aware suggestions

When showing the backlog, if no items are active, suggest the highest-leverage item:

1. Read `.claude/cache/eval-cache.json` — get per-feature sub-scores
2. Find the bottleneck feature (lowest score × highest weight)
3. Find the bottleneck dimension (lowest of value/quality/ux for that feature)
4. Find backlog todos tagged to that feature
5. Suggest: "Promoting **[title]** would target **[feature]**'s **[dimension]** ([score])"

If no todos match the bottleneck feature, suggest the oldest promoted-never item.

### 4. Auto-tag from context

When adding a todo, scan the title for:
- Feature names from `config/rhino.yml` → auto-tag `feature:`
- Version references (`v8`, `v8.0`, `v9`) → auto-tag `version:`
- File paths (`bin/score.sh`, `eval.sh`) → infer feature from rhino.yml code paths, auto-tag

If auto-detected, confirm: "Tagged to **[feature]**. Correct?"

### 5. Cross-skill + agent capture

`/todo` isn't the only way items enter the backlog. Skills and agents both produce todos as exhaust.

**Skills that write todos:**
- `/plan` quick capture: `/plan fix the login bug` → todo
- `/eval`: regressions and new gaps → todo
- `/go`: plateau detection → todo. Kept-but-warned moves → todo.
- `/retro`: wrong predictions → todo

**Agents that produce todos (via `todo:` prefixed SendMessage):**
- **builder**: auto-closes matched active todos (`todo:done`), captures new problems and regression guards (`todo:add`)
- **measurer**: captures regressions, stuck features, uncovered gaps (`todo:add`)
- **reviewer**: captures unfixed warnings from kept moves (`todo:add`), suggests recurring patterns for graduation (`todo:graduate`)
- **evaluator**: captures uncovered gaps from deep eval, rubric-informed assertions (`todo:add`, `todo:graduate`)
- **explorer**: converts research findings to tasks, new unknowns to research todos, suggests killing dead-end todos (`todo:add`, `todo:kill`)

**Agent todo protocol** — agents use `todo:` prefixed lines in SendMessage:
- `todo:add "[title]" feature:[name] source:[origin]` — new backlog item
- `todo:done [id]` — mark existing item complete
- `todo:kill [id]` — suggest killing a stale/invalid item
- `todo:graduate "[pattern] → assertion" feature:[name]` — suggest promoting to assertion

The lead agent (or /go loop) reads these messages and writes to todos.yml. Agents never write to todos.yml directly.

All cross-skill and agent captures include a `source:` field (e.g., `source: /go builder`, `source: /eval measurer`, `source: /research explorer`).

### 6. Completion velocity

Track in todos.yml per item:
- `created_at:` — when captured
- `promoted_at:` — when activated (null if never promoted)
- `done_at:` — when completed (null if not done)

`/todo health` computes:
- Avg days backlog → active
- Avg days active → done
- Per-feature velocity (which features have slow todos?)
- Done rate: done / (done + active + backlog)

## State to read

- `.claude/plans/todos.yml` — the backlog
- `config/rhino.yml` — feature names for validation + auto-tagging
- `.claude/cache/eval-cache.json` — sub-scores for smart promote
- `lens/product/eval/beliefs.yml` — existing assertions (for graduation dedup)

## Tools to use

**Use Bash** to run `rhino todo` subcommands.
**Use Read** to check rhino.yml, eval-cache, beliefs.yml.
**Use Edit** to write assertions to beliefs.yml on graduation.
**Use Grep** for fuzzy matching on graduation check.
**Use AskUserQuestion** for decay decisions, graduation confirmation, auto-tag confirmation.

For output templates, see [reference.md](reference.md).

## What you never do

- Auto-delete stale items — decay surfaces, founder decides
- Auto-promote items — suggest, don't act
- Show done items unless `all` or `version` is specified
- Add items without being asked (except cross-skill capture, which is explicit)
- Graduate to assertion without founder confirmation

## If something breaks

- No todos.yml: `rhino todo add "title"` creates it
- Invalid subcommand: show routing table
- Item not found: list available IDs
- rhino todo CLI not available: read/write `.claude/plans/todos.yml` directly
- No eval-cache for smart promote: skip suggestion, show basic list
- No beliefs.yml for graduation: create it with the graduated assertion

$ARGUMENTS
