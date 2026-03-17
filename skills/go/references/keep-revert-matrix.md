# Keep/Revert Decision Matrix

| Assertions | Reviewer | Decision | Reason |
|-----------|----------|----------|--------|
| improved | KEEP | **keep** | Best case — value gained + quality confirmed |
| improved | REVERT | **keep** | Measurement wins over review opinion |
| stable | KEEP | **keep** | No regression, reviewer approves |
| stable | REVERT | **revert** | No value gained, reviewer found problems |
| regressed | any | **revert** | Always — assertion regression is never acceptable |

## Regression debugging

Before reverting, spawn debugger to investigate WHY assertions regressed. The regression cause is often more valuable than the fix itself. The debugger agent captures:
- Which assertions broke
- What the commit changed that caused the break
- Whether the regression is a real problem or a shallow assertion

## Plateau rules

- 3 consecutive moves with <2pt improvement = stop
- Read the eval evidence field — it tells you WHY the score isn't moving
- Rethink the approach, don't iterate harder
- Run `bash scripts/plateau-check.sh` to detect this mechanically

## Edge cases

- **Temporary regression for bigger win**: Not allowed. Revert, then build the bigger change as a single atomic commit that doesn't regress at any point.
- **Reviewer REVERT on improved assertions**: Keep. Measurements are authoritative over opinions. But log the reviewer's concern — it might surface a real problem later.
- **All assertions pass but score is flat**: Assertions are too shallow. They test existence, not quality. Deepen the assertions before continuing.
