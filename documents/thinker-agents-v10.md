# Thinker Agents — Deep Ideation

Captured 2026-03-17. 20 thinker agents organized by what they think about.

The gap: our existing 14 agents live in Act and Measure. The thinking gaps are in
Model (how the world works), Predict (what will happen), and Update (what changed).

A founder can think about their product. They can't:
- Think about 50 things simultaneously and spot the contradiction
- Remember every prediction and notice the pattern in what's wrong
- Hold the full competitive landscape while making a feature decision
- Notice their own avoidance patterns in real-time
- Synthesize 6 data sources into one recommendation without losing signal

Those are the 100x thinking capabilities.

---

## Category 1: Thinking about the PRODUCT (what are we building?)

### 1. first-principles-reasoner
Model: opus | Turns: 12

Strips away assumptions. Given any feature or direction, asks: "What would we build
if we started from scratch knowing what we know now?" Reads eval-cache,
experiment-learnings, customer-intel. Outputs: "You're building X because of
decision Y made 3 weeks ago. The evidence since then says Z. If you started
today, you'd build W instead."

Why 100x: Founders get anchored to early decisions. This agent is the
anti-anchoring mechanism. Thinks from evidence, not history.

### 2. user-simulator
Model: opus | Turns: 15

Maintains a model of the target user. Given any feature or change, simulates:
"A solo founder who just installed this would see X, feel Y, do Z." Not a
persona doc — an active simulation. "Would this user understand the boot card?"
"Would they run /plan or /go first?" Grounded in customer-intel.json when
available, extrapolated from value hypothesis when not.

Why 100x: The founder is too close to the product to see it fresh. This agent
is always a stranger.

### 3. value-chain-tracer
Model: sonnet | Turns: 15

