---
name: roadmap
description: "Use when tracking version theses, checking progress, generating release narrative, or reviewing project history"
argument-hint: "[next|bump|ideate|narrative|changelog|positioning|add|done|new|v<X.Y>]"
allowed-tools: Read, Bash, Grep, Edit, AskUserQuestion, WebSearch, Agent
---

# /roadmap

Two jobs. One command.

**Internal**: Versions are theses, not releases. Each one asks a question. You test it. It's proven, disproven, or abandoned. Future versions emerge from what you learn, not what you imagine.

**External**: Every proven thesis is a story worth telling. The roadmap is the source of truth for marketing copy, changelogs, positioning, and the "why now" narrative.

## Skill folder structure

This skill is a **folder**, not just this file. Read these on demand:

- `scripts/version-progress.sh` — current version thesis, evidence status, completion %
- `scripts/version-history.sh` — all past versions with thesis/status — the project timeline
- `scripts/evidence-tracker.sh` — for each evidence item in current version, checks proven/disproven/open
- `references/version-guide.md` — major/minor/patch rules, when to bump, thesis design
- `references/changelog-guide.md` — how to write good changelogs, what to include
- `templates/roadmap-template.yml` — template for a version entry
- `templates/changelog-template.md` — changelog format
- `reference.md` — output formatting templates and version completion cycle
- `gotchas.md` — real failure modes. **Read before generating output.**

## Mode awareness

Read `project.mode` from `config/rhino.yml`:
- **build mode** (default): no shipping pressure. The roadmap is a lab notebook, not a release schedule.
- **ship mode**: full pipeline. Shipping language, deadlines, deploy verification.

## State to read (parallel)

Every route reads these first:
1. `.claude/plans/roadmap.yml` — theses, evidence, version history
2. `config/rhino.yml` — features (weight/depends_on), mode, value hypothesis
3. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — predictions mentioning the thesis
4. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known/uncertain/unknown/dead patterns
5. `git log --oneline -20` — recent work
6. `.claude/plans/strategy.yml` — bottleneck, stage
7. `.claude/cache/eval-cache.json` — per-feature sub-scores
8. `.claude/cache/narrative.yml` — current external narrative (if exists)

For the full state source list, see [STATE_MANIFEST.md](../STATE_MANIFEST.md).

## The Reflection (always comes first)

Before showing the version list, write 2-3 sentences of honest reflection from specific data:

| Dimension | Source | What to say |
|-----------|--------|-------------|
| **Velocity** | Git log + evidence status | "Evidence proving at N/week" or "Nothing moved in N days" |
| **Learning** | predictions.tsv accuracy | "Thesis predictions N% accurate" |
| **Honesty** | Evidence status vs actual | Any `partial` that should be `todo`? Any `proven` without evidence? |
| **Shape** | Cross-version pattern | Recurring themes, what keeps being hard |

## Routing

Parse `$ARGUMENTS`:

**If ambiguous:** exact route keyword wins → version string match → free-form topic. Never ask "did you mean?"

### No arguments → reflection + roadmap
Run `scripts/version-progress.sh` and `scripts/version-history.sh`. Write reflection, show version list, one forward-looking thought.

### `next` → diagnose what's most provable
Run `scripts/evidence-tracker.sh`. For each evidence item, map to features, score provability (`ready`/`close`/`blocked`/`unknown`). Recommend the first experiment.

### `ideate` → brainstorm future theses
Check 4 sources: proven evidence patterns, dead ends, unknown territory, gap between proven and aspirational. Generate 3-4 candidate theses with question, why now, evidence items, and disproven value. Present with AskUserQuestion.

### `narrative` → generate the external story
Derive from proven evidence. Generate: one-liner, paragraph, positioning statement. Every claim traces to evidence. Present via AskUserQuestion. Write to `.claude/cache/narrative.yml`.

### `changelog` → version-by-version external changelog
Read `references/changelog-guide.md` and `templates/changelog-template.md`. Translate internal language to external. Write to `.claude/cache/changelog.md`.

### `positioning` → competitive positioning check
Proven claims, honest gaps, differentiators, where behind. Present via AskUserQuestion. Write to `.claude/cache/positioning.yml`.

### Version string (e.g., `v7.0`) → version archaeology
Run `scripts/version-history.sh v7.0`. Show thesis, what it proved, what it taught, how it shaped what came after.

