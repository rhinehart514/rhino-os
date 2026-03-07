#!/usr/bin/env bash
set -euo pipefail

# uninstall.sh — Remove claude-code-os symlinks from ~/.claude/
#
# What this does:
# 1. Removes symlinks that point back to this repo
# 2. Restores backups if they exist
# 3. Unloads LaunchAgents
#
# Does NOT delete your ~/.claude/ directory or any non-symlinked files.
#
# Usage: ./uninstall.sh [--restore-backup BACKUP_DIR]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
RESTORE_DIR=""

# Parse args
for arg in "$@"; do
    case $arg in
        --restore-backup)
            shift
            RESTORE_DIR="$1"
            shift
            ;;
        --help|-h)
            echo "Usage: ./uninstall.sh [--restore-backup BACKUP_DIR]"
            echo ""
            echo "Options:"
            echo "  --restore-backup DIR  Restore files from a backup directory"
            echo ""
            echo "Backup directories are at: ~/.claude/.backup-*"
            exit 0
            ;;
    esac
done

echo "=== claude-code-os uninstaller ==="
echo ""

remove_if_symlink_to_repo() {
    local target="$1"
    if [[ -L "$target" ]]; then
        local link_target
        link_target="$(readlink "$target")"
        if [[ "$link_target" == "$SCRIPT_DIR"* ]]; then
            rm "$target"
            echo "  removed: ${target#$CLAUDE_DIR/}"
        fi
    fi
}

# --- 1. Remove agent symlinks ---
echo "Removing agents..."
for agent in "$SCRIPT_DIR"/agents/*.md; do
    name="$(basename "$agent")"
    remove_if_symlink_to_repo "$CLAUDE_DIR/agents/$name"
done

# --- 2. Remove skill symlinks ---
echo "Removing skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name="$(basename "$skill_dir")"
    remove_if_symlink_to_repo "$CLAUDE_DIR/skills/$skill_name/SKILL.md"
done

# --- 3. Remove rule symlinks ---
echo "Removing rules..."
for rule in "$SCRIPT_DIR"/rules/*.md; do
    name="$(basename "$rule")"
    remove_if_symlink_to_repo "$CLAUDE_DIR/rules/$name"
done

# --- 4. Remove hook symlinks ---
echo "Removing hooks..."
for hook in "$SCRIPT_DIR"/hooks/*; do
    name="$(basename "$hook")"
    remove_if_symlink_to_repo "$CLAUDE_DIR/hooks/$name"
done

# --- 5. Remove eval rubric symlinks ---
echo "Removing eval rubrics..."
for rubric in "$SCRIPT_DIR"/evals/rubrics/*.md; do
    name="$(basename "$rubric")"
    remove_if_symlink_to_repo "$CLAUDE_DIR/evals/rubrics/$name"
done

# --- 6. Remove CLAUDE.md if it's our symlink ---
echo "Checking CLAUDE.md..."
remove_if_symlink_to_repo "$CLAUDE_DIR/CLAUDE.md"

# --- 7. Remove knowledge template link ---
remove_if_symlink_to_repo "$CLAUDE_DIR/knowledge/_template-README.md"

# --- 8. Unload LaunchAgents ---
if [[ "$(uname)" == "Darwin" ]]; then
    echo "Unloading LaunchAgents..."
    LAUNCH_DIR="$HOME/Library/LaunchAgents"
    for plist in com.claude-os.scout.plist com.claude-os.sweep.plist; do
        if [[ -f "$LAUNCH_DIR/$plist" ]]; then
            launchctl unload "$LAUNCH_DIR/$plist" 2>/dev/null || true
            rm "$LAUNCH_DIR/$plist"
            echo "  removed: $plist"
        fi
    done
fi

# --- 9. Restore backups if requested ---
if [[ -n "$RESTORE_DIR" && -d "$RESTORE_DIR" ]]; then
    echo ""
    echo "Restoring backups from: $RESTORE_DIR"
    # Use cp -a to preserve structure
    cp -a "$RESTORE_DIR"/* "$CLAUDE_DIR/" 2>/dev/null || true
    echo "  backups restored"
fi

# --- Done ---
echo ""
echo "=== Uninstall complete ==="
echo ""
echo "Removed: symlinks pointing to $SCRIPT_DIR"
echo "Preserved: all non-symlinked files in $CLAUDE_DIR/"
echo ""

# List available backups
BACKUPS=$(ls -d "$CLAUDE_DIR"/.backup-* 2>/dev/null || true)
if [[ -n "$BACKUPS" ]]; then
    echo "Available backups to restore:"
    for b in $BACKUPS; do
        echo "  $b"
    done
    echo ""
    echo "To restore: ./uninstall.sh --restore-backup <DIR>"
fi