Traces how value flows through the product. Given a user action ("founder types
/plan"), maps every downstream effect: files read, decisions made, output
produced, what user does next. Identifies broken links where value leaks:
"/plan recommends /research, but /research doesn't read /plan's output — dead end."

Why 100x: Complex products have invisible broken links. This agent traces the
full chain and finds where value disappears.

### 4. simplicity-auditor
Model: sonnet | Turns: 10

Adversarial agent that argues for LESS. Given current state (34 agents, 31 skills),
asks: "What if we had 10 agents and 12 skills? What would we keep?" Forces hard
kill decisions. Applies Anthropic guide: "it can be quite easy to create bad or
redundant skills."

Why 100x: The natural tendency is to add. This agent's job is to subtract.
Complexity is the enemy of adoption.

---

## Category 2: Thinking about the MARKET (where do we fit?)

### 5. positioning-reasoner
Model: opus | Turns: 12

Holds competitive landscape in working memory and reasons about positioning.
Not "what do competitors do?" but "given what competitors do, what claim can we
UNIQUELY make that is also TRUE and also MATTERS to our user?" Outputs one
sentence: the positioning statement, updated with evidence.

Why 100x: Positioning requires holding N competitors + product + user simultaneously.
Humans hold ~3. This agent holds all of them.

### 6. timing-analyst
Model: sonnet | Turns: 10

Thinks about WHEN, not WHAT. "Is this the right time for this feature? Is the
market ready? Are we ready?" Reads market signals, competitive moves, tech trends.
"Ship /verify now because verification lattice is peaking. Defer /launch because
0 users — distribution tooling is premature."

Why 100x: Solo founders build what excites them, not what the moment demands.

### 7. demand-reasoner
Model: sonnet | Turns: 10

Reasons about demand. Not "would people want this?" (always yes) but "is there
EVIDENCE people want this RIGHT NOW?" Distinguishes: stated demand (people say),
revealed demand (people pay), latent demand (problem exists, nobody solving).
Grades demand confidence.

Why 100x: Most ideas die not because they're bad but because demand is imagined.

---

## Category 3: Thinking about the LEARNING LOOP (what do we know?)

### 8. epistemologist
Model: sonnet | Turns: 12

Thinks about what we know, think we know, and are wrong about. Reads
experiment-learnings.md: "Which Known Patterns have we never tested? Which
Uncertain Patterns have enough evidence to promote? Which Dead Ends should we
retry because conditions changed?"

Why 100x: The knowledge model is the product (per thinking.md). But it's
append-only. This agent is the knowledge model's immune system.

### 9. prediction-calibrator
Model: sonnet | Turns: 8

Analyzes prediction history for CALIBRATION, not accuracy. "Predictions about
craft scores are 90% right (too safe). Predictions about user behavior are 20%
right (broken model). Predictions about delivery are 60% (well-calibrated)."
Finds domain-specific blind spots.

Why 100x: 63% overall accuracy hides domain-specific miscalibration.

### 10. exploration-strategist
Model: sonnet | Turns: 8

Decides what to explore next. Reads Unknown Territory, weighs information value
against cost. "Testing whether non-founders can complete the loop costs one session
and resolves 3 downstream decisions. Higher value than testing template consistency."

Why 100x: System gravitates toward known patterns (confirmed in self.md). This
agent enforces exploration of unknown territory.

### 11. contradiction-detector
Model: haiku | Turns: 8

Scans ALL artifacts for contradictions. "Value hypothesis says 'less effort than
manually' but install scores 53 and requires 4 manual steps." "Roadmap thesis is
plugin distribution but mode is 'build' with no shipping pressure."

Why 100x: Contradictions accumulate silently. No human re-reads all artifacts
every session. This agent does.

---

## Category 4: Thinking about DECISIONS (what should we do?)

### 12. bottleneck-finder
Model: sonnet | Turns: 8

Pure bottleneck identification. Reads everything. Outputs ONE thing: "The
bottleneck is X because Y, and fixing it unblocks Z." Not a list. Not options.
One answer with reasoning.

Why 100x: /plan presents options. This agent is the opinionated version.

### 13. second-order-thinker
Model: opus | Turns: 10

Given a proposed action, thinks two steps ahead. "Build /verify → /eval gets
accurate → /go keep/revert becomes reliable → autonomous builds trustworthy →
ship /go to external users." Traces consequence chains for hidden leverage
and hidden risks.

Why 100x: Founders think one step. This agent thinks three.

### 14. cost-benefit-reasoner
Model: sonnet | Turns: 8

Estimates: tokens, time, opportunity cost, expected value, information value.
"Verifier costs ~4h and ~$2. Fixes /eval variance, enables reliable /go.
Alternative: finish todo.sh (42→65). Recommendation: verifier, because it
compounds across all skills."

Why 100x: Solo founders have one scarce resource: attention.

### 15. devil's-advocate
Model: opus | Turns: 10

Constructs the strongest possible case AGAINST any plan. Not generic — specific,
evidence-grounded. "You want 20 new agents. Counter: existing 14 have 'named
references wasted — skills bypass them.' Adding 20 more to a system that doesn't
fully use 14 is feature sprawl pattern #3."

Why 100x: The anti-sycophancy agent. Says what the founder doesn't want to hear.

---

## Category 5: Thinking about the FOUNDER (what am I doing wrong?)

### 16. avoidance-detector
Model: sonnet | Turns: 8

Reads behavior patterns (git log, command usage, prediction topics) and detects
avoidance. "You've run /ideate 3x this week and /go 0x. You're ideating instead
of building. Bottleneck is todo.sh at 42, not new agent ideas."

Why 100x: startup-patterns.md checks repo state. This checks BEHAVIOR. Notices
what you're doing, not what you say.

### 17. energy-reader
Model: haiku | Turns: 5

Reads commit patterns, message tone, session length, prediction specificity.
Detects: burnout (15+ commits/day, 3+ days), disengagement (decreasing prediction
quality), scope creep (increasing files per commit), tunnel vision (same feature
5+ sessions, no score movement). Interventions are questions, not commands.

Why 100x: Solo founders have no teammate to say "hey, you okay?"

### 18. accountability-partner
Model: sonnet | Turns: 8

Reads predictions from previous sessions and forces confrontation. "Last session
you predicted /verify would start within 2 days. It's been 4 days. What happened?"
Not judgmental — curious. Tracks commitments across sessions.

Why 100x: Predictions without accountability are journaling.

---

## Category 6: Thinking about NARRATIVE (what's the story?)

### 19. story-synthesizer
Model: opus | Turns: 12

Constructs the honest narrative from evidence. Not marketing — the REAL story.
"Started measuring health. Learned health doesn't predict value. Pivoted to
assertions. Learned LLM judges are unreliable. Building mechanical verification.
Story: measurement only works when it touches reality."

Why 100x: Every product has a story but founders can't see it — they're living it.

### 20. analogy-finder
Model: sonnet | Turns: 8

Given a challenge, finds structurally valid analogies from other domains. "Your
/eval variance is like A/B testing before statistical significance. Fix was same:
more samples, fixed methodology, predetermined stopping rules." Cross-pollinates
from engineering history, scientific method, startup patterns.

Why 100x: Best solutions come from other domains. Solo founders only see their own.

---

## Thinker Cost Model

| Tier | Model | Agents | Cost/call | Use frequency |
|------|-------|--------|-----------|---------------|
| Strategic | opus | first-principles, user-simulator, positioning, second-order, devil's-advocate, story-synthesizer | ~$0.20-0.50 | Rare (weekly, major decisions) |
| Analytical | sonnet | value-chain, timing, demand, epistemologist, calibrator, exploration, bottleneck, cost-benefit, avoidance, accountability, analogy | ~$0.05-0.15 | Regular (per session, per decision) |
| Sentinel | haiku | simplicity-auditor, contradiction-detector, energy-reader | ~$0.01-0.03 | Frequent (every session, background) |

## Which Skills Spawn Which Thinkers

| Skill | Thinker agents |
|-------|---------------|
| /plan | bottleneck-finder, cost-benefit-reasoner, avoidance-detector |
| /product | first-principles-reasoner, user-simulator, demand-reasoner |
| /strategy | positioning-reasoner, timing-analyst, devil's-advocate |
| /ideate | demand-reasoner, second-order-thinker, simplicity-auditor |
| /eval | contradiction-detector, value-chain-tracer |
| /retro | epistemologist, prediction-calibrator, accountability-partner |
| /go | cost-benefit-reasoner, second-order-thinker |
| /roadmap | story-synthesizer, timing-analyst |
| /research | exploration-strategist, demand-reasoner |
| /money | demand-reasoner, cost-benefit-reasoner |
| /rhino | energy-reader, avoidance-detector, contradiction-detector |
| /ship | devil's-advocate, timing-analyst |
| /taste | user-simulator, simplicity-auditor |
| /copy | positioning-reasoner, story-synthesizer, analogy-finder |

## The Meta-Insight

The thinker agents map directly to thinking.md's core loop:

- **Observe**: contradiction-detector, value-chain-tracer, energy-reader
- **Model**: epistemologist, prediction-calibrator, user-simulator
- **Predict**: hypothesis-generator (from doer plan), exploration-strategist
- **Act**: (existing builder, refactorer — plus new doer agents)
- **Measure**: (existing measurer, evaluator — plus new verifier, score-monitor)
- **Update**: accountability-partner, first-principles-reasoner, story-synthesizer

The existing 14 agents cluster in Act and Measure.
The 20 new thinkers fill Observe, Model, Predict, and Update.
The 10 new doers add real-world verification to Measure.

Together: a complete thinking system.
