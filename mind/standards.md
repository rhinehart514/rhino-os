# Standards — What Quality Means

This is taste, not process. What 0.1% looks like, and the traps that fake it.

## The Measurement Hierarchy

Three tiers, in order of what matters:

1. **Value** — Does the user get something they care about? (the only thing that matters)
2. **Craft** — Is the experience well-made? (amplifies value, can't replace it)
3. **Health** — Is the code clean and stable? (enables craft, invisible to users)

Most dev tools measure bottom-up: health → craft → maybe value. rhino-os measures top-down. A product with rough edges that delivers clear value beats a polished product that doesn't.

**How they map to tools:**
- `rhino score .` → Health (structural lint: build, structure, hygiene)
- `/taste <url> flows` → Delivery (does the frontend work? behavioral audit, issue list)
- `/taste <url>` → Craft (visual product intelligence, 0-100 scale)
- `rhino eval .` → Value (delivery + craft per feature from code analysis)
- `/score` → **Unified** (orchestrates all tiers + agent-backed viability into one number)

`/score` is the authoritative product quality number. It composes health + eval + taste + flows + viability (via market-analyst and customer agents). Each tier runs independently; /score synthesizes.

Score is a SUPPORTING metric. A 100/100 score with zero value is a beautiful corpse. **Eval pass rate is the north star.**

## The Value Checklist

Before every feature, ask these. If you can't answer them, you're building in the dark.

1. **Who gets value?** — Name the human. "Users" is not a name. "A solo founder who just cloned this and wants their project to get better in one session" is.
2. **What changes for them?** — After they use this feature, what's different? If nothing is measurably different, it's not value.
3. **How fast?** — Time from "I found this" to "I got value." Every minute is a chance to lose them. Target: value in the first session, ideally first 5 minutes.
4. **Would they notice if it disappeared?** — If you removed this feature tomorrow, would anyone complain? If not, it's not value — it's furniture.
5. **What's the return trigger?** — Why would they come back tomorrow? If there's no pull, they won't.

## Anti-Gaming Heuristics

Scores lie when you let them. Watch for:

- **Cosmetic-only changes** — Shuffled comments, renamed variables, reformatted code. If the user can't see the difference, the score shouldn't change.
- **Inflation** — 15+ point jump in one commit? Something's wrong. Real improvement is incremental.
- **Plateau** — Score hasn't moved in 3+ changes? The current approach is exhausted. Rethink, don't iterate.
- **Stage ceiling** — An MVP scoring 95/100? The score is wrong, not the product.

Fix the product, not the score. The score is a thermometer, not a thermostat.

## Build Discipline

- **Unit of work = one intent.** A feature, a fix, a refactor. Any number of files. No artificial limits.
- **Atomicity = git commits, not clocks.** No time caps. Each commit is a reviewable, revertable unit.
- **Immutable eval harness** — score.sh, eval.sh, and taste.mjs cannot change during a build.
- **Mechanical keep/revert** — Assertion regressed (was passing, now failing) → revert the commit. No negotiation.
- **Default ambitious.** Build whole features end-to-end, not single-file tweaks.
- **Simplicity bias** — Deleting code for equal results is always a keep. Complexity is debt; justify it against the bottleneck.
