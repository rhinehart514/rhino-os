# rhino-os

**An AI cofounder for solo founders.** Not a tool that waits for commands — a cofounder that proposes what to build, pushes back with evidence, and learns from every cycle.

Built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch).

**Principle: Give it eyes, not rails.**

---

## Quick Start

```bash
# 1. Install
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh

# 2. Open any project in Claude Code
cd ~/your-project
claude
```

That's it. rhino-os boots automatically — loads identity, surfaces the next task, shows last score.

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval.

---

## How It Works

### The Mind (not instructions — identity)

Three files in `mind/` are always loaded via `.claude/rules/` symlinks:

| File | What it does |
|------|-------------|
| `identity.md` | Who you are. Cofounder behavior, measurement habits, learning protocol. |
| `thinking.md` | How you reason. Predict → Act → Measure → Update. The five rules. |
| `standards.md` | What quality means. UX checklist, anti-gaming heuristics, experiment discipline. |

No step-by-step workflows. No "Step 1, Step 2, Step 3." The cofounder reads the room and acts.

### Measurement (the eyes)

| Command | What it does |
|---------|-------------|
| `rhino score .` | Structural lint — build health, structure, hygiene. Fast, free, every change. |
| `rhino taste` | Visual eval — Playwright screenshots scored by Claude Vision. 11 dimensions. |
| `rhino eval` | Run belief evals against your product. |

### Anti-Gaming

- **Cosmetic-only detection** — Shuffled comments? Flagged.
- **Inflation cap** — 15+ point jump in one commit? Warning.
- **Plateau detection** — Score stuck after 5+ experiments? Rethink.

---

## CLI

```bash
rhino score [dir]     # Structural lint score
rhino taste [dir]     # Visual product eval (Claude Vision)
rhino eval [dir]      # Belief evals
rhino status          # Health overview
rhino config          # Show configuration
rhino install         # Install/update
```

---

## File Tree

```
rhino-os/
  mind/
    identity.md          who you are (~40 lines)
    thinking.md          how you reason (~100 lines)
    standards.md         what quality means (~70 lines)
  bin/
    rhino                CLI (score, taste, eval, status, config)
    score.sh             structural lint (720 lines)
    taste.mjs            visual eval (1138 lines)
    eval.sh              belief eval runner
    lib/config.sh        YAML config reader
  config/
    rhino.yml            all tunables
    settings.json        hooks config
  hooks/
    session_start.sh     boot card (~60 lines)
    post_edit.sh         catch bugs at write time
  corpus/                taste database (ui, copy, code)
  install.sh             one-command setup
```

---

## The Philosophy

**Before (v5):** 10 skill files tell Claude what to do step by step. Claude follows instructions.

**After (v6):** 3 mind files tell Claude who it is. Claude figures out what to do.

Process produces consistent mediocrity. Identity + measurement + epistemology produces excellence that compounds.

---

## Customization

Everything tunable in `config/rhino.yml`: scoring weights, taste dimensions, integrity ceilings, experiment discipline.

---

## License

[MIT](LICENSE)
