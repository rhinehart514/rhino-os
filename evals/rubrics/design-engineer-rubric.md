# Design Engineer — Eval Rubric

Grade each session by mode. Threshold: 0.6 average.

## Init — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Detection accuracy | Correctly identified stack, styling, component lib | Got framework right, missed details | Wrong stack detection |
| Token extraction | Found all existing design tokens, documented exact values | Found most tokens | Invented tokens instead of detecting |
| Direction fit | Aesthetic matches what the project already is | Reasonable guess | Imposed a direction that contradicts existing code |
| system.md quality | Complete, specific, enforceable decisions | Partial, some vague sections | Template with placeholders unfilled |

## Audit — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Coverage | All 5 checks run (tokens, states, a11y, consistency, craft) | 3+ checks | Skimmed one file |
| Specificity | File:line, exact classes, proposed fix | General areas of concern | "Your UI needs work" |
| system.md enforcement | Cross-referenced every finding against design decisions | Mentioned system.md | Ignored it |
| Prioritization | Top 5 ranked by user impact + fix complexity | Unranked list | Raw grep dump |
| Score tracking | Appended to audit-history.jsonl, compared to last audit | Logged score | No history update |

## Review — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Pages read | Read every page/route component, not just one | Read 3+ pages | Evaluated from code structure alone |
| Taste honesty | Honest subjective assessment, names specific feeling gaps | Diplomatic but vague | "Looks good!" (useless) |
| All 8 dimensions | Scored every taste dimension with specific evidence | Scored most, some without evidence | Skipped dimensions |
| The Upgrade | One specific, implementable level-up suggestion | Reasonable but generic suggestion | "Improve the design" |
| Feeling gaps | Identified problems that pass mechanical checks but feel wrong | Some subjective observations | Only flagged things grep would catch |

## Recommend — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Stack awareness | Recommendations match the actual framework + component lib | Mostly relevant | Suggested React components for a Svelte project |
| Specificity | Exact package names, install commands, config snippets | Named tools without implementation steps | "Use a better font" |
| Product fit | Suggestions match the product type and aesthetic direction | Reasonable but generic | Same suggestions for every project |
| Tiered | Quick wins + level-ups + aspirational clearly separated | Some organization | Undifferentiated list |
| Knowledge-informed | Referenced knowledge.md finds, current 2026 landscape intel | Some awareness of current tools | Outdated or uninformed recommendations |

## Build — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Pattern match | All new code matches codebase conventions exactly | Mostly consistent | Introduced new patterns |
| Completeness | Fixed ALL instances project-wide | Fixed most | Fixed one file |
| Safety | Build + types pass after changes | Minor warnings | Broke the build |
| Tier discipline | T1 auto-fixed, T2 read context, T3 asked first | Mostly followed | Changed architecture without asking |
| system.md update | New decisions documented for next session | Mentioned updates needed | No memory update |
| Anti-slop | Actively fought convergence — distinctive choices preserved | Neutral | Made it more generic |

## Red Flags (auto-deduct 0.2 each)

- "Clean and modern" without specifics (the phrase itself is AI slop)
- Ignoring accessibility
- Introducing a styling approach the project doesn't use
- Fixing one instance but leaving identical ones untouched
- Generating components that duplicate existing ones
- Not running build after changes
- Contradicting decisions in system.md
- Using Inter/blue-gray/shadow-sm/rounded-lg as defaults without checking project
- Recommending tools/components incompatible with the project's stack
- Subjective eval that only finds problems grep would catch (no taste, just mechanics)
- "Looks good!" without honest critique (cheerleading is not evaluating)
