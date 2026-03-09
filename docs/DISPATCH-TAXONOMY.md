# Dispatch Taxonomy

The dispatch taxonomy classifies every action into one of four categories based on risk and reversibility. Used by `sweep` and applicable to any automated agent.

## The Four Categories

### GREEN — Auto-dispatch
**No human approval needed.** These actions are safe, reversible, and mechanical.

| Action | Why it's GREEN |
|--------|---------------|
| Run test suites | Read-only, no side effects |
| Run scout | Creates knowledge files, no external communication |
| Generate eval reports | Write-safe, creates files only |
| Check dependency versions | Read-only |
| Run linters | Read-only diagnostic |

**Rule:** If the action only reads data or creates new files (never modifies existing user code), it's GREEN.

### YELLOW — Dispatch with summary
**Low-risk but human should know.** The action is taken, but the human sees a summary of what happened.

| Action | Why it's YELLOW |
|--------|----------------|
| Auto-fix lint errors | Low risk, but modifies code |
| Update documentation | Low risk, but changes content |
| Close stale branches | Reversible via reflog, but removes visible state |
| Merge dependabot PRs (patch) | Low risk, but changes dependencies |
| Clean up temp files | Reversible in theory, but might delete something needed |

**Rule:** If the action modifies existing files but is low-risk and easily reversible, it's YELLOW.

### RED — Requires human approval
**High-impact, hard to reverse, or requires judgment.** The system describes the action and waits.

| Action | Why it's RED |
|--------|-------------|
| Deploy to production | Affects real users |
| Merge feature PRs | Requires code review judgment |
| Send external communication | Irreversible, affects reputation |
| Create new features | Requires product judgment |
| Delete anything permanent | Irreversible |
| Spend > $5 in API costs | Financial impact |
| Respond to humans | Reputation risk |
| Major dependency upgrades | Breaking change risk |

**Rule:** If you'd want to review this action before it happened, it's RED.

### GRAY — Informational only
**No action, just awareness.** Context that might influence today's priorities.

| Information | Why it's GRAY |
|-------------|--------------|
| Market trends from scout | Background intelligence |
| Competitor launches | Awareness, no immediate action |
| Community discussions | Informational |
| Stats and metrics summaries | Context for decision-making |
| Weather, news, calendar | Environmental context |

**Rule:** If it's information without a clear action, it's GRAY.

## Decision Tree

```
Is this action read-only?
├─ Yes → GREEN
└─ No → Does it modify user code or data?
         ├─ No (creates new files only) → GREEN
         └─ Yes → Is it easily reversible?
                  ├─ Yes → Is the risk low?
                  │        ├─ Yes → YELLOW
                  │        └─ No → RED
                  └─ No → RED

Does this require judgment?
├─ Yes → RED
└─ No → (apply above tree)

Is this just information?
├─ Yes → GRAY
└─ No → (apply above tree)
```

## Escalation Rules

1. **When in doubt, escalate.** YELLOW → RED, GREEN → YELLOW.
2. **Budget threshold.** Any single action estimated > $5 → RED regardless.
3. **External communication.** Always RED. No exceptions.
4. **Irreversibility.** If you can't undo it with a simple command → RED.
5. **Chain reactions.** If this action triggers other actions (CI/CD, webhooks) → RED.

## Examples

**Sweep finds outdated patch dependencies:**
- Check what's outdated → GREEN
- Update patch versions → YELLOW
- Update major versions → RED

**Automated agent finds failing tests:**
- Report the failure → GREEN (informational)
- Attempt to fix the test → RED (modifies code with judgment)
- Disable the failing test → RED (changes behavior)

**Scout finds a TIME-SENSITIVE opportunity:**
- Log it to knowledge base → GREEN
- Draft a tweet about it → GREEN (creates file, doesn't send)
- Actually post the tweet → RED (external communication)
