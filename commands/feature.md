---
name: feature
description: "Use when defining, viewing, or detecting features and their maturity"
---

# /feature

Features are named parts of your product. Each has its own assertions, its own pass rate, its own score. This is the creative command — where you define, explore, and imagine.

## What to do

Parse `$ARGUMENTS` and route:

### No arguments → list all features
Run `rhino feature` to show all features with pass rates. Read `config/rhino.yml` features section for maturity, weight, and depends_on. Show maturity and weight alongside pass rates. Then give one opinion: "**[worst feature]** needs attention — `/plan [feature]` to work on it." The worst feature is determined by lowest maturity among highest-weight features, not just pass rate.

### Feature name(s) → show status + suggest next action
One or more names: `/feature auth`, `/feature auth scoring cli`.

For each, run `rhino feature [name]`. Also read `config/rhino.yml` for the feature's maturity, weight, and depends_on. Then:
- All passing: "**[feature]** is green."
- Some failing: list failing assertions. "Run `/go [features]` to fix."
- No assertions: "Let's define what **[feature]** must do."

In detail view, also show:
- **maturity**: current level (planned/building/working/polished) with bar
- **weight**: importance to value hypothesis (1-5)
- **depends_on**: upstream features this depends on, with their maturity
- **depended on by**: downstream features that depend on this one

Multiple features → show all, identify weakest.

### `detect` → find features in the codebase
Run `rhino feature detect`. Show what was found. For unasserted features: "Run `/feature new [name]` to define it."

### `new [name]` → commit to building a specific feature

This is the DO step — you've decided what to build and you're tracking it. If you're not sure what to build yet, try `/ideate` first. If you're not sure the direction is right, try `/product` first.

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
    weight: [1-5]
    maturity: planned
    depends_on: [feature_name]  # if applicable
```

**Also ask:**
4. "How important is this to the value hypothesis? (1=nice-to-have, 5=critical)" → sets `weight`
5. "Does this depend on any existing features?" → show list of current features for selection → sets `depends_on`

Then:
1. Write to rhino.yml `features:` section (append to existing features, with weight, maturity: planned, and depends_on if provided)
2. Run `rhino eval . --feature [name] --fresh` for baseline
3. Output: "[name] defined. Verdict: [DELIVERS/PARTIAL/MISSING]. Run `/go [name]` to close gaps."

The generative eval will have Claude judge whether the code delivers what it claims. No need to write manual assertions — the claim IS the assertion.

### `[name] research` → explore the feature's codebase and context

**Use WebSearch + codebase exploration** to understand the feature deeply:

1. **Scan the codebase**: find all files related to the feature (grep for the name, trace imports, map dependencies)
2. **Check external context**: WebSearch for best practices, competitor approaches, common patterns for this type of feature
3. **Map what exists vs what's missing**: which assertions pass? which don't? why?
4. **Present findings with AskUserQuestion**
5. **Generate recommendations**: new assertions, refactoring suggestions, or tasks

### `[name] status [value]` → lifecycle transition

Transition a feature's lifecycle status. Valid values: `active`, `proven`, `killed`, `archived`.

1. Validate the value is one of: active / proven / killed / archived
2. If `killed`: use AskUserQuestion to ask for the reason. Add `killed_reason:` and `killed_date:` to the feature entry.
3. Update the feature's `status:` field in `config/rhino.yml`
4. Output: `[name] → [value]` with confirmation

Missing `status:` field = `active` (default).

### `[name] ideate` → brainstorm possibilities

**Use AskUserQuestion with previews** to explore ideas:

1. Read the feature's current state (assertions, code, pass rate)
2. Generate 3-4 ideas for improving or extending the feature
3. Present with previews showing what the code/experience would look like
4. Based on selection, generate assertions and tasks for the chosen direction

## Output format

### List all features:

Only show `active` and `proven` features by default. Suffix proven features with `(proven)`. Omit `killed` and `archived` unless the user explicitly requests them.

```
◆ features

▸ learning        ████░░░░░░  **48**/100  w:4  building   ← bottleneck
  "a model that gets smarter every session"
  for: the system itself · depends on: scoring

▸ scoring         █████░░░░░  **58**/100  w:5  working
  "honest number that tells a founder if their product improved"
  for: solo founder who just made changes

· self-diagnostic ██████░░░░  **68**/100  w:2  working  (proven)
  "system health check — measures calibration, staleness, learning loop"
  for: solo founder who wants to know if the system is working · depends on: scoring, learning

· install         ██████░░░░  **68**/100  w:3  polished
  "one-command setup — clone, run install.sh, everything works"
  for: new user trying rhino-os for the first time

· docs            ██████░░░░  **68**/100  w:3  working
  "clear explanation of what rhino-os is and how to use it"
  for: someone who has never heard of rhino-os

· commands        ███████░░░  **70**/100  w:5  working
  "slash commands that route founder intent to the right action"
  for: solo founder working in Claude Code

· todo            ██████░░░░  **--**/100  w:2  working
  "persistent backlog that survives across sessions"
  for: solo founder managing ideas across sessions

product completion: **62%**
bottleneck: **learning** (w:4, building) — `/plan learning` to work on it

/feature [name]       deep dive into one
/feature new [name]   define a new feature
/feature detect       scan codebase for undeclared features
```

### Single feature detail:

```
◆ feature — scoring

  **58**/100  █████░░░░░
  maturity: working  w:5
  depends on: (none)
  depended on by: learning, self-diagnostic

  delivers: "honest number that tells a founder if their product improved"
  for: solo founder who just made changes
  code: bin/score.sh, bin/eval.sh, bin/lib/config.sh

▾ verdict
  DELIVERS: score.sh computes honest number with health gate
  DELIVERS: per-feature breakdown identifies real bottlenecks
  PARTIAL: trend visualization exists but not surfaced in output
  MISSING: onboarding guidance for new projects is generic

/go scoring           fix the gaps
/feature scoring ideate  brainstorm improvements
/eval scoring         measure current state
```

### New feature created:

```
◆ feature new — [name]

  defined in config/rhino.yml
  delivers: "[what]"
  for: "[who]"
  code: [files]
  weight: [N]  maturity: planned
  depends on: [features or none]

  baseline: **PARTIAL** — 2 delivers, 1 partial, 1 missing

/go [name]    build what's missing
/eval [name]  measure in detail
```

## System awareness
- `/feature [name]` (you) → define, manage, detect features
- `/eval [feature|taste|full]` → run measurement stack (assertions + taste)
- `/ideate [feature|wild]` → brainstorm possibilities for a feature
- `/research [feature|topic]` → deep-dive research
- `/plan [feature]` → plan work for a feature
- `/go [feature]` → autonomous build loop

## What you never do
- Output raw CLI output without formatting — use the templates above
- Create features without asking what they deliver (use AskUserQuestion)
- Skip the baseline eval after creating a new feature

## If something breaks
- `rhino feature` fails: read rhino.yml directly and list features under `features:` section
- No features in rhino.yml: suggest `/feature new [name]` to define one
- Falls back to beliefs.yml if no `features:` section in rhino.yml
- WebSearch fails: skip external context, work with codebase only

$ARGUMENTS
