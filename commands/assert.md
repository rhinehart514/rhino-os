---
name: assert
description: "Use when adding, checking, or removing assertions — chat-native beliefs.yml editing"
---

# /assert

Assertions are the north star metric. This command makes them a chat activity, not a YAML chore.

## Routing

Parse `$ARGUMENTS`:

### Contains `:` → quick-add
Format: `feature: belief text`

Example: `/assert auth: users can log in`

1. Parse feature name (before colon) and belief text (after colon)
1b. Read `config/rhino.yml` features section. Check the feature's weight. If a w:5 feature has 0 existing assertions, flag it: "**[feature]** is weight 5 (critical) with no assertions — this belief is high priority."
2. Auto-detect assertion type from the belief text:
   - Mentions a file path (contains `/` or `.sh` or `.ts` etc.) → `file_check`
   - Mentions "should contain" / "has" / "includes" → `content_check`
   - Mentions "score" / "trend" / "improves" → `score_trend`
   - Mentions "command" / "runs" / "exits" → `command_check`
   - Otherwise → `llm_judge` (Claude evaluates subjectively)
3. Generate an id from feature + key words (e.g., `auth-login`)
4. Generate appropriate fields based on type:
   - `file_check`: extract path from text, set `contains` if mentioned
   - `content_check`: extract forbidden words or contains text
   - `score_trend`: set `window: 10`, `direction: not_flat` as defaults
   - `command_check`: extract the command from text
   - `llm_judge`: use the belief text as the `prompt`, auto-detect `path` from feature's code paths in rhino.yml
5. Default severity to `warn`
6. Append to beliefs.yml

### `list` → show all assertions
Optionally scoped: `/assert list scoring`

Read beliefs.yml, group by feature, show pass/fail status by running `rhino eval . --score --by-feature`.
Also read `config/rhino.yml` for feature weights. Show weight next to each feature group header. Flag any w:4+ features with 0 assertions: "⚠ **[feature]** (w:[N]) has no assertions — high-weight features need coverage."

### `check [id]` → run single assertion
Run `rhino eval . --no-generative` and grep for the specific assertion id in output.

### `remove [id]` → remove assertion
Find and remove the belief block with matching id from beliefs.yml.

## Output format

### Quick-add
```
◆ assert — added

  id: auth-login
  belief: "users can log in"
  type: llm_judge
  feature: auth
  severity: warn

  run `/eval auth` to test it
```

### List
```
◆ assert — 25 beliefs across 6 features

▾ scoring  w:5  (6 beliefs)
  ✓ score-runs
  ✓ value-hypothesis-exists
  ✓ value-hypothesis-defined
  · score-calibrated
  · score-not-stagnant
  ✓ score-has-history

▾ learning  w:4  (5 beliefs)
  ✓ knowledge-model-exists
  · predictions-logged
  ✗ learning-compounds

▾ commands  w:5  (3 beliefs)
  ✓ commands-have-descriptions
  ✓ plan-has-recovery
  ✓ go-has-recovery

⚠ [feature]  w:4+  has no assertions — needs coverage

/eval       run full assertions
/assert scoring: score should trend up   add a new one
```

### Remove
```
◆ assert — removed

  id: auth-login
  was: "users can log in" (llm_judge, auth)
```

## Tools to use

**Use Read** to read beliefs.yml, rhino.yml (for feature code paths, maturity, weight)
**Use Edit** to append new beliefs or remove existing ones from beliefs.yml
**Use Bash** to run `rhino eval . --score --by-feature` for list mode

## What you never do
- Add duplicate ids — check existing beliefs first
- Add block severity without explicit request (default to warn)
- Create beliefs that are impossible to evaluate mechanically or by LLM
- Remove beliefs without confirming the id exists
- Modify eval.sh or score.sh (the eval harness is immutable)

## If something breaks
- beliefs.yml missing: "No beliefs file. Creating one at lens/product/eval/beliefs.yml"
- Feature not in rhino.yml: still add the belief — features in beliefs.yml don't require rhino.yml entries
- Ambiguous type detection: default to llm_judge with the full text as the prompt
- Id collision: append a number (e.g., `auth-login-2`)

$ARGUMENTS
