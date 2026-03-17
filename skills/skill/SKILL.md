---
name: skill
description: "Use when creating new skills, managing existing ones, auditing skill quality, or checking overlap. The skill lifecycle manager."
argument-hint: "[list|create <name>|install <url>|remove <name>|info <name>|health|audit|overlap <name>]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion
---

# /skill

**The difference:** Claude Code has commands — simple prompt files. Anyone can make one. rhino-os has skills — `skills/*/SKILL.md` files that are **measured**.

A Claude Code command is a prompt. A rhino-os skill is a prompt that knows if it's good.

| | Claude Code command | rhino-os skill |
|---|---|---|
| Prompt file | ✓ | ✓ |
| Assertions that test it | | ✓ |
| Sub-scores (delivery/craft/viability) | | ✓ |
| Per-feature rubric | | ✓ |
| Maturity tracking | | ✓ |
| Agent wiring (todo exhaust) | | ✓ |
| Becomes a defensible claim in /roadmap narrative | | ✓ |

When you `/skill create`, you don't just get a file — you get the file wired into the measurement system. The skill can't hide from its own quality score.

## Routing

| Input | Action |
|-------|--------|
| `list` or (none) | Show all skills with maturity + pass rates |
| `create <name>` | Crystallize a pattern into a measured skill |
| `install <url>` | Install external skill from git repo |
| `remove <name>` | Remove a skill |
| `info <name>` | Show skill details, assertions, sub-scores |
| `health` | Skill health dashboard — tier classification, line counts, measurement status |
| `audit` | Full quality audit across all skills — format compliance, state artifacts, anti-rationalization |
| `overlap <name>` | Check proposed skill name against existing skills for route overlap |

**Ambiguity resolution:** Exact keyword match wins. If the argument matches a skill name and no keyword, default to `info <name>`. Never ask "did you mean?" — just act.

---

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| skill-health | `.claude/cache/skill-health.json` | R+W | Per-skill health metrics |
| eval-cache | `.claude/cache/eval-cache.json` | R | Per-feature scores |
| rhino.yml | `config/rhino.yml` | R | Features, weights |
| beliefs.yml | `lens/product/eval/beliefs.yml` | R+W | Assertions |
| rubrics | `.claude/cache/rubrics/*.json` | R | Rubric data per feature |

---

## Skill Quality Tiers

Every skill falls into one of four tiers. These drive `/skill health` classification and `/skill audit` grading.

- **Thick** (>300 lines, 5+ routes, assertions exist, reference.md exists, anti-rationalization section, degraded modes): Full intelligence. The gold standard. Self-aware, self-measuring, self-correcting.
- **Thin** (missing 2+ of the above): Functional but not self-aware. Can't detect its own quality. Works today, drifts tomorrow.
- **Stub** (missing 3+ or <100 lines): Placeholder. Either build it out or kill it. Stubs that survive 30 days become dead weight.
- **Dead** (unmeasured for 30+ days, no assertions, no recent usage): Candidate for removal. Not earning its keep.

The goal is not "all thick." Some skills should stay thin — low-weight, narrow scope, infrequent use. But high-weight skills (w:4-5) that are thin or stub? That's a quality gap.

---

## `/skill list`

Not just names — show which skills are measured and how they're doing.

```
◆ skill — 18 skills

  ⎯⎯ measured (feature in rhino.yml) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  /eval          ████████████░░░░░░░░  working   w:5  58 (d:62 c:50 v:60)
  /plan          ████████████░░░░░░░░  working   w:5
  /go            ██████░░░░░░░░░░░░░░  building  w:4  BETA
  /feature       ████████████░░░░░░░░  working   w:5

  ⎯⎯ unmeasured (no feature entry) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  /clone         no assertions · no feature entry
  /calibrate     no assertions · no feature entry

  ⎯⎯ context (auto-loaded) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  rhino-mind     loaded every session
  product-lens   loaded for product eval

/skill create <name>    create a measured skill
/skill info <name>      inspect one
/skill health           tier breakdown
```

## `/skill create <name>` — the main event

Skills emerge from observed patterns, not empty templates. This command creates a skill AND wires it into measurement from day one.

### Step 1: Evidence check

Skills must be earned. Ask the founder:

1. "What pattern have you seen that deserves its own skill?"
   (Something that keeps mattering across sessions — not a hypothesis, an observation)
2. "What would this skill do that existing skills don't?"
   (The specific gap. If it overlaps with an existing skill, merge instead.)
3. "Show me an example — a moment where having this skill would have changed a decision."
   (Concrete evidence. If they can't point to one, it's too early.)

If the founder can't answer #3: "This might not be ready. Keep watching for the pattern."

**Validation:**
- Has the pattern recurred across 3+ sessions?
- Can you name what it specifically does (not "quality" — something like "API response consistency")?
- Does an existing skill already cover this? Run `/skill overlap <name>` before proceeding.

