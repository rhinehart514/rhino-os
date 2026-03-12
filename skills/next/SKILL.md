---
name: next
description: Show the next task to work on. No ceremony. One task, why it matters, estimated time.
user-invocable: true
---

# /next

Read `.claude/plans/active-plan.md`.

Find the first task with `- [ ]` (unchecked).

Output:

---
**Next task:** [task name]
**Why:** [one sentence — which pyramid layer, which hypothesis it tests]
**Est:** [time estimate if mentioned, otherwise omit]

Run `/build` to start.
---

If no active-plan.md exists, say: "No active plan. Run `/plan` to create one."
If all tasks are checked, say: "All tasks complete! Run `/plan` for a new sprint."

Do not load any other context. Do not run score. Do not analyze the codebase. Just read the plan and surface the next item.
