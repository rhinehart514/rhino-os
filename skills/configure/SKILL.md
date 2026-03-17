---
name: configure
description: "Tune rhino-os behavior — agent models, output verbosity, /go gates. One place to change everything."
argument-hint: "[show|agents|output|go|reset]"
allowed-tools: Read, Write, Bash, Grep, Glob, AskUserQuestion
context: fork
---

# /configure

One place to tune rhino-os behavior. Reads project config (rhino.yml) and user preferences (~/.claude/preferences.yml). Changes are written to preferences.yml — rhino.yml stays as the project-level source of truth.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) or `show` | Display current settings with behavioral explanations |
| `agents` | Interview: cost tier and autonomy level |
| `output` | Interview: output verbosity |
| `go` | Interview: hard gate and plateau threshold |
| `reset` | Delete preferences.yml, confirm |

**Ambiguity resolution:** Exact keyword match wins. Never ask "did you mean?" — just act.

## State Artifacts

| Artifact | Path | Read/Write | Purpose |
|----------|------|------------|---------|
| preferences | `~/.claude/preferences.yml` | R+W | User preferences |
| rhino.yml | `config/rhino.yml` | R | Project config |
| strategy | `.claude/plans/strategy.yml` | R | Current stage |

---

## Agent cost tier mapping

When `agents.cost` is set, skills that spawn agents resolve the model tier from this table:

| Agent | economy | balanced | premium |
|-------|---------|----------|---------|
| builder | sonnet | opus | opus |
| evaluator | sonnet | opus | opus |
| market-analyst | sonnet | opus | opus |
| explorer | haiku | sonnet | opus |
| grader | haiku | sonnet | opus |
| debugger | haiku | sonnet | opus |
| refactorer | haiku | sonnet | opus |
| measurer | haiku | haiku | sonnet |
| reviewer | haiku | haiku | sonnet |

**balanced** is the default — opus for hard work, sonnet for research, haiku for measurement.

---

## Route: show (default)

Read in parallel:
1. `~/.claude/preferences.yml` — user preferences
2. `config/rhino.yml` — project config (go section, project section)
3. `.claude/plans/strategy.yml` — current stage

Display all current settings with behavioral explanations. Show which values come from preferences vs rhino.yml defaults. See [reference.md](reference.md) for output template.

---

## Route: agents

Interview pattern using AskUserQuestion.

### Step 1 — Cost tier

Ask: "How do you want to balance cost vs capability?"

Options:
- **economy** — haiku/sonnet for everything. Cheapest. Good for exploration and low-stakes work.
- **balanced** — opus for hard work (builder, evaluator), sonnet for research, haiku for measurement. Default.
- **premium** — opus/sonnet for everything. Most capable. Use when quality matters more than cost.

### Step 2 — Autonomy level

Ask: "How much autonomy should /go have?"

Options:
- **supervised** — /go requires approval before each move (hard gate ON). Default.
- **autonomous** — /go presents the plan but doesn't wait for approval. Still reports results.
- **full-auto** — /go runs silently until plateau or completion. Sends summary at end.

### Step 3 — Write

Write `agents.cost` and `agents.autonomy` to `~/.claude/preferences.yml`. Merge with existing preferences — don't overwrite other sections.

Show confirmation with the resolved agent models from the tier table.

---

## Route: output

Interview pattern using AskUserQuestion.

Ask: "How verbose should output be?"

Options:
- **quiet** — headers + scores + bottom commands only. No section details.
- **normal** — standard output templates. Default.
- **verbose** — full details, all sections expanded, all evidence shown.

Write `output.verbosity` to `~/.claude/preferences.yml`.

---

## Route: go

Interview pattern using AskUserQuestion.

### Step 1 — Hard gate

Ask: "Should /go require approval before each move?"

Options:
- **yes** — must approve each move before building. Safer. Default.
- **no** — presents the plan but builds immediately. Faster.

### Step 2 — Plateau threshold

Ask: "How many flat moves before /go stops? (default: 3)"

Accept a number 1-10. Default: 3.

### Step 3 — Write

Write `go.hard_gate` (boolean) and `go.plateau_threshold` (number) to `~/.claude/preferences.yml`.

---

## Route: reset

1. Check if `~/.claude/preferences.yml` exists
2. If yes: show current contents, ask for confirmation via AskUserQuestion
3. If confirmed: delete the file
4. If no: "No preferences.yml to reset. Already using defaults."

Show the defaults that will be in effect after reset.

---

## Degraded modes

- **No preferences.yml**: show defaults from rhino.yml and hardcoded balanced tier. This is the normal first-run state.
- **No rhino.yml**: show only preferences (if they exist) and hardcoded defaults. Warn: "No rhino.yml found — project-level settings unavailable."
- **No strategy.yml**: skip stage display, show "stage: unknown" in output.

---

## What you never do

- Modify rhino.yml — it's the project-level source of truth, not user preferences
- Set preferences without the interview — always confirm with the user
- Skip the confirmation on reset
- Write preferences that contradict rhino.yml without explaining the override
- Recommend config changes to fix scores — the config isn't the problem

## Anti-rationalization

- **Don't set economy to save money when quality matters.** If eval scores are low and the builder is producing weak code, switching to economy makes it worse. Economy is for exploration and low-stakes iteration.
- **Don't set full-auto to avoid the hard gate friction.** The hard gate exists because "obvious" moves have the highest skip-regret rate. If you're annoyed by the gate, that's a signal the moves aren't well-defined — fix the plan, not the gate.
- **Don't change config to fix scores.** If scores are low, the product needs work, not the configuration. /configure changes HOW the system operates, not WHAT it produces.

For output templates, see [reference.md](reference.md).
For output format rules, see [OUTPUT_FORMAT.md](../OUTPUT_FORMAT.md).

$ARGUMENTS
