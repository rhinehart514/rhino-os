---
name: todofocus
description: Task focus enforcer. Use when you need to stay on track during implementation. Reads active plan and current task, reminds you of scope, and blocks tangential work. Say "/todofocus" to check if you're still on track.
user-invocable: true
---

# Task Focus Check

1. Read `.claude/plans/active-plan.md`
2. Identify the current task being worked on
3. Compare current file changes against that task's scope

## Rules
- If working on something NOT in the current task → flag it
- If the current task is done → suggest the next task from the plan
- If no plan exists → suggest creating one with the architect agent
- If all tasks are done → suggest running qa-verify

## Output Format
```
📍 Current task: [task name]
📊 Progress: [X/Y tasks complete]
🎯 On track: [yes/no]
⏭️ Next: [next action]
```
