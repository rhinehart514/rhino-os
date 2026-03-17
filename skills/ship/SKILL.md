---
name: ship
description: "Use when work is measured and ready to ship — commits, releases, PRs, deploys, verification, rollback"
argument-hint: "[dry|hotfix|release [tag]|pr [base]|changelog|verify <url>|rollback|history]"
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, WebFetch, Agent
---

!cat .claude/cache/deploy-history.json 2>/dev/null | jq '{total: (.deploys | length), last: .deploys[-1]}' 2>/dev/null || echo "no deploy history"
!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score}) | from_entries' 2>/dev/null || echo "no eval cache"

# /ship

**When to use this:** You've built, measured, and the eval is green. Time to get it out the door. `/ship` handles the full pipeline: pre-flight checks, git, GitHub releases with auto-generated changelogs, PRs, deploy, verification, rollback, and deployment history.

**What connects here:**
- `/roadmap narrative` — the changelog and release notes come from proven theses
- `/roadmap changelog` — generates the user-facing changelog that /ship uses
- `/eval` — pre-flight assertion check
- `/go` — built the work being shipped
- `/retro` — grade predictions after a rollback

## Routing

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| (none) | Full flow: pre-flight → commit → push → deploy → verify → log |
| `dry` or `check` | Pre-flight only — score, assertions, secrets, eval scores, deploy confidence |
| `hotfix` | Skip score check, fast-path commit → push → deploy → log |
| `release [tag]` | Create GitHub release with auto-generated notes from roadmap |
| `pr [base]` | Open PR with roadmap-derived description |
| `changelog` | Generate/update CHANGELOG.md from roadmap data |
| `verify <url>` | Post-deploy verification against a live URL |
| `rollback` | Revert last deploy, push, redeploy, create investigation todo |
| `history` | Show deployment log with trends |

## State to read (parallel)

1. `rhino score .` — current score
2. `.claude/cache/eval-cache.json` — per-feature sub-scores + deltas
3. `config/rhino.yml` — features (weight), mode, deploy config
4. `.claude/plans/roadmap.yml` — current thesis + version (for release context)
5. `.claude/cache/narrative.yml` — current external narrative (for release notes)
6. `.claude/cache/changelog.md` — pre-generated changelog (if exists)
7. `git status` / `git log` — working tree state
8. `gh repo view` — GitHub repo info (for release/PR routes)
9. `.claude/cache/deploy-history.json` — deployment log (for confidence + rollback)

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| deploy-history | `.claude/cache/deploy-history.json` | R+W | Deployment log |
| eval-cache | `.claude/cache/eval-cache.json` | R | Pre-flight sub-scores |
| score-cache | `.claude/cache/score-cache.json` | R | Current score |
| rhino.yml | `config/rhino.yml` | R | Features, weight, deploy config |
| roadmap.yml | `.claude/plans/roadmap.yml` | R | Thesis, version |
| narrative | `.claude/cache/narrative.yml` | R | Release notes |
| changelog | `.claude/cache/changelog.md` | R+W | Version changelog |
| last-ship | `~/.claude/cache/last-ship.yml` | W | Cross-command artifact |

---

## Deploy History Protocol

After every deploy (full flow, hotfix, or rollback), append to `.claude/cache/deploy-history.json`:

```json
{
  "deploys": [
    {
      "date": "2026-03-16T15:00:00",
      "commit": "a1b2c3d",
      "type": "full|hotfix|rollback",
      "score_before": 92,
      "score_after": 95,
      "target": "vercel|netlify|manual",
      "verification": "pass|fail|skipped",
      "verification_details": "200 OK, key content present, 320ms",
      "rolled_back": false,
      "features_affected": ["scoring", "commands"]
    }
  ]
}
```

Before every ship, READ deploy-history.json:
- Compute deploy confidence: `(assertion_pass_rate x last_3_deploy_success_rate x 100)%`
  - `assertion_pass_rate` = PASS / TOTAL from `rhino eval .`
  - `last_3_deploy_success_rate` = deploys not rolled back / last 3 deploys
- If last deploy was rolled back, warn: "Last deploy was rolled back. Extra caution."
- If no deploy-history.json exists, create with empty deploys array, note "First tracked deployment"

