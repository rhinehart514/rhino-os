---
name: assert
description: "Use when adding, checking, or removing assertions — chat-native beliefs.yml editing"
argument-hint: "[feature: belief text] or [list|check|remove|graduate|health|coverage|suggest|flapping] [id|feature]"
allowed-tools: Read, Bash, Edit, Grep
---

# /assert

Manage assertions in `lens/product/eval/beliefs.yml`. Add, remove, audit, suggest. Does NOT run assertions — that's `/eval`.

## Skill folder structure

This skill is a **folder**, not just this file. Read on demand:

- `scripts/assertion-stats.sh` — counts by type, pass rate, coverage gaps (zero context cost)
- `scripts/belief-lint.sh` — validates beliefs.yml syntax, finds duplicates, checks mechanical-vs-llm ratio
- `scripts/assertion-diff.sh` — what changed since last eval: new, newly passing, newly failing
- `references/assertion-types.md` — all types with examples and when-to-use guidance
- `references/writing-guide.md` — how to write good assertions (mechanical > llm_judge, specific > vague)
- `templates/assertion-template.yml` — copy-paste template for each assertion type
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read before health/coverage/suggest modes.**

## State artifacts

Read in parallel at start (skip when missing):

| Artifact | Path | Purpose |
|----------|------|---------|
| beliefs | `lens/product/eval/beliefs.yml` | All assertions |
| rhino config | `config/rhino.yml` | Features, weights, code paths |
| eval cache | `.claude/cache/eval-cache.json` | Sub-scores for coverage mapping |
| todos | `.claude/plans/todos.yml` | Graduation candidates |
| assertion history | `.claude/evals/assertion-history.tsv` | Pass/fail trends |

## Routing

Parse `$ARGUMENTS`:

| Pattern | Mode | Action |
|---------|------|--------|
| Contains `:` | quick-add | Parse `feature: belief text`, auto-detect type, append to beliefs.yml |
| `list [feature]` | list | Run `scripts/assertion-stats.sh`, show grouped by feature with pass/fail |
| `check [id]` | check | Run single assertion via `rhino eval . --no-generative` |
| `remove [id]` | remove | Anti-rationalization gate if failing, then remove |
| `graduate [todo-id]` | graduate | Convert todo to assertion, show proposed, confirm |
| `health` | health | Run `scripts/belief-lint.sh` + `scripts/assertion-stats.sh`, full diagnostic |
| `coverage [feature]` | coverage | Dimension matrix: value/behavior/structure/regression/edge |
| `suggest [feature]` | suggest | Read code + claims, generate 2-3 assertions for gaps |
| `flapping` | flapping | Oscillating assertions from assertion-history.tsv |
| `diff` | diff | Run `scripts/assertion-diff.sh`, show what changed |

### Quick-add details

1. Parse feature (before `:`) and belief text (after `:`)
2. Auto-detect type: file path mention -> `file_check`, "contains"/"has" -> `content_check`, "command"/"runs" -> `command_check`, "score"/"trend" -> `score_trend`, else -> `llm_judge`
3. Generate id from feature + key words. Check for duplicates via Grep.
4. Default severity: `warn`. Append to beliefs.yml.
5. Flag w:5 features with 0 existing assertions as high priority.

### Remove gate

If the assertion is **failing**: "This assertion is failing. Failing assertions are the signal, not the problem. Removing it hides the bug." Require explicit confirmation. If passing/stale: proceed.

### Suggest protocol

Read feature's `code:` paths + `delivers:` claims from rhino.yml. Read existing assertions. Read `references/writing-guide.md`. Generate assertions that fill gaps: prefer mechanical types, target uncovered dimensions.

## Anti-rationalization checks

Flag during any mode:
- Removing a failing assertion -> warn
- All file_check for a feature -> "proves files exist, not that they work"
- 100% pass rate with <3 assertions -> "not enough coverage"
- Adding to well-covered feature when uncovered features exist -> redirect

## Task generation — the path to full assertion coverage

**/assert's job is not just managing assertions. It's generating EVERY task needed to reach comprehensive coverage.** If a feature has gaps in assertion coverage, those gaps should become tasks. The backlog drives what gets asserted next.

**For EVERY coverage gap found, generate the complete task list:**

### Coverage gap tasks (from health/coverage modes)
- Each feature with 0 assertions → task: "Feature [X] has zero assertions — add 3 (1 file_check, 1 content_check, 1 command_check)"
- Each feature with <3 assertions → task: "Feature [X] has only [N] assertions — add [3-N] more"
- Each feature with only file_check assertions → task: "Feature [X] only proves files exist — upgrade to content_check or command_check"
- Each feature with only llm_judge assertions → task: "Feature [X] relies on LLM judgment — add mechanical assertions"

### Type distribution tasks
- No command_check assertions for a feature with CLI/scripts → task: "Feature [X] has scripts but no command_check — add one"
- No content_check for a feature with config/output files → task: "Feature [X] has output files but no content_check — add one"
- >50% llm_judge for any feature → task: "Feature [X] is [N]% llm_judge — replace weakest with mechanical"
- No score_trend assertions for scored features → task: "Feature [X] is scored but has no score_trend assertion — add floor"

### Signal quality tasks
- Each always-passing assertion that tests existence not behavior → task: "Assertion [id] always passes — strengthen to test behavior"
- Each flapping assertion → task: "Assertion [id] is flapping — investigate root cause and stabilize or rewrite"
- Each assertion with vague expected value → task: "Assertion [id] has vague expectation — make specific"
- Each newly failing assertion → task: "Assertion [id] newly failing — fix the code or update the belief"

### Graduation tasks (from todo candidates)
- Each todo that's been done 3+ times → task: "Todo [id] recurs — graduate to assertion via /assert graduate"
- Each todo that matches a belief pattern → task: "Todo [id] should be an assertion — graduate it"

### High-weight feature tasks
- Each w:5 feature with <5 assertions → urgent task: "Critical feature [X] has thin coverage — add assertions"
- Each w:4+ feature with no block-severity assertions → task: "High-weight feature [X] has no blockers — add block assertion on core behavior"

**Write ALL tasks to /todo.** Tag with `source: /assert`, feature name, and gap type (coverage/type/signal/graduation). Priority: highest-weight features with lowest coverage first.

**There is no cap on task count.** A project with 7 features and thin coverage might need 25 assertion tasks. Generate all of them.

After writing tasks, show: "Generated N assertion tasks across M features. Worst coverage: [feature] with [N] assertions needs [X] more."

## What you never do

- Add duplicate ids
- Default to `block` severity (use `warn`)
- Remove failing beliefs without the anti-rationalization warning
- Modify eval.sh or score.sh (immutable eval harness)
- Graduate a todo without showing proposed assertion first
- Suggest assertions for features not in rhino.yml

## Error handling

- **No beliefs.yml**: Create at `lens/product/eval/beliefs.yml` with header
- **Feature not in rhino.yml**: Still add for quick-add; skip in health/coverage/suggest
- **Ambiguous type**: Default to `llm_judge`
- **Id collision**: Append number (e.g., `auth-login-2`)
- **No history data**: Note "Run `/eval` twice for trend data"

For output templates, see [reference.md](reference.md).

$ARGUMENTS
