---
name: skill
description: "Use when creating new skills or managing existing ones with assertions and maturity"
argument-hint: "[list|create <name>|install <url>|remove <name>|info <name>]"
allowed-tools: Read, Bash, Grep, Glob, Edit, Write, AskUserQuestion
---

# /skill

**The difference:** Claude Code has commands — `.claude/commands/*.md` prompt files. Anyone can make one. rhino-os has skills — commands that are **measured**.

A Claude Code command is a prompt. A rhino-os skill is a prompt that knows if it's good.

| | Claude Code command | rhino-os skill |
|---|---|---|
| Prompt file | ✓ | ✓ |
| Assertions that test it | | ✓ |
| Sub-scores (value/quality/ux) | | ✓ |
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

## `/skill list`

Not just names — show which skills are measured and how they're doing.

```
◆ skill — 18 skills

  ⎯⎯ measured (feature in rhino.yml) ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  /eval          ████████████░░░░░░░░  working   w:5  58 (v:62 q:50 u:60)
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
/feature detect         find skills that should be features
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
- Does an existing skill already cover this? Check `skills/*/SKILL.md` for overlap.

### Step 2: Create the skill

Once evidence is clear:

1. Create `skills/<name>/SKILL.md` with:
   - Frontmatter: name, description, argument-hint, allowed-tools
   - Routing table
   - State to read section
   - Output format (reference OUTPUT_FORMAT.md)
   - "What you never do" section
   - "If something breaks" section

2. Create `skills/<name>/reference.md` with output templates

### Step 3: Wire into measurement (this is what makes it a rhino-os skill)

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

### Step 4: Output

```
◆ skill create — <name>

  emerged from: "[the pattern they described]"

  ✓ skills/<name>/SKILL.md
  ✓ skills/<name>/reference.md
  ✓ config/rhino.yml — feature entry (w:[N], planned)
  ✓ beliefs.yml — 3 assertions seeded
  ✓ baseline eval: PARTIAL — [N] passing

  This skill is now measured. It has a score, assertions, and maturity
  tracking. When it reaches working maturity, it becomes a defensible
  claim in /roadmap narrative.

/go <name>         build it to working
/eval <name>       check current state
/feature <name>    see the full breakdown
```

## `/skill install <url>`

```bash
"$RHINO_DIR/bin/rhino" skill install "$URL"
```

After install:
1. Read the installed skill's SKILL.md
2. Check if it has a feature entry in rhino.yml — if not, create one
3. Check if it has assertions — if not, generate 2-3 mechanical ones
4. Run baseline eval
5. Suggest `/onboard` to wire up hooks/mind files if needed

**The install doesn't just add a file — it wires the skill into measurement.**

## `/skill remove <name>`

```bash
"$RHINO_DIR/bin/rhino" skill remove "$NAME"
```

After removal:
1. Mark the feature as `killed` in rhino.yml (don't delete — preserve history)
2. Note assertions that are now orphaned
3. Suggest `/onboard` to clean up

## `/skill info <name>`

Show the skill's full measurement profile:

```
◆ skill info — eval

  description: "Is my product good? Sub-scores, rubrics, multi-sample median."
  routes: deep · slop · taste · blind · coverage · trend · diff · vs
  allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebFetch

  ⎯⎯ measurement ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  feature: scoring (w:5, working)
  score: 58/100 (v:62 q:50 u:60) ↑4
  assertions: 10/11 passing
  rubric: .claude/cache/rubrics/scoring.json (fresh)

  ⎯⎯ files ⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
  skills/eval/SKILL.md      (320 lines)
  skills/eval/reference.md  (280 lines)

/eval              run it
/feature scoring   see the feature
/go scoring        improve it
```

## What you never do
- Create empty scaffold skills — evidence required
- Create a skill without wiring it into measurement (feature + assertions + baseline)
- Install a skill without checking for measurement wiring
- Delete feature entries on remove — mark killed, preserve history
- Let unmeasured skills stay unmeasured — flag them in `/skill list`

## If something breaks
- Install fails: check URL is a valid git repo with SKILL.md
- Remove fails: check `skills/` directory for exact name
- Founder can't articulate the pattern: too early — push back
- Name collision: show existing skill with `/skill info <name>`
- No rhino.yml features section: create it

$ARGUMENTS
