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
  - Evidence: 3 wrong predictions citing "average" formula. Confirmed again: taste at 40 floors everything.

- **Bash 3 on macOS breaks associative arrays.** macOS ships bash 3.2. `declare -A` fails silently. All bash scripts must use indexed arrays or parallel arrays.
  - Evidence: init.sh crashed on HIVE until fixed (2026-03-14).

- **Commands are the product, CLI is plumbing.** The slash commands (.claude/commands/*.md) are what users interact with. bin/ scripts serve them, not the other way around.
  - Evidence: Founder feedback (2026-03-14). All command upgrades focused on output templates.

- **Tests pay for themselves.** Found 3 real bugs through testing (grep-c || echo pattern, pipefail + grep). These are recurring bash antipatterns in this codebase.
  - Evidence: 2026-03-13 testing session.

- **Universal structure checks break plateaus.** Density-based scoring works but must be project-type-aware. First iteration over-penalized CLI. Always test on multiple project types.
  - Evidence: Structure score plateau broken 2026-03-13. CLI false positive caught same day.

## Uncertain Patterns (1-2 experiments, test again)

- **Generative eval variance ~15 points.** Same feature scores differently on repeated runs. Fixable: temperature=0 + structured output + rubric anchoring. Cost concern: API calls are paid vs claude -p being free.
  - Evidence: install.sh dropped 62→58 despite real improvements. Other features jumped +8-10 with no code changes.
  - Boundary: Single-run feature scores are NOT reliable for keep/revert decisions.

- **Project-local vs global knowledge.** Switched predictions.tsv and experiment-learnings.md from global to project-local. Unknown impact on cross-project learning.
  - Needs: Run 3+ sessions with project-local knowledge and compare prediction quality.

- **Named agent references are wasted — skills bypass them.** memory:user only on 1/6 agents. Agent teams completely unused despite native support.
  - Needs: Audit which skills actually use named agent refs vs spawning generic agents.

- **Code eval cannot measure visual-layer changes.** Need taste re-eval to verify visual predictions. Playwright MCP screenshot timeout is a blocker.
  - Needs: Fix Playwright timeout or find alternative screenshot approach.

- **Prediction without experiment is journaling, not learning.** System built predictions without running experiments. The loop generates hypotheses but has no mechanism to force testing them.
  - Evidence: 2026-03-11 session. Research also produced hypotheses with no validation artifact (2026-03-12).

- **Lens system closer to skills registry than predicted.** Hardcoded paths in score.sh and eval.sh are ONLY blockers to multi-lens. Distribution could be git repos.
  - Needs: Design multi-lens composition (two lenses scoring same project?).

- **External project init→score works for strangers.** commander.js: 80/100 on first init, 6 features, 8/10 assertions.
  - Evidence: 2026-03-15 validation. LLM eval variance remains dominant noise source — mechanical assertions 28/28.

## Unknown Territory (0 experiments, highest information value)

- Can a non-founder complete the init → plan → go → eval loop without getting stuck?
- Does prediction accuracy actually correlate with product improvement over time?
- Does cross-project knowledge transfer work? (e.g., patterns learned on HIVE help rhino-os)
- Does "continuous product intelligence" resonate as category positioning?
- What's the right balance between generative and belief assertions for honest scoring?
- Do the output templates produce consistent output across different Claude sessions?
- Does the pre_compact hook actually help context recovery, or is compacted context sufficient?
- Does the feedback loop (graded predictions → knowledge model → /plan recommendations) change what gets built?

## Dead Ends (confirmed failures)

- **Density-based hygiene scoring without project-type awareness.** Applied density multiplier uniformly — CLI console output got penalized like web console.log. Fixed by exempting CLI project type.
  - Last attempt: 2026-03-13. Fixed same day.
