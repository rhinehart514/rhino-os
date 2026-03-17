#!/usr/bin/env bash
# version-history.sh — Shows all versions with thesis/status. The project timeline.
# Usage: version-history.sh [project-dir] [version-filter]
# Examples:
#   version-history.sh .           → all versions
#   version-history.sh . v7.0      → just v7.0
set -euo pipefail

PROJECT_DIR="${1:-${CLAUDE_PROJECT_DIR:-.}}"
VERSION_FILTER="${2:-}"
ROADMAP="$PROJECT_DIR/.claude/plans/roadmap.yml"

echo "── version history ──"

if [[ ! -f "$ROADMAP" ]]; then
    echo "  no roadmap.yml"
    exit 0
fi

CURRENT=$(grep -m1 '^current:' "$ROADMAP" 2>/dev/null | sed 's/^current: *//' | tr -d ' ' || echo "?")

# If filtering to one version, show detail view
if [[ -n "$VERSION_FILTER" ]]; then
    V="$VERSION_FILTER"
    # Check version exists
    if ! grep -qE "^  ${V}:" "$ROADMAP" 2>/dev/null; then
        echo "  version $V not found"
        echo "  available:"
        grep -E '^  v[0-9]+\.[0-9]+' "$ROADMAP" | sed 's/://;s/^ */    /'
        exit 1
    fi

    # Extract fields for this version
    THESIS=$(awk "/^  ${V}:/{found=1} found && /thesis:/{print; exit}" "$ROADMAP" | sed 's/.*thesis: *//' | sed 's/"//g')
    TIER=$(awk "/^  ${V}:/{found=1} found && /tier:/{print; exit}" "$ROADMAP" | sed 's/.*tier: *//')
    STATUS=$(awk "/^  ${V}:/{found=1} found && /status:/{print; exit}" "$ROADMAP" | sed 's/.*status: *//')
    PROVEN_DATE=$(awk "/^  ${V}:/{found=1} found && /proven:/{print; exit}" "$ROADMAP" | sed 's/.*proven: *//')
    SUMMARY=$(awk "/^  ${V}:/{found=1} found && /summary:/{print; exit}" "$ROADMAP" | sed 's/.*summary: *//' | sed 's/"//g')
    PARENT=$(awk "/^  ${V}:/{found=1} found && /parent:/{print; exit}" "$ROADMAP" | sed 's/.*parent: *//')

    case "${STATUS:-unknown}" in
        proven) ICON="✓" ;;
        testing|active) ICON="▸" ;;
        abandoned) ICON="✗" ;;
        *) ICON="·" ;;
    esac

    echo ""
    echo "  $ICON $V [${TIER:-?}] — \"${THESIS}\""
    echo "    status: ${STATUS:-unknown}"
    [[ -n "${PROVEN_DATE}" ]] && echo "    proven: $PROVEN_DATE"
    [[ -n "${SUMMARY}" ]] && echo "    summary: $SUMMARY"
    [[ -n "${PARENT}" ]] && echo "    parent: $PARENT"
    [[ "$V" == "$CURRENT" ]] && echo "    ** current version **"

    # Show child versions
    echo ""
    echo "  ▾ child versions"
    HAS_CHILDREN=0
    while IFS= read -r child_line; do
        CHILD_V=$(echo "$child_line" | sed 's/://;s/^ *//')
        CHILD_PARENT=$(awk "/^  ${CHILD_V}:/{found=1} found && /parent:/{print; exit}" "$ROADMAP" | sed 's/.*parent: *//')
        if [[ "$CHILD_PARENT" == "$V" ]]; then
            CHILD_THESIS=$(awk "/^  ${CHILD_V}:/{found=1} found && /thesis:/{print; exit}" "$ROADMAP" | sed 's/.*thesis: *//' | sed 's/"//g')
            CHILD_TIER=$(awk "/^  ${CHILD_V}:/{found=1} found && /tier:/{print; exit}" "$ROADMAP" | sed 's/.*tier: *//')
            CHILD_STATUS=$(awk "/^  ${CHILD_V}:/{found=1} found && /status:/{print; exit}" "$ROADMAP" | sed 's/.*status: *//')
            case "${CHILD_STATUS:-?}" in
                proven) CI="✓" ;;
                testing|active) CI="▸" ;;
                *) CI="·" ;;
            esac
            echo "    $CI $CHILD_V [${CHILD_TIER:-?}] — \"${CHILD_THESIS}\""
            HAS_CHILDREN=1
        fi
    done < <(grep -E '^  v[0-9]+\.[0-9]+' "$ROADMAP")
    [[ $HAS_CHILDREN -eq 0 ]] && echo "    (none)"

    echo ""
    echo "── end history ──"
    exit 0
