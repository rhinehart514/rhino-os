---
name: skill
description: "Use when creating new skills or managing existing ones with assertions and maturity"
---

# /skill — Lens Management

Route the user's intent to the right `rhino skill` subcommand.

## Routing

| Input | Action |
|-------|--------|
| `/skill` or `/skill list` | Run `rhino skill list` |
| `/skill install <url>` | Run `rhino skill install <url>` |
| `/skill remove <name>` | Run `rhino skill remove <name>` |
| `/skill info <name>` | Run `rhino skill info <name>` |
| `/skill create <name>` | Crystallize an observed pattern into a lens |

## Instructions

1. Parse the argument after `/skill` to determine the subcommand.
2. Run the corresponding `rhino skill` command via bash.
3. Display the output to the user.

### `/skill` (no args) or `/skill list`

```bash
"$RHINO_DIR/bin/rhino" skill list
```

Show installed lenses with their name, version, and description.

### `/skill install <url>`

```bash
"$RHINO_DIR/bin/rhino" skill install "$URL"
```

After install completes:
1. Suggest running `/init` to wire up the new lens's mind files and commands.
2. Read `config/rhino.yml` features section and show how the new lens connects to existing features: "This lens adds measurement for: **[feature1]** (w:[N], [maturity]), **[feature2]** (w:[N], [maturity])." If no features match, suggest: "Consider `/feature new [name]` to define a feature this lens measures."

### `/skill remove <name>`

```bash
"$RHINO_DIR/bin/rhino" skill remove "$NAME"
```

After removal, suggest running `/init` to clean up stale symlinks.

### `/skill info <name>`

```bash
"$RHINO_DIR/bin/rhino" skill info "$NAME"
```

Display the lens.yml manifest and directory contents.

### `/skill create <name>` — Crystallize a pattern into a lens

Skills emerge from observed patterns, not empty templates. This command helps the founder capture a recurring measurement or reasoning pattern as a reusable lens.

**Before creating, require evidence.** Ask the founder:

```
Questions (2-3):
1. "What pattern have you seen that deserves its own measurement?"
   (Something that keeps mattering across sessions — not a hypothesis, an observation)
2. "What would this lens evaluate that the base system doesn't?"
   (The specific dimension or check. e.g., "API response time consistency" or "accessibility compliance")
3. "Show me an example — a moment where having this lens would have changed a decision."
   (Concrete evidence. If they can't point to one, it's too early to crystallize.)
```

If the founder can't answer #3, push back: "This might not be ready to be a skill yet. Keep watching for the pattern — rhino will flag it when it recurs."

**Validation checklist — is this pattern ready?**
- Has the pattern recurred across 3+ sessions? (One-off observations aren't patterns yet.)
- Can you name the specific measurement dimension? (Not "quality" — something like "API response consistency" or "navigation dead ends".)
- Does an existing lens already cover this? Run `rhino skill list` and check for overlap. If a lens measures the same dimension differently, that's a conflict — resolve before creating.

**Once evidence is clear:**

0. Read `config/rhino.yml` features section. Check which existing features the new lens would measure against. Show: "This lens would add measurement for: **[feature1]** (w:[N], [maturity]), **[feature2]** (w:[N], [maturity])." If it doesn't map to any existing feature, note: "This lens measures a new dimension not covered by existing features."
1. Validate name (lowercase, alphanumeric + hyphens)
2. Create `lens/<name>/` with only what the evidence justifies:
   - `lens.yml` — manifest with real description from the founder's answers
   - `eval/beliefs.yml` — seed with 2-3 assertions derived from the pattern they described. Auto-detect assertion types from what the pattern measures:
     - File exists or contains a string? → `file_check`
     - Shell command returns 0? → `command_check`
     - Forbidden patterns in source? → `content_check`
     - Genuinely subjective quality judgment? → `llm_judge` (use sparingly — each one adds WARN drag to scoring)
   - Only create `mind/`, `scoring/`, `config/` directories if the pattern needs them
3. Generate `lens.yml` with the founder's actual words:
```yaml
name: <name>
description: "<what the founder said in question 2>"
version: 0.1.0
author: ""
emerged_from: "<the example from question 3>"
provides:
  beliefs: true
  # only set others to true if the evidence supports them
```

**Output format:**
```
◆ skill create — <name>

  emerged from: "<the pattern they described>"

  ✓ lens/<name>/lens.yml
  ✓ lens/<name>/eval/beliefs.yml (N assertions seeded)

  ▾ product map connection
    measures: [feature1] (w:N, maturity), [feature2] (w:N, maturity)
    — or: new dimension, not yet mapped to a feature

  next: /eval to test the new assertions
  then: /skill info <name> to verify

rhino will track whether this lens produces useful signal.
```

**If something breaks:**
- Founder can't articulate the pattern: too early — suggest they keep observing
- Name contains invalid characters: reject with guidance (lowercase, alphanumeric, hyphens only)
- Lens already exists: show current state with `/skill info <name>`

**Cross-recommendations:**
- After create → `/eval` to test the seeded assertions
- If the lens assertions keep passing trivially → the lens isn't measuring anything real, suggest removing it

## If something breaks
- Install fails → check the URL is a valid git repo with a `lens.yml` manifest
- Remove fails → check `rhino skill list` for the exact lens name
- Commands not available after install → run `/init` to wire up symlinks

## Cross-references
- After install/remove → suggest `/init`
- To see measurement stack → `/rhino` (status)
- To evaluate with a new lens → `/eval`