### Step 2: Overlap check (mandatory)

Before creating, run the overlap detection logic from `/skill overlap`. If >50% route overlap with an existing skill, stop and recommend adding a route to the existing skill instead.

### Step 3: Create the skill

Once evidence is clear and overlap is <50%:

1. Create `skills/<name>/SKILL.md` with:
   - Frontmatter: name, description, argument-hint, allowed-tools
   - Routing table
   - State artifacts table
   - State to read section
   - Output format (reference OUTPUT_FORMAT.md)
   - Anti-rationalization section
   - "What you never do" section
   - "If something breaks" section (degraded modes)

2. Create `skills/<name>/reference.md` with output templates

### Step 4: Wire into measurement (this is what makes it a rhino-os skill)

3. **Feature entry** — add to `config/rhino.yml` under `features:`:
   ```yaml
   [name]:
     delivers: "[what the founder said in question 1]"
     for: "[who benefits]"
     code: ["skills/<name>/SKILL.md", "skills/<name>/reference.md"]
     weight: [1-5 based on centrality to value hypothesis]
     maturity: planned
   ```

4. **Assertions** — add 2-3 to `beliefs.yml`:
   - `file_check`: SKILL.md exists and has frontmatter
   - `content_check`: SKILL.md contains routing table and recovery section
   - `command_check` or `llm_judge`: the skill actually does what it claims

5. **Baseline eval** — run `rhino eval . --feature <name> --fresh`

6. **Todo** — write to todos.yml: "build [name] skill to working maturity" with `source: /skill create`

### Step 5: Output

```
◆ skill create — <name>

  emerged from: "[the pattern they described]"

  ✓ skills/<name>/SKILL.md
  ✓ skills/<name>/reference.md
  ✓ config/rhino.yml — feature entry (w:[N], planned)
  ✓ beliefs.yml — 3 assertions seeded
  ✓ overlap check — <N%> overlap (clear)
  ✓ baseline eval: PARTIAL — [N] passing

  This skill is now measured. It has a score, assertions, and maturity
  tracking. When it reaches working maturity, it becomes a defensible
  claim in /roadmap narrative.

/go <name>         build it to working
/eval <name>       check current state
/feature <name>    see the full breakdown
```

---

## `/skill health` — skill health dashboard

Scan every skill directory, classify each by tier, surface measurement gaps.

### How to compute health

For each directory in `skills/*/SKILL.md`:

1. **Line count** — `wc -l` on SKILL.md
2. **Route count** — count rows in routing table (lines matching `| \`...\`` pattern in the routing section)
3. **Assertion count** — grep `beliefs.yml` for assertions referencing this skill's files or feature name
4. **Has reference.md** — check `skills/<name>/reference.md` exists
5. **Has agent wiring** — check if any agent in `agents/` references this skill, or if SKILL.md mentions agent delegation
6. **Output compliant** — SKILL.md contains: `◆` header in output examples, state bar pattern, ends with 3 bottom commands
7. **Last eval score** — read from `.claude/cache/eval-cache.json` if feature exists
8. **Last modified** — `stat -f %Sm` on SKILL.md
9. **Anti-rationalization section** — SKILL.md contains "Anti-rationalization" or "anti-rationalization" heading/section
10. **Degraded modes** — SKILL.md contains "If something breaks" or "degraded" section

### Tier classification

Apply quality tier definitions:
- **Thick**: >300 lines AND 5+ routes AND assertions exist AND reference.md exists AND has anti-rationalization AND has degraded modes
- **Thin**: missing 2+ of the thick criteria
- **Stub**: missing 3+ of the thick criteria OR <100 lines
- **Dead**: no assertions AND last modified >30 days ago AND no eval score

### Skill Health Protocol

After every `/skill health` run, write to `.claude/cache/skill-health.json`:
```json
{
  "last_audit": "2026-03-16",
  "skills": {
    "eval": {
      "lines": 382,
      "routes": 9,
      "assertions": 11,
      "has_reference": true,
      "has_agents": true,
      "output_compliant": true,
      "has_anti_rationalization": true,
      "has_degraded_modes": true,
      "last_score": 58,
      "last_modified": "2026-03-16",
      "tier": "thick"
    }
  },
  "aggregate": {"thick": 5, "thin": 8, "stub": 3, "dead": 1}
}
```

### Output

```
◆ skill health — [N] skills

  thick: [N]  thin: [N]  stub: [N]  dead: [N]

  ▾ thick (gold standard)
    /eval       382 lines  9 routes  11 assertions  58/100
    /strategy   453 lines  12 routes  8 assertions   —
    /taste      484 lines  5 routes   6 assertions   72/100

  ▾ thin (needs work)
    /clone      114 lines  1 route   0 assertions   ⚠ no measurement
    /calibrate  178 lines  4 routes  0 assertions   ⚠ unmeasured 15d

  ▾ stub (build or kill)
    /openclaw   61 lines   2 routes  0 assertions   ⚠ no reference.md

  ▾ dead (kill or build)
    /example    45 lines   0 assertions  ⚠ unmeasured 30d+

/skill audit        full quality check
/skill create       add a new measured skill
/assert             add assertions to thin skills
```

