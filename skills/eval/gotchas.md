# Eval Gotchas — LLM Evaluation Failure Modes

These are specific to code evaluation, not generic LLM problems.

## Rubric variance
Same code scored by different sessions = +/-15pt swing. Anchor to rubrics/feature.json. If no rubric exists, the first score sets the baseline — flag it as unanchored.

## Stage ceiling blindness
Early-stage code averaging 75+ is suspicious. MVP shouldn't score like a mature product. Check rhino.yml stage field — if mvp/one, scores above 70 need justification.

## Craft overfit
Clean, well-structured code that delivers nothing scores high on craft but should score low overall. Delivery is 50% of the formula for a reason — a beautiful corpse is still a corpse.

## Viability hallucination
Without market data, viability scores default to "nobody knows about it = risky." Use customer-intel.json when available. If no market data exists, cap viability at 40 and flag: "Run /strategy market for real viability data."

## Evidence-free excellence
Any sub-score >80 without citing specific file:line evidence is inflated. The evaluator must point to code, not describe vibes.

## Delta amnesia
Ignoring eval-cache.json previous scores. Same code should get same score. If it drifts >15pts between sessions, the evaluator is miscalibrated, not the code. Run `bash scripts/variance-check.sh <feature> <proposed_score>` to catch this.

## Assertion conflation
Beliefs pass rate and eval score are different things. 90% assertion pass rate with 40 eval score means assertions are shallow — they test existence, not quality. Don't conflate the two metrics.

## Blind spot in blind eval
/eval blind compares cold-read against claims. But the cold-read itself has LLM biases — it sees patterns it expects, misses patterns it doesn't. Cross-reference with mechanical checks (DOM eval, copy eval) when possible.
