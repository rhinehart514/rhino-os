---
name: todo
description: "Use when managing backlog items — capture, tag, prioritize, promote, decay"
---

# /todo

Persistent backlog that survives across sessions. Capture ideas, tag by feature, promote to active, mark done. Storage: `.claude/plans/todos.yml`.

## What to do

Parse `$ARGUMENTS` and route:

| Input | Action |
|-------|--------|
| (no args) or `show` | `rhino todo show` — list all items |
| `add "title"` | `rhino todo add "title"` — capture to backlog |
| `done <id>` | `rhino todo done <id>` — mark complete |
| `promote <id>` | `rhino todo promote <id>` — activate for session |
| `active` | `rhino todo active` — show active only |
| `tag <id> <feature>` | `rhino todo tag <id> <feature>` |
| `tag <id> v8.0` | `rhino todo tag <id> v8.0` — tag to a version |
| `feature [name]` | `rhino todo feature [name]` — filter by feature |
| `version [tag]` | Filter by version tag (e.g., `/todo version v8.0`) |
| `all` | `rhino todo all` — show all including done |
| (plain text) | Quick capture: `rhino todo add "$ARGUMENTS"` |

## Output format

```
◆ todo — N items (M active)

▸ active
  ▸ [feature] title                            [id]

· backlog
  · [feature] title                     v8.0   [id]
  · title                                      [id]

/todo add "title"     capture
/todo promote <id>    activate for session
/todo version v8.0    filter by version
/plan                 turn active todos into moves
```

### `/todo version [tag]`
```
◆ todo — v8.0 (N items, M done)

▸ active
  ▸ [feature] title                            [id]

· backlog
  · [feature] title                            [id]

✓ done
  ✓ [feature] title                            [id]
```

**Formatting rules:**
- Active items use ▸ prefix, backlog uses · prefix
- Feature tags in brackets before title
- Version tags shown after title when present (e.g., `v8.0`)
- IDs right-aligned
- If no items exist, show: "Empty backlog. `/todo add 'title'` to capture something."

## Cross-recommendations

- After `promote` → suggest `/plan` to turn active todos into moves
- After `done` → suggest `/retro` to close the learning loop
- After `add` → suggest `/todo tag <id> <feature>` or `/todo tag <id> v[X.Y]` to connect to feature or version
- After `show` with 0 active → suggest `/todo promote <id>` on the most important item

## If something breaks

- No todos.yml: `rhino todo add "title"` creates it
- Invalid subcommand: show usage table above
- Item not found: list available IDs
- rhino todo CLI not available: read/write `.claude/plans/todos.yml` directly as YAML

## Feature tag validation

When tagging a todo with a feature name (`/todo tag <id> <feature>`), read `config/rhino.yml` features section and validate:
- If the feature exists in rhino.yml → tag it
- If the feature does NOT exist → warn: "**[feature]** is not defined in rhino.yml. `/feature new [feature]` to define it, or tag anyway?"

### `/todo version [tag]`
Read `.claude/plans/todos.yml` and filter items where tags contain the version string (e.g., `v8.0`). Show active, backlog, and done items for that version. If no items match, show: "No todos tagged **[tag]**. `/todo tag <id> [tag]` to tag one."

## What you never do

- Show done items unless `all` or `version` is specified
- Auto-promote items — that's the founder's call
- Add items without being asked

$ARGUMENTS
