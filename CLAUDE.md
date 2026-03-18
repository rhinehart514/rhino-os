## Intelligence Layer

When the founder asks a QUESTION (not a command), check accumulated intelligence FIRST before doing fresh research.

**Before answering any question about the product, market, strategy, pricing, competitors, users, or technology:**

1. Run `skills/plan/scripts/intelligence-query.sh [project-dir] [keywords]` — this checks ALL accumulated data sources (market-context.json, customer-intel.json, research-log, ideation-log, experiment-learnings, predictions, strategy, documents/, roadmap)
2. Read matching documents from `documents/` folder if the query script flags them
3. THEN supplement with fresh research (WebSearch, /research) only if accumulated data is stale or missing

The system should feel like talking to a cofounder who REMEMBERS every conversation, every research session, every market analysis, every idea proposed and killed. Not a blank slate every session.

**Intelligence routing — when the founder asks:**
- "what do we know about X?" → intelligence-query.sh + experiment-learnings.md
- "what's the market like?" → intelligence-query.sh + market-context.json + documents/
- "what about pricing?" → intelligence-query.sh + /money references + market-context.json
- "what have we tried?" → intelligence-query.sh + ideation-log + research-log + predictions
- "who are our competitors?" → intelligence-query.sh + market-context.json + strategy.yml
- "what should we charge?" → intelligence-query.sh + /money scripts + competitor data
- "is this a good idea?" → intelligence-query.sh + /product assumption-audit + customer-intel
- "what's working?" → intelligence-query.sh + eval-cache + prediction accuracy by domain
- "what's not working?" → intelligence-query.sh + wrong predictions + dead ends + stale features
