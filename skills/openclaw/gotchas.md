# OpenClaw Gotchas

Built from real failure modes. Update this when openclaw output fails in a new way.

## Formatting failures
- **Terminal formatting in chat**: The most common failure. Dividers (`⎯⎯`), progress bars (`████`), bullet styles (`▸`), and section markers (`◆`) look good in a terminal and terrible in a chat bubble. Use plain text, line breaks, and minimal formatting only.
- **Information loss from compression**: Compressing /eval output for chat strips nuance. A 93/100 score hides that one feature is at 28. Always mention the weakest point, not just the aggregate.
- **Context collapse**: What makes sense in the terminal doesn't make sense in Slack. "eval-cache shows delivery at 62" means nothing to someone reading on their phone. Translate: "your core features are working but rough around the edges."

## Content failures
- **Jargon leak**: "Assertions passing at 89%" means nothing outside rhino-os. Translate to "56 of 63 product tests are passing." Every technical term needs a plain-language equivalent.
- **Recommending slash commands**: The user reading this in Telegram can't run `/eval`. Say "check your product score next time you're coding" not "run /eval."
- **Missing the opinion**: Every openclaw response must end with what to do next. Data without direction is noise. "Score is 58" is useless. "Score is 58 — the auth flow is the weakest point, fix that first" is actionable.

## Pulse-specific failures
- **Pulse too long**: Pulse should feel like a text message, not a report. If it's more than 4 lines, it's too long. Cut context, keep the opinion.
- **Pulse without recent git context**: If there are no recent commits, pulse should say so directly. "No commits in 3 days" is useful signal, not an absence of data.

## Nudge-specific failures
- **Multiple nudges**: Nudge should be ONE thing — the most important thing. Listing 3 problems dilutes the signal. Check in priority order, stop at the first match.
- **Nudge without specificity**: "Some tests are failing" is not a nudge. "The auth-login test has been failing for 4 days" is a nudge.

## Grunt-specific failures
- **Behavioral changes in cleanup**: Grunt must only make mechanical, behavior-preserving changes. Dead imports, lint fixes, stale TODOs. If a change could alter behavior, skip it.
- **Score drop handling**: If grunt's changes drop the score, discard automatically. Don't ask — the answer is always "discard."
