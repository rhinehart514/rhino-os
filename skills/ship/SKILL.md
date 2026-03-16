---
name: ship
description: "Ship to GitHub + deploy. Commit, push, create releases with roadmap-derived changelogs, open PRs, deploy, verify. /ship for full flow, /ship release for GitHub release, /ship pr for pull request."
argument-hint: "[dry|hotfix|release [tag]|pr [base]|changelog]"
allowed-tools: Read, Bash, Edit, AskUserQuestion, WebFetch, Agent
---

# /ship

**When to use this:** You've built, measured, and the eval is green. Time to get it out the door. `/ship` handles the full pipeline: pre-flight checks, git, GitHub releases with auto-generated changelogs, PRs, deploy, and verification.

**What connects here:**
- `/roadmap narrative` → the changelog and release notes come from proven theses
- `/roadmap changelog` → generates the user-facing changelog that /ship uses
- `/eval` → pre-flight assertion check
- `/go` → built the work being shipped

## Routing

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| (none) | Full flow: pre-flight → commit → push → deploy → verify |
| `dry` or `check` | Pre-flight only — score, assertions, secrets, maturity |
| `hotfix` | Skip score check, fast-path commit → push |
| `release [tag]` | Create GitHub release with auto-generated notes from roadmap |
| `pr [base]` | Open PR with roadmap-derived description |
| `changelog` | Generate/update CHANGELOG.md from roadmap data |

## State to read (parallel)

1. `rhino score .` — current score
2. `.claude/cache/eval-cache.json` — per-feature sub-scores + deltas
3. `config/rhino.yml` — features (maturity/weight), mode
4. `.claude/plans/roadmap.yml` — current thesis + version (for release context)
5. `.claude/cache/narrative.yml` — current external narrative (for release notes)
6. `.claude/cache/changelog.md` — pre-generated changelog (if exists)
7. `git status` / `git log` — working tree state
8. `gh repo view` — GitHub repo info (for release/PR routes)

## The Full Flow

### 1. Pre-flight
- Run `rhino score .` — assertion regression → stop and ask
- Check `git status` — flag untracked files, refuse .env/credentials
- Check `git diff --stat` — flag large changesets (>20 files)
- Check block-severity assertions — failing = ask
- Check feature maturity — `planned`/`building` features → warn
- Check dependency maturity — upstream deps not `working`+ → warn
- Compute product completion % and version completion %

### 2. Stage and commit
- Stage relevant files (never `git add -A` blindly)
- Commit message: `type: description` (feat/fix/refactor/docs/chore)
- Split if multiple logical changes

### 3. Push
- Push to current branch
- If no remote tracking: `git push -u origin [branch]`

### 4. Deploy (if applicable)
- Detect: Vercel (`vercel.json`, Vercel MCP), Netlify, Railway, package.json scripts
- If Vercel MCP available: use `deploy_to_vercel`, then `get_deployment` to poll
- If none detected: "Code pushed. No auto-deploy detected."

### 5. Verify
- WebFetch the deployed URL to confirm it loads
- If deploy API available, poll for completion

---

## GitHub Integration

### `release [tag]` → create GitHub release

Creates a proper GitHub release with auto-generated notes from the roadmap. This is where internal theses become external announcements.

**Steps:**
1. Determine tag: use `[tag]` if provided, else read current version from roadmap.yml (e.g., `v8.0.3`)
2. Check if tag already exists: `git tag -l [tag]`
3. Read `.claude/cache/changelog.md` — use the relevant version section
4. If no changelog exists, generate one inline from roadmap.yml:
   - Thesis summary as the release headline
   - Proven evidence items as bullet points
   - Features that matured during this version
   - Link back to the thesis: "This release proves: [thesis]"
5. Read `.claude/cache/narrative.yml` — use the one-liner as the release title context
6. Create the release:
   ```
   gh release create [tag] --title "[version]: [thesis summary]" --notes "[generated notes]"
   ```
7. If `--draft` flag: create as draft for founder review

**Release notes format:**
```markdown
## [thesis summary — one line]

[2-3 sentences from narrative.yml paragraph, filtered to what's new in this version]

### What's new
- [user-facing change derived from evidence item]
- [user-facing change derived from feature maturity transition]
- [user-facing change]

### What we learned
- [Key Known Pattern confirmed during this version]

### Known limitations
- [Honest gap from positioning.yml — what we haven't proven yet]
```

