---
name: copy
description: "Use when you need product copy — landing pages, pitch, onboarding text, release notes. Positioning-aware, customer-grounded, design-system-aligned."
argument-hint: "[landing|pitch|outreach|release|onboard|empty-states|\"write copy for...\"]"
allowed-tools: Read, Bash, Grep, Glob, WebSearch, WebFetch, Agent, AskUserQuestion
---

# /copy

Positioning-aware product copy. Names a specific person, states what changes for them, differentiates from every alternative. Reads market context, customer signal, and design system to produce copy grounded in evidence, not adjectives.

## Skill folder structure

This skill is a **folder**. Read these on demand:

- `scripts/slop-check.sh <file>` — mechanical slop word + quality detector (pipe text or pass file)
- `scripts/copy-log.sh` — persistent copy history (add, list, stats). Uses `${CLAUDE_PLUGIN_DATA}`
- `scripts/copy-diff.sh [type]` — shows copy iteration history
- `references/voice-guide.md` — how to write in the product's voice, not generic marketing
- `references/slop-words.md` — the banned word list with why each is banned
- `references/positioning-frameworks.md` — category creation, competitor wedge framing
- `references/copy-patterns.md` — headline formulas, CTA patterns, voice guidelines
- `templates/landing-page.md` — hero + problem + solution + proof + CTA structure
- `templates/release-announcement.md` — release announcement template (user-facing, not changelog)
- `templates/pitch-narrative.md` — elevator/tweet/paragraph narrative
- `templates/cold-outreach.md` — email + DM templates
- `templates/release-notes.md` — user-facing changelog structure
- `reference.md` — output templates for all modes
- `gotchas.md` — LLM copy failure modes. **Read before generating any copy.**

## Routing

| Input | Mode |
|-------|------|
| (none) | Ask what copy is needed via AskUserQuestion |
| `landing` | Landing page: hero, problem, solution, CTA |
| `pitch` | Elevator (10s), tweet (280c), paragraph (50w) |
| `outreach` | Cold email/DM with specific targeting |
| `release` | Release notes from roadmap data |
| `onboard` | First-screen + success moment copy |
| `empty-states` | Copy for every empty state in the product |
| `[any text]` | Custom copy brief |

## The protocol

### Step 1: Read state (parallel)

Read: `config/rhino.yml` (user, features), `.claude/cache/market-context.json`, `.claude/cache/customer-intel.json`, `.claude/cache/narrative.yml`, `.claude/design-system.md`.

### Step 2: Read gotchas + references

Read `gotchas.md`. Then read `references/voice-guide.md` and `references/slop-words.md`. For landing/pitch: also read `references/positioning-frameworks.md`.

### Step 3: Spawn copywriter agent

```
Agent(subagent_type: "rhino-os:copywriter", prompt: "[copy brief with all context from state reads]")
```

For `landing` and `pitch`, also spawn market-analyst in background for competitive messaging.

### Step 4: Quality gate (mandatory)

Before presenting ANY copy, check:
1. Names a person? (not "developers" — a specific situation)
2. States what changes? (not "improve your workflow" — tangible outcome)
3. Differentiates? (names a specific alternative)
4. Slop-free? Run `echo "[copy]" | bash ${CLAUDE_SKILL_DIR}/scripts/slop-check.sh`

Any failure = rewrite before presenting.

### Step 5: Present and log

Present via AskUserQuestion. Log via `bash ${CLAUDE_SKILL_DIR}/scripts/copy-log.sh add "[type]" "[headline]" "[preview]"`.

## Output format

See `reference.md` for mode-specific templates. Every output ends with:

```
/copy [other mode]   different copy type
/taste               check if the copy works visually
/ship release        use this copy in release notes
```

## What you never do

- Write copy without reading market context — unpositioned copy is generic copy
- Use slop words — the ban list is absolute (see `references/slop-words.md`)
- Claim features that score <50 — only claim what's delivered
- Skip the quality gate — every piece of copy gets checked
- Generate copy for a product with no user defined — flag and help define

## If something breaks

- No value.user in rhino.yml: "Who is this for? Run `/product user` first."
- No market-context.json: degrade to un-positioned copy, flag it
- No customer-intel.json: use founder language from rhino.yml
- No design-system.md: use neutral tone, suggest creating one

$ARGUMENTS
