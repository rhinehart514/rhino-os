# rhino-os

Your product should get better every time you open your terminal. Not just more code — actually better.

rhino-os is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin. You install it, point it at your project, and it figures out what your product does, what's broken, and what to fix first. It predicts what will work, measures whether it did, and updates its model when it's wrong. Over sessions, it gets smarter about *your* product specifically.

Most AI coding tools help you write code faster. This one helps you build the right thing.

## See it work

```
$ cd ~/my-project && rhino init

  ◆ rhino init
  ✓ detected: node (src/)
  ✓ features: auth, dashboard, api (3 found)
  ✓ generated config/rhino.yml
  ✓ generated beliefs.yml (10 assertions)

  score  20/100  ████░░░░░░░░░░░░░░░░
```

The score is low because you just started. That's honest — you haven't proven your product works yet. Now open Claude Code:

```
$ claude

  ◆ rhino-os  ·  my-project
  score       20/100  ████░░░░░░░░░░░░░░░░
              assertions 2/10  ·  health 85

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
  Score: 50 → 60 ↑10 (reverted empty state regression, kept the rest)
```

`/plan` finds the bottleneck. `/go` builds toward it autonomously — keeping changes that improve the score, reverting changes that don't. Next session, it picks up where it left off, with a better model of what works.

## Install

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code), macOS/Linux, and [`jq`](https://jqlang.github.io/jq/download/).

**Plugin install:**
```bash
claude /plugin marketplace add https://github.com/rhinehart514/rhino-os
claude /plugin install rhino-os
```

**Manual install:**
```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
```

Then in any project: `rhino init` to bootstrap, `claude` to start working.

## What you can do

**Just talk.** Say "what should I work on?" and rhino-os runs `/plan`. Say "is this good?" and it runs `/eval`. Say "just build it" and it runs `/go`. You don't need to memorize commands — but here they are:

**Build:** `/plan` finds the bottleneck and writes tasks. `/go` builds autonomously. `/todo` manages backlog across sessions. `/assert` adds assertions from chat.

**Measure:** `/eval` runs assertions and shows sub-scores per feature. `rhino score .` gives you the number from the terminal. `rhino taste` runs visual eval via Claude Vision (11 dimensions — hierarchy, contrast, polish, density, and more).

**Think:** `/product` pressure-tests whether you're building the right thing. `/ideate` generates evidence-weighted ideas and kills what shouldn't exist. `/research` explores unknowns with multi-agent synthesis. `/strategy` gives you an honest, anti-sycophantic diagnosis of where you are.

**Navigate:** `/feature` manages features with maturity tracking and dependency graphs. `/roadmap` tracks version theses (versions are questions you're testing, not releases). `/retro` grades predictions and closes the learning loop. `/rhino` shows the dashboard.

**Ship:** `/ship` handles commit, push, deploy, and GitHub releases. `/onboard` bootstraps rhino-os into any repo. `/skill` creates new measured skills.

17 commands total. Every one suggests what to do next.

## The score

```
if build fails:              score = 0
elif health < 20:            score = 0
elif assertions exist:       score = assertion pass rate
elif value hypothesis exists: score = completion ratchet (0-50)
else:                        score = 10
```

The score is the percentage of your assertions that pass. Not lint. Not code quality. **Does your product do what you said it should do?**

Health (dead ends, `any` types, console.logs in production) is a gate, not the score. Health below 20 blocks you. Above 40, it's invisible. Fix health issues, but don't confuse them with value.

## How it learns

Every action has a prediction: "I predict X because Y. I'd be wrong if Z." Wrong predictions are the most valuable events — they update the model.

The knowledge lives in two files:
- `predictions.tsv` — every prediction, auto-graded against reality
- `experiment-learnings.md` — the causal model (known patterns, uncertain patterns, unknown territory, dead ends)

Target prediction accuracy: 50-70%. Higher means the predictions are too safe. Lower means the model is broken. rhino-os currently runs at 70% across 21 predictions.

You don't need to touch any of this. It happens automatically. But if you run `/retro`, you can see what the system learned and correct it.

## Architecture

```
rhino-os/
  mind/               how it thinks (identity, reasoning, standards, self-model)
  skills/             20 skills — slash commands + auto-triggered behaviors
  agents/             6 agents (builder, explorer, measurer, reviewer, evaluator, market-analyst)
  hooks/              9 lifecycle hooks (session start, pre-compact, post-edit, etc.)
  bin/                CLI tools (score.sh, eval.sh, grade.sh, feature.sh, todo.sh, etc.)
  config/rhino.yml    your project config — features, value hypothesis, signals
  lens/product/       product lens — taste eval, web-specific scoring, UX checklist
  tests/              mechanical tests + fixture repos
```

**Mind files** are loaded into every Claude Code session as system context. They define how rhino-os reasons — not step-by-step instructions, but identity, standards, and a thinking framework. Claude reads the room and acts like a cofounder, not an assistant.

**Skills** use the open [Agent Skills](https://claude.com/blog/skills) format. They work in Claude Code, Cursor, Codex CLI, and Gemini CLI.

**Agents** are specialists. `/go` spawns a builder (writes code) and a measurer (scores it). `/research` spawns an explorer and a market-analyst. Agents produce todos as exhaust — work they noticed but didn't do gets captured for later.

**Hooks** wire into Claude Code's lifecycle. Session start shows the boot card. Pre-compact saves context before compression. Post-edit runs quality checks. Post-commit validates. 9 hooks total, all in `hooks/`.

**The lens system** lets you add domain-specific measurement. The product lens adds visual eval (taste.mjs), web structure checks, and a UX checklist. Drop a new lens into `lens/` and `rhino init` wires it up.

## What makes this different

Most AI coding tools are stateless. Every session starts from zero. rhino-os compounds:

- **Session 1:** rhino-os learns your project structure, generates assertions, establishes a baseline score.
- **Session 5:** The knowledge model has patterns specific to your codebase. Predictions cite past results. The bottleneck finder knows which features matter most.
- **Session 20:** Wrong predictions have been graded, dead ends are marked, the model knows what works for your project and what doesn't. It's not guessing anymore.

The system was built by using itself. rhino-os improved rhino-os from score 20 to 93 across sessions, proving the loop compounds.

## Tested on

- **rhino-os itself** — score 20 to 93 over multiple sessions, 56/63 assertions passing
- **commander.js** — external project scored 80/100 on first `rhino init`, 8/10 assertions passing with zero manual configuration

## Version history

Versions are theses, not releases. Each one asks a question.

| Version | Question | Answer |
|---------|----------|--------|
| v6.0 | Does identity + measurement beat prescribed workflows? | Yes — cut 3,700 lines to 2,000, behavior emerged without instructions |
| v7.0 | Should the score measure value instead of health? | Yes — assertion pass rate tracks what actually matters |
| v8.0 | Can someone who isn't us complete a loop? | Yes — commander.js bootstrapped at 80/100 without help |
| v8.1 | Can every skill be measured and every agent produce work? | Yes — 17 skills with sub-scores, 6 agents producing todos |
| v9.0 | Can someone find rhino-os and install it without us? | Testing |

## Inspired by

[Karpathy's autoresearch](https://github.com/karpathy/autoresearch). [SWE-bench](https://www.swebench.com/). [DORA metrics](https://dora.dev/).

## License

[MIT](LICENSE)