---

## The Full Flow

### 1. Pre-flight

- Run `rhino score .` — assertion regression = stop and ask
- Check `git status` — flag untracked files, refuse .env/credentials
- Check `git diff --stat` — flag large changesets (>20 files)
- Check block-severity assertions — failing = hard stop (see Anti-rationalization)
- Check warn-severity assertions — failing = explicit acknowledge required
- Check feature eval score — features scoring <50 = warn
- Check dependency eval scores — upstream deps scoring <50 = warn
- Compute product completion % and version completion %
- Read deploy-history.json — compute deploy confidence
- If deploy confidence <60%: require explicit confirmation via AskUserQuestion

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
- Check response code (200 expected), measure load time
- Check key content is present (title, headline, or identifying text)
- If deploy API available, poll for completion
- Log verification result to deploy-history.json

### 6. Log

- Append deploy entry to `.claude/cache/deploy-history.json`
- Write `~/.claude/cache/last-ship.yml` with commit, score, version, timestamp

---

## `verify <url>` — Post-deploy verification

Hit the deployed URL and run checks against it. Use when you want to confirm a deploy is healthy without shipping new code.

**Steps:**
1. Parse URL from `$ARGUMENTS` — if no URL, check `config/rhino.yml` under `deploy.url`, then AskUserQuestion
2. WebFetch the URL — record status code, response time
3. Check response code: 200 = pass, 4xx/5xx = fail
4. Check page content for key indicators:
   - Title tag present and non-empty
   - Known headline or product name appears in body
   - No error page markers ("500 Internal Server Error", "Application Error", "Not Found")
5. If assertions reference deployed URLs (rare), run them
6. Compare against last successful verification in deploy-history.json:
   - Response time regression (>2x slower) = warn
   - Missing content that was present before = fail
7. Compute updated deploy confidence
8. Log verification result — update the most recent deploy-history entry if this is a post-deploy verify, or log as a standalone check

**Failure handling:**
- URL unreachable (timeout, DNS failure): "Deploy target unreachable. Check DNS/deploy status."
- SSL error: "SSL certificate issue. Check deploy configuration."
- 3xx redirect chain: follow up to 3 redirects, warn if more

---

## `rollback` — Revert last deploy

When something broke in production. Fast path: revert, push, redeploy, investigate.

**Steps:**
1. Read `.claude/cache/deploy-history.json` — find last deploy entry
2. If no deploy-history.json: "No deployment history. Can't determine what to rollback. Use `git revert HEAD` manually."
3. Get the commit hash from last deploy entry
4. `git revert [commit] --no-edit` — create a revert commit
5. Push: `git push origin [branch]`
6. If deploy target detected: trigger redeploy (Vercel MCP or manual)
7. Mark last deploy entry as `rolled_back: true` in deploy-history.json
8. Append new deploy entry with `type: "rollback"`
9. **MANDATORY**: create investigation todo via SendMessage:
   ```
   todo:add "[feature]: investigate rollback — [what broke]" feature:[name] source:/ship rollback
   ```
10. AskUserQuestion: "What broke? (This goes in deploy-history for the record.)" — save response as `verification_details` on the rollback entry

**Rollback of a rollback:**
- If the last deploy was already a rollback, warn: "Last deploy was already a rollback. You may be oscillating. Run `/eval` first."

---

## `history` — Deployment log

Show the deployment record with trends.

**Steps:**
1. Read `.claude/cache/deploy-history.json`
2. If no file: "No deployment history yet. Ship something first."
3. Compute:
   - Total deploys
   - Success rate: deploys not rolled back / total
   - Average score delta across successful deploys
   - Rollback rate for last 5 deploys
   - Average verification time (if tracked)
4. Show each deploy: date, commit (short hash), score before/after, target, verification status, rollback status
5. Highlight trends:
   - Improving scores across deploys = good
   - Increasing rollback rate = "Deployment stability declining. Consider more pre-flight checks."
   - Frequent hotfixes = "High hotfix rate. Consider `/eval` before shipping."

---

## GitHub Integration

### `release [tag]` — create GitHub release

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
- [user-facing change derived from feature eval score improvement]
- [user-facing change]

