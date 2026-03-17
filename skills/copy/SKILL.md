---
name: copy
description: "Use when you need product copy — landing pages, pitch, onboarding text, release notes. Positioning-aware, customer-grounded, design-system-aligned."
argument-hint: "[landing|pitch|outreach|release|onboard|empty-states|\"write copy for...\"]"
allowed-tools: Read, Bash, Grep, Glob, WebSearch, WebFetch, Agent, AskUserQuestion
---

!cat .claude/cache/narrative.yml 2>/dev/null | head -5 || echo "no narrative"
!cat config/rhino.yml 2>/dev/null | grep -A2 'user:' || echo "no user defined"

# /copy

**Positioning-aware product copy.** Not "write me marketing text." Copy that names a specific person, states what changes for them, and differentiates from every alternative. Reads your market context, customer signal, and design system to produce copy grounded in evidence, not adjectives.

## Skill contents

This skill is a folder with quality-checking scripts, reference data, and copy templates:

```
skills/copy/
  SKILL.md                            — this file (orchestrator)
  reference.md                        — output templates for all modes
  scripts/
    slop-check.sh <file>              — mechanical slop word + quality detector (pipe text or pass file)
    copy-diff.sh [type]               — shows copy iteration history
  references/
    positioning-frameworks.md         — category creation, competitor wedge, "only for..." framing
    copy-patterns.md                  — headline formulas, CTA patterns, voice guidelines, social proof
  templates/
    landing-page.md                   — hero + problem + solution + proof + CTA structure
    pitch-narrative.md                — elevator/tweet/paragraph/deck narrative
    cold-outreach.md                  — email + DM templates with anti-pattern list
    release-notes.md                  — user-facing changelog structure
  gotchas.md                          — LLM copy failure modes (adjective addiction, generic value props, etc.)
```

**Use the scripts** to mechanically check copy quality before presenting. Use the references for positioning and pattern context. Use the templates as structural starting points. Read gotchas before generating to avoid LLM copy traps.

## Memory

After every `/copy` run, append to `.claude/cache/copy-history.json`:

```json
{
  "entries": [
    {
      "date": "2026-03-17",
      "type": "landing",
      "headline": "Your product gets better every session",
      "preview": "first 60 chars of primary copy...",
      "quality_gate": {"names_person": true, "states_change": true, "differentiates": true, "slop_free": true},
      "user_from": "value.user field at time of generation"
    }
  ]
}
```

On subsequent runs, read history to:
- Avoid repeating the same headline formulas
- Track how positioning language has evolved
- Show the founder iteration count by copy type via `bash ${CLAUDE_SKILL_DIR}/scripts/copy-diff.sh`

**When to use this:**

| Need | Command |
|------|---------|
| Landing page copy | `/copy landing` |
| Pitch (elevator, tweet, paragraph) | `/copy pitch` |
| Cold outreach (email, DM) | `/copy outreach` |
| Release notes | `/copy release` |
| Onboarding text | `/copy onboard` |
| Empty state copy | `/copy empty-states` |
| Any user-facing text | `/copy [describe what you need]` |

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) | Ask what copy is needed (AskUserQuestion) |
| `landing` | Landing page: hero, problem, solution, CTA |
| `pitch` | Elevator (10s), tweet (280c), paragraph (50w) |
| `outreach` | Cold email/DM with specific targeting |
| `release` | Release notes from roadmap data |
| `onboard` | First-screen + success moment copy |
| `empty-states` | Copy for every empty state in the product |
| `[any text]` | Custom copy brief |

## State to read (parallel)

1. `config/rhino.yml` — value hypothesis, user definition, features
2. `.claude/cache/market-context.json` — competitive landscape
3. `.claude/cache/customer-intel.json` — customer language, themes
4. `.claude/cache/narrative.yml` — current external narrative
5. `.claude/cache/positioning.yml` — competitive positioning
6. `.claude/design-system.md` — design tokens, voice, tone
7. `.claude/plans/roadmap.yml` — current thesis (for release notes)
8. `.claude/cache/eval-cache.json` — feature maturity (for honest claims)
9. `~/.claude/preferences.yml` — agent cost tier

