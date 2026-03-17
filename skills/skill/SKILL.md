---
name: skill
description: "Use when creating new skills, managing existing ones, auditing skill quality, or checking overlap. The skill lifecycle manager."
argument-hint: "[list|create <name>|install <url>|remove <name>|info <name>|health|audit|overlap <name>]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion
---

# /skill

Manages the skill lifecycle: create, inspect, audit, remove. A rhino-os skill is a **measured folder** — prompt + scripts + references + assertions. Not just a markdown file.

## Skill folder structure

This skill is a **folder**. Read these on demand:

- `scripts/skill-scan.sh` — lists all skills with file counts, descriptions, last modified
- `scripts/skill-quality.sh` — grades each skill for completeness (gotchas, scripts, references, templates)
- `references/skill-anatomy.md` — what makes a good skill per Anthropic guide
- `reference.md` — output templates for all modes
- `audit-checklist.md` — 16-check quality audit matrix
- `gotchas.md` — real failure modes. **Read before creating or auditing.**

## Routing

| Input | Action |
|-------|--------|
| `list` or (none) | Run `skill-scan.sh` then show all skills with maturity + pass rates |
| `create <name>` | Evidence check → overlap check → create measured skill |
| `install <url>` | Install external skill, wire into measurement |
| `remove <name>` | Remove skill, mark killed in rhino.yml |
| `info <name>` | Show skill details, assertions, sub-scores |
| `health` | Run `skill-scan.sh` + `skill-quality.sh` → tier classification dashboard |
| `audit` | Full 16-check quality audit — spawn explorer agents in parallel batches |
| `overlap <name>` | Check proposed name against existing skills for route overlap |

## The protocol

### Step 1: Mechanical scan (always first)

Run `bash ${CLAUDE_SKILL_DIR}/scripts/skill-scan.sh` for the skill inventory. For `health` or `audit`, also run `bash ${CLAUDE_SKILL_DIR}/scripts/skill-quality.sh` for completeness grades.

### Step 2: Read gotchas

Read `gotchas.md` before creating or auditing.

### Step 3: Route-specific logic

- **create**: 3-question evidence gate → overlap check → write SKILL.md + wire into rhino.yml + seed assertions. See `references/skill-anatomy.md` for folder structure guidance.
- **audit**: Spawn explorer agents in parallel batches per `audit-checklist.md`. Write results to `.claude/cache/skill-audit.json`.
- **health**: Classify each skill into thick/thin/stub/dead tiers. Write to `.claude/cache/skill-health.json`.
- **info/list/overlap/install/remove**: See `reference.md` for output templates.

### Step 4: Output

Use templates from `reference.md`. Every output ends with 3 next commands.

## What you never do

- Create skills without evidence (3+ sessions of the pattern recurring)
- Create skills without overlap check
- Create skills without measurement wiring (feature + assertions + baseline)
- Classify "thick" without assertions — structure without measurement is theater
- Let unmeasured skills survive 30+ days without flagging

## If something breaks

- No beliefs.yml: all skills unmeasured, suggest `/onboard`
- No eval-cache.json: show structural health only, skip scores
- No rhino.yml features: show scan data only, no maturity/weight
- skill-health.json stale >7 days: regenerate from filesystem

$ARGUMENTS