### `bump` → prove/graduate with auto-synthesis
Read `references/version-guide.md` for tier rules. Auto-detect tier (thesis changed → major, new features/evidence → minor, fixes → patch). Auto-synthesize summary from evidence + predictions + git log. Present via AskUserQuestion. Transfer thesis → Known Pattern in experiment-learnings.md.

### `add [version] [milestone]` → add evidence needed
### `done [milestone-id]` → mark evidence as proven
### `new [version] [thesis]` → create a new thesis

Use `templates/roadmap-template.yml` when creating new version entries.

## Thesis Health Monitor

Run on every invocation:
- **Contradiction**: >50% thesis predictions wrong → surface warning, suggest `/roadmap ideate`
- **Stall**: no evidence movement in >14 days → diagnose why
- **Disproven**: check `if_disproven:` field, write to experiment-learnings.md as Dead End

When showing full roadmap, detect: recurring hard evidence, acceleration/deceleration, thesis evolution arc. For output templates, version completion, narrative anti-slop rules, see [reference.md](reference.md).

## Task generation — the path to thesis completion

**/roadmap's job is not just tracking theses. It's generating EVERY task needed to prove or disprove the current thesis.** Evidence items that haven't moved are tasks. Stalled theses are tasks. Every gap between "what we need to prove" and "what we've proven" is a task.

**For EVERY evidence gap found, generate the complete task list:**

### Evidence tasks (from evidence-tracker.sh)
- Each evidence item marked `todo` → task: "Evidence '[X]' unproven — design experiment to test"
- Each evidence item marked `partial` → task: "Evidence '[X]' partially proven — complete the proof"
- Each evidence item unchanged >14d → task: "Evidence '[X]' hasn't moved in [N]d — prove, disprove, or abandon"
- Each evidence item with no related feature → task: "Evidence '[X]' has no feature supporting it — create feature or rethink evidence"

### Thesis health tasks
- Thesis stalled (no evidence movement >14d) → task: "Thesis stalled for [N]d — run /research to unblock or /roadmap ideate to pivot"
- >50% thesis predictions wrong → task: "Thesis contradicted by evidence — run /strategy honest to reassess"
- Thesis evidence items >5 → task: "Thesis too broad ([N] items) — narrow to 3-4 most critical"
- Disproven evidence → task: "Evidence '[X]' disproved — update if_disproven action, write to dead ends"

### Version completion tasks
- Version completion <30% after 14d → task: "Version [X] barely started — is the thesis right?"
- Version completion >80% → task: "Version [X] nearly complete — prepare bump via /roadmap bump"
- Features tagged to version but not scored → task: "Feature [X] tagged to [version] but never evaluated — run /eval"

### Narrative tasks
- narrative.yml stale >14d → task: "External narrative hasn't been updated — run /roadmap narrative"
- Proven evidence not reflected in narrative → task: "Evidence '[X]' proven but not in narrative — update via /roadmap narrative"
- Changelog not updated for recent version → task: "No changelog for [version] — run /roadmap changelog"

### Cross-version tasks
- Recurring hard evidence across versions → task: "Pattern '[X]' recurs across versions — promote to Known Pattern"
- Previous version's unproven evidence still relevant → task: "Evidence '[X]' from [old version] still unproven — carry forward or kill"

**Write ALL tasks to /todo.** Tag with `source: /roadmap`, version, and evidence item. Priority: evidence items on the current thesis first, then stalled items.

**There is no cap on task count.** A thesis with 5 evidence items might generate 10+ tasks. Generate all of them.

After writing tasks, show: "Generated N tasks for version [X]. [M] evidence items need attention. Thesis completion: [%]."

## Agent usage — `rhino-os:explorer` for thesis research when evidence sources are insufficient.

## What you never do
- Auto-bump without asking — graduating a thesis is a founder decision
- Create versions with more than 5 evidence items — thesis is too broad
- Invent future versions without evidence — only `/roadmap ideate` creates them
- Write a reflection that sounds like a status update — it should sound like thinking
- In build mode: mention shipping, deploying, releasing, or deadlines
- Mark evidence as `proven` without citing specific evidence
- Ignore disproven evidence — it's the most valuable signal

## If something breaks
- No roadmap.yml → create from git log. Missing ID → list available. Missing predictions → skip, note it.

$ARGUMENTS