## Agent spawning

For all modes:
```
Agent(subagent_type: "rhino-os:copywriter", prompt: "[copy brief with all context from state reads]")
```

For `landing` and `pitch` modes, also spawn market-analyst for competitive positioning:
```
Agent(subagent_type: "rhino-os:market-analyst", prompt: "Research competitor messaging for [category]. Capture: headlines, value props, CTAs, pricing language. Focus on what they claim vs what reviews say.", run_in_background: true)
```

## Copy quality gate

Before presenting ANY copy to the founder, the copywriter agent checks:

1. **Names a person?** Not "developers" — a specific situation. If rhino.yml `value.user` is generic, flag it and use the best available specificity.
2. **States what changes?** Not "improve your workflow" — a measurable or tangible outcome.
3. **Differentiates?** Not "the best tool" — names a specific alternative and says why this is different.
4. **Slop-free?** None of: revolutionary, cutting-edge, seamlessly, leverage, unlock, empower, transform, supercharge, game-changing, next-generation, elevate, robust, holistic, synergy, scalable (as value claim).

Any failure → rewrite before presenting.

**Mechanical check:** After generating copy, run `echo "[copy text]" | bash ${CLAUDE_SKILL_DIR}/scripts/slop-check.sh` to catch slop words, long sentences, passive voice, and generic value props programmatically. This catches things the LLM misses about its own output.

## Landing page mode

Produces:
- **Hero** — headline (7 words max) + subhead (15 words max) + CTA
- **Problem** — what the person deals with today (in their language, from customer-intel)
- **Solution** — what changes (specifics from eval-cache — only claim what scores 50+)
- **Proof** — customer quotes if available, metrics if measurable
- **CTA** — one action, clear outcome

## Pitch mode

Three variants:
- **Elevator** (10 seconds, ~20 words): who, what changes, why different
- **Tweet** (280 chars): the hook that makes someone click
- **Paragraph** (50 words): the full story

Each variant presented side by side via AskUserQuestion for founder selection.

## Outreach mode

- **Subject line**: specific to their situation (not "Quick question" or "Intro")
- **Opening**: reference something specific about them (not "I hope this finds you well")
- **Problem**: the pain point in their words
- **Bridge**: what changes (one sentence)
- **CTA**: one specific ask (not "let me know if you'd like to chat")

## Release notes mode

Reads `roadmap.yml` and `eval-cache.json`:
- What changed (user-facing, not code-level)
- Why it matters (for the named person)
- What's next (one sentence)

Uses same anti-slop rules as `/roadmap narrative`.

## Empty states mode

Scan features in rhino.yml. For each feature with a UI component:
- What does a new user with zero data see?
- Write guidance copy, CTA copy, and sample content suggestion
- Match design system tone if available

## Output format

```
◆ copy — [mode]

  for: "[user from rhino.yml]"
  positioning: "[one-line from narrative or market-context]"

⎯⎯ [copy type] ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  [the copy itself]

⎯⎯ quality gate ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯

  ✓ names person: [who]
  ✓ states change: [what]
  ✓ differentiates: [vs what]
  ✓ slop-free

/copy [other mode]   different copy type
/taste               check if the copy works visually
/ship release        use this copy in release notes
```

## What you never do

- Write copy without reading market context — unpositioned copy is generic copy
- Use slop words — the ban list is absolute
- Claim features that score <50 — only claim what's actually delivered
- Write more than asked — if they want a headline, don't write a page
- Skip the quality gate — every piece of copy gets checked before presenting
- Generate copy for a product with no user defined — flag this and help define the user first

## If something breaks

- No value.user in rhino.yml: "Who is this for? `/product user` to define your person."
- No market-context.json: degrade to un-positioned copy, flag: "Run `/strategy market` for competitive positioning."
- No customer-intel.json: use founder language from rhino.yml, flag: "Run `/discover` for customer language."
- No design-system.md: use neutral tone, suggest creating one
- No narrative.yml: derive positioning from rhino.yml + market-context

$ARGUMENTS
