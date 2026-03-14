#!/usr/bin/env bash
# feature.sh — List, view, and detect features
# Primary: reads features from rhino.yml features: section
# Fallback: reads from beliefs.yml if no features: section
set -euo pipefail

_FEAT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_FEAT_SOURCE" ]]; do _FEAT_SOURCE="$(readlink "$_FEAT_SOURCE")"; done
RHINO_DIR="$(cd "$(dirname "$_FEAT_SOURCE")/.." && pwd)"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# Detect feature source
HAS_FEATURES_YML=false
if [[ -f "config/rhino.yml" ]] && grep -q '^features:' "config/rhino.yml" 2>/dev/null; then
    HAS_FEATURES_YML=true
fi

# Find beliefs file (fallback)
BELIEFS_FILE=""
for bf in "lens/product/eval/beliefs.yml" "config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS_FILE="$bf" && break
done

# Get features from rhino.yml features: section
get_features_yml() {
    local in_features=false
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        if echo "$line" | grep -q '^features:'; then
            in_features=true
            continue
        fi
        if [[ "$in_features" == true ]] && echo "$line" | grep -qE '^[a-z]'; then
            break
        fi
        [[ "$in_features" != true ]] && continue
        if echo "$line" | grep -qE '^  [a-z][a-z0-9_-]*:$'; then
            echo "$line" | sed 's/^[[:space:]]*//;s/:[[:space:]]*$//'
        fi
    done < "config/rhino.yml"
}

# Get delivers: value for a feature
get_feature_delivers() {
    local feat="$1"
    local in_feat=false
    while IFS= read -r line; do
        if echo "$line" | grep -qE "^  ${feat}:\$"; then
            in_feat=true
            continue
        fi
        if [[ "$in_feat" == true ]] && echo "$line" | grep -qE '^  [a-z]'; then
            break
        fi
        [[ "$in_feat" != true ]] && continue
        if echo "$line" | grep -q '^\s*delivers:'; then
            echo "$line" | sed 's/.*delivers: *//;s/^"//;s/"$//'
            return
        fi
    done < "config/rhino.yml"
}

# Get for: value for a feature
get_feature_for() {
    local feat="$1"
    local in_feat=false
    while IFS= read -r line; do
        if echo "$line" | grep -qE "^  ${feat}:\$"; then
            in_feat=true
            continue
        fi
        if [[ "$in_feat" == true ]] && echo "$line" | grep -qE '^  [a-z]'; then
            break
        fi
        [[ "$in_feat" != true ]] && continue
        if echo "$line" | grep -q '^\s*for:'; then
            echo "$line" | sed 's/.*for: *//;s/^"//;s/"$//'
            return
        fi
    done < "config/rhino.yml"
}

# Get features from beliefs.yml (fallback)
get_features_beliefs() {
    [[ -z "$BELIEFS_FILE" ]] && return
    grep '^\s*feature:' "$BELIEFS_FILE" 2>/dev/null | sed 's/.*feature: *//' | sort -u
}

