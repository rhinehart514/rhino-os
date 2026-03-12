# rhino-os v5 — Research & Vision Document
_Compiled: March 12, 2026_

---

## 1. The Core Shift

rhino-os is not a toolkit you command. It's an OS that runs, remembers, learns, and ships.

**Current state:** Commands you call (`/build`, `/plan`, `/strategy`)  
**Target state:** A cofounder that boots, runs autonomously, and pushes Claude toward top 0.1% output

Three pillars:
1. **OpenClaw architecture** — persistent identity, memory, proactive behavior
2. **Karpathy loop** — mechanical eval, experiment→keep/discard, runs unattended
3. **Corpus-driven evals** — AI-discovered examples of exceptional work that force Claude past the median

---

## 2. The Karpathy Parallel

### autoresearch (ML research)
```
program.md (you edit) → agent modifies train.py → 5 min train → val_bpb → keep/discard → repeat
~100 experiments overnight
```

### rhino-os (product dev)
```
programs/ (you edit) → agent modifies codebase → score + eval → keep/discard → repeat
N experiments per session or overnight /go loop
```

### Key properties that make autoresearch work
| Property | autoresearch | rhino-os target |
|---|---|---|
| One mutable unit | train.py (1 file) | 1 file per experiment |
| Fixed eval budget | 5 min training | score.sh (2 sec) + eval suite |
| External metric | val_bpb (math) | Tier 1 evals (computed) |
| Mechanical keep/discard | score up → keep | eval pass → keep |
| Runs unattended | overnight on H100 | /go with no iteration cap |
| Human programs the org | edits program.md | edits programs/ + beliefs.yml |

### The abstraction level shift
You are not writing code. You are writing `programs/` and `beliefs.yml`.  
The agent writes the code. You program the research org.

---

## 3. The Eval Architecture

### Problem with current taste eval
Claude Vision scores Claude's output → circular.  
Agent can learn to produce screenshots that score well without improving the product.

### Three-tier eval system

```
Tier 1 — Computed (fully mechanical, 0 LLM, ungameable)
  ├── Color contrast ratio (WCAG formula)
  ├── Font hierarchy (h1 > h2 > body, computed from CSS)
  ├── Click target sizes (min 44×44px)
  ├── Element density (elements per viewport)
  ├── Whitespace ratio (empty px / total px)
  └── CLS score (Playwright native)

Tier 2 — Behavioral (external blind agent, hard to game)
  ├── Playwright launches app as fresh user
  ├── Blind LLM (no app context) attempts primary task
  ├── Metric: pass/fail + time + click count
  └── App must actually work — can't be gamed by screenshots

Tier 3 — Corpus comparison (LLM, but anchored and resistant)
  ├── Show Claude: current output + 3-5 corpus examples
  ├── Ask: "What specific differences? How to close the gap?"
  ├── Multi-model consensus (Claude + GPT-4V + Gemini)
  └── ELO ranking (comparative, not absolute)
```

**val_bpb equivalent:** Tier 2 task completion. The app either works for a naive user or it doesn't.

---

## 4. Beliefs → Evals Pipeline

The founder encodes their subjective beliefs as mechanical evals.  
The agent must satisfy the founder's soul on every commit.

```yaml
# .claude/evals/beliefs.yml

beliefs:
  - id: single-cta
    belief: "Users bounce when overwhelmed. One CTA above fold, always."
    type: dom_check
    check: "hero contains exactly 1 button or anchor"

  - id: onboarding-speed
    belief: "If signup takes > 90 seconds, we lose them"
    type: playwright_task
    scenario: "new user completes signup + first action"
    threshold_seconds: 90

  - id: premium-feel
    belief: "We should feel like Linear, not a university portal"
    type: corpus_compare
    corpus: "ui/saas"
    threshold: 0.72

  - id: no-jargon
    belief: "No user needs a glossary to understand our homepage"
    type: content_check
    forbidden: ["utilize", "leverage", "synergy", "ecosystem"]
    reading_level_max: 8
```

