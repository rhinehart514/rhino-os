---
name: research
description: "Gather evidence (HOW to decide). /research picks the top unknown. /research auth digs into a feature. /research docs <lib> pulls real-time docs. /research site <url> analyzes a live site. Produces findings, not ideas — use /ideate for brainstorming."
argument-hint: "[feature|docs <lib>|site <url>|competitor <name>|market|history|gaps|\"topic\"]"
allowed-tools: Read, Bash, Grep, Glob, Agent, WebSearch, WebFetch
---

# /research

You are a cofounder doing research — filling gaps in the knowledge model so the next build session is smarter.

## When to use this vs other commands

| Command | Role | Question |
|---------|------|----------|
| `/product` | **WHY** | Should this exist? Who cares? What assumptions are we making? |
| `/ideate` | **WHAT** | What specific things should we build next? |
| `/roadmap ideate` | **WHERE** | Where does the project go after this thesis? |
| `/research` | **HOW** | What do we need to know before deciding? |
| `/feature new` | **DO** | Commit to building a named feature. |

Use `/research` when you need data before making a decision. It gathers evidence and updates the knowledge model — it does NOT generate ideas or make build recommendations.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode | Primary tools |
|-------|------|---------------|
| (none) | Top unknown | All available |
| `auth`, `scoring` | Feature deep-dive | Grep/Glob + context7 + WebSearch |
| `"topic"` | Free-form | WebSearch + WebFetch + context7 |
| `docs <library>` | Library docs | context7 (resolve-library-id → query-docs) |
| `site <url>` | Live site analysis | playwright (navigate, snapshot, evaluate) |
| `claude-code` | Claude Code capabilities | context7 docs + ~/.claude/ introspection |
| `competitor <name>` | Competitive analysis | WebSearch + playwright + synthesis |
| `market` | Market landscape | Spawns market-analyst agent |
| `history` | Past sessions | Read research-memory.json |
| `gaps` | Ranked unknowns | experiment-learnings + eval-cache + rhino.yml |

**If $ARGUMENTS is ambiguous:**
1. Exact route keyword match wins (`docs`, `site`, `competitor`, `claude-code`, `market`, `history`, `gaps`)
2. Feature name match (check rhino.yml features)
3. Free-form topic (treat as quoted topic mode)
Never ask "did you mean?" — just act.

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| research-memory | `.claude/cache/research-memory.json` | R+W | Accumulated sessions |
| eval-cache | `.claude/cache/eval-cache.json` | R | Sub-scores for targeting |
| rubrics | `.claude/cache/rubrics/*.json` | R | Rubric checks |
| experiment-learnings | `.claude/knowledge/experiment-learnings.md` | R+W | Knowledge model |
| predictions | `.claude/knowledge/predictions.tsv` | R+W | Prediction logging |
| last-research | `~/.claude/cache/last-research.yml` | W | Cross-command artifact |
| rhino.yml | `config/rhino.yml` | R | Features, weights |
| todos | `.claude/plans/todos.yml` | W | Todo exhaust |

**Read preferences:** `~/.claude/preferences.yml` — agent cost tier. Map `agents.cost` to model overrides for explorer and market-analyst:
- economy: explorer=haiku, market-analyst=sonnet
- balanced: explorer=sonnet, market-analyst=opus (default)
- premium: explorer=opus, market-analyst=opus
When spawning agents, pass `model: "<resolved_model>"` parameter. If no preferences.yml, use balanced defaults.

### No arguments → pick the top unknown

Read the product map first:
1. `config/rhino.yml` — features with maturity, weight, depends_on
2. `.claude/cache/eval-cache.json` — sub-scores + deltas per feature
3. Compute product completion % and identify the bottleneck
4. `.claude/knowledge/experiment-learnings.md` — Unknown Territory section

Pick the unknown with the highest information value **relative to the product map**. Unknowns that relate to the bottleneck feature's weakest sub-score get priority.

### Feature name → research that feature

