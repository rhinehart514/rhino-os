# Experiment Learnings — rhino-os

## Known Patterns (3+ experiments, high confidence)

- **File-exists beliefs inflate scores.** Mechanical file_check assertions pass easily (95%+) while generative evals (Claude judging value delivery) average 38-55%. Blending them equally produces dishonest scores.
  - Evidence: HIVE scored 79 with equal weight, 65 with 3x generative weight. rhino-os same pattern.
  - Boundary: Projects with only generative evals won't see this inflation.
  - Fix: eval.sh now weights generative 3x (committed 2026-03-14).

- **head-500 eliminates truncation false negatives.** Eval reads code files via `head -N`. Files >200 lines got truncated, causing Claude to say "missing X" when X existed past the cutoff.
  - Evidence: CLI 35→68, install 35→62 after head-200→head-500.
  - Boundary: Files >500 lines still truncated. score.sh is 979 lines.

- **Score = min(dimensions) is non-obvious.** Three predictions assumed score was an average. It's min(structure, hygiene, product). One weak dimension floors everything.
  - Evidence: 3 wrong predictions citing "average" formula.

- **Bash 3 on macOS breaks associative arrays.** macOS ships bash 3.2. `declare -A` fails silently. All bash scripts must use indexed arrays or parallel arrays.
  - Evidence: init.sh crashed on HIVE until fixed (2026-03-14).

