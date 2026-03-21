---
name: session-summary
description: "Produce a before/after session summary when the session is ending, the user says goodbye/done/wrapping up, or significant work is complete. Shows what changed: score delta, assertions fixed, predictions made. Do NOT run this mid-session — only at natural endpoints."
user-invocable: false
disable-model-invocation: false
allowed-tools: Read, Bash, Grep
---

# Session Summary (auto-triggered at session end)

Produce a compact before/after summary of what this session accomplished.

## Protocol

1. **Read session start state** from `.claude/sessions/` — find the most recent session YAML file. It has `score_before`, `score_after`, `predictions_count`, `moves`.

2. **Read current state:**
   - Score: `.claude/cache/score-cache.json` → `score` field
   - Assertions: `.claude/cache/score-cache.json` → `assertion_pass_count` / `assertion_count`
   - Predictions made today: `grep "$(date +%Y-%m-%d)" ~/.claude/knowledge/predictions.tsv | wc -l`
   - Commits: `git log --oneline --since="$(date +%Y-%m-%d)" | wc -l`

3. **Compute deltas** — score before vs now, assertions before vs now.

4. **Format output:**

```
Session: [score_before] → [score_now] ([+/-delta])
  [N] commits · [M] assertions passing · [P] predictions made
  [one-line summary of what improved or what's still broken]
```

## System integration

Reads: `.claude/sessions/` (session start state), `.claude/cache/score-cache.json`, `~/.claude/knowledge/predictions.tsv`, `git log`
Writes: nothing (read-only summary)
Triggers: nothing (terminal output)
Triggered by: session end detection (user says goodbye/done/wrapping up), stop hook

## Rules

- **Keep it to 3 lines max.** This is a status bar, not a report.
- **Only run at session end.** If the user is clearly mid-work, don't trigger.
- **Show delta, not absolute.** "+5" is more useful than "85" — they want to know if the session mattered.
- **If no score data exists**, just summarize commits and what was built.
- **Name what improved.** Not "score went up" but "auth flow fixed, 2 dead ends removed."

## If something breaks

- No session file in `.claude/sessions/` → skip "before" state, just show current snapshot and commits.
- score-cache.json missing → fall back to git log summary only.
- predictions.tsv missing → omit prediction count, don't error.
