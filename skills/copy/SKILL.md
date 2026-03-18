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

## Task generation — the path to great copy everywhere

**/copy's job is not just writing. It's generating EVERY task needed to eliminate bad copy across the product.** Slop words, missing copy, positioning gaps, inconsistent voice — all are tasks. Every surface where users read text is /copy's responsibility.

**For EVERY copy gap found, generate a task:**

### Slop tasks (from slop-check.sh)
- Each file with slop words → task: "File [X] contains slop words ([list]) — rewrite"
- Each landing page with generic copy → task: "Landing page uses generic copy — rewrite with /copy landing"
- Each README with slop → task: "README contains [N] slop words — rewrite hero section"
- Each empty-state with no copy → task: "Empty state at [location] has no guidance — write copy"

### Positioning tasks
- No positioning statement → task: "No positioning — run /copy pitch to define"
- Positioning doesn't name a person → task: "Positioning says 'developers' not a person — rewrite with /product user"
- Positioning doesn't differentiate → task: "Positioning doesn't name alternatives — rewrite with competitor awareness"
- Positioning claims undelivered features → task: "Copy claims [X] but feature scores [Y] — fix code or fix claim"

### Voice consistency tasks
- No voice-guide.md → task: "No voice guide — create from existing copy patterns"
- Different voice across pages → task: "Voice inconsistent between [page A] and [page B] — align"
- Marketing voice doesn't match product voice → task: "Landing page tone differs from in-app — harmonize"

### Coverage tasks
- No landing page copy → task: "No landing page — run /copy landing"
- No README hero section → task: "README missing hero section — run /copy landing for content"
- No onboarding copy → task: "No first-screen copy — run /copy onboard"
- No empty-state copy → task: "Empty states have no guidance — run /copy empty-states"
- No release notes for current version → task: "No release notes — run /copy release"
- No pitch (elevator/tweet/paragraph) → task: "No pitch copy — run /copy pitch"

### Quality tasks
- Copy that fails the quality gate → task: "Copy at [location] fails gate: [which check] — rewrite"
- Copy not grounded in customer language → task: "Copy uses founder language not customer language — rewrite with customer-intel.json"
- Copy not design-system aligned → task: "Copy doesn't match design system tone — align"

**Write ALL tasks to /todo.** Tag with `source: /copy` and type (slop/positioning/voice/coverage/quality). Priority: slop on user-facing surfaces first.

**There is no cap on task count.** A product with no copy strategy might need 20+ tasks. Generate all of them.

After copy generation, show: "Generated N copy tasks. [M] slop issues, [X] positioning gaps, [Y] coverage gaps."

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
