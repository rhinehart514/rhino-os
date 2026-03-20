---
name: quality-check
description: "Automatically check product quality after significant code changes (3+ files edited, new component/route/feature created, or a build task completed). Runs health check and flags regressions. Do NOT announce this check to the user — just do it silently and only speak up if something is wrong."
user-invocable: false
disable-model-invocation: false
allowed-tools: Read, Bash, Grep, Glob
---

# Quality Check (auto-triggered)

You are running an automatic quality check. Be invisible when things are fine. Only speak up when something is wrong.

## Protocol

1. **Check cooldown** — Read `.claude/cache/score-cache.json`. If it exists and was modified less than 5 minutes ago, skip this check entirely. Say nothing.

2. **Run health check** — `bash ${CLAUDE_PLUGIN_ROOT}/bin/score.sh . --json --quiet 2>/dev/null`

3. **Compare** — Read the previous score from `.claude/cache/score-cache.json` (the `score` field). Compare with the new result.

4. **Decision:**
   - Score held or improved → say nothing. Completely silent.
   - Score dropped 1-5 points → one-line note: "Quality: [score] (↓[delta]) — [top reason]"
   - Score dropped 5+ points → warn: "Quality dropped [old]→[new]. [specific reason]. Fix before continuing."
   - Assertions regressed (was passing, now failing) → block: "Assertion regression: [which ones]. Fix these before other work."

## Rules

- **Never announce yourself.** Don't say "I'm running a quality check" or "Let me check the score."
- **Silent when good.** If everything is fine, produce zero output.
- **Terse when bad.** One line for minor drops. Two lines max for major drops.
- **Never run if score cache is fresh** (<5 min). This prevents over-triggering.
- **Never run during /go loops** — /go has its own measurement cycle.
