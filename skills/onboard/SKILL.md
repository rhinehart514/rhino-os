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

## What you never do

- Leave placeholder text — fill everything from the code
- Make up features that don't exist in the codebase
- Run /plan or /go automatically — let the stranger see what was set up first
- Create more than 7 features — start focused
- Create only llm_judge assertions — mechanical first
- Skip the learning loop setup
- Apologize for low scores

$ARGUMENTS
