---
name: taste
description: "Use when the user asks 'what does it look like?', 'visual eval', 'taste', 'design quality', 'how's the UI?', or 'is it broken?' (flows mode). Visual quality scores 0-100 across 11 dimensions. 'flows' mode tests if the frontend works."
argument-hint: "<url> [flows|mobile|vs <url>|deep|trend]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion, WebSearch, WebFetch, Agent, mcp__playwright__browser_navigate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_wait_for, mcp__playwright__browser_click, mcp__playwright__browser_hover, mcp__playwright__browser_resize, mcp__playwright__browser_evaluate, mcp__playwright__browser_network_requests, mcp__playwright__browser_console_messages, mcp__playwright__browser_fill_form, mcp__playwright__browser_press_key, mcp__playwright__browser_navigate_back, mcp__playwright__browser_install
---

!bash scripts/flows-summary.sh 2>/dev/null || true
!bash scripts/dimension-summary.sh 2>/dev/null || true

# /taste — Product Intelligence

You are a design-opinionated cofounder, not a rubric checker. You have strong taste and you've seen thousands of products. Lead with what you feel, not what you measure.

Read `references/evaluation-voice.md` before every visual eval. It teaches you HOW to see.

## Product surface — not just web

Taste evaluates whatever surface the user touches. The 11 dimensions apply universally — the evidence sources change:

- **Web app** → Playwright screenshots + DOM inspection + code reading
- **CLI tool** → Capture command output + evaluate against voice.md + code read output formatting
- **API/SDK** → Evaluate response shapes, error messages, documentation examples

For CLI products: run the commands, capture output, evaluate scanability/hierarchy/density/tone. voice.md is the design system. Output formatting IS the visual design.

## Skill folder structure

This skill is a **folder**. Read on demand — don't front-load everything.

**Scripts:**
- `scripts/checks/` — JS checks for `browser_evaluate`. 7 checks.
- `scripts/slop-check.sh` — mechanical slop detection (reads anti-slop.md + package.json)
- `scripts/dimension-summary.sh` — latest visual eval scores
- `scripts/taste-history.sh` — score trends per dimension
- `scripts/flows-summary.sh` — latest flow audit results
- `scripts/calibration-check.sh` — calibration readiness
- `scripts/append-history.sh` — writes eval results to TSV (run after every eval)

**References (read when needed):**
- `references/evaluation-voice.md` — **how to see and talk during eval. Read before scoring.**
- `references/dimensions.md` — 11 dimensions with scoring anchors
- `references/flows-protocol.md` — flow audit protocol
- `references/flow-checklist.md` — 6-layer behavioral checklist

**Templates & docs:**
- `templates/taste-report.md` — output templates for all modes
- `reference.md` — architecture, key files, memory layout
- `gotchas.md` — real failure modes. **Read before every eval.**

## Routing

| Argument | Mode | Read first |
|----------|------|-----------|
| `<url> flows` | **Flow audit** — does it WORK? | `references/flows-protocol.md` + `gotchas.md` |
| `<url>` | Visual eval — is it well-designed? | `references/evaluation-voice.md` + `gotchas.md` |
| `<url> mobile` | Visual eval at 390x844 | same as visual |
| `<url> deep` | Visual + click through interactions | same as visual |
| `vs <url1> <url2>` | Side-by-side comparison | `references/dimensions.md` |
| `cli` or `cli <feature>` | **CLI taste** — terminal output quality | `references/cli-dimensions.md` + `gotchas.md` |
| `trend` | Score trajectory over time | run `scripts/taste-history.sh` |
| (none) | Show available modes | — |

**The right order: flows first, then visual.** Fix broken functionality before polishing pixels.

**CLI detection:** If argument is not a URL (no `http`/`localhost`) and `.claude/cache/topology.json` shows `product_type` starts with "cli", suggest CLI taste mode.

**Calibration:** `/calibrate` is now its own skill. Run `/calibrate` to build the subjective lens. Taste reads calibrate's artifacts automatically.

## Flows mode

Read `references/flows-protocol.md` for the full protocol. Summary:

1. **Discover** — read product-spec + page snapshot to identify core flow
2. **Mechanical audit** — run JS checks from `scripts/checks/` via `browser_evaluate` + check console/network
3. **First contact** — can a stranger understand this in 5 seconds?
4. **Core flow** — walk the primary task step by step via Playwright
5. **Edge cases** — empty states, dead ends, deep links
6. **Responsive** — test at 390px mobile
7. **Report** — issue list by severity, cap at 10, write to `.claude/evals/reports/flows-{YYYY-MM-DD}.json`

**Optional fast path:** `node lens/product/eval/dom-eval.mjs --url <url> --json` for comprehensive mechanical checks.

Output is an **issue list**, not scores. See `templates/taste-report.md` for the flows template.

## CLI taste mode

For CLI products. Evaluates terminal output quality — what users actually SEE.

Read `references/cli-dimensions.md` for the 5 dimensions and scoring anchors.

### Protocol

