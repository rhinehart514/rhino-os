#!/usr/bin/env bash
# List knowledge gaps ranked by bottleneck relevance
# Usage: bash scripts/knowledge-gaps.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
echo "── knowledge gaps ──"
# Get bottleneck
BOTTLENECK=$("$RHINO_DIR/bin/compute-bottleneck.sh" 2>/dev/null | head -1 | cut -f1 || echo "")
[[ -n "$BOTTLENECK" ]] && echo "  bottleneck: $BOTTLENECK"
# Show unknowns
echo ""
"$RHINO_DIR/bin/detect-staleness.sh" 2>/dev/null | grep -A20 "unknown_territory:" || echo "  no unknowns found"
