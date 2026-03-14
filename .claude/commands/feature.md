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

### `new [name]` → create a feature definition

**Use AskUserQuestion** to understand what the feature delivers:

```
Questions (2-3):
1. "What does [name] deliver to the user?" — free text
   (The specific value. Not "handles auth" but "users can sign up, log in, and reset their password")
2. "Who specifically uses this?"
   (End users | Admins | Developers | The system itself)
3. "What code files are involved?" — options from codebase scan
   (src/[detected paths], bin/[scripts])
```

Based on answers, add a feature entry to `config/rhino.yml` under `features:`:

```yaml
features:
  [name]:
    delivers: "[what they said it delivers]"
    for: "[who they said uses it]"
    code: ["path/to/file1", "path/to/dir/"]
```

Then:
1. Write to rhino.yml `features:` section (append to existing features)
2. Run `rhino eval . --feature [name] --fresh` for baseline
3. Output: "[name] defined. Verdict: [DELIVERS/PARTIAL/MISSING]. Run `/go [name]` to close gaps."

The generative eval will have Claude judge whether the code delivers what it claims. No need to write manual assertions — the claim IS the assertion.

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

## System awareness
- `/feature [name]` (you) → define, manage, detect features
- `/eval [feature|taste|full]` → run measurement stack (assertions + taste)
- `/ideate [feature|wild]` → brainstorm possibilities for a feature
- `/research [feature|topic]` → deep-dive research
- `/plan [feature]` → plan work for a feature
- `/go [feature]` → autonomous build loop

## The point

Features make the product concrete. `/feature` is where you define what your product is. `/eval` measures it. `/ideate` imagines what it could be. `/plan` and `/go` execute.

## Next action (always recommend one)
- Feature created with failing assertions → "Run `/go [feature]` to build it."
- Feature is all green → "Run `/ideate [feature]` to extend it, or `/eval taste` to check craft."
- Research revealed gaps → "Run `/plan [feature]` to prioritize fixes."
- No features exist → "Run `/feature detect` to scan, or `/feature new [name]` to define one."

## If something breaks
- `rhino feature` fails: read rhino.yml directly and list features under `features:` section
- No features in rhino.yml: suggest `/feature new [name]` to define one
- Falls back to beliefs.yml if no `features:` section in rhino.yml
- WebSearch fails: skip external context, work with codebase only

$ARGUMENTS
