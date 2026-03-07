# Money Scout — Eval Rubric

Run after every scouting session. Grade the output, then grade the knowledge base.

## 1. Signal Quality (per find)

Each opportunity logged gets scored 0–3:

| Score | Criteria |
|-------|----------|
| 0 | Generic hype. No numbers, no specifics, no actionable detail. ("AI is the future!") |
| 1 | Interesting but vague. Has a thesis but no proof or specifics. ("You could sell AI consulting") |
| 2 | Specific and plausible. Names a niche, a price point, or a real example. Has engagement signal. |
| 3 | Actionable gold. Specific niche + business model + price point + evidence it works + clear next step. |

**Threshold:** Average score across finds must be >= 2.0. If below, the scout is returning noise.

**Auto-fail triggers:**
- Any find that's just "use AI to make money" with no specifics → score 0, flag as noise
- Any find older than 60 days → should have been filtered out
- Any find already in the knowledge base → scout didn't read existing knowledge

## 2. Novelty Check

Compare new finds against `opportunities.md`:

- **New opportunities found this session:** N
- **Duplicates of existing entries:** N
- **Novelty ratio:** new / (new + duplicates)

**Threshold:** Novelty ratio >= 0.7. If the scout keeps finding the same things, the search strategy needs updating.

## 3. Actionability (per find)

Each find must answer: "What would the founder do with this tomorrow?"

| Grade | Criteria |
|-------|----------|
| PASS | Action item is specific and doable within 1 week by a solo founder |
| WEAK | Action item exists but is vague ("look into this") |
| FAIL | No action item, or action requires a team/capital/brand the founder doesn't have |

**Threshold:** >= 70% of finds grade PASS.

## 4. Relevance Filter

Each find scored on the founder-relevance:

| Score | Criteria |
|-------|----------|
| 0 | Requires skills/network/capital the founder doesn't have |
| 1 | Tangentially related to their skills but would require pivoting |
| 2 | Fits their technical skills but no unique angle |
| 3 | Directly leverages their expertise + domain positioning or existing work |

**Threshold:** Average relevance >= 1.5. Below that, scout is looking in the wrong places.

## 5. Knowledge Base Growth (cumulative)

After each session, check:

| Metric | How to measure | Healthy sign |
|--------|---------------|--------------|
| Total opportunities | Count entries in opportunities.md | Growing by 3-8 per session |
| Unique niches | Count distinct niches across all entries | Growing, not just "AI consulting" repeated |
| Pattern updates | Diff knowledge.md before/after | New patterns or updated confidence on existing ones |
| Hot niches ranked | Count ranked entries in hot-niches.md | At least 3 niches ranked after 3 sessions |
| Price point data | Count distinct price points logged | Building a realistic pricing landscape |

## 6. The Money Test (most important)

After each session, answer these YES/NO:

- [ ] **Did this session surface at least 1 opportunity I hadn't considered?**
- [ ] **Could I explain to someone in 30 seconds how to make money from the top find?**
- [ ] **Is there a find here I could start executing on THIS WEEK?**
- [ ] **Did the knowledge base get meaningfully smarter (new pattern, confirmed trend, killed a bad idea)?**
- [ ] **Am I closer to knowing what niche to target than before this session?**

**Threshold:** >= 3/5 YES. Below that, the session was noise.

## Eval Report Template

```markdown
## Money Scout Eval — [date]

### Session Stats
- Finds this session: N
- New (not duplicate): N
- Novelty ratio: X%

### Signal Quality
- Average score: X.X/3.0 (threshold: 2.0)
- Distribution: [0s: N, 1s: N, 2s: N, 3s: N]
- Auto-fail triggers hit: [list or "none"]

### Actionability
- PASS: N | WEAK: N | FAIL: N
- Actionability rate: X% (threshold: 70%)

### Relevance
- Average relevance: X.X/3.0 (threshold: 1.5)

### Knowledge Base Growth
- Total opportunities (cumulative): N
- Unique niches (cumulative): N
- New patterns identified: [list]
- Hot niches ranked: N

### The Money Test
- [x/o] New opportunity I hadn't considered
- [x/o] Can explain top find in 30 seconds
- [x/o] Could start executing this week
- [x/o] Knowledge base got smarter
- [x/o] Closer to knowing my niche
- Score: X/5 (threshold: 3)

### Verdict
- **GOOD SESSION** — knowledge compounded, actionable finds
- **MEH SESSION** — some signal but mostly noise, tweak search strategy
- **BAD SESSION** — wasted cycles, need to rethink what we're looking for

### Search Strategy Adjustments
[What to change for next session based on what worked/didn't]
```

## Meta-Eval (run monthly)

After ~4 sessions, zoom out:

1. **Has any scouted opportunity led to actual revenue?** (the only eval that truly matters)
2. **Has the knowledge base changed your strategy or focus?**
3. **Are you spending more time scouting than doing?** (trap — cap at 1 session/week)
4. **Is the scout finding things you wouldn't find yourself in 10 min of scrolling?** (if not, it's not adding value)
5. **Kill criterion:** If after 4 sessions, zero finds have led to even a conversation with a potential customer → rethink the entire approach.
