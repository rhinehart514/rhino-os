---
name: smart-commit
description: Analyzes staged changes and generates a conventional commit message tied to the active plan. Use after completing a task.
user-invocable: true
---

# Smart Commit

1. Run `git diff --staged --stat` and `git diff --staged`
2. Read `.claude/plans/active-plan.md` for context on what was being built
3. Summarize changes
4. Generate a Conventional Commits message:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `refactor:` for restructuring
   - `chore:` for tooling/config
   - `docs:` for documentation
5. Include scope if in a monorepo: `feat(packages/ui): add Button variant`
6. Body should reference the ADR task if applicable
7. Present the message for approval, then commit