# === List all features ===
cmd_list() {
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}features${NC}"
    echo ""

    if [[ "$HAS_FEATURES_YML" == true ]]; then
        # Read from rhino.yml features: section
        local features
        features=$(get_features_yml)

        if [[ -z "$features" ]]; then
            echo -e "  ${DIM}No features defined in rhino.yml features: section${NC}"
            echo ""
            return
        fi

        # Read eval cache for verdicts
        local cache=".claude/cache/eval-cache.json"

        while IFS= read -r feat; do
            [[ -z "$feat" ]] && continue
            local delivers verdict color icon

            delivers=$(get_feature_delivers "$feat")

            if [[ -f "$cache" ]] && command -v jq &>/dev/null; then
                verdict=$(jq -r ".\"$feat\".verdict // \"—\"" "$cache" 2>/dev/null) || verdict="—"
            else
                verdict="—"
            fi

            case "$verdict" in
                DELIVERS) color="$GREEN"; icon="✓" ;;
                PARTIAL)  color="$YELLOW"; icon="·" ;;
                MISSING)  color="$RED"; icon="✗" ;;
                *)        color="$DIM"; icon="?" ;;
            esac

            printf "  ${color}${icon}${NC} ${BOLD}%-14s${NC} %s\n" "$feat" "${delivers:0:60}"
        done <<< "$features"
    else
        # Fallback: beliefs.yml
        local features
        features=$(get_features_beliefs)

        if [[ -z "$features" ]]; then
            echo -e "  ${DIM}No features defined. Add features: to rhino.yml${NC}"
            echo -e "  ${DIM}or run: rhino feature detect${NC}"
            echo ""
            return
        fi

        # Read from score cache if available
        local cache=".claude/cache/score-cache.json"

        while IFS= read -r feat; do
            [[ -z "$feat" ]] && continue
            local pass total pct color bar

            if [[ -f "$cache" ]] && command -v jq &>/dev/null; then
                pass=$(jq -r ".features.\"$feat\".pass // 0" "$cache" 2>/dev/null) || pass=0
                total=$(jq -r ".features.\"$feat\".total // 0" "$cache" 2>/dev/null) || total=0
            else
                total="?"
                pass="?"
            fi

            if [[ "$total" -gt 0 && "$pass" != "?" ]]; then
                pct=$((pass * 100 / total))
                if [[ "$pct" -ge 70 ]]; then color="$GREEN"
                elif [[ "$pct" -ge 40 ]]; then color="$YELLOW"
                else color="$RED"
                fi
                local filled=$((pct / 10)) empty=$((10 - pct / 10))
                bar=""
                for ((i=0; i<filled; i++)); do bar+="█"; done
                for ((i=0; i<empty; i++)); do bar+="░"; done
                printf "  %-14s ${color}${bar}${NC}  %s/%s\n" "$feat" "$pass" "$total"
            else
                printf "  %-14s ${DIM}no eval data${NC}\n" "$feat"
            fi
        done <<< "$features"
    fi

    echo ""
}

# === View one feature ===
cmd_view() {
    local feat="$1"
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}$feat${NC}"
    echo ""

    if [[ "$HAS_FEATURES_YML" == true ]]; then
        local delivers for_whom
        delivers=$(get_feature_delivers "$feat")
        for_whom=$(get_feature_for "$feat")

        if [[ -n "$delivers" ]]; then
            echo -e "  ${DIM}delivers:${NC} $delivers"
            echo -e "  ${DIM}for:${NC} $for_whom"
            echo ""
        fi

        # Check eval cache for last verdict
        local cache=".claude/cache/eval-cache.json"
        if [[ -f "$cache" ]] && command -v jq &>/dev/null; then
            local verdict gaps
            verdict=$(jq -r ".\"$feat\".verdict // empty" "$cache" 2>/dev/null)
            if [[ -n "$verdict" ]]; then
                case "$verdict" in
                    DELIVERS) echo -e "  ${GREEN}✓ DELIVERS${NC}" ;;
                    PARTIAL)  echo -e "  ${YELLOW}· PARTIAL${NC}" ;;
                    MISSING)  echo -e "  ${RED}✗ MISSING${NC}" ;;
                esac
                gaps=$(jq -r ".\"$feat\".gaps // [] | .[]" "$cache" 2>/dev/null)
                if [[ -n "$gaps" ]]; then
                    echo ""
                    echo -e "  ${DIM}gaps:${NC}"
                    echo "$gaps" | while IFS= read -r gap; do
                        [[ -n "$gap" ]] && echo -e "    ${YELLOW}·${NC} $gap"
                    done
                fi
            else
                echo -e "  ${DIM}no eval data — run: rhino eval .${NC}"
            fi
        else
            echo -e "  ${DIM}no eval data — run: rhino eval .${NC}"
        fi
    else
        # Fallback: run eval for this feature from beliefs.yml
        if [[ -z "$BELIEFS_FILE" ]]; then
            echo -e "  ${DIM}No beliefs.yml found${NC}"
            echo ""
            return
        fi

        local eval_output
        eval_output=$("$RHINO_DIR/bin/eval.sh" . --feature "$feat" 2>/dev/null) || eval_output=""

        if [[ -n "$eval_output" ]]; then
            echo "$eval_output" | grep '^\s*\[' | while IFS= read -r line; do
                if echo "$line" | grep -q '\[PASS\]'; then
                    echo -e "    ${GREEN}✓${NC} $(echo "$line" | sed 's/.*\[PASS\] //')"
                elif echo "$line" | grep -q '\[FAIL\]'; then
                    echo -e "    ${RED}✗${NC} $(echo "$line" | sed 's/.*\[FAIL\] //')"
                elif echo "$line" | grep -q '\[WARN\]'; then
                    echo -e "    ${YELLOW}⚠${NC} $(echo "$line" | sed 's/.*\[WARN\] //')"
                fi
            done
        else
            echo -e "  ${DIM}No assertions for feature '$feat'${NC}"
        fi
    fi

    echo ""
}

