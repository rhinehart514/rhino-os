# /openclaw Reference — Output Templates

Loaded on demand. Routing and design rules are in SKILL.md.

---

## Pulse output

```
Score: 93. Assertions: 56/63 passing. Health: 80.

What happened: Error handling added to score.sh, trend sparkline shipped.

Bottleneck: learning — predictions log but never auto-grade.

The measurement system is solid but the learning loop is broken. Fix auto-grading before adding more features.
```

## Ask output

```
[Direct answer in 1-3 sentences. No preamble.]

[If relevant: one suggestion for what to do about it.]
```

Examples:

```
Scoring is at 58/100. Delivery is strong (62) but craft is dragging it down (50) — 4 unhandled error paths in score.sh.

Fix the error paths and craft should jump to ~60.
```

```
Three commits in the last day: error boundary hardening, sparkline, and a hook fix that got reverted. Score went from 54 to 63.

The hook revert is worth investigating — session_start is confirmed fragile.
```

## Nudge output

```
[The nudge. One paragraph. Direct. Specific.]

[What to do about it — in plain language, not commands.]
```

Examples:

```
Score dropped from 63 to 58 since your last session. The sparkline commit broke an assertion in eval — "score-honest" is now failing.

Open Claude Code and check what changed in the score output format. Probably a string parsing issue.
```

```
You have 3 predictions sitting ungraded for 5 days. The learning loop doesn't work if predictions never get graded.

Next time you're in Claude Code, run a retro to grade them. Two look like they can be auto-graded from the score history.
```

```
All clear. Score holding at 93. The last 3 commits all improved craft scores.

Keep going — learning is still the bottleneck but you're making progress on the right things.
```

## Bet output

```
Logged: "[prediction text]"

Evidence: [what you inferred or "none stated — pure hunch"]
Wrong if: [falsification criteria]

This'll get tested next time you run /go or /eval. I'll grade it then.
```

## Grunt output

```
Cleanup done. Score: 92 → 95 (+3)

Fixed:
· removed 4 dead imports in bin/score.sh
· cleaned 2 stale TODO comments
· fixed lint warning in eval.sh:720

Branch: cleanup/2026-03-16

Reply "ship it" to merge, or "nah" to discard.
```

Score dropped case:

```
Score dropped. Discarding automatically. Something unexpected happened — check it from Claude Code.
```

## Help output (no arguments)

```
/openclaw — rhino-os for your chat

pulse     morning heartbeat (score + bottleneck + opinion)
ask       "how's auth?" — natural language about your project
nudge     the one thing that matters right now
bet       log a prediction from anywhere
grunt     do the boring cleanup, report back

Works best with OpenClaw's coding-agent. Install rhino-os as a Claude Code plugin, point your coding-agent at the project, and these commands just work.
```

## Formatting rules

- **No terminal formatting.** No dividers, no progress bars, no `⎯⎯`, no `◆`, no `▾`.
- **Plain language.** Write like texting a cofounder, not generating a dashboard.
- **One message.** Every response fits in a single chat bubble.
- **Opinion first.** Lead with what matters, details after.
- **Actionable.** End with what to do next — as prose, not `/command` syntax.
- **Under 280 characters for pulse** when possible.
- No rhino-os jargon without explaining it.
- No slash commands in suggestions — the user might not be in Claude Code.
