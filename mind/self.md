# Self-Model

How rhino-os itself is performing. Updated from real data, not guesses.

## Capabilities

### Measurement Stack (Skills)
- `/score` — **unified product quality score**. Orchestrates all tiers: health + code eval + visual taste + behavioral flows + agent-backed viability. The authoritative "is this good?" number. Status: operational (v9.3).
- `/eval` — code eval tier (delivery + craft per feature). LLM judges claim vs code. Viability removed — now scored by /score via agents. Status: operational.
- `/taste <url>` — visual tier. Product intelligence via Playwright MCP + Claude Vision. 11 dimensions, 0-100 scale. Status: operational.
- `/taste <url> flows` — behavioral tier. Frontend delivery audit via Playwright MCP. 6-layer checklist. Status: operational.

### Internal Tooling (CLI — used by skills and scripts)
- `rhino score .` — health tier (structural lint, build gate). Fast, free, every change. Called internally by /score.
- `rhino eval .` — assertion runner. Called internally by /eval.
- `rhino tier` — maturity tier router. Determines project tier from score + eval data. Consumed by /plan, /go, session hook. Status: operational.
- `rhino self` — 4-system self-diagnostic. Status: operational.

### Skills
24 skills in `skills/*/SKILL.md`. Split into marketplace (user-facing) and internal (self-management):

**Marketplace (15):** /eval, /taste, /go, /plan, /push, /ship, /onboard, /research, /ideate, /product, /money, /copy, /todo, /roadmap, /retro
**Internal (9):** /score, /calibrate, /strategy, /discover, /feature, /assert, /rhino, /skill, /configure

Demoted to `.claude/rules/`: rhino-mind, product-lens. Demoted to hooks: quality-check, session-summary. Killed: /openclaw, /clone.

### Agents
14 custom agents in agents/: measurer, explorer, builder, reviewer, evaluator, market-analyst, grader, debugger, refactorer, customer, founder-coach, consolidator, gtm, copywriter

### Intelligence Layer
- **Symlinks**: mind/ files (identity, thinking, standards, startup-patterns) loaded via .claude/rules/ on every conversation. self.md is project-local only — not symlinked globally to avoid contaminating other projects.
- **Hooks**: 7 total — session_start (boot card), pre_compact (context recovery), post_edit (quality checks), post_skill (YAML validation), stop, post_commit, subagent_stop, pre_commit_check
- **Learning loop**: predict → act → measure → update model → repeat

## Known Weaknesses
(Confirmed across 3+ sessions)

- **Prediction grading is manual.** Predictions log to TSV but only get graded when /plan runs. No automatic grading mechanism. This is the #1 gap in the learning loop.
- **Knowledge model is append-only.** experiment-learnings.md grows but never prunes stale patterns. No staleness detection on individual entries.
- **LLM judge variance.** Generative eval (feature scoring) produces different scores on repeated runs. No temperature control, no rubric anchoring, no multi-sample averaging. Variance is ~15 points.
- **Score formula is min(dimensions).** A single weak dimension floors the entire score. Taste at 40 makes everything else irrelevant. This is by design but non-obvious.
- **CLI console output false positives.** Hygiene checks flag console.log in CLI tools that legitimately use stdout. Project-type awareness partially fixes this but edge cases remain.

## Uncertain Weaknesses
(Suspected, needs confirmation)

- Commands produce better output than before, but untested whether founders actually follow the recommended next commands or ignore them.
- The innovation matrix in /ideate may produce ideas that cluster by quadrant label rather than genuine novelty.
- Score reasons may be too terse for founders unfamiliar with the codebase.

## Unknown Territory
(Never tested — highest information value)

- Does prediction accuracy actually correlate with product improvement?
- Does the measurement stack catch regressions that matter to users, or just structural noise?
- Can someone who isn't us complete the full /go loop without getting stuck? (init→score validated on commander.js 2026-03-15 at 80/100, /go loop untested)
- Do the output templates in commands actually produce consistent output across different Claude models/sessions?
- Does the pre_compact hook actually help context recovery, or is the compacted context already sufficient?

## Product Completion Model

rhino tracks product completion across multiple signals, not just score:

**Eval-driven completion** (the primary signal):
- `/eval` scores each feature 0-100 across three dimensions: delivery (50%), craft (30%), viability (20%)
- Each feature has a `weight` (1-5) indicating importance to the value hypothesis
- Product completion = sum(eval_score × weight) / sum(weight × 100)
- Maturity is a computed label from eval score: 0-29=planned, 30-49=building, 50-69=working, 70-89=polished, 90+=proven

