#!/usr/bin/env bash
# resolve-rhino-dir.sh — Resolve RHINO_DIR consistently across all scripts.
# Works in both plugin mode (CLAUDE_PLUGIN_ROOT) and repo mode.
#
# Usage (from any script):
#   source "$(dirname "$0")/lib/resolve-rhino-dir.sh" || source "$(dirname "$0")/../lib/resolve-rhino-dir.sh"
#   echo "$RHINO_DIR"  # guaranteed set
#
# For skill scripts in plugin cache:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "$SCRIPT_DIR/../../bin/lib/resolve-rhino-dir.sh" 2>/dev/null || {
#     # Fallback: walk up until we find bin/
#     ...
#   }

if [[ -n "${RHINO_DIR:-}" ]]; then
    # Already set (e.g. by a parent script)
    return 0 2>/dev/null || true
fi

if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    RHINO_DIR="$CLAUDE_PLUGIN_ROOT"
else
    # Walk up from the sourcing script to find the repo root (has bin/ and config/)
    _RESOLVE_SOURCE="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    while [[ -L "$_RESOLVE_SOURCE" ]]; do
        _RESOLVE_SOURCE="$(readlink "$_RESOLVE_SOURCE")"
    done
    _RESOLVE_DIR="$(cd "$(dirname "$_RESOLVE_SOURCE")" && pwd)"

    # Try common locations: bin/lib/, bin/, hooks/, hooks/lib/, skills/*/scripts/
    RHINO_DIR=""
    _check="$_RESOLVE_DIR"
    for _i in 1 2 3 4 5; do
        if [[ -d "$_check/bin" && -d "$_check/config" ]]; then
            RHINO_DIR="$_check"
            break
        fi
        _check="$(dirname "$_check")"
    done

    # Final fallback
    if [[ -z "$RHINO_DIR" ]]; then
        RHINO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
fi

export RHINO_DIR
