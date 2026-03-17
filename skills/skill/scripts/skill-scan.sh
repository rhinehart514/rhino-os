#!/usr/bin/env bash
# Scan all skills for folder richness
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SKILLS_DIR="$PROJECT_DIR/skills"
echo "── skill scan ──"
echo ""
printf "  %-16s %5s %3s %3s %3s  %s\n" "skill" "lines" "scr" "ref" "tpl" "tier"
printf "  %-16s %5s %3s %3s %3s  %s\n" "─────" "─────" "───" "───" "───" "────"
for d in "$SKILLS_DIR"/*/; do
    [[ ! -f "$d/SKILL.md" ]] && continue
    NAME=$(basename "$d")
    LINES=$(wc -l < "$d/SKILL.md" | tr -d ' ')
    SCRIPTS=$(find "$d" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    REFS=$(find "$d" -path "*/references/*" -type f 2>/dev/null | wc -l | tr -d ' ')
    TMPLS=$(find "$d" -path "*/templates/*" -type f 2>/dev/null | wc -l | tr -d ' ')
    TOTAL_FILES=$(find "$d" -type f | wc -l | tr -d ' ')
    HAS_GOTCHAS=$([[ -f "$d/gotchas.md" ]] && echo "G" || echo "·")
    if [[ "$TOTAL_FILES" -ge 6 && "$SCRIPTS" -ge 1 ]]; then TIER="rich"
    elif [[ "$TOTAL_FILES" -ge 3 ]]; then TIER="basic"
    else TIER="bare"; fi
    printf "  %-16s %5s %3s %3s %3s  %-5s %s\n" "$NAME" "$LINES" "$SCRIPTS" "$REFS" "$TMPLS" "$TIER" "$HAS_GOTCHAS"
done
