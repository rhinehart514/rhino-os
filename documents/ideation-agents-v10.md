# Ideation & Brainstorming Agents

Captured 2026-03-17. 12 agents, each a different MODE of creative thinking.

A solo founder naturally uses 2-3 thinking modes. They get stuck in those modes.
These agents give access to 12 modes simultaneously — ideas the founder wouldn't
reach alone.

---

## The 12 Modes

### 1. divergent-thinker
Model: opus | Turns: 15
Mode: Volume generation. No filters, no judgment.
Technique: SCAMPER, random association, forced connections.
Output: 30+ raw ideas, numbered, unfiltered. Founder picks sparks.
Why: Solo founders self-censor. This agent has no filter. Weird ideas are the point.

### 2. inverter
Model: sonnet | Turns: 10
Mode: Assumption flipping. Takes any statement and reverses it.
Technique: Invert every clause of the value hypothesis.
Output: 5-10 inversions, each a potential pivot direction.
Why: Founders are anchored to current framing. Inversion breaks the frame.

### 3. constraint-forcer
Model: sonnet | Turns: 10
Mode: Artificial constraints as creative tool.
Technique: "Build this with no UI." "Build this for $1000/mo." "Build this offline."
Output: Solutions that only exist under constraints — often better than unconstrained.
Why: Constraints are the mother of invention.

### 4. user-whisperer
Model: opus | Turns: 15
Mode: Role-play AS the user in specific emotional states.
Technique: "I'm frustrated at 11pm." "I'm skeptical and have 30 minutes." "I'm excited and want to go deep."
Output: Ideas grounded in emotional reality, not logical analysis.
Why: Founders think about what users SHOULD want. This thinks what they FEEL.

### 5. combination-engine
Model: sonnet | Turns: 12
Mode: Smash two things together and see what happens.
Technique: Feature + Feature, Product + Service, Tool + Market.
Output: Integration ideas, mashup features, new product concepts.
Why: Innovation is mostly recombination.

### 6. time-traveler
Model: opus | Turns: 12
Mode: Think from the future backward.
Technique: "It's 2028, 10K users. What exists? What was the unlock?"
Output: Endgame vision + backward chain to what needs to exist first.
Why: Most thinking is incremental. This thinks in leaps.

### 7. pattern-stealer
Model: sonnet | Turns: 15
Mode: Extract structural patterns from successful products.
Technique: Not "copy Notion's features" — "steal Notion's 'everything is a block' pattern."
Output: Patterns applicable to rhino-os with specific implementation ideas.
Why: Copying features is lazy. Stealing patterns is genius.

### 8. killer
Model: sonnet | Turns: 8
Mode: Find the fastest way to disprove any idea.
Technique: Cheapest experiment, strongest counterargument, most likely failure mode.
Output: Kill criteria for every idea. Survivors are 10x more likely to work.
Why: Founders fall in love with ideas. This agent kills them.

### 9. adjacent-explorer
Model: sonnet | Turns: 12
Mode: Find ideas one step away from what exists.
Technique: Map the adjacency graph of every feature and market.
Output: Lowest-effort, highest-value extensions.
Why: Best products grow by adjacency, not moonshot.

### 10. provocateur
Model: opus | Turns: 10
Mode: Challenge the premise. Say the uncomfortable thing.
Technique: "What if the entire direction is wrong?" "What if you should charge 10x more and serve 10x fewer?"
Output: Questions that reframe the entire product.
Why: The most valuable brainstorming moment is the thing nobody will say.

### 11. cross-pollinator
Model: sonnet | Turns: 12
Mode: Import ideas from unrelated fields.
Technique: Medicine, military, sports, cooking, music, architecture, biology, game design.
Output: Structural solutions from other domains applied to our problems.
Why: Best ideas come from outside your field.

### 12. scenario-player
Model: opus | Turns: 15
Mode: Run "what if" scenarios end-to-end.
Technique: "What if YC accepts us?" "What if competitor copies us?" "What if 1000 users tomorrow?"
Output: Gap analysis for non-obvious scenarios.
Why: Founders plan for expected case. This plans for the interesting cases.

---

## How They Work Together

Brainstorming session flow:

