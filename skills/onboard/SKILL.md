---
name: onboard
description: "Onboard any repo into rhino-os. Detects project, understands what it does, generates real config + assertions, starts the learning loop. One command, zero placeholders. Works for strangers, new team members, or adding a new area to an existing project."
argument-hint: "[--force]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion
---

# /onboard

**This is the first thing a stranger does.** If this doesn't work, nothing else matters. One command, zero prompts, zero placeholders. Detect what the project is, understand what it does, and make the full system work.

The goal is **time to first value**. Stranger goes from `/onboard` to seeing a real score with real features in under 2 minutes.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/detect-project.sh` — detects language, framework, key files, source structure
- `scripts/onboard-checklist.sh` — checks what's already set up (rhino.yml? beliefs? features? scores?)
- `scripts/first-score.sh` — runs first score and explains what each number means
- `references/onboarding-flow.md` — the step-by-step flow with what happens at each step
- `templates/rhino-yml-template.yml` — skeleton config with comments explaining each field
- `gotchas.md` — real failure modes. **Read before generating config.**

## The protocol

### Step 1: Detect and check

Run in parallel:
```bash
bash scripts/detect-project.sh
bash scripts/onboard-checklist.sh
```

If checklist shows already initialized and `--force` not set: show what exists, suggest `--force` to regenerate.

### Step 2: Understand the product

Read the codebase to form an opinion. Read in parallel:
- README.md, package.json / pyproject.toml / go.mod / Cargo.toml
- Landing page or main layout (app/page.tsx, src/App.tsx, pages/index.*)
- Route structure (app/ or pages/ tree)
- 3-5 key source files from the main source directory
- Test files and CI config if they exist

Determine: **What is this?** (one sentence), **Who uses it?** (a person), **What value?** (what changes), **Current state?** (working/broken/half-built)

### Step 3: Write real config

Read `templates/rhino-yml-template.yml` for structure. Edit `config/rhino.yml` — replace every placeholder with real content from code analysis. No brackets, no TODO.

### Step 4: Generate features (3-7)

Detect from route directories, source modules, CLI commands, package scripts. Each feature gets: delivers, for, code paths, weight (1-5), maturity (planned/building/working/polished).

### Step 5: Generate assertions (2-3 per feature)

Mechanical assertions in beliefs.yml. At least one file_check, one command_check or content_check per feature. Prefer mechanical over llm_judge.

### Step 6: Start the learning loop

Create: predictions.tsv (header), experiment-learnings.md (template), strategy.yml, roadmap.yml. Every downstream command works immediately.

### Step 7: First eval

```bash
bash scripts/first-score.sh
```

Also run `rhino eval .` and write output to `.claude/cache/eval-cache.json`.

### Step 8: Present results

Use output template from `references/onboarding-flow.md`. Show what was set up, features detected with scores, and one clear next step.

## Task generation — the path from onboarded to productive

**/onboard's job is not just setup. It's generating EVERY task needed to go from "just initialized" to "productive."** After onboarding, the founder should have a full backlog of next steps. An onboarded project with no tasks is a project that doesn't know what to do next.

**After onboarding completes, generate the complete task list:**

### Setup completion tasks
- No beliefs.yml or <3 assertions → task: "Only [N] assertions — run /assert suggest to add more"
- No strategy.yml → task: "No strategic diagnosis — run /strategy honest"
- No predictions yet → task: "No predictions — next /go session must include predictions"
- Score below 50 → task: "Initial score is [N] — run /eval to identify gaps"
- No roadmap.yml or empty thesis → task: "No thesis defined — run /roadmap new"

### Feature gap tasks
- Each feature detected with no assertions → task: "Feature [X] has no assertions — run /assert suggest [X]"
- Each feature with empty code paths → task: "Feature [X] has no code — implement or remove"
- Each feature with weight not set → task: "Feature [X] has no weight — assign based on value"
- Features list has >7 items → task: "Too many features ([N]) — run /ideate kill to focus"
- Features list has <2 items → task: "Only [N] features — run /feature detect to find more"

### First session tasks
- Run first /eval → task: "Run /eval to establish baseline scores"
- Run first /strategy → task: "Run /strategy honest for initial diagnosis"
- Run first /plan → task: "Run /plan to pick the first move"
- Define the person → task: "Name the specific person this is for in rhino.yml value.user"

### Documentation tasks
- No README or generic README → task: "Write a real README — run /copy landing"
- CLAUDE.md is empty or minimal → task: "Add project-specific instructions to CLAUDE.md"
- No design-system.md for web projects → task: "Create .claude/design-system.md for visual consistency"

**Write ALL tasks to /todo.** Tag with `source: /onboard` and type (setup/feature/first-session/docs). Priority: first session tasks first.

**There is no cap on task count.** A fresh onboard might generate 15+ tasks. Generate all of them. This IS the founder's first backlog.

After onboarding, show: "Generated N tasks to get started. First priority: [task]. Run /plan to pick your first move."

## What you never do

- Leave placeholder text — fill everything from the code
- Make up features that don't exist in the codebase
- Run /plan or /go automatically — let the stranger see what was set up first
- Create more than 7 features — start focused
- Create only llm_judge assertions — mechanical first
- Skip the learning loop setup
- Apologize for low scores

## If something breaks

- detect-project.sh returns "unknown": the project has no recognizable package manager or entry point — manually specify the language and framework in rhino.yml
- first-score.sh fails with "no features": rhino.yml was generated but features section is empty — re-run with `--force` or manually add features
- beliefs.yml assertions all fail on first eval: assertions were generated from code analysis but the project may not be building — check if `npm run build` or equivalent succeeds first
- "Already initialized" but config is stale: use `/onboard --force` to regenerate everything from scratch

$ARGUMENTS
