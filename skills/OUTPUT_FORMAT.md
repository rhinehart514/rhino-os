# Output Format — The ONE Canonical Spec

Every skill follows this format. No exceptions except /rhino (dashboard uses `──` dividers) and /product (7-lens structure uses `──` dividers).

## Header

```
◆ [command] — [scope]
```

- Command name without slash prefix: `◆ plan — auth`, not `◆ /plan`
- Scope is optional: `◆ retro — 3 ungraded, 2 stale` or just `◆ shipped`
- Em-dash with spaces: ` — ` (not `—` or `-` or `:`)

## State Bar

One line, immediately after header:

```
v[X.Y]: **[pct]%** · product: **[pct]%** · score: [N]
```

- Version completion bold, product completion bold, score plain
- Separated by ` · ` (space-dot-space)
- Only show what's available — skip missing signals, don't show placeholders

## Thesis

Always on its own line when shown:

```
thesis: "[text]"
```

Quoted, lowercase key.

## Section Markers

```
▾  collapsible heading (detail section)
▸  action / move / active item
·  pending / backlog / unresolved
✓  pass / done / resolved
✗  fail / wrong
⚠  warning / attention needed
```

## Bars

20 characters wide. `█` filled, `░` empty.

```
████████████░░░░░░░░  working   60%
██████░░░░░░░░░░░░░░  building  30%
████████████████████  polished  100%
░░░░░░░░░░░░░░░░░░░░  planned   0%
```

## Bottom Commands

Exactly 3 next commands. Always at the very end. No more, no fewer.

```
/command1       brief description
/command2       brief description
/command3       brief description
```

Left-aligned command, tab-indented description. No bullets, no numbers.

## General Rules

- Dense over verbose — every line earns its place
- Bold for emphasis: **feature names**, **percentages**, **verdicts**
- No trailing summaries — the output IS the summary
- No preamble — start with the header, not "Here's what I found"
- No emoji beyond the section markers above
