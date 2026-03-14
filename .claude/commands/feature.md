---
description: "Work with features. /feature lists them. /feature auth shows status. /feature new payments creates one. /feature auth research explores it. /feature auth ideate brainstorms."
---

# /feature

Features are named parts of your product. Each has its own assertions, its own pass rate, its own score. This is the creative command — where you define, explore, and imagine.

## What to do

Parse `$ARGUMENTS` and route:

### No arguments → list all features
Run `rhino feature` to show all features with pass rates. Then give one opinion: "**[worst feature]** needs attention — `/plan [feature]` to work on it."

### Feature name(s) → show status + suggest next action
One or more names: `/feature auth`, `/feature auth scoring cli`.

For each, run `rhino feature [name]`. Then:
- All passing: "**[feature]** is green."
- Some failing: list failing assertions. "Run `/go [features]` to fix."
- No assertions: "Let's define what **[feature]** must do."

Multiple features → show all, identify weakest.

### `detect` → find features in the codebase
Run `rhino feature detect`. Show what was found. For unasserted features: "Run `/feature new [name]` to define it."

### `new [name]` → create a feature with interactive questions

**Use AskUserQuestion** to understand the feature before planting assertions:

```
Questions (up to 4):
1. "What does [name] do?" — options based on codebase scan
   (Handles data | User-facing UI | Auth/access | API/integration)
2. "What must NEVER break?" — multiSelect
   (Data integrity | Auth/security | Core flow | Performance)
3. "Who uses this?"
   (End users | Admins | Both | Developers)
4. "What files are involved?" — options from codebase scan
   (src/[detected paths])
```

Based on answers, generate 3-5 assertions mixing mechanical and subjective:

**Mechanical** (fast, deterministic):
- `type: file_check` with `path:` and `contains:` — does the code exist?
- `type: content_check` with `forbidden:` — code quality gates

**Subjective** (Claude evaluates quality):
- `type: llm_judge` with `path:` and `prompt:` — is the code good? coherent? complete?
  Example: `prompt: "Is the auth flow complete? Can a user sign up, log in, reset password?"`

**Behavioral** (requires dev server):
- `type: dom_check` or `playwright_task` — only if dev server is detected

Always include at least 1 llm_judge assertion per feature. Mechanical checks tell you "it exists." LLM judges tell you "it's good."

Then:
1. Write to beliefs.yml with `feature: [name]`
2. Run `rhino eval . --feature [name]` for baseline
3. Create tasks (TaskCreate) for any failing assertions
4. Output: "[name] created with N assertions. X/N passing. Run `/go [name]`."

### `[name] research` → explore the feature's codebase and context

**Use WebSearch + codebase exploration** to understand the feature deeply:

1. **Scan the codebase**: find all files related to the feature (grep for the name, trace imports, map dependencies)
2. **Check external context**: WebSearch for best practices, competitor approaches, common patterns for this type of feature
3. **Map what exists vs what's missing**: which assertions pass? which don't? why?
4. **Present findings with AskUserQuestion**:
   ```
   "I found 3 gaps in [feature]. Which matters most?"
   Options with previews showing the code/context for each gap
   ```
5. **Generate recommendations**: new assertions, refactoring suggestions, or tasks

### `[name] ideate` → brainstorm possibilities

**Use AskUserQuestion with previews** to explore ideas:

1. Read the feature's current state (assertions, code, pass rate)
2. Generate 3-4 ideas for improving or extending the feature
3. Present each idea with an ASCII preview or code snippet:
   ```
   Question: "Which direction for [feature]?"
   Options with previews:
     - "Add [capability]" → preview showing what the code would look like
     - "Refactor [pattern]" → preview showing before/after
     - "Split into [sub-features]" → preview showing the new structure
   ```
4. Based on selection, generate assertions and tasks for the chosen direction

## The point

Features make the product concrete. `/feature` is where you think about what your product is. `/plan` and `/go` are where you execute. This is the creative space.

## If something breaks
- `rhino feature` fails: read beliefs.yml directly and list unique `feature:` values
- No beliefs.yml: create one with the header, then run the `new` flow
- WebSearch fails: skip external context, work with codebase only
- No features in beliefs.yml: all assertions are unscoped — suggest adding `feature:` fields

$ARGUMENTS