fi

# Full timeline view
echo "  current: $CURRENT"
echo ""

while IFS= read -r ver_line; do
    V=$(echo "$ver_line" | sed 's/://;s/^ *//')

    THESIS=$(awk "/^  ${V}:/{found=1} found && /thesis:/{print; exit}" "$ROADMAP" | sed 's/.*thesis: *//' | sed 's/"//g')
    TIER=$(awk "/^  ${V}:/{found=1} found && /tier:/{print; exit}" "$ROADMAP" | sed 's/.*tier: *//')
    STATUS=$(awk "/^  ${V}:/{found=1} found && /status:/{print; exit}" "$ROADMAP" | sed 's/.*status: *//')
    PROVEN_DATE=$(awk "/^  ${V}:/{found=1} found && /proven:/{print; exit}" "$ROADMAP" | sed 's/.*proven: *//')
    SUMMARY=$(awk "/^  ${V}:/{found=1} found && /summary:/{print; exit}" "$ROADMAP" | sed 's/.*summary: *//' | sed 's/"//g')
    PARENT=$(awk "/^  ${V}:/{found=1} found && /parent:/{print; exit}" "$ROADMAP" | sed 's/.*parent: *//')

    case "${STATUS:-unknown}" in
        proven) ICON="✓" ;;
        testing|active) ICON="▸" ;;
        abandoned) ICON="✗" ;;
        *) ICON="·" ;;
    esac

    # Indent patches/minors under parents
    INDENT=""
    [[ -n "$PARENT" ]] && INDENT="  "

    DATE_SUFFIX=""
    [[ -n "$PROVEN_DATE" ]] && DATE_SUFFIX=" · $PROVEN_DATE"

    echo "  ${INDENT}$ICON $V [${TIER:-?}] — \"${THESIS}\"${DATE_SUFFIX}"

    # Summary for proven versions
    if [[ "$STATUS" == "proven" ]] && [[ -n "$SUMMARY" ]]; then
        echo "  ${INDENT}  ${SUMMARY}"
    fi

    [[ "$V" == "$CURRENT" ]] && echo "  ${INDENT}  ** current **"
done < <(grep -E '^  v[0-9]+\.[0-9]+' "$ROADMAP")

# Thesis arc — major versions only
echo ""
echo "  ▾ thesis arc"
ARC=""
while IFS= read -r ver_line; do
    V=$(echo "$ver_line" | sed 's/://;s/^ *//')
    TIER=$(awk "/^  ${V}:/{found=1} found && /tier:/{print; exit}" "$ROADMAP" | sed 's/.*tier: *//')
    if [[ "$TIER" == "major" ]]; then
        THESIS=$(awk "/^  ${V}:/{found=1} found && /thesis:/{print; exit}" "$ROADMAP" | sed 's/.*thesis: *//' | sed 's/"//g' | cut -c1-50)
        [[ -n "$ARC" ]] && ARC="$ARC → "
        ARC="${ARC}${V}"
    fi
done < <(grep -E '^  v[0-9]+\.[0-9]+' "$ROADMAP")
echo "    $ARC"

# Velocity — days between proven major versions
echo ""
echo "  ▾ velocity"
PREV_DATE=""
PREV_V=""
while IFS= read -r ver_line; do
    V=$(echo "$ver_line" | sed 's/://;s/^ *//')
    TIER=$(awk "/^  ${V}:/{found=1} found && /tier:/{print; exit}" "$ROADMAP" | sed 's/.*tier: *//')
    PROVEN_DATE=$(awk "/^  ${V}:/{found=1} found && /proven:/{print; exit}" "$ROADMAP" | sed 's/.*proven: *//')
    if [[ "$TIER" == "major" ]] && [[ -n "$PROVEN_DATE" ]]; then
        if [[ -n "$PREV_DATE" ]]; then
            D1=$(date -j -f "%Y-%m-%d" "$PREV_DATE" +%s 2>/dev/null || echo "")
            D2=$(date -j -f "%Y-%m-%d" "$PROVEN_DATE" +%s 2>/dev/null || echo "")
            if [[ -n "$D1" ]] && [[ -n "$D2" ]]; then
                DAYS=$(( (D2 - D1) / 86400 ))
                echo "    $PREV_V → $V: ${DAYS}d"
            fi
        fi
        PREV_DATE="$PROVEN_DATE"
        PREV_V="$V"
    fi
done < <(grep -E '^  v[0-9]+\.[0-9]+' "$ROADMAP")

echo ""
echo "── end history ──"