**Anti-slop**: same ban list as `/roadmap narrative`. Every bullet traces to evidence.

### `pr [base]` → open pull request

Creates a PR with a roadmap-aware description. Not just "what changed" — "why it matters."

**Steps:**
1. Determine base branch: use `[base]` if provided, else `main`
2. Read `git log [base]..HEAD --oneline` — commits in this PR
3. Read `git diff [base]...HEAD --stat` — files changed
4. Map changed files to features (via rhino.yml `code:` paths)
5. Read eval-cache sub-scores for affected features
6. Read roadmap.yml — does this PR advance any evidence items?

**PR body format:**
```markdown
## What this does
[1-2 sentences — what changed for the user, not what code changed]

## Why
[Which thesis evidence item or bottleneck this addresses]

## Features affected
- [feature] ([maturity]) — [sub-score change if measurable]

## Evidence
- [assertion pass/fail changes]
- [score delta if available]

## What's NOT in this PR
- [Honest scope — what this doesn't address]
```

Create with:
```
gh pr create --title "[type]: [summary]" --body "[generated body]"
```

### `changelog` → generate CHANGELOG.md

Reads roadmap.yml and generates a proper CHANGELOG.md at the repo root. Uses the same logic as `/roadmap changelog` but writes to the file instead of cache.

**Steps:**
1. Read `.claude/cache/changelog.md` if it exists (pre-generated by /roadmap changelog)
2. If not, generate from roadmap.yml (same logic as /roadmap changelog route)
3. Write to `CHANGELOG.md` at repo root
4. Stage and commit: `docs: update changelog`

---

## Output format

### Pre-flight:
```
◆ ship — pre-flight

  score: **92** (no regression)
  files: 7 changed, 2 new
  assertions: 57/63 passing (no block failures)
  secrets: none detected
  product: **62%** · version: **v8.0** — 43% proven

  ▾ features affected
    ✓ scoring     w:5  working   58 (v:62 q:50 u:60) ↑4
    ✓ commands    w:5  working   70 (v:75 q:65 u:68) ↑2
    ⚠ learning    w:4  building  — not ready to ship

  ⚠ learning is still building — ship anyway?
```

### Ship complete:
```
◆ shipped

  `a1b2c3d` feat: eval scoring engine — sub-scores, rubrics, multi-sample median

  score: 92 → 95 ↑3
  product: **62%** · version: **v8.0** — 43% proven
  branch: main → origin/main
  deploy: vercel — building

/roadmap narrative   update the external story
/ship release v8.1   create GitHub release
/eval                verify assertions held
```

### Release created:
```
◆ shipped release — v8.1

  tag: v8.1
  title: "v8.1: Eval scoring engine upgrade"
  url: https://github.com/[owner]/[repo]/releases/tag/v8.1

  ▾ release notes (published)
    ## Eval scoring engine upgrade
    Multi-sample median scoring, decomposed sub-scores (value/quality/UX),
    per-feature rubrics, and structured output via API.

    ### What's new
    - 3-sample median reduces eval variance from ±15 to ±5 points
    - Sub-scores break down value delivery, code quality, and UX separately
    - Per-feature rubrics generated from code inspection (SWE-bench for features)

    ### Known limitations
    - /go loop untested on external projects
    - No retention data yet

/roadmap bump        graduate the thesis if ready
/eval                verify current state
```

### PR created:
```
◆ shipped pr — #42

  title: feat: eval scoring engine upgrade
  base: main ← feature/eval-engine
  url: https://github.com/[owner]/[repo]/pull/42

  features: scoring (↑4), eval (+sub-scores)
  advances: v8.0 evidence "first-go" (indirectly)

/ship                merge and deploy when approved
/eval                verify assertions
```

## What you never do
- Push without checking score (unless hotfix)
- Commit secrets (.env, credentials.json, API keys)
- Force push to main
- Deploy uncommitted changes
- Create a release with unproven claims in the notes
- Write PR descriptions that don't map to features or evidence
- Use slop words in release notes (same ban list as /roadmap narrative)

## If something breaks
- Score check fails: show delta, AskUserQuestion
- Push fails: suggest `git pull --rebase`
- Deploy fails: show error, don't retry blindly
- `gh` not installed: "GitHub CLI required for releases/PRs. `brew install gh`"
- No git repo: tell the founder
- No roadmap.yml: generate release notes from git log only (degraded mode)
- Vercel MCP not available: skip deploy verification, note it

$ARGUMENTS
