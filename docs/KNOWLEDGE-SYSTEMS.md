# Knowledge Systems

How learning agents work in rhino-os.

## The Problem

Standard AI agents are stateless. Every session starts from zero. This means:
- The same searches are repeated
- The same dead ends are explored
- No pattern recognition across sessions
- No improvement over time

## The Solution: Persistent Knowledge + Self-Eval

A learning agent maintains 5 files that persist between sessions:

```
knowledge/[agent-name]/
├── knowledge.md          # What we know (patterns, insights, data)
├── confidence-scores.md  # How sure we are (WEAK → STRONG → CONFIRMED)
├── eval-history.md       # How well we've performed (scores over time)
├── search-strategy.md    # What works (self-adapting search approach)
└── acted-on.md           # What happened when we acted (feedback loop)
```

### The Compounding Loop

```
Session N:
  1. READ all knowledge files (don't rediscover what you know)
  2. Search/work with awareness of past findings
  3. LOG new findings (skip duplicates)
  4. EVAL this session against rubric
  5. UPDATE search strategy based on eval
  6. WRITE updated knowledge files

Session N+1:
  1. READ updated knowledge (now includes Session N's learning)
  2. SKIP confirmed patterns, focus on gaps
  3. ... (each session builds on the last)
```

### File Roles

**knowledge.md** — The "memory" file. Organized by confidence level:
- Confirmed Patterns (3+ sessions of evidence)
- Strong Patterns (2+ independent sources)
- Weak Patterns (single source, needs verification)
- Dead Ends (investigated and rejected — prevents re-exploration)
- Key Data Points (specific numbers worth remembering)

**confidence-scores.md** — Tracks each pattern's confidence over time:
- WEAK → seen once, might be noise
- STRONG → seen in 2+ independent sources
- CONFIRMED → consistent across 3+ sessions, stop researching
- DISPROVEN → contradicting evidence found, skip in future

**eval-history.md** — Session score tracking:
- Enables trend detection (are sessions getting better or worse?)
- Triggers strategy changes (3 bad sessions → change approach)
- Provides accountability (was this session worth the API cost?)

**search-strategy.md** — Self-adapting search approach:
- HIGH-YIELD: queries that produced great results → repeat
- STANDARD: queries producing adequate results → keep
- LOW-YIELD: queries producing noise → replace
- NEW: untried approaches added when novelty drops
- EXHAUSTED: fully explored areas → skip

**acted-on.md** — Closes the feedback loop:
- Tracks what knowledge was acted on
- Records the outcome (revenue, learning, nothing)
- Calibrates confidence (acted on a pattern and it worked → boost confidence)

## Creating a New Learning Agent

1. **Define the domain** — what is this agent learning about?
2. **Copy the template** — `cp -r knowledge/_template/ knowledge/[agent-name]/`
3. **Write the agent** — create `agents/[agent-name].md` with:
   - STEP 0: Read all knowledge files
   - Normal workflow steps
   - Self-eval step (grade against rubric)
   - Knowledge update step (write findings back)
4. **Write the rubric** — create `evals/rubrics/[agent-name]-rubric.md`
5. **Run it** — `claude --agent [agent-name]`

## Reference Implementation: Scout

The scout agent is the canonical example:

- **Domain:** Business opportunities and tech trends
- **Search:** Scans Twitter, HN, Reddit, Product Hunt, tech news
- **Knowledge:** Tracks opportunities, patterns, price points, niches
- **Self-eval:** Grades signal quality, novelty, actionability per session
- **Adaptation:** Updates search strategy based on what yields high-signal results
- **Feedback:** Tracks which opportunities were acted on and outcomes

After 4+ sessions, the scout:
- Skips confirmed patterns (doesn't waste time rediscovering them)
- Avoids dead ends (explicitly marked, never revisited)
- Focuses search on gaps (areas with WEAK confidence)
- Uses proven search queries (HIGH-YIELD from previous sessions)
- Has accumulated pricing data, pattern evidence, and trend history

## Auto-Capture (Post-Session Hook)

The `capture_knowledge.sh` hook fires on session Stop events. It automatically:

1. Checks if the session was substantial (>5 tool uses in last 30 minutes)
2. Runs a lightweight `claude -p` summarization ($0.25 budget cap)
3. Appends key decisions and patterns to `~/.claude/knowledge/sessions/[project].md`
4. Prunes entries older than 60 days

This closes the biggest gap in the knowledge system — manual curation. Sessions now self-document without intervention.

**Skipped for:** trivial sessions (<5 tool uses), concurrent captures (lock file prevents overlap).

## MCP Access

Agents can read/write knowledge via MCP tools instead of direct file access:

- `rhino_query_knowledge(agent, file, confidence)` — read with filters
- `rhino_update_knowledge(agent, file, content, mode)` — append or replace
- `rhino_backup_knowledge()` — snapshot all knowledge

These tools read/write the same files, so MCP and direct access are interchangeable.

## Anti-Patterns

1. **Not reading past knowledge** — agent starts fresh, repeats work
2. **Not evaluating** — no signal on whether sessions are improving
3. **Not updating strategy** — same searches produce same (diminishing) results
4. **Not marking dead ends** — agent re-explores failed paths
5. **Not closing the loop** — knowledge accumulates but never informs action