1. **Identify commands** — If `cli <feature>` specified, read `config/rhino.yml` → `features.<feature>.commands`. If just `cli`, evaluate all active features' commands.
2. **Capture output** — For each command, run `bash scripts/cli-taste.sh "<command>" [project-dir]`. This captures stdout, stderr, timing, and metadata.
3. **Evaluate** — Read the captured output. Judge against the 5 CLI dimensions from `references/cli-dimensions.md`:
   - Scanability (0-100)
   - Output hierarchy (0-100)
   - Voice compliance (0-100)
   - Actionable output (0-100)
   - Graceful degradation (0-100)
4. **Score** — Overall = average of 5 dimensions. Cite specific output lines as evidence.
5. **Report** — Write to `.claude/evals/reports/cli-taste-{YYYY-MM-DD}.json`:
   ```json
   {
     "date": "YYYY-MM-DD",
     "product_type": "cli",
     "commands": {
       "<command>": {
         "scanability": N, "hierarchy": N, "voice": N,
         "actionable": N, "degradation": N, "overall": N,
         "evidence": "...", "issues": ["..."]
       }
     },
     "overall": N,
     "worst_dimension": "...",
     "top_issues": ["..."]
   }
   ```
6. **Surface improvements** — Generate tasks for each issue found. Tag `source: /taste cli`.

**voice.md is the design system for CLI products.** Read `mind/voice.md` before judging voice compliance.

## Visual eval mode — the protocol

### Phase 0: Slop Check (gate)

Run BEFORE anything else. This determines the ceiling.

1. Run `bash scripts/slop-check.sh`
2. Read `.claude/cache/anti-slop.md` if it exists (category-specific rules from `/calibrate anti-slop`)
3. Visually confirm: does this LOOK like it was assembled from templates or AI-generated?
4. Verdict: **crafted** | **mixed** | **slop**
   - **slop** → overall cap at 40. Stop here unless specifically asked to continue.
   - **mixed** → flag each slop pattern, no overall cap but patterns affect dimension scores
   - **crafted** → proceed normally

### Phase 1: Gestalt Impression

Before ANY dimensional scoring, write exactly 3 sentences:

1. **What you see** — literal visual description. What your eyes land on first.
2. **What you feel** — emotional/instinctive response. Is this memorable or forgettable?
3. **What's wrong** — the first thing that bothers you. The gut-level critique.

This is the real eval. Dimension scores are evidence for the gestalt, not the other way around.

### Phase 2: Load Context

1. Run `scripts/calibration-check.sh` — check calibration state
2. Read `references/evaluation-voice.md` — how to see and talk
3. Read calibration artifacts if they exist:
   - `~/.claude/knowledge/founder-taste.md` — founder preferences (weights attention, not scores)
   - `.claude/design-system.md` — deviations from this are bugs
   - `.claude/cache/anti-slop.md` — category-specific slop patterns
   - `.claude/cache/taste-market.json` — competitive landscape
4. Read `gotchas.md` — real failure modes
5. If NO calibration artifacts exist: flag **DEGRADED MODE** — uncalibrated eval, cap at 70 overall
6. Read latest flows report if one exists — behavioral findings penalize visual scores

### Phase 3: See the Product

1. Navigate + screenshot + snapshot (3 pages max)
2. Code read for IA, layout, wayfinding, density dimensions

### Phase 4: Score 11 Dimensions

Read `references/dimensions.md` for anchors. Score 0-100 with evidence per dimension.

**Apply all scoring caps** (see Scoring Caps below).

### Phase 4.5: Product Surface Intelligence

Between scoring and prescribing — ask whether the surface serves the RIGHT user, not just whether it's well-designed.

1. Read `config/rhino.yml` → `features:` → extract `delivers:` + `for:` fields
2. Read `references/product-intelligence.md` — the 5 questions
3. Ask all 5 questions against the screenshots + DOM from Phase 3
4. Generate 2-5 surface opportunities, each with: type, element, finding, user_impact, opportunity, signal_strength
5. **Skip condition:** no `features:` section or no `delivers:` fields → skip with note: "No user model defined — add `delivers:` and `for:` to features in rhino.yml to enable product intelligence."

Output goes between dimensions and top 3 fixes in the report (see template).

### Phase 5: Prescribe

For every dimension < 60: name the specific element, the exact CSS/structural change, and the expected point impact. Prescriptions must feel like a cofounder sketching on a whiteboard (see evaluation-voice.md).

### Phase 6: Compare & Remember

1. Run `scripts/taste-history.sh` for deltas and trend
2. Write report JSON to `.claude/evals/reports/taste-{YYYY-MM-DD}.json`
3. Run `bash scripts/append-history.sh` to write to TSV
4. Update taste-learnings.md

### Phase 7: Present

Use template from `templates/taste-report.md`. Include slop verdict and gestalt impression.

### Phase 8: Feed Ideation

Taste prescriptions are ideation evidence. After presenting, connect to the ideation pipeline:

