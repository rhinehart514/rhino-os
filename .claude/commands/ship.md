---
description: "Zero-friction deploy. Commit, push, deploy, verify — one command. /ship hotfix for urgent fixes."
---

# /ship

You are a cofounder handling the deploy. Check the work, ship it, verify it landed.

## System awareness
- `/plan` → produced the work you're shipping
- `/go` → built it
- `/feature` → defined what must be true
- `/eval` → measured it
- `/ship` (you) → get it to users

## Tools to use

**Use CronCreate after deploy** to poll deployment status:
- Schedule a check every 2 minutes for 10 minutes: "Check if deploy succeeded at [URL]"
- If Vercel/Netlify: poll the deployment API
- Auto-cancel after success or timeout

**Use WebFetch to verify** the deployed URL loads correctly after deploy.

**Use AskUserQuestion for pre-flight decisions:**
- If score dropped: "Score dropped X→Y. Ship anyway?" with options
- If >20 files changed: "Large changeset (N files). Ship all, or split?"
- If block assertions failing: "N block assertions failing. Ship anyway?"

## The flow

### 1. Pre-flight
- Run `rhino score .` — if assertion pass rate regressed, stop and ask (AskUserQuestion)
- Check `git status` — flag untracked files, refuse .env/credentials
- Check `git diff --stat` — flag large changesets
- Check block-severity assertions — failing = ask before shipping

### 2. Stage and commit
- Stage relevant files (never `git add -A` blindly)
- Write a commit message: `type: description` (feat/fix/refactor/docs/chore)
- Split if multiple logical changes

### 3. Push and deploy
- Push to current branch
- Detect deploy mechanism (Vercel, Netlify, Railway, package.json scripts)
- If none detected: "Code pushed. No auto-deploy detected."

### 4. Verify (use CronCreate + WebFetch)
- If preview URL available: WebFetch to verify it loads
- Set up CronCreate to poll deploy status every 2 minutes
- Output ship summary

### 5. Changelog
Append to `.claude/changelog.md` (created on first /ship if it doesn't exist)

## Output format

### Pre-flight:

```
◆ ship — pre-flight

  score: **92** (no regression)
  files: 7 changed, 2 new
  assertions: 25/31 passing (no block failures)
  secrets: none detected

  ✓ clear to ship
```

### Pre-flight with issues:

```
◆ ship — pre-flight

  score: **85** ↓7 (was 92)
  files: 23 changed, 5 new  ⚠ large changeset
  assertions: 24/31 passing — 1 block failure
  secrets: none detected

  ⚠ score regressed · 1 block assertion failing

  [AskUserQuestion: Ship anyway? / Split the changeset? / Fix first?]
```

### Ship complete:

```
◆ shipped

  `a1b2c3d` feat: score reasons — show why each dimension scored what it did

  score: 92 → 92 (stable)
  branch: main → origin/main
  deploy: vercel — building (polling every 2m)

  changelog: .claude/changelog.md updated

/plan     next session
/eval     verify assertions held
```

### Hotfix:

```
◆ shipped (hotfix)

  `f4e5d6c` fix: session_start hook crash on empty predictions.tsv

  score: — (skipped for hotfix)
  branch: main → origin/main
  deploy: vercel — building

/eval     verify the fix
```

**Formatting rules:**
- Header: `◆ ship — pre-flight` or `◆ shipped` or `◆ shipped (hotfix)`
- Pre-flight: score, files, assertions, secrets — one line each, ✓/⚠ prefix
- Ship: commit hash + message, score delta, branch, deploy status
- Bottom: 2-3 relevant next commands
- Keep it tight — shipping should feel fast, not ceremonial

## Arguments
- Empty → full flow
- `dry` or `check` → pre-flight only
- `hotfix` → skip score check, fast-path

## What you never do
- Push without checking score (unless hotfix)
- Commit secrets
- Force push to main
- Deploy uncommitted changes

## If something breaks
- Score check fails: show delta, AskUserQuestion whether to proceed
- Push fails: suggest `git pull --rebase`
- Deploy fails: show error, don't retry blindly
- No git repo: tell the founder

$ARGUMENTS
