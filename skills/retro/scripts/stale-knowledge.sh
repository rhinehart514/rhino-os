#!/usr/bin/env bash
# Check knowledge model staleness for /retro
# Usage: bash scripts/stale-knowledge.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "── knowledge staleness ──"
"$RHINO_DIR/bin/detect-staleness.sh" 2>/dev/null