---

## `/skill audit` — full quality audit

Scan ALL skills for compliance against the thick skill standard. This is the quality gate for the entire skill system.

### What to check

For each skill directory in `skills/*/SKILL.md`:

**Output format compliance:**
- Header uses `◆ name — scope` pattern in output examples
- State bar appears after header in output examples (e.g., `score: X  assertions: Y/Z  maturity: W`)
- Section markers use `⎯⎯` or `▾` patterns
- Output examples end with 3 bottom commands (lines starting with `/`)

**State artifact declarations:**
- Skill contains a "State Artifacts" table (or equivalent "State to read" section)
- Table lists paths, read/write access, and purpose

**Anti-rationalization sections:**
- Skill contains explicit self-deception checks
- Checks are specific to the skill's domain (not generic)

**Degraded mode paths:**
- Skill has "If something breaks" or equivalent section
- Each failure mode has a specific recovery action (not just "error")

**Prediction logging:**
- Skill's major decisions reference prediction tracking
- Output suggests prediction-worthy actions

### Scoring

Compliance % = (checks passing / total checks) across all skills. Report both aggregate and per-skill.

### Output

```
◆ skill audit — [N]% compliant

  ▾ output format
    ✓ 12/18 skills have proper header (◆ name — scope)
    ✗ 6 skills missing state bar after header
    ✓ 15/18 skills end with 3 bottom commands

  ▾ state artifacts
    ✓ 8/18 skills declare state artifacts table
    ✗ 10 skills have no artifact declarations

  ▾ anti-rationalization
    ✓ 5/18 skills have anti-rationalization section
    ✗ 13 skills lack self-deception checks

  ▾ degraded modes
    ✓ 14/18 skills have "if something breaks" section
    ✗ 4 skills fail silently on missing data

  ▾ worst offenders
    /clone        1/5 checks passing  ⚠ stub
    /calibrate    2/5 checks passing  ⚠ thin
    /openclaw     0/5 checks passing  ⚠ stub

/skill health       per-skill breakdown
/go [weakest]       improve the weakest skill
/assert             add missing assertions
```

---

## `/skill overlap <name>` — route overlap detection

Before creating a new skill, check if it duplicates existing capability. This is a HARD GATE — overlapping skills fragment intelligence instead of concentrating it.

### How to detect overlap

1. Read `$ARGUMENTS` as the proposed skill name
2. Glob all `skills/*/SKILL.md` files
3. For each existing skill, extract the routing table (lines between `## Routing` and the next `##` or `---`)
4. Parse route keywords from each table row (the text in the Input column)
5. Ask the founder: "What routes would `/[proposed name]` have?" (or infer from the name if obvious)
6. Build a keyword set for the proposed skill: split route descriptions into normalized keywords
7. For each existing skill, compute overlap: `|intersection| / |proposed keywords|`
8. If any existing skill overlaps >50%, flag it

### Decision logic

- **<30% overlap**: clear to create. Mention the closest skill for awareness.
- **30-50% overlap**: warn but allow. "Some overlap with /[existing] — consider whether a new route on /[existing] would be simpler."
- **>50% overlap**: block creation. "This overlaps significantly with /[existing]. Add a route to /[existing] instead."

### Output

```
◆ skill overlap — [proposed name]

  checking against [N] existing skills...

  ⚠ 65% overlap with /eval
    shared routes: deep analysis, scoring, sub-scores
    unique to proposed: [what's different]

  recommendation: add a route to /eval instead of creating /[name]

/eval               the skill that already covers this
/skill create       proceed anyway (not recommended)
```

Or if clear:

```
◆ skill overlap — [proposed name]

  checking against [N] existing skills...

  ✓ no significant overlap detected
    closest: /eval at 15% (shared keyword: "analysis")

  clear to create.

/skill create <name>    proceed with creation
```

---

## `/skill install <url>`

```bash
"$RHINO_DIR/bin/rhino" skill install "$URL"
```

After install:
1. Read the installed skill's SKILL.md
2. Run overlap check against existing skills — warn if >30%
3. Check if it has a feature entry in rhino.yml — if not, create one
4. Check if it has assertions — if not, generate 2-3 mechanical ones
5. Run baseline eval
6. Suggest `/onboard` to wire up hooks/mind files if needed

**The install doesn't just add a file — it wires the skill into measurement.**

## `/skill remove <name>`

```bash
"$RHINO_DIR/bin/rhino" skill remove "$NAME"
```

