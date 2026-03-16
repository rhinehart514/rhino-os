---
name: assert
description: "Add, list, check, or remove assertions. Accepts todo graduations. Makes beliefs.yml a chat-native activity instead of manual YAML editing."
argument-hint: "[feature: belief text] or [list|check|remove|graduate] [id]"
allowed-tools: Read, Bash, Edit, Grep
---

# /assert

**When to use this:** You just built something and want to make sure it stays working. Or a todo keeps recurring and should become permanent. Or `/eval coverage` flagged a high-weight feature with no assertions. You don't need to open beliefs.yml — just type what should be true.

**When NOT to use this:** If you want to *run* assertions, use `/eval`. If you want to *audit* assertion quality, use `/eval coverage`. `/assert` is for writing and managing — not measuring.

Assertions are the north star metric. Todos are temporary. Assertions are permanent. This command manages both — and handles the graduation from one to the other.

**Where assertions come from:**
- `/assert auth: users can log in` — founder types one directly
- `/todo` graduation — a recurring todo becomes a permanent assertion
- `/research` — findings suggest a testable belief
- `/go` reviewer — recurring pattern flagged for graduation
- `/eval` evaluator — rubric check that should be permanent

## Routing

Parse `$ARGUMENTS`:

### Contains `:` → quick-add
Format: `feature: belief text`

Example: `/assert auth: users can log in`

1. Parse feature name (before colon) and belief text (after colon)
2. Read `config/rhino.yml` features section. Check the feature's weight. If a w:5 feature has 0 existing assertions, flag it: "**[feature]** is weight 5 (critical) with no assertions — this belief is high priority."
3. Auto-detect assertion type from the belief text:
   - Mentions a file path (contains `/` or `.sh` or `.ts` etc.) → `file_check`
   - Mentions "should contain" / "has" / "includes" → `content_check`
   - Mentions "score" / "trend" / "improves" → `score_trend`
   - Mentions "command" / "runs" / "exits" → `command_check`
   - Otherwise → `llm_judge` (Claude evaluates subjectively)
4. Generate an id from feature + key words (e.g., `auth-login`)
5. Generate appropriate fields based on type:
   - `file_check`: extract path, set `contains` if mentioned
   - `content_check`: extract forbidden words or contains text
   - `score_trend`: set `window: 10`, `direction: not_flat`
   - `command_check`: extract the command from text
   - `llm_judge`: use the belief text as the `prompt`, auto-detect `path` from feature's code paths in rhino.yml
6. Default severity to `warn`
7. Append to beliefs.yml
8. If this came from a todo graduation, mark the todo done in todos.yml

### `list` → show all assertions
Optionally scoped: `/assert list scoring`

Read beliefs.yml, group by feature, show pass/fail status by running `rhino eval . --score --by-feature`.
Read `config/rhino.yml` for feature weights. Show weight next to each feature group header.
Flag any w:4+ features with 0 assertions: "**[feature]** (w:[N]) has no assertions — needs coverage."

### `check [id]` → run single assertion
Run `rhino eval . --no-generative` and grep for the specific assertion id in output.

### `remove [id]` → remove assertion
Find and remove the belief block with matching id from beliefs.yml.

### `graduate [todo-id]` → convert todo to assertion
Read the todo from todos.yml, extract its title and feature tag:
1. Auto-detect assertion type from the todo title (same rules as quick-add)
2. Generate assertion fields
3. Show the proposed assertion for confirmation
4. On confirm: write to beliefs.yml, mark todo done in todos.yml
5. Output: "Graduated: [todo title] → assertion [id]"

This is the endpoint for `todo:graduate` messages from agents.

## Tools to use

**Use Read** to read beliefs.yml, rhino.yml, todos.yml
**Use Edit** to append/remove beliefs, mark todos done on graduation
**Use Bash** to run `rhino eval . --score --by-feature` for list mode
**Use Grep** to check for duplicate ids before adding

For output templates, see [reference.md](reference.md).

## What you never do
- Add duplicate ids — check existing beliefs first
- Add block severity without explicit request (default to warn)
- Create beliefs that are impossible to evaluate mechanically or by LLM
- Remove beliefs without confirming the id exists
- Modify eval.sh or score.sh (the eval harness is immutable)
- Graduate a todo without showing the proposed assertion first

## If something breaks
- beliefs.yml missing: "No beliefs file. Creating one at lens/product/eval/beliefs.yml"
- Feature not in rhino.yml: still add the belief
- Ambiguous type detection: default to llm_judge with the full text as the prompt
- Id collision: append a number (e.g., `auth-login-2`)
- Todo not found for graduation: "Todo [id] not found. `/assert feature: text` to add directly."

$ARGUMENTS
