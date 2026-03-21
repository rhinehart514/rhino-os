# Voice — How rhino-os Communicates

Every command reads this. Output should feel like a native Claude Code extension, not a framework bolted on top.

## Principles

1. **Scan, don't read.** Users skim terminal output. Lead with the signal, dim the noise. If someone glances at your output for 2 seconds, they should get the key info.
2. **Consistent status blocks.** Every command opens with a status line and closes with a next-action line. Same format, every time.
3. **Show momentum.** During loops (/go), the user should feel progress — not silence punctuated by walls of text.
4. **Match Claude Code's aesthetic.** Dim labels, bold values, minimal color. No ASCII art, no boxes, no banners.

## Output Format

### Status block (open every command with this)

```
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
score  80/100  ████████████████░░░░
       build 100 · struct 80 · hygiene 95
plan   3 tasks · ▸ Fix value-hypothesis eval
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
```

Rules:
- Use `⎯` (horizontal bar, U+2500 range) as separator, not `---` (which renders as markdown `<hr>`)
- Score bar: `█` for filled, `░` for empty. 20 chars total = 5 points per char.
- Color the bar: green (≥80), yellow (50-79), red (<50). Sub-scores same thresholds.
- Always show score + plan in the status block if they exist. Omit sections that don't exist yet.

### Section headers

Use **bold** for section names within a command's output. Keep them short:

```
**Bottleneck**
The bottleneck is activation — users land but don't complete the first loop.

**Prediction**
I predict score improves +5 after fixing the empty state on /dashboard.
Because: new UI elements have 100% keep rate (experiment-learnings.md).
I'd be wrong if: the empty state isn't the dropout point.

**Tasks**
1. ▸ Fix empty state on /dashboard
2. · Wire value-hypothesis eval
3. · Kill dead-end on /settings
```

Rules:
- No `###` headers (too heavy). Use **bold** inline.
- Tasks: `▸` for the current/next task, `·` for queued, `✓` for done.
- Keep section content to 1-3 lines. If you need more, you're over-explaining.

### Iteration pulse (/go loop)

Every iteration, output one compact block:

```
⎯ iteration 3 ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
predict  Score +3 from empty state fix
build    app/dashboard/page.tsx — added fallback UI
measure  78 → 81 (+3) ✓ kept
model    Confirmed: new UI elements improve score
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
```

Rules:
- Four lines max per iteration: predict, build, measure, model.
- `✓ kept` / `✗ reverted` / `⟳ retrying` after the score delta.
- Every 3 iterations, add a progress summary line:
  ```
  ⎯ progress ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  3/5 tasks · score 75 → 81 · predictions 2/3
  ```

### Completion block (close every command with this)

```
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
done   3/5 tasks · score 75 → 83 · 2/3 predictions correct
next   Run /go to continue · 2 tasks remaining
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
```

Rules:
- Always end with a `next` line. One action. Not a menu.
- `done` summarizes what happened. Numbers, not prose.

### Alerts and warnings

Inline, not blocks:

```
⚠ Strategy stale (4d) — will refresh inline
⚠ 3 ungraded predictions — run /retro
● value-hypothesis-exists failing (block severity)
```

Rules:
- `⚠` for warnings (yellow). `●` for blockers (red). `✓` for resolved (green).
- One line per alert. No paragraphs.
- Blockers before warnings.

### Data tables

For structured data (feature breakdowns, score comparisons, multi-item lists), use aligned columnar tables with inline bars:

```
                              del  cra  via
todo         60 ████████░░░░  68   58   28  ●●
learning     64 ████████░░░░  62   67   73  ●●●●
scoring      68 █████████░░░  72   65   79  ●●●●●
commands     73 █████████░░░  78   72   72  ●●●●●
```

Rules:
- **Name column**: left-aligned, bold. 12 chars wide.
- **Score + bar**: score value (colored), then compact 12-char bar inline.
- **Sub-scores**: right-aligned numbers, colored by threshold.
- **Weight**: use `●` dots (1 dot per weight point, dim).
- **Sort**: worst-to-best (worst at top catches the eye first).
- **Header row**: dim, no separators — just column labels above the data.
- No box-drawing characters (`┌─┬─┐`). No markdown table pipes (`|`). Just aligned text.
- Each row is one line. Dense, scannable, appealing.

Use this pattern whenever you display 3+ items with comparable metrics. For 1-2 items, use the label-value format instead.

## What NOT to do

- **No prose summaries at the end.** "Great session! We accomplished a lot." is noise. The numbers speak.
- **No restating what just happened.** The user saw it happen. Don't narrate.
- **No box-drawing or markdown tables.** Use aligned columns, not `┌─┬─┐` or `| col |`.
- **No emoji** beyond the standard set: `▸ · ✓ ✗ ⟳ ⚠ ● ◆`
- **No color for decoration.** Color means something: green = good/done, yellow = warning/mid, red = bad/blocker. That's it.
- **No long explanations between actions.** If you need to explain why, one sentence. If it takes a paragraph, the decision isn't clear enough.

## Score bar helper

Two sizes depending on context:

**Large bar (headers, single-score displays):** 20 characters.
- Filled chars: `round(score / 5)` using `█`
- Empty chars: `20 - filled` using `░`

**Compact bar (table rows, inline):** 12 characters.
- Filled chars: `round(score / 8)` using `█`
- Empty chars: `12 - filled` using `░`

Color: green if ≥80, yellow if 50-79, red if <50.

Example (large): score 73 → `██████████████░░░░░░` (15 filled, yellow)
Example (compact): score 73 → `█████████░░░` (9 filled, yellow)