1. **divergent-thinker** generates 30+ raw ideas (2 min)
2. **inverter** flips the top assumptions (1 min)
3. **constraint-forcer** adds 3 constraints, generates constrained solutions (2 min)
4. **combination-engine** combines the best raw ideas (1 min)
5. **killer** attacks every idea, finds kill criteria (2 min)
6. **adjacent-explorer** maps extensions of survivors (1 min)

Total: ~10 min, 50+ ideas, filtered to 5-8 survivors with kill criteria.

For deeper sessions:
- **user-whisperer** validates survivors against emotional reality
- **time-traveler** checks if survivors lead to the right endgame
- **pattern-stealer** finds proven patterns for implementation
- **scenario-player** stress-tests survivors against edge scenarios
- **provocateur** challenges whether any of this is the right direction
- **cross-pollinator** imports solutions from other domains

## Which Skills Spawn Which Ideation Agents

| Skill | Agents | When |
|-------|--------|------|
| /ideate | divergent, killer, adjacent, combination | Default brainstorm |
| /ideate wild | inverter, provocateur, time-traveler | High-conviction bets |
| /ideate kill | killer (primary), constraint-forcer | Kill exercise |
| /product | user-whisperer, provocateur, scenario-player | Product pressure-test |
| /strategy | pattern-stealer, cross-pollinator, scenario-player | Strategic thinking |
| /research | adjacent-explorer, cross-pollinator | Exploration |
| /roadmap ideate | time-traveler, adjacent-explorer | Version planning |

## Cost Model

| Tier | Model | Agents | Cost/session |
|------|-------|--------|-------------|
| Premium creative | opus | divergent, user-whisperer, time-traveler, provocateur, scenario-player | ~$0.20-0.40 |
| Analytical creative | sonnet | inverter, constraint, combination, pattern-stealer, killer, adjacent, cross-pollinator | ~$0.05-0.12 |

Full brainstorming session (all 12): ~$1.50-2.00
Quick brainstorm (top 6): ~$0.50-0.80

---

## Product-Building Agents (from same session)

These agents form a complete startup team for a solo founder:

### customer-dev (opus, 25 turns)
Finds potential users, drafts outreach, maintains customer database,
extracts patterns from conversation transcripts. The agent YC cares about most.

### product-designer (opus, 20 turns)
Product THINKER, not UI designer. Makes hard product calls. Maintains living
product spec. Decides between implementation options with stage-appropriate reasoning.

### full-stack-builder (opus, 40 turns)
Builds end-to-end from product spec + customer feedback + competitive analysis.
Ships working code, not components.

### growth-hacker (sonnet, 20 turns)
Gets first 100 users. Concrete actions: community posts, A/B tested headlines,
cold outreach. Maintains growth-log.jsonl with conversion data.

### revenue-engineer (sonnet, 15 turns)
Turns users into money. Pricing design from real data. Stripe integration.
Revenue tracking. "You need to cut churn to 10% OR double conversion to hit $1K MRR."

### demo-builder (sonnet, 15 turns)
Makes the product LOOK good. Records demos, generates GIFs, builds landing
page content. YC demo videos with real traction numbers.

### ops-runner (haiku, 10 turns, background)
Keeps product running. Monitors uptime. Auto-reverts broken deploys.
CronCreate for continuous monitoring.

### pitch-writer (opus, 15 turns)
YC applications, investor updates, pitch decks — all from real data.
"Your application says '50 users.' Reframe: '50 users, 10% paying, 40% WoW growth.'"

### market-researcher (sonnet, 20 turns, background)
Continuous market intelligence. Competitor launches, funding, pricing changes.
Maintains market-intel.json updated weekly.

### qa-tester (haiku, 15 turns)
Breaks your product before users do. Full regression + exploratory testing
after every build. Bug rate tracking.

### data-analyst (sonnet, 15 turns)
Turns raw data into decisions. Every insight ends with "therefore, do X."
Weekly reports: activation bottleneck, retention cohorts, feature usage.

### legal-ops (sonnet, 10 turns)
ToS, privacy policy, GDPR, SOC 2 readiness. Reads codebase for data handling
issues. Delaware C-corp checklist for YC.