### Belief lifecycle (connected to hypothesis tracking)
```
Hypothesis created    →  eval created (belief untested)
Hypothesis validated  →  eval locked permanently (belief confirmed)
Hypothesis killed     →  eval removed (belief was wrong)
```

Evals are living beliefs. As you learn, they evolve.  
The eval file is the product's intellectual history.

---

## 5. AI-Discovered Corpus

### The problem with manual curation
Someone has to decide what's top 0.1%. They have blind spots, get tired, go stale.  
Manual doesn't scale for open source.

### The autoresearch loop for corpus building

```
Search reputation signals → Screenshot candidates → Multi-model score → Keep if exceptional → Repeat
```

**Reputation signals (highest quality):**
- Awwwards SOTD/SOTM
- Product Hunt #1 products
- Designer Twitter consensus ("best UI I've seen")
- Products that get design teardowns (exceptional = studied)
- Dribbble top shots by saves

**Multi-model consensus scoring:**
```
Candidate → Claude Vision: 8.2 | GPT-4V: 7.9 | Gemini: 8.4
Average: 8.2 | Variance: 0.2 (low) → ADMIT

If variance > 1.0 → REJECT (controversial ≠ exceptional)
```

Low variance + high score = consensus exceptional.  
Gaming three models simultaneously is effectively impossible.

### Corpus structure
```
corpus/
  ui/
    saas/        → Linear, Vercel, Stripe, Raycast
    consumer/    → Duolingo, Superhuman, Arc  
    developer/   → Warp, GitHub, Railway
  copy/
    landing/     → Stripe, Basecamp, 37signals
    onboarding/  → Duolingo, Notion, Figma first-run
  code/
    patterns/    → exemplary readability, structure, naming
```

### The overnight corpus loop
```
/go --corpus

Iteration 1: Search ui/saas → 3 new admissions
Iteration 2: Search copy/landing → 1 admitted, 2 rejected (low consensus)  
Iteration 3: Evict stale entries (>90 days, re-check if still exceptional)
Iteration 4: Cross-category search (find UI+copy pairing for same product)

Morning: Corpus updated +4 admitted, -2 evicted
```

### Community flywheel (open source moat)
```
User A runs /go --corpus → discovers exceptional fintech UI examples
User A publishes pack → community votes → high-voted packs distributed
1000 users running corpus loops → aggregated AI research on taste
No competitor can replicate without the community
```

---

## 6. The OpenClaw Architecture

### What OpenClaw does that Claude Code doesn't
| OpenClaw | rhino-os (current) | rhino-os (target) |
|---|---|---|
| Boots with identity | No boot | session_start loads full context |
| Memory across sessions | Files exist but unused | brains/ as living MEMORY.md |
| Proactive (heartbeats) | Missing | post_build hook surfaces insights |
| Initiates | Missing | Cofounder speaks without being asked |
| Autonomous | Missing | /go uncapped, runs overnight |
| Programs the org | SOUL.md evolves | programs/ evolve per session |

### session_start rewrite — the boot screen
```
🦏 rhino-os booted

Project: [name] | Stage: growth | Score: 82/100
Last session: fixed auth flow (+8) — March 11

Active plan: 3 tasks remaining
→ NEXT: Reduce onboarding from 5 to 3 steps
   Why: conversion hypothesis — unvalidated, blocking Value layer
   Est: 90 min

Beliefs at risk:
  ⚠️  "onboarding-speed" — last measured 112s (threshold: 90s)
  
Corpus: 28 examples | Last updated: 2 days ago

/build to start | /status for full briefing | /eval to check beliefs
```

No commands needed to get oriented. It just knows.

---

## 7. "Ship Faster" Workflow

### Where solo founders lose time
```
1. Prioritization     → What do I build next? (decision overhead)
2. Context recovery   → Where was I? (re-orientation kills mornings)
3. Research rabbit holes → 3 hours researching instead of 30 min + building
4. Build-ship gap     → Built wrong thing, have to rebuild
5. Perfectionism      → Over-engineering before shipping
```

