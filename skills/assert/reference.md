# /assert Reference — Output Templates

Loaded on demand. Routing and logic are in SKILL.md.

---

## Quick-add

```
◆ assert — added

  id: auth-login
  belief: "users can log in"
  type: llm_judge
  feature: auth  w:4
  severity: warn

/eval auth         test it
/assert list       see all beliefs
/feature auth      feature status
```

## List

```
◆ assert — 25 beliefs across 6 features

▾ scoring  w:5  (6 beliefs · 5 pass · 1 warn)
  ✓ score-runs
  ✓ value-hypothesis-exists
  ✓ value-hypothesis-defined
  · score-calibrated
  · score-not-stagnant
  ✓ score-has-history

▾ learning  w:4  (5 beliefs · 3 pass · 1 warn · 1 fail)
  ✓ knowledge-model-exists
  · predictions-logged
  ✗ learning-compounds

▾ commands  w:5  (3 beliefs · 3 pass)
  ✓ commands-have-descriptions
  ✓ plan-has-recovery
  ✓ go-has-recovery

⚠ deploy  w:4  has no assertions — needs coverage

pass rate: **84%** (21/25)

/eval              run full assertions
/assert scoring: score should trend up   add one
/assert graduate ag-01                    graduate a todo
```

## Remove

```
◆ assert — removed

  id: auth-login
  was: "users can log in" (llm_judge, auth)

/assert list       see remaining
```

## Graduate (from todo)

```
◆ assert graduate — ag-01

  todo: "auto-grade predictions on session start"
  feature: learning
  occurred: 2 times (2026-03-10, 2026-03-16)

  proposed assertion:
    id: learning-auto-grade
    belief: "predictions are graded automatically on session start"
    type: command_check
    command: "grep -c 'correct' ~/.claude/knowledge/predictions.tsv"
    feature: learning
    severity: warn

  [Confirm] / [Edit] / [Skip]
```

After confirm:

```
◆ assert — graduated

  todo [ag-01] → assertion [learning-auto-grade]
  todo marked done · assertion added to beliefs.yml

/eval learning     test the new assertion
/todo              see remaining items
/assert list       see all assertions
```

## Formatting rules

- Quick-add: show all fields, weight next to feature
- List: group by feature, ✓/·/✗ per assertion, weight in header, pass rate at bottom
- Graduate: show the todo context (how many times it recurred), the proposed assertion, confirmation prompt
- Flag w:4+ features with 0 assertions
- Bottom: exactly 3 next commands
