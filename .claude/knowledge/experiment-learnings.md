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
  - Needs: Implement temperature=0 + rubric-anchored prompt and measure variance reduction.

- **Project-local vs global knowledge.** Just switched predictions.tsv and experiment-learnings.md from global to project-local. Unknown whether this improves or hurts cross-project learning.
  - Needs: Run 3+ sessions with project-local knowledge and compare prediction quality.

- **Todo parsing is O(n²) with awk.** Each field read spawns a new awk process. Works for <10 items, slow for 30+.
  - Needs: Pre-parse all items in one awk pass if performance becomes a problem.

## Unknown Territory (0 experiments, highest information value)

- Can a non-founder complete the init → plan → go → eval loop?
- Do the output templates produce consistent output across different Claude sessions?
- Does prediction accuracy correlate with product improvement?
- What's the right balance between generative and belief assertions?
- Does the pre_compact hook actually help context recovery?

## Dead Ends (confirmed failures)

- **Density-based hygiene scoring without project-type awareness.** Applied density multiplier uniformly — CLI console output got penalized like web console.log. Fixed by exempting CLI project type.
  - Last attempt: 2026-03-13. Fixed same day.
