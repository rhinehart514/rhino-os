# OpenClaw Formatting Guide

How to format rhino-os output for messaging platforms. Read on demand when generating chat responses.

## Platform constraints

| Platform | Max message | Rich formatting | Notes |
|----------|-------------|-----------------|-------|
| Telegram | 4096 chars | Markdown (limited) | Bold, italic, code, links. No tables. |
| Slack | 40000 chars (but aim for short) | mrkdwn | Bold, italic, code blocks, links, emoji. |
| WhatsApp | 65536 chars | Minimal | Bold, italic, strikethrough, monospace. No links in formatting. |
| iMessage | No hard limit | None | Plain text only. |

**Target: under 280 characters for pulse.** All other responses should fit in a single screen on a phone without scrolling.

## Formatting rules

### Do
- Write like you're texting a cofounder who's busy
- Lead with the most important thing
- Use numbers when they exist ("56 of 63 passing" not "most passing")
- End every response with what to do next — in plain language
- Use line breaks to separate sections (not dividers)
- Use bold for the single most important word/phrase per response

### Don't
- Use terminal characters: `◆`, `▾`, `▸`, `⎯⎯`, `███`, `░░░`
- Use code blocks for non-code content
- Use tables (most platforms render them poorly)
- Use emoji for decoration (✓ and ✗ for status are fine)
- Reference slash commands ("run /eval") — the user may not be in Claude Code
- Use rhino-os jargon without translating: "assertions" → "tests", "bottleneck" → "the thing holding you back", "eval cache" → don't mention it at all

## Translation table

| rhino-os term | Chat-friendly version |
|---------------|----------------------|
| assertions | tests |
| beliefs | things you expect to be true |
| eval | product check |
| bottleneck | the thing holding you back |
| score | health score |
| predictions.tsv | your prediction log |
| sub-scores | scores by area |
| craft score | design quality |
| delivery score | does it work? |
| viability score | will people pay? |
| maturity: building | in progress |
| maturity: working | functional |
| maturity: polished | solid |
| hard gate | approval step |
| plateau | stuck |

## Response structure

Every openclaw response follows this pattern:

```
[Headline fact or status — 1 line]

[Context — 1-2 sentences explaining what this means]

[Action — what to do about it, in plain language]
```

For pulse, compress to:
```
[Score + key metric]. [What happened]. [Bottleneck]. [Opinion].
```

## Tone

- Direct, not casual. "Score dropped 5 points" not "uh oh score went down lol"
- Opinionated. "Fix the auth flow before touching anything else" not "you might want to consider looking at auth"
- Specific. "3 tests failing in the auth module" not "some things are broken"
- Brief. If you can cut a word, cut it.
