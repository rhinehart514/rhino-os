# Discovery Guide — How the Pipeline Works

## What makes a good product spec

A product spec is the contract between intent and implementation. Every skill in rhino-os reads it. If the spec is vague, everything downstream is vague.

### The hierarchy of spec quality

1. **Specific person > category.** "A solo technical founder in month 3 with code but no users" beats "developers" every time.
2. **Measurable change > aspiration.** "Score improves by 10+ points per session" beats "product gets better."
3. **Evidence > belief.** "Forum posts on Indie Hackers asking for this" beats "I think people want this."
4. **Kill list > feature list.** What you refuse to build defines the product more than what you build.
5. **2026 signal > generic timing.** "MCP just became the standard" beats "AI is growing."

### The question sequence for Define mode

Walk the founder through these one at a time via AskUserQuestion. React to their answers. Follow threads. Don't dump all questions at once.

**1. Who has this pain?**
Not "who would use this" — who has the pain RIGHT NOW? Can they name three humans? Where do those humans congregate? What language do they use when describing the pain?

If the founder says "developers" — push back. "Which developers? Building what? At what stage? In what situation?"

**2. What do they do today?**
The current workaround IS the competition. If there's no workaround, there might not be real pain. If the workaround is "they just don't do it," that's either a massive opportunity or a sign nobody cares.

**3. What changes?**
Before/after in one sentence. "Before: guessing what matters. After: every session improves measurably." The sentence should be concrete enough that you could TEST it.

**4. What's the core loop?**
The thing the user does repeatedly. Four parts:
- Trigger: what makes them start?
- Action: what do they do?
- Reward: what do they get?
- Frequency: how often?

A weak core loop = a weak product. If the frequency is "occasionally" or "when they remember," the product doesn't have pull.

**5. What makes them try it?**
The first 5 minutes. Every step is a chance to lose them. What's step 1, step 2, step 3? Where's the first value moment? Where's the most likely drop-off?

**6. What brings them back?**
The return trigger. Three components:
- Mechanism: what pulls them back? (data accumulated, score baseline, new insights)
- Data lock-in: what gets more valuable over time?
- Habit cue: what reminds them to come back?

No return trigger = a tool, not a product. Tools get used once. Products create habits.

**7. What are you NOT building?**
Minimum 3 items. This is the most important section. The kill list defines the product by exclusion. "Not a project management tool" is more useful than "a developer tool."

Push for more. If the founder lists 2 items, say: "Only 2. You haven't killed enough. What else could this become that it SHOULDN'T?"

**8. Why now?**
Must cite a 2026-specific signal. Read references/market-2026.md for valid signals:
- MCP becoming the standard
- Claude Code marketplace (340+ plugins, 89K installs on top skill)
- Solo founders as the new normal (AI tools let one person do what required 5-10)
- Verification > generation shift
- No product-thinking tool exists

"AI is getting better" is NOT a valid why-now. It's always true.

**9. When do you pivot?**
Specific triggers with specific responses. Not "if users don't come back" but "if 3 of our first 10 users don't return within 7 days, we re-examine the core loop."

Each trigger needs:
- The signal (specific, measurable)
- The response (what changes)
- The threshold (how much evidence before acting)

### Systems decomposition (for systems/invert modes)

Five categories of systems:

- **Core value systems** — deliver the primary value. Without these, no product.
- **Enabler systems** — make core systems work (auth, data, config).
- **Growth systems** — bring users back or bring new users (notifications, sharing, onboarding).
- **Intelligence systems** — make the product smarter over time (analytics, learning, personalization).
- **Trust systems** — make users feel safe (security, reliability, transparency).

For each system: what does it DO for the user? What depends on it? What does it depend on? How hard? Table stakes or differentiating?

The critical path answers: "If you could only build 3 systems, which 3?"

### Inversion mode

"What would kill this product?" Map failure modes:
- Onboarding failure (too hard to start)
- Retention failure (no return trigger)
- Competition failure (someone ships it better)
- Tech debt failure (can't iterate fast enough)
- Wrong thesis (the pain doesn't exist)

Rate each: likelihood x defense strength. The most vulnerable failure mode = the missing defensive system.