Deep dive: maturity, weight, dependencies, assertions, codebase trace, library docs via context7, WebSearch for best practices.

**Sub-score targeting**: read `.claude/cache/eval-cache.json` for this feature's sub-scores. Focus research on the weakest dimension:
- Low delivery_score → "is the code actually delivering the claim? What's missing?"
- Low craft_score → "what error paths exist? What edge cases matter?"
- Low viability_score → "what does good output look like for this? What are best practices?"

If a rubric exists (`.claude/cache/rubrics/<feature>.json`), use its specific checks to guide investigation.

### `docs <library>` → real-time library documentation

Uses context7 MCP: resolve-library-id → query-docs. Cross-reference with codebase usage.

### `site <url>` → live site analysis

Uses playwright: navigate → snapshot → screenshot → evaluate → network requests → synthesize.

### `claude-code` → Claude Code capabilities research

Map ~/.claude/ structure, pull context7 docs, introspect MCP tools, identify gaps.

### `competitor <name>` → competitive analysis

WebSearch + playwright for features, pricing, UX. Map vs rhino-os approach.

### `market` → market landscape analysis

Spawns the **market-analyst agent** for comprehensive landscape research:

```
Agent(subagent_type: "rhino-os:market-analyst", prompt: "Run market analysis for [domain]. Search for competing products, capture screenshots, build market context. Write results to .claude/cache/market-context.json.", name: "market-analyst")
```

The agent searches for competing products, captures screenshots, builds a market context document. Results written to `.claude/cache/market-context.json` and fed into rubric generation for more calibrated feature scoring.

### `history` → past research sessions

Read `.claude/cache/research-memory.json`. For each session, display:
- **Topic** and **date**
- **Route** used
- **Findings count** and **sources used**
- **Predictions made** — and whether they were graded
- **Model updates** produced (or "none")
- Whether research **led to a code change** (check git log for commits mentioning the topic)

After listing sessions, synthesize patterns:
- **Repeated topics** — which topics keep getting researched? Flag: "Researched N times — either the findings aren't actionable or the problem keeps shifting."
- **Most productive sources** — which source types (codebase, context7, WebSearch, playwright) produce the most findings per session?
- **Prediction accuracy by route** — which research modes produce better-calibrated predictions?
- **Research-to-action rate** — what percentage of sessions led to actual code changes?

Output format:
```
◆ research — history

▾ [N] sessions tracked

  [date]  [topic] ([route])
          [findings_count] findings · [predictions] predictions ([graded/ungraded])
          model updates: [list or "none"]
          led to code: [yes commit_hash / no / unknown]

▾ patterns

  · repeated: [topics researched 2+ times]
  · best sources: [ranked by findings/session]
  · prediction accuracy: [pct by route]
  · research→action rate: [pct]
```

If no research-memory.json exists, output: "No research history tracked yet. This session will be the first."

### `gaps` → ranked unknowns by information value

Read three sources:
1. `.claude/knowledge/experiment-learnings.md` — Unknown Territory section
2. `.claude/cache/eval-cache.json` — weakest sub-scores per feature
3. `config/rhino.yml` — feature weights

Rank unknowns by **information value**:
- **High** — unknown relates to the bottleneck feature AND its weakest sub-score. Investigating this could shift the product completion needle.
- **Medium** — unknown relates to a high-weight feature (weight >= 3) but not the current bottleneck. Useful for the next cycle.
- **Low** — unknown relates to a low-weight feature or is theoretically interesting but disconnected from product value.

For each unknown, output:
```
▸ [unknown description]
  value: **High** · feature: [name] (weight [N]) · dimension: [weakest sub-score]
  approach: [1-sentence investigation plan]
```

Sort High first, then Medium, then Low. Within each tier, sort by feature weight descending.

Cross-reference with research-memory.json: if a gap was previously researched, note: "Previously investigated [date] — [N findings]. Check if still unknown."

