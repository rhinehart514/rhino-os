#!/usr/bin/env bash
# Detect project type and key files
set -euo pipefail
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "── project detection ──"
# Framework detection
[[ -f "$PROJECT_DIR/package.json" ]] && echo "  node: $(jq -r '.name // "unnamed"' "$PROJECT_DIR/package.json" 2>/dev/null)"
[[ -f "$PROJECT_DIR/Cargo.toml" ]] && echo "  rust: $(grep -m1 'name' "$PROJECT_DIR/Cargo.toml" | sed 's/.*= *//' | tr -d '"')"
[[ -f "$PROJECT_DIR/pyproject.toml" ]] && echo "  python: pyproject.toml"
[[ -f "$PROJECT_DIR/go.mod" ]] && echo "  go: $(head -1 "$PROJECT_DIR/go.mod" | awk '{print $2}')"
[[ -f "$PROJECT_DIR/Gemfile" ]] && echo "  ruby: Gemfile"
# Web framework
[[ -f "$PROJECT_DIR/next.config.js" || -f "$PROJECT_DIR/next.config.mjs" || -f "$PROJECT_DIR/next.config.ts" ]] && echo "  framework: next.js"
[[ -f "$PROJECT_DIR/nuxt.config.ts" ]] && echo "  framework: nuxt"
[[ -f "$PROJECT_DIR/svelte.config.js" ]] && echo "  framework: sveltekit"
[[ -f "$PROJECT_DIR/astro.config.mjs" ]] && echo "  framework: astro"
# Key files
echo ""
echo "  key files:"
for f in README.md CLAUDE.md config/rhino.yml; do
    [[ -f "$PROJECT_DIR/$f" ]] && echo "    ✓ $f" || echo "    · $f (missing)"
done
# Source structure
echo ""
echo "  source:"
for d in src app pages components lib bin skills; do
    [[ -d "$PROJECT_DIR/$d" ]] && echo "    $d/ ($(find "$PROJECT_DIR/$d" -type f | wc -l | tr -d ' ') files)"
done
