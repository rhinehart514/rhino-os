# Self-Model

How rhino-os itself is performing. Updated from real data, not guesses.

## Capabilities

### Measurement Stack
- `rhino score .` — value scoring with health gate. Status: operational. Now includes reasons for each penalty.
- `rhino eval .` — generative feature eval (Claude judges claim vs code). Status: operational.
- `rhino taste` — visual eval via Claude Vision, 11 dimensions. Status: operational.
- `rhino self` — 4-system self-diagnostic. Status: operational.

### Commands (the product surface)
17 slash commands, each with explicit output templates and state awareness:
/plan, /go, /eval, /feature, /init, /ship, /ideate, /research, /roadmap, /rhino, /assert, /clone, /retro, /skill, /strategy, /todo, /product

### Agents
4 custom agents in agents/: measurer, explorer, builder, reviewer

### Intelligence Layer
- **Symlinks**: mind/ files (identity, thinking, standards) loaded via .claude/rules/ on every conversation. self.md is project-local only — not symlinked globally to avoid contaminating other projects.
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

**Feature maturity** (the primary signal):
- `planned` (0%) → `building` (33%) → `working` (66%) → `polished` (100%)
- Each feature has a `weight` (1-5) indicating importance to the value hypothesis
- Product completion = weighted average of feature maturities
- Auto-detected from assertions + code, or manually set in rhino.yml

**Completion signals** (all aggregated in /rhino dashboard):
- Feature maturity × weight → product completion %
- Assertion pass rate → value delivery %
- Todo done/total → backlog clearance %
- Plan tasks completed/total → session momentum %
- Roadmap evidence proven/total → thesis progress %
- Prediction accuracy → model quality %

**Dependency graph**: features can declare `depends_on: [other_feature]`. The bottleneck is always the lowest-maturity, highest-weight feature. Dependencies determine build order.

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
- Commands should read state uniformly — right now /plan reads 9 sources, /eval reads 2.
- The CLI (bin/) should serve the commands, not the other way around. Commands are the product.
- Mind files are loaded but never validated — no mechanism to check if they actually influenced behavior.

## Available MCP Tools
- **context7**: resolve-library-id + query-docs — real-time library documentation for any framework. Use in /research for accurate docs instead of web search hallucinations.
- **playwright**: browser automation — navigate, click, snapshot, evaluate, network requests. Use in /research site for live product analysis.
- **Vercel**: deploy, project management, runtime logs, toolbar threads. Use in /ship for deployment.

## Plugin Surface (what rhino-os extends in Claude Code)

Two install modes, same capabilities:

**Plugin mode** (`CLAUDE_PLUGIN_ROOT` set):
- `skills/rhino-mind/SKILL.md` — mind files concatenated into a single skill
- `commands/*.md` — slash commands delivered via plugin system
- `hooks/hooks.json` — hook definitions referencing hooks/*.sh
- MCP tools — context7, playwright, Vercel (when available)

**Manual install** (legacy symlinks):
- `~/.claude/rules/` — mind files symlinked as system context
- `~/.claude/commands/` — slash commands symlinked
- `settings.json` — hook configuration pointing to hooks/*.sh
- MCP tools — context7, playwright, Vercel (when available)

**Shared** (both modes):
- `~/.claude/knowledge/` — predictions.tsv, experiment-learnings.md (persistent learning)
- `~/.claude/cache/` — research artifacts, score cache (cross-command communication)

## Untapped Claude Code Capabilities

rhino-os uses a fraction of what Claude Code offers. Full reference: `skills/CAPABILITIES.md`.

**Skills:** `context: fork` (isolated subagent context — expensive skills like /eval taste shouldn't pollute main context), `allowed-tools` (readonly skills shouldn't Write), `model` override (haiku for /todo, opus for /product), cross-tool portability (AgentSkills.io — skills work in Cursor/Gemini CLI too).

**Agents:** `memory: user` (agents that learn patterns across sessions natively), `isolation: worktree` (/go should build in a worktree, merge on keep, discard on revert), agent teams (shared tasks + inter-agent messaging — Anthropic built a 100K-line compiler with 16 coordinated agents).

**Hooks:** Using 8 of 22 available events. `UserPromptSubmit` could auto-route intent to skills. `TaskCompleted` could enforce quality gates in /go loops. `PreToolUse` can modify tool inputs. `SessionEnd` could auto-log sessions.

**Composites:** The `/batch` pattern (ships with Claude Code) decomposes work into N units, spawns agents in isolated worktrees, each opens a PR. This is the architecture for composite skills — parallel orchestration, not sequential chaining.

## Meta-Learning
- The predict→measure→update loop works when predictions are graded. It breaks when they're not.
- 63% accuracy is well-calibrated. Predictions are informative, not performative.
- Wrong predictions (8/16) produced the most valuable model updates — confirming the system design.
- The highest-information experiments are always in Unknown Territory, but the system gravitates toward known patterns. Need to enforce exploration.