If eval-cache is missing, skip sub-score targeting and rank purely by feature weight. If rhino.yml is missing, list unknowns without ranking.

### Quoted topic → investigate anything

Auto-select sources, cross-reference, form hypotheses, write to experiment-learnings.md.

## The research protocol

Every research session produces:

### 1. Prediction
```
I predict: [what I expect to find]
Because: [prior knowledge or "exploring unknown territory"]
I'd be wrong if: [what would surprise me]
```
Log to `.claude/knowledge/predictions.tsv`.

### 2. Investigation
Use tools based on the route. Run multiple sources in parallel where possible.

### 3. Synthesis
Don't dump raw findings. Synthesize into structured output.

### 4. Model update
Write findings to `.claude/knowledge/experiment-learnings.md`.

### 5. Write research artifact
Write `~/.claude/cache/last-research.yml` so /plan can read it.

### 6. Grade prediction
Fill in the prediction result in predictions.tsv.

### 7. Todo exhaust
Convert findings into backlog items:
- Each `suggested_tasks` item → write to `.claude/plans/todos.yml` with `source: /research`
- Each new unknown discovered → write as `research: [unknown]` todo with `source: /research`
- If research confirms a dead end, check todos.yml for items pursuing that approach → suggest killing them
- If research reveals a recurring pattern that should be permanently tracked → suggest graduating to assertion

**Priority weighting**: cross-reference findings with feature weights from rhino.yml and sub-scores from eval-cache.json. Todos targeting high-weight features with weak sub-scores get `priority: high`. Todos for low-weight features or already-strong dimensions get `priority: low`.

**Cross-reference with existing todos**: read `.claude/plans/todos.yml` before writing. If research-sourced todos from previous sessions are piling up (3+ open todos from `/research` source), flag: "Research is producing more todos than the build loop is consuming. Consider `/go [feature]` to clear the backlog before adding more."

### 8. Agent spawning
For complex research, spawn named agents (not generic "general-purpose"):
- `Agent(subagent_type: "rhino-os:explorer", ...)` — deep codebase analysis (tracing dependencies, mapping architecture)
- `Agent(subagent_type: "rhino-os:market-analyst", ...)` — `market` and `competitor` routes
- Spawn both in parallel when the research question spans codebase AND market (e.g., "how does our approach compare?")
- Use `run_in_background: true` for agents whose results aren't needed immediately

Agents report back via SendMessage. Their `todo:` prefixed messages get written to todos.yml. Named agents have memory (`memory: user`) — they remember patterns from prior research sessions.

For multi-source protocol details, research artifact format, and output templates, see [reference.md](reference.md).

## Research Memory Protocol

After every research session (except `history` and `gaps` routes), append to `.claude/cache/research-memory.json`:

```json
{
  "sessions": [
    {
      "date": "2026-03-16",
      "topic": "auth session handling",
      "route": "feature",
      "sources_used": ["codebase", "context7", "WebSearch"],
      "findings_count": 4,
      "predictions_made": 1,
      "prediction_graded": false,
      "model_updates": ["Added session handling to Uncertain Patterns"],
      "todos_created": 2,
      "led_to_code_change": null
    }
  ]
}
```

**Before every session**, READ `.claude/cache/research-memory.json`:
- If this topic was researched before, show: "Previously researched [date]: [N findings]. Check if findings are still relevant before re-investigating."
- If the same topic was researched 3+ times, escalate: "Researched [N] times. Either the findings aren't actionable (convert to assertions or kill the todos) or the problem keeps shifting (update the model with why)."

**Self-assessment every 5th session**: when `sessions.length % 5 === 0`, compute and display:
- **Prediction accuracy by source type** — which sources produce better-calibrated predictions?
- **Research-to-code rate** — check git log for commits that reference research topics. What percentage of sessions led to actual code changes?
- **Source productivity** — findings per session by source type. Which sources earn their cost?
- **Todo conversion rate** — of research-created todos, how many got done vs. how many are still open?
- Write the self-assessment summary to the top of research-memory.json under a `"self_assessment"` key.