### What we learned
- [Key Known Pattern confirmed during this version]

### Known limitations
- [Honest gap from positioning.yml — what we haven't proven yet]
```

**Anti-slop**: same ban list as `/roadmap narrative`. Every bullet traces to evidence.

### `pr [base]` — open pull request

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
- [feature] (eval:[score]) — [sub-score change if measurable]

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

### `changelog` — generate CHANGELOG.md

Reads roadmap.yml and generates a proper CHANGELOG.md at the repo root. Uses the same logic as `/roadmap changelog` but writes to the file instead of cache.

**Steps:**
1. Read `.claude/cache/changelog.md` if it exists (pre-generated by /roadmap changelog)
2. If not, generate from roadmap.yml (same logic as /roadmap changelog route)
3. Write to `CHANGELOG.md` at repo root
4. Stage and commit: `docs: update changelog`

---

## Anti-rationalization checks

These fire during pre-flight and before any deploy action. They are not suggestions.

| Excuse | Check | Response |
|--------|-------|----------|
| "Ship with failing assertions" | Block-severity assertions failing | **Hard stop.** "Block-severity assertions are failing. Fix them or downgrade severity. Shipping past failures doesn't make them go away." |
| "Ship with warnings" | Warn-severity assertions failing | Require explicit acknowledge via AskUserQuestion: "[N] warn-severity assertions failing. Ship anyway?" |
| "Ship low-scoring features" | Any affected feature with eval < 50 | Flag: "Feature [name] scores below 50. Ship anyway only if this is a hotfix for something else." |
| "Rollback without investigation" | Rollback route triggered | Every rollback MUST produce a todo with root cause. "What broke and why?" is not optional. |
| "Deploy confidence below 60%" | `(assertion_pass_rate x last_3_success_rate x 100) < 60` | Require explicit confirmation: "Deploy confidence is [N]%. Are you sure?" |
| "Frequent rollbacks" | 2+ of last 5 deploys were rolled back | Flag: "Rollback rate is high ([N]/5). Consider `/eval` before shipping." |
| "Score dropped since last deploy" | Current score < last deploy's score_after | Warn: "Score dropped from [last] to [current] since last deploy. Investigate before shipping." |

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
  deploy confidence: **87%** ████████████████░░░░ (assertions 90% x deploys 97%)

  ⎯⎯ features affected ⎯⎯

  scoring  ████████████████████ w:5  working  90 ✓
  commands ██████████████████░░ w:5  working  85 ✓
  learning ████████░░░░░░░░░░░░ w:4  building 40 ⚠

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
  deploy confidence: **91%** ██████████████████░░

/ship verify [url]  confirm it's live
/ship history       deployment log
/roadmap narrative  update the external story
/ship release v8.1  create GitHub release
/eval               verify assertions held
```

### Release created:
```
◆ shipped release — v8.1

  tag: v8.1
  title: "v8.1: Eval scoring engine upgrade"
  url: https://github.com/[owner]/[repo]/releases/tag/v8.1

  ▾ release notes (published)
    ## Eval scoring engine upgrade
    Multi-sample median scoring, decomposed sub-scores (delivery/craft/viability),
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

### Verify output:
```
◆ ship verify — [url]

  status: **[pass/fail]**

  ⎯⎯ response ⎯⎯

  status:    200 OK
  time:      320ms  ██████░░░░░░░░░░░░░░ (target <500ms)
  ssl:       valid, expires 2026-12-01

  ⎯⎯ content checks ⎯⎯

  ✓ title tag present: "[page title]"
  ✓ headline found: "[product name or heading]"
  ✓ no error markers (500, Application Error, Not Found)
  ✗ assertion [id] fails on deployed version

  ⎯⎯ assertions (live) ⎯⎯

  ✓ 56/63 passing on deployed version
  ✗ deploy-smoke — expected 200, got 503
  ⚠ response time regression: 320ms vs 180ms last deploy (+78%)

  deploy confidence: **[N]%** ████████████████░░░░ ([trend])

/ship rollback     revert if broken
/eval              full assertion check
/go [feature]      fix the failure
```

### Rollback output:
```
◆ ship rollback

  reverted: [commit hash] → [previous hash]
  pushed: origin/[branch]
  deploy: [rebuilding/manual]

  severity: ██████████████████░░ HIGH — assertion regression in production

  ⚠ investigation required
  · what broke: [from deploy-history]
  · affected features: [feature list with weights]
  · todo created: "[feature]: investigate rollback — [reason]"

/eval              check current state
/retro             grade the prediction
/go [feature]      fix the root cause
```

### History output:
```
◆ ship history — [N] deploys

  success rate: **[N]%** ████████████████░░░░ ([M]/[N])
  avg score delta: +[N]
  rollback rate (last 5): [N]/5

  ⎯⎯ recent deploys ⎯⎯

  date        commit   score   target  status
  2026-03-16  a1b2c3d  92→95   vercel  ✓ verified   320ms
  2026-03-15  d4e5f6g  88→92   vercel  ✓ verified   280ms
  2026-03-14  g7h8i9j  85→82   vercel  ✗ rolled back — assertion regression

  ⎯⎯ trends ⎯⎯

  scores:     ██████████████████░░ improving across last 5 deploys
  stability:  ████████████████████ no rollbacks in last 3 deploys
  confidence: 72% → 87% → 91% ████████████████████ trending up

/ship              deploy now
/ship dry          pre-flight check
/eval              verify assertions
```

---

## Tool usage

**WebFetch** in verify route:
1. Fetch the deployed URL — record HTTP status code and measure response time (start/end timestamp delta)
2. Check response body for key heading text (product name, title tag, known headline)
3. Check response body for error markers ("500 Internal Server Error", "Application Error", "Not Found")
4. Compare response time against last successful verification in deploy-history.json — flag >2x regression

**Vercel MCP tools** when available (detect via `vercel.json` or Vercel project):
1. After deploy: `mcp__claude_ai_Vercel__get_deployment` — poll deployment status (building/ready/error), show real state in output
2. On verify or post-deploy: `mcp__claude_ai_Vercel__get_runtime_logs` — check for runtime errors, surface first error if any
3. On deploy failure: `mcp__claude_ai_Vercel__get_deployment_build_logs` — show build error excerpt

**Bash** for git operations, `rhino score .`, and `rhino eval . --no-generative` for pre-flight checks.

---

## What you never do

- Push without checking score (unless hotfix)
- Commit secrets (.env, credentials.json, API keys)
- Force push to main
- Deploy uncommitted changes
- Create a release with unproven claims in the notes
- Write PR descriptions that don't map to features or evidence
- Use slop words in release notes (same ban list as /roadmap narrative)
- Rollback without creating an investigation todo
- Ship past block-severity assertion failures
- Ignore deploy confidence warnings

---

## Degraded modes

| Missing | Behavior |
|---------|----------|
| No deploy-history.json | Create with empty deploys array, note "First tracked deployment" |
| Vercel MCP unavailable | "Code pushed. Set up deploy target or verify manually at [URL]" |
| `gh` CLI not installed | Skip release/PR routes entirely, show: "`brew install gh` to enable releases and PRs" |
| No verification URL configured | AskUserQuestion for one, save to rhino.yml under `deploy.url` |
| No narrative.yml | Generate release notes from git log + roadmap.yml only |
| No changelog.md | Generate inline from roadmap.yml |
| No roadmap.yml | Generate release notes from git log only (fully degraded mode) |
| No eval-cache.json | Skip sub-score display, warn: "Run `/eval` for full pre-flight data" |
| WebFetch fails on verify | "Verification failed — URL unreachable. Check deploy status manually." |
| No git repo | Tell the founder |
| Deploy target unreachable | Retry once after 5s, then report failure with status details |

---

## If something breaks

- Score check fails: show delta, AskUserQuestion
- Push fails: suggest `git pull --rebase`
- Deploy fails: show error, don't retry blindly, log to deploy-history with `verification: "fail"`
- `gh` not installed: "GitHub CLI required for releases/PRs. `brew install gh`"
- `git revert` conflicts (rollback): show conflict, AskUserQuestion for resolution approach
- deploy-history.json malformed: back up to `.claude/cache/deploy-history.json.bak`, create fresh

$ARGUMENTS
