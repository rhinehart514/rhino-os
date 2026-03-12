---
name: setup
description: "Onboard any project. Scans codebase, generates product-brief, pyramid, master backlog, rules files, and knowledge stubs."
user-invocable: true
disable-model-invocation: true
---

# Setup — Project Onboarding

## Step 1: Detect Project Type

Check for: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`.
Read package.json to identify framework (Next.js, React, Vue, etc.).

## Step 2: Create Project Structure

```
.claude/
  rules/          # copied from rhino-os config/rules/
    identity.md
    product-brief.md
    hypotheses.md
  plans/
  experiments/
  cache/
knowledge/
  decisions.md
  killed.md
  experiment-learnings.md
  founder-voice.tsv
.claude/product-map.yml
.claude/product-todo.md
```

## Step 3: Copy Rule Files

Copy from `$RHINO_DIR/config/rules/` to `.claude/rules/`:
- `identity.md` — customize with project identity
- `product-brief.md` — will be populated by discovery
- `hypotheses.md` — empty template, grows over time

## Step 4: Ask Configuration (3 questions)

### Stage
"What stage is this project?"
- **mvp** — pre-launch, finding product-market fit (default)
- **early** — launched, early users
- **growth** — PMF found, scaling
- **mature** — established, optimizing

### Autonomy
"What autonomy level?"
- **manual** — I approve everything
- **guided** — I set direction, you execute (default)
- **autonomous** — full loop with /go

### Experimentation
"How aggressive should experiments be?"
- **conservative** — mostly exploit known patterns
- **balanced** — mix of known and exploration (default)
- **aggressive** — prefer unknown territory

## Step 5: Product Discovery

Scan the codebase to build the product pyramid:

1. Find all routes/pages/screens
2. For each: assess completion % and quality %
3. Classify into pyramid layers:
   - **Functional**: core features that do the job
   - **Emotional**: UX, onboarding, polish, feedback
   - **Ecological**: sharing, discovery, growth, retention
4. Write `.claude/product-map.yml`:

```yaml
pyramid:
  functional:
    - feature: "[name]"
      completion: [0-100]
      quality: [0-100]
      routes: ["/path"]
      gaps: ["specific gap"]
  emotional:
    - feature: "[name]"
      ...
  ecological:
    - feature: "[name]"
      ...
updated: "[ISO date]"
```

5. Present to founder: "Does this map look right?"

## Step 6: Generate Master Product Backlog

This is the big one. Generate `.claude/product-todo.md` — the COMPLETE list of everything needed to ship this product. This is not a sprint. This is the whole picture.

For every feature in product-map.yml, for every gap, generate concrete TODOs. Organize by pyramid layer. Be exhaustive — the goal is "what does DONE look like?"

```markdown
# Product Backlog — [project-name]

Generated: [date] | Stage: [stage]
Progress: [X/Y] items complete ([Z%])

## Functional — Does It Work?

### [Feature: e.g. "User Authentication"]
Completion: [X%] | Quality: [X%]
- [ ] [concrete task — e.g. "Add email verification flow"]
- [ ] [concrete task — e.g. "Handle password reset"]
- [ ] [concrete task — e.g. "Add OAuth with Google"]
- [x] [already done — e.g. "Basic login/register forms"]

### [Feature: e.g. "Content Creation"]
Completion: [X%] | Quality: [X%]
- [ ] [task]
- [ ] [task]

## Emotional — Does It Feel Good?

### [Feature: e.g. "Onboarding"]
Completion: [X%] | Quality: [X%]
- [ ] [task — e.g. "Add welcome walkthrough for new users"]
- [ ] [task — e.g. "Empty state guidance on dashboard"]
- [ ] [task — e.g. "Loading states on all async actions"]

### [Feature: e.g. "Visual Polish"]
- [ ] [task — e.g. "Consistent spacing system"]
- [ ] [task — e.g. "Hover/focus states on all interactive elements"]
- [ ] [task — e.g. "Transitions between page navigations"]

## Ecological — Does It Grow?

### [Feature: e.g. "Sharing"]
Completion: [X%] | Quality: [X%]
- [ ] [task — e.g. "Share button on content pages"]
- [ ] [task — e.g. "Share preview cards (Open Graph)"]
- [ ] [task — e.g. "Copy-link with success feedback"]

### [Feature: e.g. "Return Triggers"]
- [ ] [task — e.g. "Email notification for new activity"]
- [ ] [task — e.g. "Push notification opt-in"]

## Infrastructure (non-user-facing but required)

- [ ] [task — e.g. "Error monitoring (Sentry)"]
- [ ] [task — e.g. "Analytics tracking"]
- [ ] [task — e.g. "Deploy pipeline"]
```

**Rules for generating the backlog:**
1. Every gap in product-map.yml becomes at least one TODO
2. Every feature with completion < 100% gets TODOs for missing pieces
3. Every feature with quality < 50% gets TODOs for quality gaps
4. Include infrastructure items that block shipping
5. Mark already-completed items as `[x]` so progress is visible
6. Be SPECIFIC — "improve onboarding" is not a TODO. "Add welcome modal with 3-step product tour" is.
7. Err on the side of too many items. This is the exhaustive picture.
8. Ask the founder: "What am I missing? What else needs to happen before this ships?"

**After generating**, print the summary:
```
Product backlog: X items across Y features
  Functional: A/B done
  Emotional:  C/D done
  Ecological: E/F done
  Infrastructure: G/H done
```

## Step 7: Generate Product Brief

Populate `.claude/rules/product-brief.md` from discovery results:
- Product name and one-line description
- Pyramid state with percentages
- Backlog progress (X/Y items, Z%)
- Baseline score
- Empty hypotheses (will grow)

## Step 8: Generate Knowledge Stubs

### decisions.md
Scan git log for architectural commits. Seed with discoverable decisions.
Tell founder: "Add any major decisions I missed."

### killed.md
Ask: "Has anything been tried and killed?"
If new project, write empty template.

### experiment-learnings.md
Create with Known/Uncertain/Unknown/Dead Ends sections (all empty).

### founder-voice.tsv
Create with header: `date	statement	feature	quality_dimension	action_taken`

## Step 9: Run Baseline Score

```bash
rhino score . --json
```

Record in product-brief.md.

## Step 10: Print Summary

```
Project onboarded: [name]
  Type: [detected]  Stage: [stage]  Autonomy: [level]
  Features: [count] across [pyramid layers]
  Readiness: [%] ([completion%] built, [quality%] quality)
  Backlog: [X] items ([Y] done, [Z] remaining)
  Baseline score: [score]

Files created:
  .claude/rules/identity.md
  .claude/rules/product-brief.md
  .claude/rules/hypotheses.md
  .claude/product-map.yml
  .claude/product-todo.md          <- THE FULL PICTURE
  knowledge/decisions.md
  knowledge/killed.md

Next: run /plan to get today's tasks.
```
