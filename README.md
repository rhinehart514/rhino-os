# rhino-os

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that makes your product measurably better every session.

## Try it (2 minutes)

```bash
# 1. Install
claude /plugin marketplace add rhinehart514/rhino-os
claude /plugin install rhino-os@rhino-marketplace

# 2. Point it at your project
cd ~/your-project
claude
```

```
  ◆ rhino-os  ·  your-project
  score       20/100  ████░░░░░░░░░░░░░░░░
              assertions 2/10  ·  health 85
```

```
> /plan
  Bottleneck: auth — 0/3 assertions passing, weight 5
  Task: implement signup flow, write tests, handle edge cases

> /go
  Building auth...
  ✓ signup-completes        PASS
  ✓ login-works             PASS
  ✓ password-validation     PASS
  Score: 20 → 50 ↑30

  Building dashboard...
  ✓ dashboard-loads         PASS
  · data-displays           FAIL — empty state unhandled
  Score: 50 → 60 ↑10
```

`/plan` finds what's broken. `/go` fixes it — keeping what passes, reverting what doesn't.

That's it. Next session, it picks up where it left off, smarter than before.

---

**No plugin system?** Install manually:

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
```

Then: `cd ~/your-project && rhino init && claude`

**Requires:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), macOS/Linux, [jq](https://jqlang.github.io/jq/download/)

---

## What happens

You talk. rhino-os does the right thing.

| You say | It does |
|---------|---------|
| "what should I work on?" | `/plan` — finds the bottleneck |
| "just build it" | `/go` — autonomous build loop |
| "is this good?" | `/eval` — runs assertions, shows sub-scores |
| "what could we build?" | `/ideate` — evidence-weighted ideas + kill list |
| "am I building the right thing?" | `/product` — pressure-tests assumptions |
| "ship it" | `/ship` — commit, push, deploy, release |

19 commands total. Every one suggests what to do next. You don't need to memorize any of them.

## The score

The score is the percentage of your assertions that pass. Not lint. Not code quality. **Does your product do what you said it should do?**

```
  score       60/100  ████████████░░░░░░░░
              assertions 6/10  ·  health 90
              ↑40 from first session
```

Score goes up → you're shipping value. Score drops → the change gets reverted. Simple.

## It gets smarter

Most AI tools are stateless. Every session starts from zero.

rhino-os predicts before it acts. Measures after. Updates its model when it's wrong. Over sessions, it learns what works for *your* project specifically.

| Session | What happens |
|---------|-------------|
| 1 | Learns your project, generates assertions, baseline score |
| 5 | Predictions cite past results, bottleneck finder knows what matters |
| 20 | Dead ends marked, patterns confirmed, not guessing anymore |

70% prediction accuracy across 21 predictions. Built by using itself — score 20 to 93.

## What's inside

```
19 slash commands    /plan /go /eval /taste /feature /todo /assert /product
                     /ideate /research /strategy /roadmap /retro
                     /rhino /ship /onboard /skill /calibrate /clone

6 agents             builder  measurer  explorer
                     reviewer  evaluator  market-analyst

22 skills            auto-triggered behaviors + slash command definitions

8 hooks              session start, pre-compact, post-edit, post-commit, etc.

CLI                  rhino score .  rhino eval .  rhino taste
                     rhino feature  rhino todo  rhino trail
```

Uses the open [Agent Skills](https://claude.com/blog/skills) format. Works in Claude Code, Cursor, Codex CLI, and Gemini CLI.

## Tested on

- **rhino-os itself** — 20 → 93 over multiple sessions, 56/63 assertions passing
- **commander.js** — 80/100 on first `rhino init`, zero manual configuration

---

[MIT](LICENSE) · Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch), [SWE-bench](https://www.swebench.com/), [DORA metrics](https://dora.dev/)
