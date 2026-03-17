# Agent Expansion Plan — v10 Ideation

Captured 2026-03-17. 20 new agents (10 thinkers, 10 doers), 10 new skills.
The thinker layer reasons about what matters. The doer layer proves it.

## The Architecture: Thinkers + Doers

Every decision loop has two phases:
1. **Think** — what should we check? what matters? what's the hypothesis?
2. **Do** — run it, measure it, prove it

Current rhino-os (v9.0): 14 thinker agents, 0 doer agents.
Target (v10): 14 existing thinkers + 10 new thinkers + 10 new doers = 34 agents.

The thinker-doer pairing:
- Thinker decides what to verify → Doer runs verification
- Thinker identifies market question → Doer fetches real data
- Thinker spots regression pattern → Doer traces the incident
- Thinker generates hypothesis → Doer tests it mechanically

## 10 New Thinker Agents

### 1. strategist
**Model:** opus | **Turns:** 15 | **BG:** no
Synthesizes multiple data sources (eval-cache, market-data, customer-intel, score history) into strategic recommendations. Not "here's the landscape" (that's market-analyst) — "here's what we should do about it and why." Makes judgment calls that downstream doers execute.
**Feeds:** release-gate (what to ship), harvester (what data to fetch), competitor-crawler (who to analyze)
**Consumes:** harvester output, signal-aggregator output, eval-cache

### 2. hypothesis-generator
**Model:** sonnet | **Turns:** 10 | **BG:** no
Reads experiment-learnings.md Unknown Territory + eval gaps + prediction failures. Generates testable hypotheses with specific pass/fail criteria. "I predict running the onboarding flow will fail at step 3 because install.sh only symlinks 3 commands." Every hypothesis becomes a verifier task.
**Feeds:** verifier (what to test), onboarding-auditor (what flows to check)
**Consumes:** experiment-learnings.md, eval-cache, predictions.tsv

### 3. prioritizer
**Model:** sonnet | **Turns:** 8 | **BG:** no
Given N possible actions (from /ideate, /todo, /plan), ranks by expected information value. Uses prediction accuracy history to weight: actions in Unknown Territory rank higher than Known Pattern exploitation. Prevents the system from gravitating toward known patterns when unknowns have higher learning value.
**Feeds:** /plan task ordering, /go build sequence
**Consumes:** predictions.tsv (accuracy by domain), experiment-learnings.md, todos.yml

### 4. risk-assessor
**Model:** sonnet | **Turns:** 8 | **BG:** no
Evaluates proposed changes before execution. Reads the diff, checks which assertions might break, estimates score impact, flags irreversible actions. Outputs risk score (low/medium/high) that release-gate uses for auto-approve vs escalate decisions. The "measure twice" agent.
**Feeds:** release-gate (risk level), /go (revert triggers)
**Consumes:** git diff, beliefs.yml, eval-cache, score-cache

### 5. pattern-detector
**Model:** sonnet | **Turns:** 12 | **BG:** yes
Reads score history, prediction log, eval cache deltas over time. Detects patterns humans miss: "score always drops on Mondays" (stale cache), "predictions about craft are 80% wrong" (miscalibrated model), "feature X improves when feature Y changes" (hidden dependencies). Updates experiment-learnings.md with discovered patterns.
**Feeds:** experiment-learnings.md, /retro analysis
**Consumes:** history.tsv, predictions.tsv, eval-cache over time

### 6. user-modeler
**Model:** opus | **Turns:** 15 | **BG:** no
Builds and maintains a model of who the target user is, what they care about, and what they'd do next. Not a persona doc — a living model that updates from customer-intel.json, interview notes, feedback signals. When /product asks "would a user care about X?" — this agent has the answer grounded in accumulated evidence.
**Feeds:** /product decisions, /ideate evidence, /copy voice
**Consumes:** customer-intel.json, interview notes, GitHub issues, feedback

### 7. thesis-validator
**Model:** sonnet | **Turns:** 10 | **BG:** no
Reads current roadmap thesis and available evidence. Judges: is the thesis proven, disproven, or still open? Not optimistic — adversarial. Looks for evidence AGAINST the thesis as hard as evidence for it. Prevents the failure mode where founders keep building toward a thesis that evidence has already killed.
**Feeds:** /roadmap (bump decisions), /plan (thesis alignment)
**Consumes:** roadmap.yml, eval-cache, experiment-learnings.md, customer-intel.json

### 8. coherence-checker
**Model:** sonnet | **Turns:** 8 | **BG:** no
Checks that all the pieces of the product tell one story. Does the README match what /eval measures? Does the value hypothesis match what the features deliver? Do the assertions test what the thesis claims? Finds contradictions between artifacts that accumulate as the product evolves.
**Feeds:** /product coherence audit, /copy positioning
**Consumes:** README, rhino.yml, beliefs.yml, roadmap.yml, eval-cache

### 9. question-ranker
**Model:** haiku | **Turns:** 5 | **BG:** no
Given a set of open questions (from Unknown Territory, from /research, from /product), ranks by information value per token spent. "Answering question A costs ~$0.03 and resolves 2 downstream decisions. Answering question B costs ~$0.50 and resolves 1." Prevents expensive research on low-value questions.
**Feeds:** /research (what to investigate), harvester (what to fetch)
**Consumes:** experiment-learnings.md Unknown Territory, todos.yml research items

### 10. narrative-builder
**Model:** opus | **Turns:** 15 | **BG:** no
Constructs the story of the product from evidence. Not marketing copy — the honest narrative: "We started with X. We learned Y. We're now building toward Z because of evidence A, B, C." This narrative feeds /copy, /ship release notes, /roadmap version summaries, and investor updates. The difference between "we built stuff" and "here's why it matters."
**Feeds:** /copy, /ship, /roadmap, /product
**Consumes:** roadmap.yml (version history), experiment-learnings.md, eval-cache, customer-intel.json

---

## 10 New Doer Agents

### 1. verifier
**Model:** haiku | **Turns:** 10 | **BG:** no
Mechanical proof. Runs commands, hits endpoints, checks outputs programmatically. Reports pass/fail with evidence. No LLM judgment — assertion checking.
**Anthropic category:** Product Verification
**Serves:** /verify, /eval, /go, /assert

### 2. score-monitor
**Model:** haiku | **Turns:** 5 | **BG:** yes
CronCreate persistent watcher. Polls score, detects regressions, alerts on meaningful changes. Writes monitoring-log.jsonl.
**Anthropic category:** Business Process Automation
**Serves:** /monitor, /retro, /plan

### 3. harvester
**Model:** haiku | **Turns:** 15 | **BG:** yes
Data pipeline. Fetches structured data from GitHub API, npm, social search, Google Trends. Writes JSON. No prose.
**Anthropic category:** Data Fetching & Analysis
**Serves:** /signal, /strategy, /money, /research, /launch

### 4. release-gate
**Model:** haiku | **Turns:** 8 | **BG:** no
Verification lattice. Runs checklist mechanically: assertions, score, eval freshness, changelog, beliefs. Pass/fail with blockers.
**Anthropic category:** CI/CD & Deployment
**Serves:** /gate, /ship, /go

### 5. onboarding-auditor
**Model:** sonnet | **Turns:** 15 | **BG:** no
End-to-end flow tester. Runs full product flow in isolation. Times steps. Screenshots states. Reports friction points.
**Anthropic category:** Product Verification
**Serves:** /verify, /onboard, /product, /taste

### 6. competitor-crawler
**Model:** sonnet | **Turns:** 20 | **BG:** yes
Playwright site teardown. Marketing site, docs, GitHub, pricing, reviews. Structured JSON output.
**Anthropic category:** Data Fetching + Runbooks
**Serves:** /compete, /strategy, /ideate

### 7. signal-aggregator
**Model:** haiku | **Turns:** 10 | **BG:** yes
Polls GitHub Issues, discussions, social mentions. Clusters themes. Writes customer-intel.json.
**Anthropic category:** Data Fetching & Analysis
**Serves:** /signal, /product, /ideate

### 8. funnel-modeler
**Model:** sonnet | **Turns:** 12 | **BG:** no
Conversion analysis. Models funnel from data, identifies biggest drop-off, recommends fix point.
**Anthropic category:** Data Fetching & Analysis
**Serves:** /funnel, /strategy, /plan

### 9. demo-recorder
**Model:** sonnet | **Turns:** 15 | **BG:** no
Playwright walkthrough. Navigates flows, screenshots, annotates. Outputs shareable markdown or artifact.
**Anthropic category:** Product Verification
**Serves:** /demo, /copy, /ship

### 10. incident-tracer
**Model:** sonnet | **Turns:** 12 | **BG:** no
Incident reconstruction. Given symptom, reads git/score/eval/prediction history. Builds timeline, identifies root cause.
**Anthropic category:** Runbooks
**Serves:** /replay, /retro, /go

---

## 10 New Skills

### 1. /verify
Run the product, check it works. Mechanical proof, not LLM judgment.
Agents: verifier, onboarding-auditor

### 2. /monitor
Persistent score/regression tracking via CronCreate. Alerts on meaningful changes.
Agents: score-monitor

### 3. /compete
Competitor teardown on demand. Structured intelligence brief.
Agents: competitor-crawler

### 4. /gate
Pre-ship verification lattice. Risk-based auto-approve or escalate.
Agents: release-gate, risk-assessor

### 5. /signal
Aggregate real user/market signals from external sources.
Agents: signal-aggregator, harvester

### 6. /careful
On-demand hooks for risky operations. Session-scoped behavior modification.
Agents: none (pure hook skill)

### 7. /demo
Generate recorded product walkthrough. Shareable artifact.
Agents: demo-recorder

### 8. /funnel
Model conversion funnel from real data. Identify biggest drop-off.
Agents: funnel-modeler

### 9. /launch
Sequenced multi-channel launch plan with concrete actions and timeline.
Agents: harvester, narrative-builder

### 10. /replay
Incident reconstruction. Symptom to root cause timeline.
Agents: incident-tracer

---

## Thinker-Doer Pairings

| Decision Loop | Thinker | Doer | Skill |
|--------------|---------|------|-------|
| Is this worth building? | hypothesis-generator | verifier | /verify |
| What should we work on? | prioritizer | (existing builder) | /plan |
| Is this ready to ship? | risk-assessor | release-gate | /gate |
| What's the competition doing? | strategist | competitor-crawler | /compete |
| What do users want? | user-modeler | signal-aggregator | /signal |
| Is the thesis still valid? | thesis-validator | harvester | /roadmap |
| Are we regressing? | pattern-detector | score-monitor | /monitor |
| What's the story? | narrative-builder | demo-recorder | /demo |
| Where should we launch? | strategist | harvester | /launch |
| What went wrong? | coherence-checker | incident-tracer | /replay |

## Full Agent Roster (v10 target: 34 agents)

### Existing Thinkers (14)
builder(opus), explorer(sonnet), evaluator(opus), market-analyst(opus),
measurer(haiku), reviewer(haiku), grader(sonnet), debugger(sonnet),
refactorer(sonnet), customer(sonnet), founder-coach(opus),
consolidator(sonnet), gtm(opus), copywriter(opus)

### New Thinkers (10)
strategist(opus), hypothesis-generator(sonnet), prioritizer(sonnet),
risk-assessor(sonnet), pattern-detector(sonnet), user-modeler(opus),
thesis-validator(sonnet), coherence-checker(sonnet),
question-ranker(haiku), narrative-builder(opus)

### New Doers (10)
verifier(haiku), score-monitor(haiku), harvester(haiku),
release-gate(haiku), onboarding-auditor(sonnet), competitor-crawler(sonnet),
signal-aggregator(haiku), funnel-modeler(sonnet),
demo-recorder(sonnet), incident-tracer(sonnet)

## Full Skill Roster (v10 target: 31 skills)

### Existing (21)
/plan, /go, /eval, /taste, /feature, /onboard, /ship, /ideate,
/research, /roadmap, /rhino, /assert, /clone, /retro, /skill,
/strategy, /todo, /product, /configure, /money, /copy

### New (10)
/verify, /monitor, /compete, /gate, /signal, /careful, /demo,
/funnel, /launch, /replay

### Killed
/discover (folded into /ideate)

## Structural Change: Scripts Architecture

Move heavy skill logic to scripts/ directories. Skills become thin orchestrators.
Scripts do deterministic work at zero context cost (only output enters context window).
bin/ already does this correctly. Skills should follow the same pattern.

Priority skills to refactor: /eval, /research, /strategy (longest SKILL.md files).

## Cost Model (estimated per-run)

| Agent tier | Model | Cost/run | Use pattern |
|-----------|-------|----------|-------------|
| Economy doers | haiku | ~$0.01-0.03 | Every build, every check |
| Balanced | sonnet | ~$0.05-0.15 | On-demand, specific investigations |
| Premium thinkers | opus | ~$0.20-0.50 | Strategic decisions, rare |

Background agents (score-monitor, harvester, signal-aggregator, competitor-crawler, pattern-detector) run cheap and accumulate data. Premium thinkers (strategist, user-modeler, narrative-builder) consume that data to make high-leverage decisions.

## Build Sequence (suggested)

Phase 1 — Verification foundation:
  verifier + risk-assessor + /verify + /gate

Phase 2 — Data pipeline:
  harvester + signal-aggregator + /signal + /monitor

Phase 3 — Strategic intelligence:
  strategist + competitor-crawler + /compete

Phase 4 — User intelligence:
  user-modeler + onboarding-auditor + hypothesis-generator

Phase 5 — Distribution:
  narrative-builder + demo-recorder + funnel-modeler + /demo + /funnel + /launch

Phase 6 — Meta-learning:
  pattern-detector + thesis-validator + coherence-checker + question-ranker + /replay + /careful + score-monitor

## Market Context (from explorer research 2026-03-17)

- Verification lattice is #1 2026 pattern (gate-based state machines)
- Amplitude shipped 5 monitoring agents Feb 2026 (continuous, not point-in-time)
- MCP connectors are the integration surface (Salesforce Agentforce $540M ARR)
- Official CC marketplace has 89k installs on top skill, business-focused gap confirmed open
- Bundled scripts are zero context cost — the architectural gap in current skills
- "Cursor for PMs" demand from YC founders still unmet
