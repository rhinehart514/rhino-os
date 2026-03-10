---
name: eval
description: Feature evaluator. Runs eval spec (TDD for AI) — deterministic checks, functional assertions, ceiling tests, perspective stress-test. Calibrated to 2026 market. Gaps feed forward into future plans. Say "/eval" anytime.
user-invocable: true
---

# Eval — Ship or Don't

> **Score integrity**: Read `agents/refs/score-integrity.md` before scoring. Scores are diagnostic, not goals. Ceiling tests SHOULD score low on some dimensions. A 0.7 ceiling average is good. If everything is 0.9+, you're being too lenient.

## Step 0: Load Context

Before evaluating, read:
1. **Previous eval reports** — check `.claude/evals/reports/history.jsonl` and the most recent report in `.claude/evals/reports/`. What ceiling gaps keep recurring? What scored low last time?
2. **Product context** — read the project's CLAUDE.md. Who is the user? What stage is the product? What do users compare this to?

This context calibrates your scoring. A feature that's "fine for a dev tool" might be terrible for a consumer app targeting college students.

## Step 1: Load the Eval Spec

Look for eval spec in order:
1. `.claude/evals/[feature-name].yml` (preferred — YAML with tiers)
2. `.claude/plans/active-eval.md` (legacy markdown format)
3. If neither exists → read `.claude/plans/active-plan.md` and generate assertions on-the-fly. Warn: "No eval spec found. Next time, run plan mode first."

Read `git diff --stat` to see what changed.

## Step 2: Tier 1 — Deterministic (binary pass/fail)

Run every command in the `deterministic` section. Use `pnpm` if the project uses it, `npm` otherwise.

All must pass. If any fail → BLOCKED, fix first. Do not proceed to Tier 2.

## Step 3: Tier 2 — Functional Assertions

Walk through each assertion in the `functional` section:
- Read the relevant files cited in the spec
- Verify the assertion by reading code, checking exports, tracing data flow
- Score: PASS / FAIL / CANT_VERIFY
- If CANT_VERIFY, explain what's needed to verify (e.g., runtime test, manual check)

All must pass. If any FAIL → BLOCKED.

## Step 4: Tier 3 — Ceiling Tests (push hard)

This is the real eval. Some of these SHOULD score low — that's the point.

### Market Calibration (2026)

Before scoring, ground yourself in what users actually experience daily:
- **The comparison set**: Instagram, TikTok, Discord, iMessage, Notion, Arc. Not other startups — the apps users open 50x/day. Your UI competes with these for attention.
- **Table stakes**: Sub-200ms local interactions, no spinners for cached data, mobile-first, dark mode, real-time, AI-assisted creation. If you're missing these, it's not a ceiling test failure — it's a Tier 2 failure.
- **What separates good from great**: The product feels alive. It knows your context. Creation is faster than describing what you want. Every screen has a reason to come back. Empty states feel like invitations, not dead ends.

### Scoring

For each test in the `ceiling` section:
- Read the prompt carefully — it's intentionally ambiguous or demanding
- Read ALL relevant code, not just the changed files
- Evaluate against the criteria with genuine rigor
- **Think like the target user**, not the developer. A student org leader doesn't care about clean architecture — they care about whether their poll reached their people.
- Score: 0.0-1.0

**Scoring guide:**
- 1.0 = A user would screenshot this and send it to a friend. Unreachable for most features.
- 0.8 = Feels polished, intentional, branded. User wouldn't think about switching.
- 0.6 = Functional and fine. User wouldn't complain but wouldn't evangelize.
- 0.4 = Feels generic, template-y, or has judgment gaps a user would notice.
- 0.2 = Wrong approach. User would think "this isn't for me."
- 0.0 = Fundamental misunderstanding of user or market.

**Be strict.** A 0.7 average is a good score. If you're giving 0.9+ on every ceiling test, you're being too lenient. Some tests SHOULD score low — that's signal, not failure.

### Mandatory Ceiling Dimensions

Every eval MUST include assessment of these, even if not in the spec:

1. **Escape velocity**: Does this feature compound? Does it get better with more users/content/time? Or is it static — same on day 1 and day 100?
2. **UI/UX uniqueness**: Does this feel like THIS product or like a template? Could you swap the logo and it'd be indistinguishable from another app?
3. **IA benefit**: Does the information architecture surface the right thing at the right time? Or does the user have to hunt for value?
4. **Return pull**: Is there a reason to come back? Does the user's next visit feel different from their first?

## Step 5: Perspective Check

Use the `perspectives` section from the eval spec. For each persona:
- **Simulate being them.** What app did they just close? What's their emotional state? How many seconds until they decide to stay or leave?
- Does their specific `value_moment` happen?
- For skeptics: does the `dealbreaker` apply?
- Score: 0.0-1.0

If no spec perspectives, use: the target user (from CLAUDE.md), a skeptic (day 3 returning), and someone who got a link (no context).

## Step 6: Verdict

```markdown
## Eval: [feature] — [date]

### Previous Gaps Addressed
[List which ceiling gaps from previous evals this feature addressed, and whether they improved]

### Tier 1: Deterministic
| Check | Result |
|-------|--------|
| TypeScript | PASS/FAIL |
| Tests | PASS/FAIL |
| Build | PASS/FAIL |
| [custom] | PASS/FAIL |

### Tier 2: Functional
| Assertion | Result | Notes |
|-----------|--------|-------|
| [name] | PASS/FAIL/CANT_VERIFY | [brief] |

### Tier 3: Ceiling
| Test | Score | Assessment |
|------|-------|------------|
| [name] | X.X | [what was good/bad] |
| Escape velocity | X.X | [does it compound?] |
| UI/UX uniqueness | X.X | [template or branded?] |
| IA benefit | X.X | [right thing at right time?] |
| Return pull | X.X | [reason to come back?] |
Average: X.X/1.0 (threshold: 0.6)

### Perspectives
| Persona | Score | Assessment |
|---------|-------|------------|
| [name] | X.X | [why] |
Average: X.X/1.0 (threshold: 0.6)

### Verdict: SHIP / SHIP WITH FIXES / BLOCKED
Reasoning: [1-2 sentences]
Top fixes: [ordered by impact]

### Ceiling Gaps (feed forward)
[These MUST be read by builder before the next plan. They are the input to the next PRD.]
- [gap]: [why it scored low] → [what the next feature/plan should do about it]
- [gap]: [why it scored low] → [what the next feature/plan should do about it]

### Market Position
[One sentence: where does this put the product relative to what users expect in 2026?]
```

## Step 7: Save Report

Save full report to `.claude/evals/reports/[feature]-[date].md`

Append single-line JSON to `.claude/evals/reports/history.jsonl`:
```json
{"date":"[date]","feature":"[feature]","deterministic":"N/N","functional":"N/N","ceiling":0.0,"perspectives":0.0,"verdict":"[SHIP|SHIP WITH FIXES|NOT READY]","ceiling_gaps":["[gap 1]","[gap 2]"],"gaps_addressed":["[addressed gap]"],"escape_velocity":0.0,"uniqueness":0.0,"ia_benefit":0.0,"return_pull":0.0}
```

The `ceiling_gaps` field feeds forward: builder reads it in Step 0, gate mode checks against it, and the next eval spec's ceiling tests should verify the gaps were addressed.

**The loop: eval → gaps → next plan addresses gaps → build → eval checks if gaps improved → new gaps → repeat.**
