---
name: ship
description: "Use when work is measured and ready to ship — commits, releases, PRs, deploys, verification, rollback"
argument-hint: "[dry|hotfix|release [tag]|pr [base]|changelog|verify <url>|rollback|history]"
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, WebFetch, Agent
---

!cat .claude/cache/deploy-history.json 2>/dev/null | jq '{total: (.deploys | length), last: .deploys[-1]}' 2>/dev/null || echo "no deploy history"
!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score}) | from_entries' 2>/dev/null || echo "no eval cache"

# /ship

Ship measured work. Pre-flight checks, git, GitHub releases, PRs, deploy, verification, rollback, and deployment history.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/pre-flight.sh` — runs pre-ship checks: score, assertions, secrets, eval freshness, changelog, deploy confidence
- `scripts/ship-log.sh` — persistent shipping history in `${CLAUDE_PLUGIN_DATA}` (add, list, stats, last)
- `scripts/release-notes.sh` — generates release notes from git log + roadmap.yml + eval-cache deltas
- `references/ship-checklist.md` — full pre-ship checklist with explanations (read before first ship)
- `references/release-types.md` — commit vs PR vs release vs deploy: when to use each
- `templates/release-notes.md` — release notes template for GitHub releases
- `templates/pr-body.md` — PR description template
- `reference.md` — output formatting templates
- `gotchas.md` — real failure modes. **Read this before shipping.**

## Routing

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| (none) | Full flow: pre-flight → commit → push → deploy → verify → log |
| `dry` or `check` | Pre-flight only — run `scripts/pre-flight.sh`, show results |
| `hotfix` | Skip score check, fast-path commit → push → deploy → log |
| `release [tag]` | Run `scripts/release-notes.sh` → create GitHub release |
| `pr [base]` | Read `templates/pr-body.md` → open PR with roadmap-derived description |
| `changelog` | Generate/update CHANGELOG.md from roadmap data |
| `verify <url>` | Post-deploy verification against a live URL |
| `rollback` | Revert last deploy, push, redeploy, create investigation todo |
| `history` | Run `scripts/ship-log.sh list` — deployment log with trends |

## The protocol

### Step 1: Read gotchas

Read `gotchas.md` before any ship action. Every gotcha is a failure mode from a real session.

### Step 2: Pre-flight (always, unless hotfix)

Run `scripts/pre-flight.sh` via Bash. It checks score, assertions, secrets, eval freshness, deploy confidence. Output is structured — parse the verdict line (SHIP/BLOCK/WARN).

For `release` type ships, also check launch readiness: GTM strategy, customer signal, narrative freshness. These are informational only — they don't block.

### Step 3: Execute the route

- **Full flow / hotfix**: stage → commit → push → deploy (detect Vercel/Netlify/manual) → verify → log
- **Release**: run `scripts/release-notes.sh` → read `templates/release-notes.md` → `gh release create`
- **PR**: read `templates/pr-body.md` → fill from git log + eval-cache + roadmap → `gh pr create`
- **Verify**: WebFetch URL → check status, content, response time → compare to last verification
- **Rollback**: read deploy history → `git revert` → push → redeploy → create investigation todo → log

### Step 4: Log the ship

Run `scripts/ship-log.sh add` after every deploy, release, or PR. This persists across sessions in `${CLAUDE_PLUGIN_DATA}`.

## Connections

- `/roadmap narrative` — changelog and release notes source
- `/eval` — pre-flight assertion check
- `/go` — built the work being shipped
- `/retro` — grade predictions after rollback

## Agent usage

- **Agent (rhino-os:measurer)** — run score checks (cheapest model)

## State artifacts

| Artifact | Path | Purpose |
|----------|------|---------|
| deploy-history | `.claude/cache/deploy-history.json` | Local deployment log |
| ship-log | `${CLAUDE_PLUGIN_DATA}/ship-log.jsonl` | Persistent cross-session shipping history |
| eval-cache | `.claude/cache/eval-cache.json` | Pre-flight sub-scores |
| roadmap | `.claude/plans/roadmap.yml` | Thesis, version for release context |

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

$ARGUMENTS