### The ideal daily loop
```
Open Claude Code
  → session_start boots (30 seconds, no commands)
  → context loaded, next task surfaced automatically
  
/build
  → implements task
  → score.sh runs automatically  
  → evals run (Tier 1 always, Tier 2 on demand)
  → keep/discard mechanical

rhino score .   (2 seconds, any time)
  → structural feedback immediately

Done → next task surfaces
```

### Research budget
```
/research [topic] --budget 30m

Mandatory output template:
  Hypothesis: [specific belief]
  Evidence: [what I found]
  Confidence: low / medium / high
  Build implication: [exactly what to build or not build]
  Time spent: [must be under budget]

If template isn't filled → research didn't produce value → stop
```

---

## 8. The Missing Commands

### `/next` — the highest-leverage addition
```
/next

→ Reads active-plan.md
→ Surfaces first unchecked task
→ Output: task name, one-sentence why, estimated time
→ No pyramid. No strategy. No context loading.
→ 20 lines of skill code.
```

This changes the daily start from "figure out what to work on" to "start working."

### `/eval` — run belief checks
```
/eval

📋 Eval Results — March 12 2026

✅ single-cta        hero has 1 CTA                     PASS
✅ no-jargon         0 forbidden words                   PASS
⚠️  onboarding-speed  avg 112s (threshold: 90s)          FAIL (-8 pts)
❌ premium-feel      CLIP similarity 0.61 (min: 0.72)    FAIL (-12 pts)
✅ two-click-rule    all core features ≤ 2 clicks         PASS

Score: 72/100 → 68/100 (eval failures)
Keep? No — evals regressed. Reverting.
```

### `/corpus update` — run corpus research loop
```
/corpus update [category]

→ Searches reputation signals
→ Screenshots candidates
→ Multi-model consensus score
→ Admits exceptional, rejects controversial
→ Evicts stale entries
→ Proposes additions for approval
```

---

## 9. Build Roadmap

### Sprint 1 — OpenClaw boot (highest leverage, 1-2 days)
- [ ] Rewrite `session_start.sh` — full context boot
- [ ] Add `/next` skill — one task, no ceremony
- [ ] `.claude/brains/` as living memory file
- [ ] Remove `/go` iteration cap, add plateau stop

### Sprint 2 — Tier 1 evals (ungameable, 2-3 days)
- [ ] DOM check eval runner (contrast, hierarchy, targets, density)
- [ ] Route graph eval (click depth to any feature)
- [ ] Content eval (forbidden words, reading level)
- [ ] `beliefs.yml` schema + parser
- [ ] Integrate into `rhino score .` output

### Sprint 3 — Tier 2 behavioral eval (the val_bpb, 3-5 days)
- [ ] Playwright task completion script
- [ ] Blind agent persona prompt (no app context)
- [ ] Pass/fail + time + click count output
- [ ] Integrate into eval suite

### Sprint 4 — Corpus system (the moat, 1 week)
- [ ] Corpus schema + storage format
- [ ] `/research --corpus` command
- [ ] Reputation signal search (Awwwards, PH, designer Twitter)
- [ ] Multi-model consensus scorer
- [ ] Eviction logic (stale entries)
- [ ] `/go --corpus` overnight loop

### Sprint 5 — Community layer (after v1, ongoing)
- [ ] `rhino corpus publish --pack [category]`
- [ ] Pack voting mechanism
- [ ] Community corpus registry

---

## 10. The Defensible Position

**What rhino-os has that can't be cloned:**

1. The corpus — community-maintained, AI-curated, consensus-validated, domain-specific
2. The beliefs system — your product's soul, encoded as mechanical evals
3. The compounding memory — hypotheses that grow with every session
4. The Karpathy loop — runs overnight, scales with compute, finds improvements you wouldn't

**What makes it for anyone:**
- Default corpus ships with rhino-os (works out of box)
- Domain packs (community extends it)
- beliefs.yml written in plain English (no eval code required)
- session_start boots without configuration

**The network effect:**
More users → more corpus research loops → better taste database → better evals → better output → more users.

Taste compounds. That's the moat.