# === Detect features from codebase ===
cmd_detect() {
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}feature detect${NC}"
    echo ""

    local found=0

    # Next.js route groups: app/(group)/
    if [[ -d "app" ]]; then
        for d in app/\(*/; do
            [[ ! -d "$d" ]] && continue
            local name
            name=$(basename "$d" | tr -d '()')
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(route group: $d)${NC}"
            found=$((found + 1))
        done
    fi

    # Top-level src directories
    if [[ -d "src" ]]; then
        for d in src/*/; do
            [[ ! -d "$d" ]] && continue
            local name
            name=$(basename "$d")
            [[ "$name" == "components" || "$name" == "lib" || "$name" == "utils" || "$name" == "styles" || "$name" == "types" ]] && continue
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(src directory: $d)${NC}"
            found=$((found + 1))
        done
    fi

    # Package.json workspaces
    if [[ -f "package.json" ]] && grep -q '"workspaces"' package.json 2>/dev/null; then
        for ws in packages/*/; do
            [[ ! -d "$ws" ]] && continue
            local name
            name=$(basename "$ws")
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(workspace: $ws)${NC}"
            found=$((found + 1))
        done
    fi

    # CLI project: named scripts in bin/
    if [[ -d "bin" ]]; then
        for f in bin/*.sh bin/*.mjs; do
            [[ ! -f "$f" ]] && continue
            local name
            name=$(basename "$f" | sed 's/\.[^.]*$//')
            [[ "$name" == "rhino" || "$name" == "lib" ]] && continue
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(script: $f)${NC}"
            found=$((found + 1))
        done
    fi

    # Show existing features
    if [[ "$HAS_FEATURES_YML" == true ]]; then
        local existing
        existing=$(get_features_yml)
        if [[ -n "$existing" ]]; then
            echo ""
            echo -e "  ${DIM}Already defined in rhino.yml:${NC}"
            while IFS= read -r f; do
                [[ -n "$f" ]] && echo -e "    ${DIM}· $f${NC}"
            done <<< "$existing"
        fi
    elif [[ -n "$BELIEFS_FILE" ]]; then
        local existing
        existing=$(get_features_beliefs)
        if [[ -n "$existing" ]]; then
            echo ""
            echo -e "  ${DIM}Already defined in beliefs.yml:${NC}"
            while IFS= read -r f; do
                [[ -n "$f" ]] && echo -e "    ${DIM}· $f${NC}"
            done <<< "$existing"
        fi
    fi

    if [[ "$found" -eq 0 ]]; then
        echo -e "  ${DIM}No features detected.${NC}"
    fi

    echo ""
}

# === Main ===
case "${1:-}" in
    ""|list) cmd_list ;;
    detect)  cmd_detect ;;
    help|--help|-h)
        echo "Usage: rhino feature [list|detect|<name>]"
        echo "  list      Show all features with verdicts"
        echo "  detect    Auto-detect features from codebase"
        echo "  <name>    Show detail for one feature"
        ;;
    *) cmd_view "$1" ;;
esac
