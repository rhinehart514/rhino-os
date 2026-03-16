---
name: feature
description: "Work with features (DO). /feature lists them. /feature auth shows status. /feature new payments commits to building one. Not sure what to build? Use /ideate first."
argument-hint: "[name|new|detect] [name]"
allowed-tools: Read, Bash, Grep, Glob, Edit, AskUserQuestion, WebSearch
---

!cat .claude/cache/eval-cache.json 2>/dev/null | jq 'to_entries | map({key, score: .value.score, value: .value.value_score, quality: .value.quality_score, ux: .value.ux_score, delta: .value.delta}) | from_entries' 2>/dev/null || echo "no eval cache"

# /feature

Features are named parts of your product. Each has its own assertions, its own pass rate, its own score with decomposed sub-scores (value/quality/ux).

## Routing

Parse `$ARGUMENTS` and route:

**If $ARGUMENTS is ambiguous:**
1. Exact route keyword match wins (`new`, `detect`)
2. Feature name match (check rhino.yml features → show status)
3. Free-form topic (treat as feature name lookup)
Never ask "did you mean?" — just act.

### Feature status filter
Only show features with status `active` or `proven`. Skip `killed` and `archived` unless explicitly requested. Missing `status:` = `active`.

---

### No arguments → list all features
Run `rhino feature`. Read `config/rhino.yml` for maturity, weight, depends_on. Read `.claude/cache/eval-cache.json` for sub-scores (value_score, quality_score, ux_score) and deltas. Show maturity and weight alongside pass rates. Give one opinion: "**[worst feature]** needs attention" — worst = lowest maturity among highest-weight features.

### Feature name(s) → show status + suggest next action
One or more names: `/feature auth`, `/feature auth scoring cli`.

For each, run `rhino feature [name]`. Also read:
- `config/rhino.yml` for maturity, weight, depends_on
- `.claude/cache/eval-cache.json` for sub-scores and delta
- `.claude/cache/rubrics/<name>.json` for rubric (if exists)

Show maturity bar, weight, dependencies (upstream and downstream), sub-score breakdown.
- All passing → green
- Some failing → list them
- No assertions → define what it must do

Multiple features → show all, identify weakest.

### `detect` → find features in the codebase

1. Run `rhino feature detect` to get the initial list of detected modules
2. For each detected module, read 2-3 key files to understand what it does:
   - Entry point or main file (index.ts, main file, etc.)
   - Any test files or config files
3. Draft `delivers:` and `for:` descriptions from actual code reading (not guessing)
4. Estimate `weight:` based on centrality to the value hypothesis in rhino.yml:
   - Core to hypothesis → w:5
   - Supports core flow → w:3-4
   - Peripheral/utility → w:1-2
5. Cross-reference against existing `config/rhino.yml` features — skip already-declared ones
6. Present findings via AskUserQuestion: "Found N undeclared features — add all / pick / skip?"
7. For selected features: write to rhino.yml `features:` section, run `rhino eval . --feature [name] --fresh` for baseline

### `new [name]` → commit to building a specific feature

This is the DO step — you've decided what to build and you're tracking it. If you're not sure what to build yet, try `/ideate` first. If you're not sure the direction is right, try `/product` first.

**Use AskUserQuestion** to understand:

```
1. "What does [name] deliver to the user?"
   (The specific value. Not "handles auth" but "users can sign up, log in, and reset their password")
2. "Who specifically uses this?"
   (End users | Admins | Developers | The system itself)
3. "What code files are involved?" — options from codebase scan
4. "How important is this to the value hypothesis? (1-5)" → weight
5. "Does this depend on any existing features?" → depends_on
```

Write to `config/rhino.yml` under `features:`:

```yaml
features:
  [name]:
    delivers: "[what they said it delivers]"
    for: "[who they said uses it]"
    code: ["path/to/file1", "path/to/dir/"]
    weight: [1-5]
    maturity: planned
    depends_on: [feature_name]  # if applicable
```

Then:
1. Run `rhino eval . --feature [name] --fresh` for baseline (gets sub-scores)
2. Output verdict with sub-score breakdown

### `[name] research` → explore the feature's codebase and context

**Use WebSearch + codebase exploration** to understand:
1. Scan the codebase: find all files related to the feature (grep for name, trace imports, map dependencies)
2. Check external context: WebSearch for best practices, competitor approaches
3. Map what exists vs what's missing: which assertions pass? which don't? why?
4. Present findings with AskUserQuestion
5. Generate recommendations: new assertions, refactoring suggestions, or tasks

### `[name] status [value]` → lifecycle transition

Transition a feature's lifecycle status. Valid values: `active`, `proven`, `killed`, `archived`.

1. Validate the value is one of: active / proven / killed / archived
2. If `killed`: use AskUserQuestion to ask for the reason. Add `killed_reason:` and `killed_date:` to the feature entry
3. Update the feature's `status:` field in `config/rhino.yml`
4. Output: `[name] → [value]` with confirmation

For transition criteria, see the **Maturity Transition Rubric** in [STATE_MANIFEST.md](../STATE_MANIFEST.md).

### `[name] ideate` → brainstorm possibilities

1. Read the feature's current state (assertions, code, pass rate, sub-scores)
2. Identify weakest sub-score dimension — focus ideas there
3. Generate 3-4 ideas for improving or extending the feature
4. Present with AskUserQuestion showing what the code/experience would look like
5. Based on selection, generate assertions and tasks for the chosen direction

## State to read (parallel)

Before presenting results, read:
1. `config/rhino.yml` — feature definitions (delivers/for/code/maturity/weight/depends_on)
2. `.claude/cache/eval-cache.json` — sub-scores (value_score, quality_score, ux_score), deltas
3. `.claude/cache/rubrics/<feature>.json` — per-feature rubric (if exists, for detail view)
4. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/`) — predictions relevant to this feature
5. `.claude/plans/roadmap.yml` — check if feature is referenced in thesis evidence

For the full state source list, see [STATE_MANIFEST.md](../STATE_MANIFEST.md).

## Tools to use

**Use Bash** to run `rhino feature`, `rhino eval . --feature [name]`.
**Use Read** to check rhino.yml, eval-cache, rubrics, predictions.
**Use Grep/Glob** for codebase scanning in `detect` and `research` routes.
**Use Edit** to write feature entries to rhino.yml.
**Use AskUserQuestion** for `new` interviews, `detect` confirmation, `ideate` selection.
**Use WebSearch** for `research` route external context.

## System awareness
- `/feature [name]` (you) → define, manage, detect features
- `/eval [feature|deep|slop]` → run measurement stack (assertions, sub-scores, rubrics)
- `/ideate [feature|wild]` → brainstorm possibilities
- `/research [feature|topic]` → deep-dive research
- `/plan [feature]` → plan work for a feature
- `/go [feature]` → autonomous build loop

For output templates and formatting examples, see [reference.md](reference.md).

## What you never do
- Output raw CLI output without formatting — use the output templates
- Create features without asking what they deliver (use AskUserQuestion)
- Skip the baseline eval after creating a new feature
- Show scores without sub-score breakdown when eval-cache has them

## If something breaks
- `rhino feature` fails: read rhino.yml directly and list features under `features:` section
- No features in rhino.yml: suggest `/feature new [name]` to define one
- Falls back to beliefs.yml if no `features:` section in rhino.yml
- No eval-cache.json: run `rhino eval .` first to populate
- WebSearch fails: skip external context, work with codebase only

$ARGUMENTS