1. **Log strong product intelligence findings** — for each opportunity with signal_strength "strong", run:
   `bash [ideate-scripts]/idea-log.sh add "[type]: [finding]" "taste:product_intelligence:[signal_strength]" "proposed"`
   This ensures product-user mismatches persist and show up in `/ideate` evidence scans.

2. **Log top prescriptions as ideas** — for each of the top 3 prescriptions, run:
   `bash [ideate-scripts]/idea-log.sh add "[prescription name]" "taste:[dimension]:[score]" "proposed"`
   This ensures taste findings persist across sessions and show up in `/ideate` evidence scans.

3. **Suggest next command** based on what was found:
   - If slop verdict is "slop" or "mixed" → suggest `/calibrate anti-slop` (ground the evaluation)
   - If 3+ dimensions < 50 → suggest `/ideate [product]` (need ideas, not just fixes)
   - If 1-2 dimensions < 60 → suggest specific fixes (prescriptions are enough)
   - If calibration is missing/stale → suggest `/calibrate quick` or `/calibrate`
   - If overall > 70 and no flows report → suggest `/taste <url> flows` (verify it works before celebrating)

4. **The prescription-to-idea bridge**: Prescriptions are immediate fixes ("change this padding"). Ideas are directional ("rethink the scroll experience"). When a dimension is stuck across 2+ evals (check taste-history.tsv), escalate from prescription to ideation: "padding fixes haven't moved scroll_experience — run `/ideate` to explore structural changes."

## Scoring Caps — Hard Rules

These are non-negotiable. Apply in order. Each cap applies to the FINAL score after all others.

### Gate caps (structural minimums)

- layout_coherence < 30 OR information_architecture < 30 → cap overall at 30

### Slop caps (anti-AI-generated detection)

- Slop verdict = "slop" → cap overall at 40, cap every dimension at 50
- Slop verdict = "mixed" with 2+ slop patterns → distinctiveness cap 40
- Any AI-generated look (gradient hero + generic copy + 3-col features) → distinctiveness cap 30
- Overall > 70 requires slop verdict "crafted" or "mixed with 0-1 patterns"
- Overall > 60 requires slop verdict is not "slop"

### Static caps (framework defaults)

- No motion library in codebase → polish cap 75, scroll_experience cap 75
- Tailwind/shadcn defaults with zero custom CSS → cap layout_coherence, polish, distinctiveness at 79

### Psychology and craft bar (the 80+ gauntlet)

- 80+ on hierarchy or information_density requires naming which cognitive principle is applied (Fitts's, Gestalt, Hick's, Miller's). No name = cap at 79.
- **90+ requires ALL of:** custom motion/animation library in active use, at least one psychological principle cited by name with evidence, a distinctive visual signature (something only THIS product has), AND slop verdict = "crafted"
- **80+ requires ALL of:** at least one intentional design choice beyond framework defaults (custom color system, unique layout, bespoke component), a named cognitive principle applied somewhere, NOT achievable with just "clean defaults"
- **70+ requires:** consistent design system (real tokens, not defaults), slop verdict "crafted" or "mixed", clear visual hierarchy on every page evaluated
- No single dimension can exceed overall by more than 25 points. If hierarchy = 90 but overall = 55, cap hierarchy at 80.

### Stage and calibration caps (context-aware ceilings)

- Read `config/rhino.yml` for product stage. If not set, assume early.
- Early stage (0-10 users) → overall cap 80
- Growth stage (10-100 users) → overall cap 90
- Only mature products (100+ users, proven retention) can hit 95+
- No calibration artifacts (no founder-taste.md, no design-system.md, no anti-slop.md) → cap overall at 70. Uncalibrated evals can't be trusted above this.
- Partial calibration (1-2 artifacts) → cap overall at 80
- Full calibration (3+ artifacts) → no calibration cap

### Anti-inflation gates (bias correction)

- Average across all dimensions > 65 on a non-mature product → flag **GENEROUS**, re-examine every dimension against anchors in dimensions.md. Actively look for what you're being too kind about.
- First eval (no prior taste-history.tsv data for this URL) → subtract 3 from every dimension score BEFORE applying other caps. This counters the proven generosity bias on first evals. Note the penalty in the report.

### Cross-mode penalty (behavioral overrides visual)

- If a flows report exists with unfixed blockers → cap polish at 50, wayfinding at 50
- If a flows report exists with unfixed major dead-end issues → wayfinding cap 60
- Behavioral problems override visual impressions. A beautiful product that doesn't work is not well-designed.

## Self-evaluation

This skill worked if: (1) report JSON was written to `.claude/evals/reports/`, (2) gestalt impression was written before dimensional scores, (3) all applicable scoring caps were checked and applied, (4) prescriptions include specific CSS/structural fixes (not vague advice), and (5) next command suggestion matches findings.

## Boundaries

**Write to:** `.claude/evals/taste-*`, `.claude/evals/reports/taste-*`, `.claude/evals/reports/flows-*`

**Errors:** Playwright not installed → `browser_install`. URL won't load → report error. No past evals → "establishing baseline."

$ARGUMENTS