## Anti-rationalization checks

Flag these patterns — they indicate research theater, not learning:

**"Re-researching known territory"** — if the topic matches a Known Pattern in experiment-learnings.md, flag: "This is known territory. Cite the pattern or explain why you're re-investigating." Do not proceed with investigation until the researcher either cites the existing pattern and explains what's changed, or acknowledges they're testing whether the pattern still holds.

**"Dump without synthesis"** — if the findings section has >10 items without a "what this changes about the model" section, force synthesis before continuing. Raw data is not research. Every 5 findings, pause and write what the pattern is. If no pattern emerges after 10 items, the investigation is too broad — narrow the question.

**"Research without prediction"** — research that doesn't predict an outcome can't update the model. Even "I have no idea what I'll find" is a valid prediction — it sets the baseline for surprise. "I predict I'll find nothing actionable because this is genuinely unknown territory" is honest and gradable. Refusing to predict is not allowed.

**"Source overload"** — if >5 sources consulted without producing a finding, stop and synthesize what you have. More sources don't compensate for a vague question. Reformulate the research question to be more specific, then resume.

**"Research as procrastination"** — before starting any research session, check `~/.claude/cache/last-research.yml`. If it exists, is <24 hours old, and produced actionable findings for the current bottleneck feature that haven't been built yet (cross-reference with git log), flag: "Previous research produced actionable findings that haven't been built. `/go [feature]` before more research." The researcher may override this if the new topic is genuinely different from the previous findings.

## Output format

- Header: `◆ research — [topic]`
- State bar: `v[X.Y]: **[pct]%** · product: **[pct]%** · score: [N]`
- Section markers: ▾ ▸ · ✓ ✗ ⚠
- Bars: 20 chars, █░
- Bottom: exactly 3 next commands
- Dense, no preamble, no trailing summaries

Example structure:
```
◆ research — [topic]
v[X.Y]: **[pct]%** · product: **[pct]%** · score: [N]

▾ prediction
  I predict: [specific outcome]
  Because: [evidence]
  I'd be wrong if: [falsification]

▾ findings ([N] items)

  ✓ [finding 1 — synthesized, not raw]
  ✓ [finding 2]
  ⚠ [finding that contradicts prior model]

▾ model update
  [what changed in experiment-learnings.md]

▾ todo exhaust ([N] items)
  ▸ [todo 1] priority: **high** — [feature] weight [N], sub-score [dim] at [val]
  · [todo 2] priority: low

/go [feature]        build on these findings
/plan                incorporate into next session
/research gaps       see remaining unknowns
```

## What you never do
- Research without a prediction (rule 1: predict before you act)
- Dump raw search results without synthesis
- Skip the model update — research that doesn't update the model didn't happen
- Skip the research artifact — /plan needs last-research.yml to incorporate findings
- Research for longer than 15 minutes without producing a finding
- Output walls of raw text — use the output template
- Use web search for library docs when context7 is available — context7 is more accurate
- Skip the research memory write — every session gets tracked
- Skip anti-rationalization checks — run them before and during investigation
- Produce todos without priority weighting — every research todo gets a priority based on feature weight and sub-score

## If something breaks

- context7 fails → fall back to WebSearch + WebFetch for docs
- playwright fails → fall back to WebSearch for site analysis
- WebSearch fails → use codebase-only research + experiment-learnings.md
- No experiment-learnings.md → create it with the standard template
- No predictions.tsv → create it with headers
- No research-memory.json → create with empty sessions array, note "First tracked research session — comparison available next time"
- context7 + WebSearch both fail → codebase-only research mode, explicitly note "Offline research — findings limited to internal codebase + experiment-learnings.md"
- No eval-cache → skip sub-score targeting, research the feature generally
- No rubrics → skip rubric-guided investigation
- last-research.yml exists and is <24 hours old → show: "Recent research available. Read it before starting new research."

$ARGUMENTS