After removal:
1. Mark the feature as `killed` in rhino.yml (don't delete — preserve history)
2. Note assertions that are now orphaned
3. Update skill-health.json to remove the entry
4. Suggest `/onboard` to clean up

## `/skill info <name>`

Show the skill's full measurement profile:

```
◆ skill info — eval

  description: "Is my product good? Sub-scores, rubrics, multi-sample median."
  routes: deep · slop · taste · blind · coverage · trend · diff · vs
  tier: thick (382 lines, 9 routes, 11 assertions, reference.md)
  allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebFetch

  ⎯⎯ measurement ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  feature: scoring (w:5, working)
  score: 58/100 (d:62 c:50 v:60) ↑4
  assertions: 10/11 passing
  rubric: .claude/cache/rubrics/scoring.json (fresh)

  ⎯⎯ quality checks ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  ✓ output format compliant
  ✓ state artifacts declared
  ✓ anti-rationalization section
  ✓ degraded modes documented
  ✗ no prediction logging references

  ⎯⎯ files ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  skills/eval/SKILL.md      (382 lines)
  skills/eval/reference.md  (280 lines)

/eval              run it
/feature scoring   see the feature
/go scoring        improve it
```

---

## Anti-Rationalization Checks

Self-deception is the enemy of skill quality. These checks run implicitly during every `/skill` route.

### "Creating a skill without evidence"
The 3-question evidence check (Step 1 of create) is the first gate. Strengthen it: if the founder cannot point to 3+ sessions where the pattern appeared, STOP. "Skills emerge from patterns, not wishes. Keep watching for the pattern — if it matters, it'll keep showing up."

### "Unmeasured skill at >30 days"
If a skill has existed for a month without a feature entry + assertions, it's dead weight. Flag in `/skill list` and `/skill health`:
"⚠ [name] has been unmeasured for [N] days. Either wire it into measurement or `/skill remove [name]`."

### "Skill without reference.md"
Output templates should be documented. Without reference.md, every run produces unpredictable output — the skill can't be evaluated consistently. Flag:
"⚠ [name] has no reference.md — output is unpredictable across sessions."

### "Overlapping skills"
If `/skill overlap` detects >50% route overlap, block creation. Do not allow the founder to rationalize "but mine is slightly different." If the routes overlap, the intelligence should be concentrated, not fragmented:
"This overlaps with /[existing]. Add a route to /[existing] instead of creating a new skill."

### "All skills thin"
If aggregate health shows >60% thin/stub/dead, the skill system itself is degraded. The quantity of skills is masking quality gaps. Flag:
"Most skills are below quality bar. [N] of [total] are thin or worse. `/skill audit` to see specifics, then `/go [weakest]` to improve one."

### "Thick skill without assertions"
A skill can pass structural checks (lines, routes, reference.md) but still have zero assertions. Structure without measurement is theater. Flag:
"⚠ [name] looks thick structurally but has 0 assertions — it can't prove it works."

---

## What you never do

- Create empty scaffold skills — evidence required
- Create a skill without running overlap check first
- Create a skill without wiring it into measurement (feature + assertions + baseline)
- Install a skill without checking for measurement wiring
- Delete feature entries on remove — mark killed, preserve history
- Let unmeasured skills stay unmeasured — flag them in `/skill list` and `/skill health`
- Classify a skill as "thick" when it lacks assertions — structure without measurement is theater
- Ignore overlap >50% — always recommend merging as a route on the existing skill
- Write skill-health.json without actually scanning the filesystem — no cached-only reads

## If something breaks

### Degraded modes

- **No skill-health.json** → generate fresh from filesystem scan. Glob all `skills/*/SKILL.md` files, count lines, check for reference.md, check beliefs.yml for assertions matching each skill. Write the result to `.claude/cache/skill-health.json` for next time.
- **No beliefs.yml** → note "no assertions file — all skills unmeasured." Every skill classified as thin or worse. Suggest `/onboard` to set up the measurement system.
- **No eval-cache.json** → skip scores in health output, show structural health only (lines, routes, reference.md, format compliance). Note "eval cache missing — run `rhino eval .` for scores."
- **No rhino.yml features section** → note "no features defined — `/onboard` to set up." Skills can still be scanned structurally but won't have maturity/weight data.
- **Install fails** → check URL is a valid git repo with SKILL.md. If not a git URL, check if it's a local path.
- **Remove fails** → check `skills/` directory for exact name match. Show closest match if typo suspected.
- **Founder can't articulate the pattern** → too early. Push back firmly: "This might not be ready. Keep watching for the pattern."
- **Name collision** → show existing skill with `/skill info <name>` and suggest a different name or merging.
- **skill-health.json is stale (>7 days)** → regenerate from filesystem before displaying. Note "cache was stale, regenerated."

$ARGUMENTS
