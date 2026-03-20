#!/usr/bin/env bash
# journey-weight.sh — Compute feature's journey position from topology.
# Returns JSON: { "position": "entry|core|leaf", "delivery_multiplier": N }
# Usage: bash scripts/journey-weight.sh <feature> [project-dir]
set -uo pipefail

FEATURE="${1:?Usage: journey-weight.sh <feature> [project-dir]}"
PROJECT_DIR="${2:-.}"
TOPOLOGY="$PROJECT_DIR/.claude/cache/topology.json"

# If no topology, generate it
if [[ ! -f "$TOPOLOGY" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    SHARED_DIR="$(cd "$SCRIPT_DIR/../../shared" && pwd)"
    if [[ -f "$SHARED_DIR/product-topology.sh" ]]; then
        bash "$SHARED_DIR/product-topology.sh" "$PROJECT_DIR" > /dev/null 2>&1
    fi
fi

if [[ ! -f "$TOPOLOGY" ]]; then
    echo '{"position":"unknown","delivery_multiplier":1.0,"inbound":0,"outbound":0}'
    exit 0
fi

# Read journey position from topology
python3 << PYEOF
import json, sys

topology_path = "$TOPOLOGY"
feature = "$FEATURE"

try:
    with open(topology_path) as f:
        topo = json.load(f)
except:
    print('{"position":"unknown","delivery_multiplier":1.0,"inbound":0,"outbound":0}')
    sys.exit(0)

positions = topo.get("journey_positions", {})
feat = positions.get(feature, {})

position = feat.get("position", "unknown")
inbound = feat.get("inbound", 0)
outbound = feat.get("outbound", 0)

# Multipliers: entry features matter most for delivery
multipliers = {
    "entry": 1.2,
    "core": 1.1,
    "leaf": 1.0,
    "unknown": 1.0
}

result = {
    "position": position,
    "delivery_multiplier": multipliers.get(position, 1.0),
    "inbound": inbound,
    "outbound": outbound
}

print(json.dumps(result))
PYEOF