**Completion signals** (all aggregated in /rhino dashboard):
- Eval score × weight → product completion %
- Assertion pass rate → value delivery %
- Todo done/total → backlog clearance %
- Plan tasks completed/total → session momentum %
- Roadmap evidence proven/total → thesis progress %
- Prediction accuracy → model quality %

**Dependency graph**: features can declare `depends_on: [other_feature]`. The bottleneck is the lowest eval score among highest-weight features. Dependencies determine build order.

**Visualization**: /rhino renders a product map with bars, weights, bottleneck markers, and dependency arrows. /plan includes a compact version.

**Version completion cycle**: product completion is cumulative (features mature over time), but VERSION completion resets on each `/roadmap bump`. Each version thesis defines what "done" means — evidence items, relevant features, tagged todos. When version completion hits ~80%, rhino suggests bumping. After bump, new thesis starts, version completion drops, climb begins again. This creates the natural rhythm: define thesis → work → prove/disprove → next thesis.

**Three-tier version lifecycle**:
- `major` (v9.0) — New thesis. Big question. Resets version completion fully. Evidence: 4-5 items, weeks to prove.
- `minor` (v8.1) — Significant improvement within current thesis. Resets partially. Evidence: 2-3 items, days-weeks.
- `patch` (v8.0.1) — Bug fix, polish, incremental. No new question. Doesn't reset completion. Evidence: 0-1 items, hours-days. Can auto-suggest after /go fixes a regression.

Bump auto-detection: thesis changed → major, new features/evidence → minor, assertions fixed/score improved → patch. `/roadmap bump` suggests tier, founder confirms.

## Calibration Data
- Prediction accuracy: 63% (10/16 graded, with partials at 0.5). In target range (50-70%).
- Score: 26/100 (56/63 beliefs passing, 7 gen features avg 49)
- Assertions: 63 planted (was 64, 1 duplicate deleted), 56 passing
- Health: 90 (struct:95, hygiene:90)
- Worst features: self-diagnostic 28, scoring 32
- Best features: commands 64, docs 62, todo 58
- External project (commander.js): 80/100 on first init (6 features, 8/10 assertions)
- 5 large files >500 lines, 19 TODO/FIXME markers
- v8.1 finding: beliefs-only cap at 50 was HIDING low generative scores. Pipeline now honest but score dropped 50→26. The generative eval (LLM feature audit) avg 49 dominates the formula. Belief pass rate is 89% but doesn't drive the score when generative data exists.

## What I Would Change About Myself
- The learning feature should be the smartest part of the system. It's the worst.
- Skills should read state uniformly — right now /plan reads 9 sources, /eval reads 2.
- The CLI (bin/) is internal plumbing — skills are the product surface. This inversion is now documented but not fully enforced in code.
- Mind files are loaded but never validated — no mechanism to check if they actually influenced behavior.

## Available MCP Tools
- **context7**: resolve-library-id + query-docs — real-time library documentation for any framework. Use in /research for accurate docs instead of web search hallucinations.
- **playwright**: browser automation — navigate, click, snapshot, evaluate, network requests. Use in /research site for live product analysis.
- **Vercel**: deploy, project management, runtime logs, toolbar threads. Use in /ship for deployment.

## Plugin Surface (what rhino-os extends in Claude Code)

Skills ARE the commands. Each skill lives in `skills/*/SKILL.md` — there is no separate `commands/` directory.

Two install modes, same capabilities:

