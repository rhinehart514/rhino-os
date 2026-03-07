# Customization Guide

How to make claude-code-os yours.

## First Steps After Install

### 1. Edit CLAUDE.md
The most important file. Open `~/.claude/CLAUDE.md` and replace:
- `[YOUR PROJECT]` with your project name
- `[YOUR USERS]` with your target user description
- Add project-specific context, conventions, and constraints

### 2. Configure MCP Servers
Edit `~/.claude/config.json` to add your MCP servers. The installer preserves existing servers and merges new ones.

### 3. Update Settings
Edit `~/.claude/settings.json` to add:
- Additional hooks
- Plugin configurations
- Custom environment variables

## Adding a New Agent

1. Create a file in `~/claude-code-os/agents/[name].md`:

```markdown
---
name: my-agent
description: What this agent does. When to use it.
model: sonnet  # or haiku, opus, inherit
tools:
  - Read
  - Grep
  - Glob
  # Add Write, Edit, Bash only if needed
color: blue  # optional: visual identification
---

Your agent prompt here. Be specific about:
- What context to load first
- What steps to follow
- What output format to produce
- What safety constraints apply
```

2. Run `./install.sh` to symlink the new agent
3. Test: `claude --agent my-agent "test prompt"`

## Adding a New Skill

1. Create a directory: `~/claude-code-os/skills/[name]/`
2. Create `SKILL.md`:

```markdown
---
name: my-skill
description: What this skill does
user-invocable: true  # if you want /my-skill to work
---

# Skill Instructions

Steps for the skill to follow...
```

3. Run `./install.sh` to symlink
4. Use: `/my-skill` in Claude Code

## Adding a New Rule

1. Create a file in `~/claude-code-os/rules/[name].md`:

```markdown
---
paths:
  - "**/*.tsx"
  - "**/*.ts"
---

# Rule Name

Rules automatically loaded when working on files matching the paths above.
```

2. Run `./install.sh` to symlink

## Creating a Learning Agent

See [KNOWLEDGE-SYSTEMS.md](KNOWLEDGE-SYSTEMS.md) for the full pattern.

Quick version:
1. Copy `knowledge/_template/` to `knowledge/[agent-name]/`
2. Create `agents/[agent-name].md` with read-first, eval-last pattern
3. Create `evals/rubrics/[agent-name]-rubric.md`
4. Run `./install.sh`

## Adding Automation

### macOS LaunchAgent

1. Create a script in `automation/scripts/[name].sh`
2. Create a plist in `automation/launchd/com.claude-os.[name].plist`
3. Run `./install.sh` to install the LaunchAgent

### Cron (Linux)

Add to crontab:
```bash
# Daily morning sweep at 8am
0 8 * * * $HOME/claude-code-os/automation/scripts/morning-sweep.sh

# Weekly scout on Mondays at 6am
0 6 * * 1 $HOME/claude-code-os/automation/scripts/run-scout.sh
```

## Customizing the Dispatch Taxonomy

Edit the morning-sweep agent to adjust which actions are GREEN/YELLOW/RED:
- Make your own actions GREEN if they're truly safe for your workflow
- Escalate anything you're uncomfortable automating to RED

## Project-Specific Agents

You can have agents in both:
- `~/.claude/agents/` — OS-level agents (from this repo)
- `.claude/agents/` — project-specific agents (in each repo)

The install script symlinks individual files, not directories, so project-specific agents coexist with OS agents.

## Keeping Up to Date

```bash
cd ~/claude-code-os
git pull
./install.sh  # re-run to pick up new agents, skills, etc.
```

The installer is idempotent — safe to re-run. It only overwrites symlinks pointing to this repo and merges config files.

## Removing Specific Components

Don't want an agent? Delete its symlink:
```bash
rm ~/.claude/agents/night-watch.md
```

Or remove it from the repo and re-run `./install.sh`.

To fully uninstall: `./uninstall.sh`
