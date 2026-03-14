---
description: "Manage rhino-os lenses (skills). List, install, remove, or inspect lenses."
---

# /skill — Lens Management

Route the user's intent to the right `rhino skill` subcommand.

## Routing

| Input | Action |
|-------|--------|
| `/skill` or `/skill list` | Run `rhino skill list` |
| `/skill install <url>` | Run `rhino skill install <url>` |
| `/skill remove <name>` | Run `rhino skill remove <name>` |
| `/skill info <name>` | Run `rhino skill info <name>` |

## Instructions

1. Parse the argument after `/skill` to determine the subcommand.
2. Run the corresponding `rhino skill` command via bash.
3. Display the output to the user.

### `/skill` (no args) or `/skill list`

```bash
"$RHINO_DIR/bin/rhino" skill list
```

Show installed lenses with their name, version, and description.

### `/skill install <url>`

```bash
"$RHINO_DIR/bin/rhino" skill install "$URL"
```

After install completes, suggest running `/init` to wire up the new lens's mind files and commands.

### `/skill remove <name>`

```bash
"$RHINO_DIR/bin/rhino" skill remove "$NAME"
```

After removal, suggest running `/init` to clean up stale symlinks.

### `/skill info <name>`

```bash
"$RHINO_DIR/bin/rhino" skill info "$NAME"
```

Display the lens.yml manifest and directory contents.

## Cross-references
- After install/remove → suggest `/init`
- To see measurement stack → `/rhino` (status)
- To evaluate with a new lens → `/eval`