**Plugin mode** (`CLAUDE_PLUGIN_ROOT` set):
- `skills/rhino-mind/SKILL.md` — mind files concatenated into a single skill
- `skills/*/SKILL.md` — slash commands delivered as skills via plugin system
- `hooks/hooks.json` — hook definitions referencing hooks/*.sh
- MCP tools — context7, playwright, Vercel (when available)

**Manual install** (legacy symlinks):
- `~/.claude/rules/` — mind files symlinked as system context
- `settings.json` — hook configuration pointing to hooks/*.sh
- MCP tools — context7, playwright, Vercel (when available)

**Shared** (both modes):
- `~/.claude/knowledge/` — predictions.tsv, experiment-learnings.md (persistent learning)
- `~/.claude/cache/` — research artifacts, score cache (cross-command communication)

## Agent Architecture (v8.3)

**Critical constraint**: `context: fork` and Agent spawning are MUTUALLY EXCLUSIVE. Forked skills run AS subagents and cannot spawn sub-subagents.

**Two skill architectures:**
- **Architecture A (Inline Orchestrator)**: No fork, spawns named agents. Skills: /go, /eval, /research, /strategy, /discover, /ideate, /taste, /retro, /roadmap, /ship, /product, /money, /copy
- **Architecture B (Forked Task)**: Fork, does all work itself. Skills: /configure

**14 agents**, all with `memory: user` (cross-session learning) and `maxTurns` (safety valve):

| Agent | Model | Turns | Background | Skills | Role |
|-------|-------|-------|-----------|--------|------|
| builder | opus | 30 | - | rhino-mind, product-lens | Writes code, worktree isolation |
| explorer | sonnet | 25 | yes | rhino-mind | Researches unknowns, multi-source |
| evaluator | opus | 20 | - | rhino-mind | Deep feature eval, rubric generation |
| market-analyst | opus | 20 | yes | - | Competitive/market research |
| measurer | haiku | 15 | - | - | Runs scores, cheapest |
| reviewer | haiku | 10 | - | product-lens | UX checklist, cheapest |
| grader | sonnet | 10 | - | rhino-mind | Auto-grades predictions |
| debugger | sonnet | 15 | - | - | Regression investigation |
| refactorer | sonnet | 20 | - | rhino-mind | No-behavior-change cleanup |
| customer | sonnet | 20 | yes | rhino-mind | Customer signal synthesis |
| founder-coach | opus | 10 | - | rhino-mind | Startup failure mode detection |
| consolidator | sonnet | 15 | - | rhino-mind | Knowledge model maintenance |
| gtm | opus | 25 | yes | - | Go-to-market strategy |
| copywriter | opus | 20 | - | rhino-mind, product-lens | Positioning-aware product copy |

Skills spawn agents by name: `Agent(subagent_type: "rhino-os:builder", ...)` — never generic `"general-purpose"`.

**Startup awareness layer (v9.0):**
- `mind/startup-patterns.md` loaded into every session via `.claude/rules/` symlink
- 8 failure mode detection rules checkable from repo state
- /plan runs startup pattern check before bottleneck diagnosis
- /go has soft discovery gate (informational, non-blocking)
- /ship has launch readiness checks for release-type ships
- /eval uses customer-intel.json for viability scoring when available

**Agent wiring across skills:**
- /go → builder (worktree), measurer, reviewer, grader, debugger (background), refactorer (worktree)
- /eval → evaluator (parallel per feature), measurer
- /research → explorer, market-analyst (parallel)
- /strategy → explorer, market-analyst (parallel), gtm (for gtm/price modes)
- /discover → explorer, market-analyst, customer (parallel)
- /retro → grader (batch mode), consolidator (post-grading)
- /product → customer (background), founder-coach
- /ideate → explorer, customer (background)
- /copy → copywriter, market-analyst (for landing/pitch modes)
- /money → gtm, market-analyst (parallel)

**5 critical flow fixes (v8.3):**
1. /onboard writes roadmap.yml + strategy.yml + eval-cache.json
2. /rhino defers bottleneck to /plan (plan is authoritative)
3. /go auto-grades predictions via grader agent
4. /eval spawns parallel evaluators per feature + suggests /taste for web products
5. /plan detects unknowns → suggests /research before building

**Merged:** /calibrate → /taste (taste owns its calibration via /taste calibrate)

## Remaining Untapped Capabilities

Full reference: `skills/CAPABILITIES.md`.

**New CC features (discovered 2026-03-17):** LSP tool (50ms code navigation), /simplify pattern (3 parallel review agents), /batch pattern (worktree decomposition), CronCreate (periodic monitoring), auto-memory (may overlap experiment-learnings.md), plugin settings.json agent key, PostCompact hook, MCP elicitation.

**Hooks:** Using 8 of 22 available events. Priority additions: PostCompact (context rebuild), SessionEnd (auto session logging), TaskCompleted (quality gate for /go), InstructionsLoaded (validate mind files loaded).

**Composites:** The `/batch` pattern (ships with Claude Code) decomposes work into N units, spawns agents in isolated worktrees, each opens a PR. This is the architecture for composite skills — parallel orchestration, not sequential chaining.

## Meta-Learning
- The predict→measure→update loop works when predictions are graded. It breaks when they're not.
- 63% accuracy is well-calibrated. Predictions are informative, not performative.
- Wrong predictions (8/16) produced the most valuable model updates — confirming the system design.
- The highest-information experiments are always in Unknown Territory, but the system gravitates toward known patterns. Need to enforce exploration.
