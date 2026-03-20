---
name: ship
description: "Use when work is measured and ready to ship — commits, releases, PRs, deploys, verification, rollback. Also triggers on 'deploy', 'push', 'ship it', 'create a PR', 'release'."
argument-hint: "[dry|hotfix|release [tag]|pr [base]|changelog|verify <url>|rollback|history]"
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, WebFetch, Agent
---

# /ship

Ship measured work. Pre-flight checks, git, GitHub releases, PRs, deploy, verification, rollback, and deployment history.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/pre-flight.sh` — runs pre-ship checks: score, assertions, secrets, eval freshness, deploy confidence. **Real gate — always run unless hotfix.**
- `scripts/release-notes.sh` — generates release notes from git log + roadmap.yml + eval-cache deltas. **Real utility for release mode.**
- `references/ship-checklist.md` — full pre-ship checklist with explanations (read before first ship)
- `references/release-types.md` — commit vs PR vs release vs deploy: when to use each
- `templates/release-notes.md` — release notes template for GitHub releases
- `templates/pr-body.md` — PR description template
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read this before shipping.**

## Routing

Parse `$ARGUMENTS`:

| Input | Mode | What happens |
|-------|------|-------------|
| (none) | Full flow | Pre-flight → commit → push → deploy → verify → log |
| `dry` or `check` | Pre-flight only | Run `scripts/pre-flight.sh`, show results, generate tasks for blockers |
| `hotfix` | Fast path | Skip score check, commit → push → deploy → log |
| `release [tag]` | GitHub release | Run `scripts/release-notes.sh` → `gh release create` |
| `pr [base]` | Pull request | Read `templates/pr-body.md` → `gh pr create` with roadmap-derived description |
| `changelog` | Changelog | Generate/update CHANGELOG.md from roadmap data |
| `verify <url>` | Post-deploy check | WebFetch URL → check status, content, response time |
| `rollback` | Revert | `git revert` last deploy → push → redeploy → investigation todo |
| `history` | Ship log | Read `${CLAUDE_PLUGIN_DATA}/ship-log.jsonl` directly, show recent entries + stats |

## State to read

Read `gotchas.md` first. Then read these in parallel — you reason from state, not script output:

**Ship readiness** — compute from state files:
- Read `.claude/cache/eval-cache.json` — per-feature scores, freshness (stale if >7d)
- Read `.claude/cache/deploy-history.json` — last deploy commit, score at deploy time, score delta
- Read `.claude/plans/roadmap.yml` — current version, thesis, evidence needed
- Read `.claude/plans/todos.yml` — any blocking todos tagged `source: /ship`
- Read `config/rhino.yml` — deploy target, features, mode
- Read `config/product-spec.yml` if exists — does this ship advance the spec's thesis?

**Ship history** — read directly instead of running ship-log.sh:
- Read `${CLAUDE_PLUGIN_DATA}/ship-log.jsonl` (fall back to `~/.claude/cache/ship-log.jsonl`)
- Parse JSONL: each line is `{timestamp, type, version, commit, score, features, target, pr, tag}`
- Compute: total ships, ships by type, last ship, score trend from last 5 entries with scores

**For release-type ships**, also check launch readiness (informational, non-blocking):
- `.claude/cache/market-context.json` — GTM strategy exists?
- `.claude/cache/customer-intel.json` — customer signal exists?
- `.claude/plans/roadmap.yml` — narrative freshness

**Deploy target detection**: Vercel (vercel.json or .vercel/), Netlify (netlify.toml), or manual. No deploy target detected = git operations only (commit, push, release, PR).

## How to ship

Read gotchas first. Then route based on mode:

**Pre-flight** (always, unless hotfix): Run `bash scripts/pre-flight.sh` — it checks score regression, assertions, secrets, eval freshness, deploy confidence. Parse the verdict line (SHIP/BLOCK/WARN). Every blocker and warning becomes a task.

**Execute the route:**
- **Full flow / hotfix**: stage → commit → push → deploy (auto-detect target) → verify → log
- **Release**: run `bash scripts/release-notes.sh [tag]` → read `templates/release-notes.md` → `gh release create`
- **PR**: read `templates/pr-body.md` → fill from git log + eval-cache + roadmap → `gh pr create`
- **Verify**: WebFetch URL → check status, content, response time → compare to last verification
- **Rollback**: read deploy history → `git revert` → push → redeploy → create investigation todo

**Log the ship** — after every deploy, release, or PR, append a JSONL entry directly to `${CLAUDE_PLUGIN_DATA}/ship-log.jsonl`:
```json
{"timestamp":"2026-03-20T...Z","type":"deploy|release|pr|hotfix|rollback","version":"v9.x","commit":"abc1234","score":85,"features":"scoring,commands","target":"vercel","pr":"","tag":""}
```

Run `bash scripts/pre-flight.sh` as verification after logging — confirm the ship didn't regress anything.

## Task generation — the path to shipability

**/ship's job is not just checking readiness. It's generating EVERY task needed to make the product shippable.** Every pre-flight blocker is a task. Every warning is a task. If /ship can't ship, the backlog should contain exactly what needs to happen first.

**For EVERY blocker or warning found in pre-flight, generate a task:**

### Pre-flight blocker tasks
- Score regressed since last ship → task: "Score dropped from [X] to [Y] — diagnose and fix before shipping"
- Block-severity assertion failing → task: "Assertion [id] blocking ship — fix [specific issue]"
- Secrets detected in staged files → task: "Secrets found in [file] — remove before shipping"
- Eval data stale >7d → task: "Eval data is [N]d old — run /eval before shipping"

### Pre-flight warning tasks
- Warn-severity assertions failing → task: "Assertion [id] failing (warn) — fix or acknowledge"
- Score flat (no improvement since last ship) → task: "Score hasn't improved — is this ship worth it?"
- Uncommitted changes → task: "Uncommitted changes — commit or stash before shipping"
- No changelog entry for this version → task: "Missing changelog — run /roadmap changelog"

### Release readiness tasks (for release-type ships)
- No GTM strategy → task: "No GTM plan — run /strategy gtm before release"
- No customer signal → task: "No customer intel — run /discover before announcing"
- Narrative stale → task: "Narrative not updated — run /roadmap narrative"
- No release notes → task: "No release notes — run /ship release to generate"

### Post-ship tasks (after successful ship)
- Verification not run → task: "Verify deployment at [url] via /ship verify"
- Related predictions not graded → task: "Ship predictions need grading — run /retro"

### Rollback tasks (after rollback)
- Investigation todo (mandatory) → task: "Investigate rollback cause — [what went wrong]"
- Related assertions that should have caught it → task: "Add assertion to prevent recurrence: [specific check]"
- Prediction about the shipped change → task: "Grade prediction about [change] — it was wrong"

**Write ALL tasks to /todo.** Tag with `source: /ship` and blocker type. Priority: blockers first, then warnings. No cap on task count.

## System integration

Reads: `.claude/cache/eval-cache.json`, `.claude/cache/deploy-history.json`, `.claude/plans/roadmap.yml`, `.claude/plans/todos.yml`, `config/rhino.yml`, `config/product-spec.yml`, `${CLAUDE_PLUGIN_DATA}/ship-log.jsonl`, `.claude/cache/market-context.json`, `.claude/cache/customer-intel.json`
Writes: `${CLAUDE_PLUGIN_DATA}/ship-log.jsonl`, `.claude/cache/deploy-history.json`, `.claude/plans/todos.yml`
Triggers: `/retro` (grade ship predictions), `/verify` (post-deploy check)
Triggered by: `/go` (work complete), `/plan` (ship readiness check), founder ("ship it", "deploy", "push")

## Agent usage

- **Agent (rhino-os:measurer)** — run score checks (cheapest model, haiku)

## Self-evaluation

/ship succeeded if:
- Pre-flight ran and verdict was SHIP (or WARN with founder acknowledgment)
- Ship log entry was appended to ship-log.jsonl
- Every blocker found has a corresponding task in /todo
- For deploys: verification ran against the live URL
- For rollbacks: an investigation todo was created

## What you never do

- Push without checking score (unless hotfix)
- Commit secrets (.env, credentials.json, API keys)
- Force push to main
- Deploy uncommitted changes
- Create releases with unproven claims
- Rollback without creating an investigation todo
- Ship past block-severity assertion failures

## Degraded modes

| Missing | Behavior |
|---------|----------|
| No deploy-history | Create empty, note "First tracked deployment" |
| No `gh` CLI | Skip release/PR routes: "`brew install gh` to enable" |
| No roadmap.yml | Generate release notes from git log only |
| No eval-cache | Warn: "Run `/eval` for full pre-flight data" |
| WebFetch fails | "URL unreachable. Check deploy status manually." |

## If something breaks

- pre-flight.sh exits with "no score": run `rhino score .` first — pre-flight needs a baseline score
- `gh release create` fails: check `gh auth status` — you may need to re-authenticate with `gh auth login`
- Push rejected on deploy: check branch protection rules, run `git pull --rebase` to sync with remote
- Rollback fails with merge conflicts: the revert may conflict with subsequent commits — resolve conflicts manually, then re-run `/ship verify` to confirm

$ARGUMENTS
