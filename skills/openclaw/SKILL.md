---
name: openclaw
description: "Chat-optimized interface for OpenClaw users. Formats rhino-os output for messaging delivery. /openclaw pulse, /openclaw ask, /openclaw nudge, /openclaw bet, /openclaw grunt."
argument-hint: "[pulse|ask|nudge|bet|grunt]"
allowed-tools: Read, Bash, Grep, Glob, Agent
---

!cat .claude/cache/score-cache.json 2>/dev/null | jq '{score, features: (.features | to_entries | map({key, score: .value.score}) | from_entries)}' 2>/dev/null || echo "no cache"

# /openclaw

The interface layer for OpenClaw users. When OpenClaw's coding-agent spawns Claude Code, this skill formats rhino-os intelligence for chat delivery — tight, plain-language, one-message responses that work in Telegram/Slack/WhatsApp.

**This is not a separate product.** It's a view layer. Every sub-command calls existing rhino-os internals and reformats the output for a chat bubble instead of a terminal dashboard.

## Design rules

1. **One message.** Every response fits in a single chat message. No dashboards, no dividers, no progress bars.
2. **Plain language.** No `w:5` or `◐` or `███`. Write like you're texting a cofounder.
3. **Opinion first.** Lead with what matters, details after. The founder is reading this on a phone.
4. **Actionable.** End with what to do next — but as prose, not `/command` syntax (they may not be in Claude Code).

## Routing

Parse `$ARGUMENTS`:

### `pulse` → product heartbeat
The one-message status update. Designed for daily cron via OpenClaw.

**Steps:**
1. Run `rhino score . --quiet` — get current score
2. Read `.claude/cache/eval-cache.json` — feature sub-scores
3. Read `config/rhino.yml` — stage, features, value hypothesis
4. Read `.claude/plans/roadmap.yml` — thesis progress
5. `git log --oneline -3` — recent work

**Output format:**
```
Score: 93. Assertions: 56/63 passing. Health: 80.

What happened: [1-2 sentences from git log — what was actually built]

Bottleneck: [feature name] — [why in plain language]

[One opinion sentence. What matters most right now.]
```

Keep it under 280 characters when possible. This should feel like a text from a cofounder, not a report.

### `ask <question>` → natural language query
The universal entry point. Parse the question and route to the right rhino-os internal.

**Routing logic:**
- "how's [feature]?" → read feature from rhino.yml + eval-cache, summarize in 2-3 sentences
- "what broke?" / "what changed?" → `git log --oneline -5` + score delta from history.tsv, plain English summary
- "what should I work on?" → read plan.yml bottleneck logic, one sentence recommendation
- "how's the score?" → `rhino score . --quiet`, one sentence
- "what's the strategy?" → read strategy.yml, 2-3 sentence summary
- Anything else → best-effort answer from project state, or "I don't have enough context for that. Try asking from Claude Code where I can dig deeper."

**Output format:**
```
[Direct answer in 1-3 sentences. No preamble.]

[If relevant: one suggestion for what to do about it.]
```

### `nudge` → proactive observation
The most important thing the founder should know right now. Designed for daily cron — one nudge per day, the highest-priority one.

**Steps (check in order, stop at first match):**
1. Read `.claude/scores/history.tsv` — score dropped since last check? → alert
2. Read `.claude/plans/todos.yml` — any item stale >5 days? → nag
3. Read `~/.claude/knowledge/predictions.tsv` (fall back to `.claude/knowledge/`) — ungraded predictions >3 days old? → remind
4. Read `config/rhino.yml` features — any feature at `building` for >7 days without assertion progress? → flag
5. Read `.claude/plans/roadmap.yml` — thesis evidence items with no progress? → prompt
6. `git log --since="3 days ago" --oneline` — no commits in 3+ days? → check in
7. Nothing urgent → "All clear. Score holding at [N]. [One encouraging observation about recent progress.]"

**Output format:**
```
[The nudge. One paragraph. Direct. Specific.]

[What to do about it — in plain language, not commands.]
```

### `bet <prediction>` → log a prediction
Capture a prediction from chat. The founder has an idea while away from the IDE — this logs it as a real prediction with evidence and falsification criteria.

**Steps:**
1. Parse the prediction from the argument
2. Ask clarifying questions if needed (but try to infer): what's the evidence? what would disprove it?
3. Append to `~/.claude/knowledge/predictions.tsv` (fall back to `.claude/knowledge/`):
   ```
   [date]	[prediction]	[evidence — inferred from context]	untested
   ```
4. Confirm what was logged

**Output format:**
```
Logged: "[prediction]"

Evidence: [what you inferred or "none stated — pure hunch"]
Wrong if: [falsification criteria — infer from the prediction]

This'll get tested next time you run /go or /eval. I'll grade it then.
```

### `grunt` → autonomous cleanup
Do the tedious work. Run in a worktree, score before/after, report back. The founder approves or rejects from chat.

**Steps:**
1. Run `rhino score . --quiet` — baseline score
2. Read the codebase for: dead imports, lint warnings, stale TODOs, broken file references, dependency updates available
3. Spawn a builder agent with `isolation: worktree` to fix everything mechanical (nothing that changes behavior)
4. Run `rhino score .` in the worktree — new score
5. Report the delta

**Output format:**
```
Cleanup done. Score: [before] → [after] ([+/-delta])

Fixed:
· [what was fixed, 1 line each, max 5 items]
· [...]

Branch: [branch name]

Reply "ship it" to merge, or "nah" to discard.
```

If score dropped: "Score dropped. Discarding automatically. Something unexpected happened — check it from Claude Code."

### No arguments → help
```
/openclaw — rhino-os for your chat

pulse     morning heartbeat (score + bottleneck + opinion)
ask       "how's auth?" — natural language about your project
nudge     the one thing that matters right now
bet       log a prediction from anywhere
grunt     do the boring cleanup, report back

Works best with OpenClaw's coding-agent. Install rhino-os as a Claude Code plugin, point your coding-agent at the project, and these commands just work.
```

## What you never do
- Output terminal formatting (dividers, progress bars, ANSI, box drawing)
- Give long responses — every output should fit comfortably in a chat bubble
- Use rhino-os jargon without explaining it ("assertions passing" → "56 of 63 tests passing")
- Recommend slash commands — the user might not be in Claude Code
- Skip the opinion — every response ends with what to do next

## If something breaks
- Score unavailable: "Can't reach the scoring engine. Are you in the right project directory?"
- No eval cache: use assertion counts only, skip sub-scores
- No predictions file: "No predictions logged yet. Try: bet [your prediction here]"
- Worktree fails (grunt): "Couldn't create an isolated workspace. Try running /go from Claude Code instead."

$ARGUMENTS