- **Commands are the product, CLI is plumbing.** The slash commands (.claude/commands/*.md) are what users interact with. bin/ scripts serve them, not the other way around.
  - Evidence: Founder feedback (2026-03-14). All command upgrades focused on output templates.

## Uncertain Patterns (1-2 experiments, test again)

- **Generative eval variance ~15 points.** Same feature scores differently on repeated runs. No temperature control, no rubric anchoring. Research confirmed 5 fixes exist (2026-03-14 research).
  - Evidence: install.sh got real improvements (mind files + commands globally) but score dropped 62→58 in same session. Other features jumped +8-10 with no code changes.
  - Needs: Implement temperature=0 + rubric-anchored prompt and measure variance reduction.
  - Boundary: Single-run feature scores are NOT reliable for keep/revert decisions. Only overall score (which blends many signals) is stable enough.

- **Project-local vs global knowledge.** Just switched predictions.tsv and experiment-learnings.md from global to project-local. Unknown whether this improves or hurts cross-project learning.
  - Needs: Run 3+ sessions with project-local knowledge and compare prediction quality.

- **Todo parsing is O(n²) with awk.** Each field read spawns a new awk process. Works for <10 items, slow for 30+.
  - Needs: Pre-parse all items in one awk pass if performance becomes a problem.


- **Auto-graded** (2026-03-11): System built predictions without running experiments. The loop generates hypotheses but has no mechanism to force testing them. Prediction without experiment is journaling, not learning.
- **Auto-graded** (2026-03-12): Research produced a hypothesis but no validation artifact. Competitive analysis ≠ user validation. The model was too confident in desk research.
- **Auto-graded** (2026-03-13): Tiered penalty uses -gt (strictly greater), so 1:-3 means count must be ≥2. For single-instance detection need 0:-N tier. Current fix catches the worst cases but misses singletons. Density-based scoring would be better than absolute thresholds for varying codebase sizes.
- **Auto-graded** (2026-03-13): Universal structure checks are high-value — they broke a real plateau. Density-based scoring works but must be project-type-aware: CLI console output ≠ web console.log pollution. First iteration over-penalized CLI; scoping density to web-only fixed it. The test project caught the bug before it shipped — always test on multiple project types.
- **Auto-graded** (2026-03-13): Score calculation is not a simple average of dimensions. Structure is the bottleneck dimension and its weight in the final score is higher than expected. Need to understand the actual score formula.
- **Auto-graded** (2026-03-13): Score = min(dimensions) confirmed. Predicted ~98 because I still didn't internalize that score = min, not avg. Hygiene 95 is now the floor. Also found and fixed a secondary bug: grep -c || echo 0 produces multiline values inside $().
- **Auto-graded** (2026-03-13): Found 3 real bugs through testing. Tests pay for themselves by exposing issues in the tools being tested. The grep-c || echo pattern and pipefail + grep are recurring bash antipatterns in this codebase.
- **Auto-graded** (2026-03-13): Score = min(all dimensions) confirmed again. Taste at 40 is the floor — no other dimension matters until taste moves. Structure 75 is legitimate codebase-scale debt, not dead ends. The 'dead ends, empty states' label in score output is misleading for large codebases.
- **Auto-graded** (2026-03-14): Value measurement doesn't require users. It requires test fixtures (known-state repos) + trend tracking (score deltas across sessions) + time measurement (wall-clock to first improvement). The gap isn't "no users" — it's "no value assertions." New assertion types needed: score_trend, assertion_trend, session_continuity, value_velocity. These read history.tsv and predictions.tsv, not files.
- **Auto-graded** (2026-03-14): Member return is a motivation problem, not a delivery problem. Notifications without drives are noise. Next experiment: wire one Octalysis drive (social influence) for members and measure return pull delta.
- **Auto-graded** (2026-03-14): Context bar "always empty" was correct behavior (no data), not broken wiring. The exploration agent misdiagnosed the root cause (said elementType missing, it wasn't). Always verify subagent claims before acting.
- **Auto-graded** (2026-03-14): Underestimated the impact. trend_for + per-feature change tracking addressed more complaints than expected. Score drop was caused by eval.sh changes (head-500 + JSON parsing) allowing generative results to cache and blend — a side effect, not a regression. The eval is now a real signal.
- **Auto-graded** (2026-03-14): head-500 eliminated truncation false negatives for files under 500 lines. Remaining eval inaccuracy comes from: (1) JSON parsing failures in judge_feature, (2) genuine gaps the eval correctly identifies. The eval is now a useful signal, not noise.
- **Auto-graded** (2026-03-14): The variance is entirely fixable with mechanical changes. Switch from claude -p to direct API with temperature=0 + structured output schema + rubric-anchored prompt. JSON parsing code becomes unnecessary. Cost concern: API calls are paid vs claude -p being free.
- **Auto-graded** (2026-03-14): Lens system closer to skills registry than predicted. Hardcoded paths in score.sh and eval.sh are ONLY blockers to multi-lens. Multi-lens composition (two lenses scoring?) is the real design question. Distribution could be git repos.2026-03-14	cofounder	Marking test-external-project done + creating project-local knowledge will raise learning from 48 to 55+	Learning eval judges prediction/knowledge model presence. No local files exist.	untested
- **Auto-graded** (2026-03-15): External project scoring validated. Init→score path works for strangers. LLM eval variance remains the dominant noise source — mechanical assertions are 28/28.


- **Auto-graded** (2026-03-13): Score prediction wrong (100 vs 95). YAML parser is different-fragile, not simpler — sed/grep single-line extraction breaks on multi-line scalars and complex quoting. The determinism claim was aspirational, not tested.
- **Auto-graded** (2026-03-14): Prediction was about an action that was never taken. The learning eval gap (infrastructure assertions, no value assertions) remains. Project-local knowledge is still a valid idea but was deprioritized.


- **Auto-graded** (2026-03-17): Named agent references are wasted — skills bypass them. memory:user only on 1/6 agents. Agent teams completely unused despite native support.


- **Auto-graded** (2026-03-17): Code eval cannot measure visual-layer changes. Need taste re-eval to verify prediction. Playwright MCP screenshot timeout is a blocker for taste measurement.

## Unknown Territory (0 experiments, highest information value)

- Can a non-founder complete the init → plan → go → eval loop?
- Do the output templates produce consistent output across different Claude sessions?
- Does prediction accuracy correlate with product improvement?
- What's the right balance between generative and belief assertions?
- Does the pre_compact hook actually help context recovery?

## Dead Ends (confirmed failures)

- **Density-based hygiene scoring without project-type awareness.** Applied density multiplier uniformly — CLI console output got penalized like web console.log. Fixed by exempting CLI project type.
  - Last attempt: 2026-03-13. Fixed same day.
