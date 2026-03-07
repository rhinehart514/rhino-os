# Agent Session — Generic Eval Rubric

Use this rubric to evaluate ANY agent session. Adapt the criteria to the specific agent type.

## 1. Task Completion (0-3)

| Score | Criteria |
|-------|----------|
| 0 | Did not complete the assigned task |
| 1 | Partially completed — missing key deliverables |
| 2 | Completed the task with minor gaps |
| 3 | Fully completed with all deliverables present and high quality |

## 2. Accuracy (0-3)

| Score | Criteria |
|-------|----------|
| 0 | Major errors or incorrect conclusions |
| 1 | Some errors that affect reliability |
| 2 | Mostly accurate, minor issues |
| 3 | Accurate, well-sourced, verifiable |

## 3. Actionability (0-3)

| Score | Criteria |
|-------|----------|
| 0 | Output is informational only — no clear next steps |
| 1 | Vague recommendations ("look into this") |
| 2 | Specific recommendations with clear steps |
| 3 | Immediately actionable — founder can execute within 1 hour |

## 4. Efficiency (0-3)

| Score | Criteria |
|-------|----------|
| 0 | Excessive tool calls, wasted API budget, circular exploration |
| 1 | Some wasted effort but eventually productive |
| 2 | Efficient with minor detours |
| 3 | Minimal tool calls, direct path to output |

## 5. Knowledge Contribution (0-3)

| Score | Criteria |
|-------|----------|
| 0 | No new information added to the system |
| 1 | Confirmed existing knowledge |
| 2 | Added new insights or updated existing knowledge |
| 3 | Significant new knowledge that changes strategy or approach |

## Scoring

| Total | Verdict |
|-------|---------|
| 12-15 | EXCELLENT — this agent session was highly valuable |
| 9-11  | GOOD — solid session, minor improvements possible |
| 6-8   | MEH — some value but significant room for improvement |
| 0-5   | BAD — wasted cycles, rethink approach |

## Eval Report Template

```markdown
## Agent Session Eval — [agent name] — [date]

### Scores
| Dimension | Score | Notes |
|-----------|-------|-------|
| Task Completion | X/3 | [details] |
| Accuracy | X/3 | [details] |
| Actionability | X/3 | [details] |
| Efficiency | X/3 | [details] |
| Knowledge Contribution | X/3 | [details] |
| **Total** | **X/15** | **[VERDICT]** |

### Key Takeaways
- [most valuable output from session]
- [what to improve next time]

### Follow-up Actions
- [ ] [action item from session]
```
