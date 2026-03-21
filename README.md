# rhino-os

Product quality measurement for vibe-coded products.

You build with AI. rhino-os tells you if your product actually got better — automatically, while you work, without learning any commands.

Developers using AI coding tools think they're 20% more productive. [They're actually 19% less productive](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/). The gap is measurement — nobody checks whether AI-assisted work actually made the product better. rhino-os closes that gap.

## Install

```bash
claude /plugin marketplace add rhinehart514/rhino-os
claude /plugin install rhino-os@rhino-marketplace
```

That's it. Start a Claude Code session in any project. rhino-os works automatically.

**After install:** `cd your-project && claude`, then type `/onboard`. rhino-os reads your code, infers what it does, and gives you a score — no configuration needed.

**Requires:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), macOS or Linux, [jq](https://jqlang.github.io/jq/download/)

## What happens

You don't learn commands. You don't configure anything. You just code.

**While you code:**
- Every file edit is checked for missing error states, loading indicators, dead ends, and hardcoded secrets. Claude sees the warnings and fixes them in the next turn — you don't have to ask.
- After significant changes, product quality is measured automatically. If the score drops, you're told immediately.

**When you ask:**
- "Is this good?" → honest product quality score with specific gaps
- "What should I work on?" → finds the bottleneck, proposes the highest-leverage fix
- "Just build it" → autonomous build loop that measures after every change and reverts regressions

**Across sessions:**
- Every action starts with a prediction. Wrong predictions update the model. The system gets smarter over time.
- Session 1 is useful. Session 10 is significantly better — the knowledge model compounds.

## Real output: rhino-os running on itself

### "What should I work on?"

```
◆ plan

  score: 65 ●●○○○  · assertions: 61/62 · thesis: v9.4

  bottleneck: docs at 60 — weight:3, walkthrough stale, no quickstart
    delivery:62 craft:57

  move 1: update README with current data + add quickstart
    predict: "docs delivery moves from 62 to 72 in one session"
    acceptance: README opens with clear first action, not just features
```

### "Just build it"

```
◆ go — scoring

  predict: "contextual output + error communication → scoring d:70→78"
  because: "numbers without context is the #1 gap across all features"

  move 1: add context to score output
  ▾ commit
    built: assertions show "61/62 (98%) — 1 warning remaining"
           prediction accuracy shows "(target: 50-70%)"
    ✓ assertions pass  ✓ score held

  measure: scoring at 69 (d:72 c:65) ↑12
  grade: "Predicted d:70→78, got 72. Partial — right direction, magnitude off."
```

### The score compounds

```
Session 1:   26% complete  ·  48/63 assertions  ·  score 20
Session 10:  58% complete  ·  54/63 assertions  ·  score 45
Session 20:  74% complete  ·  56/62 assertions  ·  score 58
Session 38:  92% complete  ·  61/62 assertions  ·  score 65 ●●○○○
```

## How it works

rhino-os measures **product quality** (not code quality). It plants assertions (testable beliefs about your product, like "the signup flow completes in under 30 seconds"), scores them, and reverts changes that make things worse.

```
  Observe ─── what's the product state?
     │
  Model ───── what patterns explain it?
     │
  Predict ─── what will improve it?
     │
  Act ──────── build it
     │
  Measure ─── did it work?
     │
  Update ───── wrong predictions update the model
     │
     └──────── repeat ─── compounds across sessions
```

The score combines 5 measurement tiers — health, code eval, visual quality, behavioral testing, and market viability — into one honest number. Score goes up = you shipped value. Score drops = the change gets reverted.

**Reading the scores:** 90+ = genuinely excellent. 70-89 = solid, ships and works. 50-69 = works but has gaps. 30-49 = half-built. Below 30 = broken. Scores are honest — early-stage products scoring 75+ are flagged as suspicious.

## vs alternatives

- **CI / GitHub Actions** measure whether code passes tests. rhino-os measures whether the product delivers value.
- **SonarQube / CodeClimate** catch code smells. rhino-os catches product smells — features that don't deliver, craft that doesn't compound.
- **Linear / Jira** measure task throughput. rhino-os measures outcomes — a "done" task that drops the product score gets reverted automatically.
- **Cursor / Copilot** generate code. rhino-os measures whether the generated code helped, learns what works, and stops doing what doesn't.

## If you want more control

You don't need these — but they're there when you want to dig deeper.

- **"Is my product good?"** → `/score` (unified quality) or `/eval` (code-level detail)
- **"What should I work on?"** → `/plan` (find the bottleneck, propose the fix)
- **"Just build it"** → `/go` (autonomous build loop with measurement)

Type `/rhino help` to see them all. Or just talk naturally: "brainstorm ideas", "deploy", "what's the strategy" — rhino-os routes to the right command.

## On a fresh project

```
cd some-new-project
claude
> "set this up"

◆ onboard — some-new-project
  detected: Node.js web app, 12 routes, 3 API endpoints
  generated: 6 features, 10 assertions, initial roadmap
  score: 45 ●○○○○ — structural issues found, no eval data yet
```

No configuration. rhino-os reads your code, infers what it does, generates assertions, and gives you a score.

## Tested on

- **rhino-os itself** — score 20 to 65 over ~38 sessions, 61/62 assertions passing, 63% prediction accuracy
- **commander.js** — 80/100 on first init, zero configuration

## Troubleshooting

**`jq: command not found`** — `brew install jq` (macOS) or `sudo apt install jq` (Linux), then reinstall the plugin.

**Plugin not loading** — Check that `skills/rhino-mind/SKILL.md` exists in the plugin root. Run `./install.sh --test` to verify structure.

## Limitations

- **LLM eval variance.** Feature scores can vary ~15 points between runs. Multi-sample median reduces this.
- **macOS/Linux only.** No Windows support.
- **Claude Code required.** Doesn't work standalone or with other AI coding tools.
- **Solo founder optimized.** Assumes one person making decisions.

---

[MIT](LICENSE)
