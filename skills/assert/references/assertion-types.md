# Assertion Types

## file_check (lowest signal)
Verifies a file exists. Useful for infrastructure but tells you nothing about quality.
```yaml
- id: score-script-exists
  type: file_check
  path: bin/score.sh
```

## content_check (medium signal)
Verifies file contains specific content. Better than file_check — tests structure.
```yaml
- id: score-has-health-gate
  type: content_check
  path: bin/score.sh
  contains: "health_gate"
```

## command_check (high signal)
Runs a command, checks exit code or output. Tests actual behavior.
```yaml
- id: score-runs-clean
  type: command_check
  command: "bash bin/score.sh . 2>&1"
  expect_exit: 0
```

## llm_judge (highest signal, highest variance)
Claude evaluates a claim. Use sparingly — results vary across runs.
```yaml
- id: scoring-delivers-value
  type: llm_judge
  claim: "bin/score.sh produces an actionable score"
  evidence_files: ["bin/score.sh"]
```

## score_trend (mechanical, longitudinal)
Checks score history for improvement or regression.
```yaml
- id: score-improving
  type: score_trend
  direction: up
  window: 5
```
