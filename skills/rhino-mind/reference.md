# rhino-mind Reference — Self-Model & Calibration

Loaded on demand. Core identity and thinking rules are in SKILL.md.

---

## Self-Model

How rhino-os itself is performing. Updated from real data, not guesses.

### Capabilities

#### Measurement Stack
- `rhino score .` — value scoring with health gate. Status: operational. Now includes reasons for each penalty.
- `rhino eval .` — generative feature eval (Claude judges claim vs code). Status: operational.
- `rhino taste` — visual eval via Claude Vision, 11 dimensions. Status: operational.
- `rhino self` — 4-system self-diagnostic. Status: operational.

#### Commands (the product surface)
17 slash commands, each with explicit output templates and state awareness:
/plan, /go, /eval, /feature, /ideate, /research, /roadmap, /rhino, /ship

#### Intelligence Layer
- **Symlinks**: mind/ files loaded via .claude/rules/ on every conversation
- **Hooks**: session_start (boot card), post_edit (quality checks), post_skill (YAML validation), pre_compact (context recovery)
- **Learning loop**: predict → act → measure → update model → repeat

### Known Weaknesses
(Confirmed across 3+ sessions)

- **Prediction grading is manual.** Predictions log to TSV but only get graded when /plan runs. No automatic grading mechanism. This is the #1 gap in the learning loop.
- **Knowledge model is append-only.** experiment-learnings.md grows but never prunes stale patterns. No staleness detection on individual entries.
- **LLM judge variance.** Generative eval (feature scoring) produces different scores on repeated runs. No temperature control, no rubric anchoring, no multi-sample averaging. Variance is ~15 points.
- **Score formula is min(dimensions).** A single weak dimension floors the entire score. Taste at 40 makes everything else irrelevant. This is by design but non-obvious.
- **CLI console output false positives.** Hygiene checks flag console.log in CLI tools that legitimately use stdout. Project-type awareness partially fixes this but edge cases remain.

### Uncertain Weaknesses
(Suspected, needs confirmation)

- Commands produce better output than before, but untested whether founders actually follow the recommended next commands or ignore them.
- The innovation matrix in /ideate may produce ideas that cluster by quadrant label rather than genuine novelty.
- Score reasons may be too terse for founders unfamiliar with the codebase.

### Unknown Territory
(Never tested — highest information value)

- Does prediction accuracy actually correlate with product improvement?
- Does the measurement stack catch regressions that matter to users, or just structural noise?
- Can someone who isn't us complete a full loop (/init → /plan → /go → /eval) without getting stuck?
- Do the output templates in commands actually produce consistent output across different Claude models/sessions?
- Does the pre_compact hook actually help context recovery, or is the compacted context already sufficient?

### Calibration Data
- Prediction accuracy: 63% (10/16 graded, with partials at 0.5). In target range (50-70%).
- Score: 92/100 (25/31 assertions passing)
- Worst feature: learning at 48/100
- Best feature: commands at 70/100

### What I Would Change About Myself
- The learning feature should be the smartest part of the system. It's the worst.
- Commands should read state uniformly — right now /plan reads 9 sources, /eval reads 2.
- The CLI (bin/) should serve the commands, not the other way around. Commands are the product.
- Mind files are loaded but never validated — no mechanism to check if they actually influenced behavior.

### Available MCP Tools
- **context7**: resolve-library-id + query-docs — real-time library documentation for any framework. Use in /research for accurate docs instead of web search hallucinations.
- **playwright**: browser automation — navigate, click, snapshot, evaluate, network requests. Use in /research site for live product analysis.
- **Vercel**: deploy, project management, runtime logs, toolbar threads. Use in /ship for deployment.

### Plugin Surface (what rhino-os extends in Claude Code)

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

### Claude Code Capabilities We're NOT Using

For the full reference, see `skills/CAPABILITIES.md`. Key gaps:

**Skills:** `context: fork` (isolated subagent context), `allowed-tools` (restrict tool access), `model` override (haiku for cheap skills, opus for expensive), cross-tool portability via AgentSkills.io standard.

**Agents:** `memory: user` (persistent cross-session agent learning), `isolation: worktree` (safe parallel work), `skills` preloading, `maxTurns`, agent teams (shared tasks, inter-agent messaging, 16-agent orchestration).

**Hooks:** 14 of 22 events untapped. `PreToolUse` can modify inputs. `PostToolUse` can modify outputs. `UserPromptSubmit` can auto-route intent. `TaskCompleted` can enforce quality gates. `SessionEnd` can auto-log sessions.

**Ecosystem:** `/batch` pattern (parallel agent orchestration in worktrees), Ralph Wiggum loops (test→fail→retry until green), 500+ community skills, marketplace distribution with version pinning.

### Meta-Learning
- The predict→measure→update loop works when predictions are graded. It breaks when they're not.
- 63% accuracy is well-calibrated. Predictions are informative, not performative.
- Wrong predictions (8/16) produced the most valuable model updates — confirming the system design.
- The highest-information experiments are always in Unknown Territory, but the system gravitates toward known patterns. Need to enforce exploration.
