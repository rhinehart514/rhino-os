# Standards — What Quality Means

This is taste, not process. What 0.1% looks like, and the traps that fake it.

## The Measurement Hierarchy

Three tiers, in order of what matters:

1. **Value** — Does the user get something they care about? (the only thing that matters)
2. **Craft** — Is the experience well-made? (amplifies value, can't replace it)
3. **Health** — Is the code clean and stable? (enables craft, invisible to users)

Most dev tools measure bottom-up: health → craft → maybe value. rhino-os measures top-down. A product with rough edges that delivers clear value beats a polished product that doesn't.

**The question every tier answers: does the user get it?**

This applies to any product surface — web UI, CLI output, API responses, docs. The evidence changes. The question doesn't.

## The Product Journey

A product isn't code. It's the full path a human walks from "I heard about this" to "I can't live without it." Every stage is a potential failure point. Measuring code quality while ignoring the journey is like tuning an engine in a car with no wheels.

```
FIND → UNDERSTAND → TRY → GET VALUE → COME BACK → TELL SOMEONE → PAY
```

**FIND** — How does someone discover this product?
- Acquisition surface exists (landing page, marketplace listing, README-as-marketing)
- Discoverable where the target user already looks
- Social proof (stars, testimonials, case studies, usage numbers)

**UNDERSTAND** — In 5 seconds, do they get it?
- Value proposition is specific and outcome-focused (not feature-focused)
- Clear who it's for and who it's NOT for
- One sentence explains what changes for the user

**TRY** — How much friction to first experience?
- Install/signup is one action, not three
- Time from "I want to try this" to "I got something useful" is minimized
- Failure during setup has recovery guidance, not just an error

**GET VALUE** — Does it actually help?
- First session delivers a concrete outcome
- The user does LESS work than without the product, not more
- The output changes what the user does next

**COME BACK** — Why tomorrow?
- State persists and makes next session better than the first
- There's a pull — something the user wants to check or continue
- The product compounds (session 10 is meaningfully better than session 1)

**TELL SOMEONE** — Is there a shareable moment?
- Output worth screenshotting or copy-pasting
- Easy to explain to someone else in one sentence
- "Try this" is a low-effort ask (not "install 5 things and configure a YAML file")

**PAY** — Does the value justify a price?
- Pricing exists and is visible before deep commitment
- The free/paid boundary maps to real value thresholds
- The user would pay to keep it, not just use it because it's free

**How the journey maps to measurement:**
- `/eval` measures GET VALUE (delivery + craft from code)
- `/taste` measures UNDERSTAND + GET VALUE (product surface quality)
- `/taste flows` measures TRY + GET VALUE (does it actually work?)
- `/score viability` measures FIND + PAY (market position, competitive landscape)
- `/push` checks ALL stages and surfaces gaps at every level

Score is a SUPPORTING metric. A 100/100 score with zero value is a beautiful corpse. A perfect codebase that nobody can find, understand, or try is a product failure.

## Five Rings of Product Thinking

When evaluating or improving a product, think at five levels — from inside out:

```
CODE → FEATURE → PRODUCT → MARKET → VISION
```

**Code** — Is this function correct? Is this script robust?
**Feature** — Does this capability deliver its promise? Is anything missing?
**Product** — Does the full journey work? Is every stage covered?
**Market** — What's happening outside? Competitors, trends, platform shifts, user behavior changes?
**Vision** — What's the 10x version? What would make this inevitable?

The inner rings are measurable from code. The outer rings require external awareness — market research, user feedback, competitive analysis, strategic thinking. Both matter. A product that scores 90 on code quality but has no acquisition surface is a private hobby project.

**How rings map to maturity:**
- Score 0-50: mostly Code + Feature rings
- Score 50-70: add Product ring (is the journey complete?)
- Score 70-85: add Market ring (how does this compare? what's shifting?)
- Score 85+: add Vision ring (what's the 10x version?)

**How they map to skills:**
- `/eval` → Code + Feature rings (delivery + craft per feature from code analysis)
- `/taste` → Product ring (product surface intelligence — visual, output, interaction)
- `/taste flows` → Product ring (does the journey work end-to-end?)
- `/score` → Unified (orchestrates all tiers into one number)
- `/push` → All five rings (extract gaps, diagnose, ideate at every level)
- `/strategy` → Market ring (competitive position, market shifts)
- `/product` → Vision ring (is this the right thing to build?)
- `/research` → Market ring (gather external evidence)
- `/discover` → Feature + Product rings (what should exist?)

Skills call internal CLI tools (`rhino score .`, `rhino eval .`) as plumbing — those are not the product surface.

## The Value Checklist

Before every feature, ask these. If you can't answer them, you're building in the dark.

1. **Who gets value?** — Name the human. "Users" is not a name. "A solo founder who just cloned this and wants their project to get better in one session" is.
2. **What changes for them?** — After they use this feature, what's different? If nothing is measurably different, it's not value.
3. **How do they find it?** — Where does your target user already look? If this feature exists but nobody can discover it, it delivers zero value.
4. **How fast?** — Time from "I found this" to "I got value." Every minute is a chance to lose them. Target: value in the first session, ideally first 5 minutes.
5. **Would they notice if it disappeared?** — If you removed this feature tomorrow, would anyone complain? If not, it's not value — it's furniture.
6. **What's the return trigger?** — Why would they come back tomorrow? If there's no pull, they won't.
7. **Would they tell someone?** — Is there a moment good enough to share? If nothing is screenshot-worthy or copy-paste-worthy, the product isn't creating shareable value.
8. **Would they pay?** — Not "could we charge" but "would they pay to keep this." If the answer is unclear, the value isn't strong enough yet.

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
