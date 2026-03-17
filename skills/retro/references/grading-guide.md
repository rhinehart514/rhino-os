# Prediction Grading Guide

## Gradable predictions (numeric targets)
- "Raise scoring from 42 to 55" → check eval-cache.json: score >= 55? yes. 50-54? partial. <50? no.
- "Assertions will increase from 56 to 60" → check score-cache.json assertion_pass_count.
- "Score will improve by >5 points" → check score delta in history.tsv.

## Ungradable predictions (qualitative)
- "Improve error handling" → need proxy: did error-related assertions improve?
- "Better UX" → need taste eval or user signal.
- "Make the code cleaner" → need slop score change.

For ungradable predictions: propose a grade with evidence, present to founder for confirmation. Don't auto-grade qualitative predictions.

## Calibration assessment
- 50-70% accuracy = well-calibrated (learning zone)
- >70% = predictions too safe, not learning enough
- <50% = model is broken, review prediction quality
- 100% = definitely too safe

## Anti-rationalization checkpoints
1. All predictions correct? → Too safe. Make bolder predictions.
2. Accuracy jumped >20% in one session? → Check for lenient grading.
3. Model update without new evidence? → Flag as speculation.
4. "Dead end" keeps recurring? → Maybe not dead. Investigate.
5. All grades are "partial"? → Push for yes/no. Partial is a hedge.
