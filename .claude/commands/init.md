---
description: "Bootstrap rhino-os into any repo. Detects project, understands what it does, generates real config + assertions. One command, zero placeholders."
---

# /init

You are bootstrapping rhino-os into this repo. One command, zero prompts, zero placeholders. Detect what the project is, understand what it does, and make the full command suite work.

## Steps

### 1. Scaffolding

```bash
rhino init $ARGUMENTS
```

This creates directories, detects project type, and generates skeleton files. The config it produces has placeholder values — your job is to replace them with real ones.

### 2. Understand the product

Read the codebase to form an opinion about what this product is. Read these in parallel:

- `README.md` — what the project says about itself
- `package.json` (or `pyproject.toml`, `go.mod`) — name, description, dependencies
- Landing page or main layout (`app/page.tsx`, `app/layout.tsx`, `src/App.tsx`, `pages/index.*`)
- Route structure (`app/` or `pages/` tree) — what can users do?
- Key source files — scan 3-5 files in the main source directory to understand domain

From this, determine:
- **What is this product?** (one sentence)
- **Who uses it?** (specific person, not "users")
- **What value does it deliver?** (what changes for them)
- **What are the measurable signals?** (how would you know it's working)

### 3. Write real config

Edit `config/rhino.yml` — replace the placeholder hypothesis, user, and signals with real ones based on what you learned. No brackets, no "[do X]", no placeholders.

Example for a document sharing app:
```yaml
value:
  hypothesis: "Teams can share documents with prospects and track engagement without email attachments"
  user: "Sales teams sending decks and proposals to prospects"
  signals:
    - name: document_shared
      description: "A document gets shared via link"
      target: "Share flow completes without error"
      measurable: true
    - name: engagement_tracked
      description: "Viewer analytics are captured and shown"
      target: "View event appears in analytics dashboard"
      measurable: true
```

### 4. Generate meaningful assertions

Edit `config/evals/beliefs.yml` — add assertions that test whether the product actually delivers value, not just whether files exist. Use what you learned about the product.

Keep assertion types to `file_check` and `content_check` only (mechanical, no LLM calls). But make them test things that matter:
- Does the main entry point exist and render something useful?
- Do key features have their routes/components?
- Are critical config files present?
- Is the codebase free of obvious debt markers?

### 5. Validate

```bash
rhino eval .
```

Show the results. Report the pass rate and which features need work.

### 6. Present the result

Show what you learned and what you set up:

```
◆ rhino init

[project name] — [one-sentence description]
for: [who uses it]
hypothesis: "[the real hypothesis you wrote]"

✓ config/rhino.yml (value hypothesis defined)
✓ config/evals/beliefs.yml (N assertions)
✓ N features detected

eval: M/N passing

next: /plan
```

## Arguments

- No args: full bootstrap with understanding
- `--force`: regenerate even if already initialized

## What you never do
- Leave placeholder text like "[do X]" or "[Who specifically uses this?]" — fill it in
- Make up features that don't exist in the codebase
- Run `/plan` or `/go` automatically — let the founder see what you set up first
- Apologize for low eval pass rates — they're honest

## If something breaks
- `rhino init` not found: run `bash $RHINO_DIR/bin/init.sh` directly
- Can't determine what the product does: state what you see and ask the founder
- No README or landing page: infer from code structure and dependencies, flag low confidence

$ARGUMENTS
