---
name: onboard
description: "Onboard any repo into rhino-os. Detects project, understands what it does, generates real config + assertions, starts the learning loop. One command, zero placeholders. Works for strangers, new team members, or adding a new area to an existing project."
argument-hint: "[--force]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion
---

# /init

**This is the first thing a stranger does.** If this doesn't work, nothing else matters. One command, zero prompts, zero placeholders. Detect what the project is, understand what it does, and make the full system work.

The goal isn't setup — it's **time to first value**. The stranger should go from `/init` to seeing a real score with real feature breakdowns in under 2 minutes. Everything after that is earned attention.

## Steps

### 1. Scaffold

```bash
rhino init $ARGUMENTS
```

Creates directories, detects project type, generates skeleton files. The config has placeholders — your job is to replace them with real content from reading the code.

### 2. Understand the product

Read the codebase to form an opinion. Read in parallel:

- `README.md` — what the project says about itself
- `package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` — name, description, deps
- Landing page or main layout (`app/page.tsx`, `app/layout.tsx`, `src/App.tsx`, `pages/index.*`)
- Route structure (`app/` or `pages/` tree) — what can users do?
- 3-5 key source files — scan main source directory to understand domain
- Test files (if they exist) — what does the project think is important?
- CI config (`.github/workflows/`, `Makefile`) — what's automated?

Determine:
- **What is this product?** (one sentence, specific)
- **Who uses it?** (a person, not "users")
- **What value does it deliver?** (what changes for them)
- **What's the current state?** (working? broken? half-built? polished?)

### 3. Write real config

Edit `config/rhino.yml` — replace every placeholder with real content. No brackets, no "[do X]", no "TODO".

The value hypothesis should be one testable sentence: "X can Y without Z."

### 4. Generate features

Detect 3-7 features from the codebase. For each:
- `delivers:` — what it actually does (read the code, don't guess)
- `for:` — who benefits
- `code:` — file paths that implement it
- `weight:` — importance to the value hypothesis (1-5)
- `maturity:` — honest assessment (planned/building/working/polished)

**Feature detection heuristic:**
- Route directories → features (e.g., `app/dashboard/` → dashboard feature)
- Major source modules → features (e.g., `src/auth/` → auth feature)
- CLI commands → features (e.g., `bin/score.sh` → scoring feature)
- Package.json scripts → features (e.g., `"test"` → testing feature)
- Don't create features for utilities, configs, or infrastructure

### 5. Generate initial assertions

For each feature, create 2-3 mechanical assertions in `beliefs.yml`:
- At least one `file_check` (infrastructure: does core file exist?)
- At least one `command_check` or `content_check` (logic: does something work?)
- Prefer mechanical assertions over `llm_judge` for the initial set (lower variance, more reliable signal)

### 6. Start the learning loop

Create initial files so the loop works from session one:
- `.claude/knowledge/predictions.tsv` — header row if doesn't exist
- `.claude/knowledge/experiment-learnings.md` — standard template if doesn't exist

Write `.claude/plans/strategy.yml`:
```yaml
stage: mvp
bottleneck: "unknown — run /plan to diagnose"
last_updated: [today's date in YYYY-MM-DD]
```

Write `.claude/plans/roadmap.yml`:
```yaml
current_version: "v0.1"
thesis: "[the value hypothesis from rhino.yml — restate it here]"
evidence:
  - item: "Score improves after first /go session"
    status: unproven
  - item: "Assertions pass rate > 50% within 3 sessions"
    status: unproven
previous_versions: []
```

This means `/plan`, `/go`, `/retro`, `/rhino`, and `/strategy` all work immediately. No "run X first to set up Y."

### 7. First eval

```bash
rhino eval .
```

Show results with sub-score breakdown if available. This is the stranger's first real signal — make it count.

After running the baseline eval, write the eval output to `.claude/cache/eval-cache.json` so `/rhino` and `/plan` can read sub-scores immediately without requiring a separate eval run. Create `.claude/cache/` if it doesn't exist.

### 8. Present the result

Show what was set up and give one clear next step.

## Output format

```
◆ init — [project name]

  [project name] — [one sentence]
  for: [who]
  hypothesis: "[testable sentence]"
  stage: one · mode: build

  ✓ config/rhino.yml — value hypothesis + [N] features defined
  ✓ beliefs.yml — [N] assertions across [N] features
  ✓ learning loop — predictions.tsv, experiment-learnings.md, strategy.yml, roadmap.yml
  ✓ first eval complete

▾ features detected
  ▸ [name]     w:[N]  [maturity]  [score]/100
    "[delivers]"
  ▸ [name]     w:[N]  [maturity]  [score]/100
    "[delivers]"

  eval: [N] passing · [N] failing · [N] warn
  bottleneck: **[worst feature]** — [why]

▾ what's next
  Your product has a score now. Here's how to make it better:

  /plan              find the bottleneck and plan a fix
  /go [feature]      autonomous build loop on the worst feature
  /eval              re-measure after changes
```

## Arguments

- No args: full bootstrap
- `--force`: regenerate even if already initialized

## What you never do
- Leave placeholder text — fill everything in from the code
- Make up features that don't exist in the codebase
- Run `/plan` or `/go` automatically — let the stranger see what was set up first
- Create more than 7 features — start focused, detect more later with `/feature detect`
- Create only `llm_judge` assertions — mechanical assertions are more reliable for first contact
- Skip the learning loop setup — every /init should leave the system ready for /plan and /go
- Apologize for low scores — they're honest, and that's the point

## If something breaks
- `rhino init` not found: run `bash $RHINO_DIR/bin/init.sh` directly
- Can't determine what the product does: state what you see and ask via AskUserQuestion
- No README or landing page: infer from code structure and deps, flag low confidence
- beliefs.yml already exists: append new assertions, don't overwrite existing ones
- rhino.yml already exists and `--force` not set: "Already initialized. Use `--force` to regenerate."
- eval fails: show what failed, suggest `/feature [name]` to investigate

$ARGUMENTS
