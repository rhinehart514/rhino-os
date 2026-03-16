# Plugin Install

## Install as a Claude Code plugin (recommended)

Inside Claude Code:

```
/plugin marketplace add rhinehart514/rhino-os
/plugin install rhino-os@rhino-marketplace
```

That's it. Commands, skills, agents, and hooks load automatically. No symlinks, no shell profile changes.

### Scopes

```
/plugin install rhino-os@rhino-marketplace                  # user scope (default, all projects)
/plugin install rhino-os@rhino-marketplace --scope project  # project scope (shared with team via git)
/plugin install rhino-os@rhino-marketplace --scope local    # local scope (gitignored)
```

### Auto-update (recommended)

After installing the marketplace, enable auto-update so you always get the latest:

```
/plugin marketplace update    # check for updates now
```

Claude Code checks for plugin updates at session start when auto-update is enabled for the marketplace. After an update, run `/reload-plugins` to activate changes without restarting.

### Manual update

```
/plugin install rhino-os@rhino-marketplace   # re-install pulls latest
```

Or for manual installs: `rhino update`

### Environment variables

- `FORCE_AUTOUPDATE_PLUGINS=true` — keep plugin auto-updates even if CLI auto-update is disabled
- `DISABLE_AUTOUPDATER` — disable all auto-updates (CLI and plugins)

## Install manually (legacy)

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
source ~/.zshrc
```

Manual install symlinks everything into `~/.claude/`. Updates are `rhino update` (pulls latest + refreshes symlinks).

## Dependencies

**Required:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working.

**Optional (for eval/taste):**
```bash
cd ~/rhino-os/bin && npm install        # yaml, js-yaml for eval
cd ~/rhino-os/lens/product/eval && npm install  # playwright for taste
```

Without these, `rhino score .` still works. `rhino eval .` and `rhino taste` need Node 18+.

## Get started

```bash
cd ~/your-project
claude                # start Claude Code — rhino-os boots automatically
```

Then type:
- `/plan` — find the bottleneck, get tasks
- `/go` — autonomous build loop
- `/eval` — check what's passing
- `/product` — product thinking session

## What gets installed

| Component | Files | Purpose |
|-----------|-------|---------|
| Commands | 19 slash commands | /plan, /go, /eval, /taste, /feature, /product, etc. |
| Skills | 22 skills | Command definitions, mind files, product lens, openclaw |
| Agents | 6 agents | builder, measurer, explorer, reviewer, evaluator, market-analyst |
| Hooks | 8 hooks | Boot card, quality checks, context recovery, pre-commit |

## Commands

| Command | What it does |
|---------|-------------|
| `/plan` | Find the bottleneck, write tasks |
| `/go` | Autonomous build — keeps what passes, reverts what doesn't |
| `/eval` | Run assertions, see what's working |
| `/taste` | Visual product intelligence — 0-100, market-calibrated, remembers |
| `/feature` | List features with pass rates, maturity, weights |
| `/product` | Product thinking — who, why, assumptions, focus |
| `/ideate` | Brainstorm what to build |
| `/init` | Bootstrap into a new project |
| `/ship` | Commit, push, deploy |
| `/research` | Explore unknown territory |
| `/roadmap` | Version theses and progress |
| `/strategy` | Stage, bottleneck, loop health |
| `/rhino` | Status dashboard |
| `/assert` | Add/list/check assertions |
| `/retro` | Grade predictions, close learning loop |
| `/todo` | Manage backlog across sessions |
| `/discover` | Product discovery — diagnose, ideate, validate in one pass |
| `/clone` | Screenshot → components |
| `/skill` | Manage lenses |

Full docs: [README.md](README.md)
