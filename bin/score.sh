#!/usr/bin/env bash
set -euo pipefail

# score.sh — Structural lint. Fast, every commit, no opinions.
#
# Tracks 5 dimensions INDEPENDENTLY (no composite — composites hide problems):
#   1. Build health    — does it compile? (gate: pass/fail)
#   2. Structure       — dead ends, empty states (0-100)
#   3. Product signals — creation→share depth, return pull, social (0-100)
#   4. Capabilities    — routes, components, auth, search depth (0-100)
#   5. Code hygiene    — hardcoded colors, any types, console.logs (0-100)
#
# Each dimension is tracked over time in .claude/scores/history.tsv.
# The trend per dimension IS the signal. No weighted average.
#
# When --score returns a single number, it returns the LOWEST dimension
# (weakest link), not an average. This surfaces what needs work.
#
# For actual taste evaluation (visual, expensive): rhino taste eval
#
# Usage:
#   score.sh [project-dir]              # weakest dimension score
#   score.sh [project-dir] --json       # all dimensions
#   score.sh [project-dir] --breakdown  # show all + trends

PROJECT_DIR="."
OUTPUT_MODE="score"
FORCE=false

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --breakdown) OUTPUT_MODE="breakdown" ;;
        --force) FORCE=true ;;
        --help|-h)
            echo "Usage: score.sh [project-dir] [--json] [--breakdown] [--force]"
            exit 0
            ;;
        -*) ;; # skip unknown flags
        *) PROJECT_DIR="$arg" ;;
    esac
done

cd "$PROJECT_DIR"

# --- Progress display ---
SPINNER_PID=""
spin() {
    local msg="$1"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    printf '\033[2m' >&2
    while true; do
        for (( i=0; i<${#chars}; i++ )); do
            printf "\r  %s %s" "${chars:$i:1}" "$msg" >&2
            sleep 0.1
        done
    done
}

start_spinner() {
    [[ "$OUTPUT_MODE" == "score" ]] && return  # quiet mode
    spin "$1" &
    SPINNER_PID=$!
    disown $SPINNER_PID 2>/dev/null
}

stop_spinner() {
    local result="${1:-done}"
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
    fi
    [[ "$OUTPUT_MODE" != "score" ]] && printf "\r  ✓ %s\033[0m\n" "$result" >&2
}

cleanup_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        printf "\033[0m\n" >&2
    fi
}
trap cleanup_spinner EXIT

# --- Freshness cache ---
CACHE_DIR=".claude/cache"
CACHE_FILE="$CACHE_DIR/score-cache.json"
CACHE_MAX_AGE=300  # 5 minutes

if [[ "$FORCE" != true && -f "$CACHE_FILE" ]]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [[ "$cache_age" -lt "$CACHE_MAX_AGE" ]]; then
        case "$OUTPUT_MODE" in
            score) jq -r '.score' "$CACHE_FILE" 2>/dev/null && exit 0 ;;
            json) cat "$CACHE_FILE" 2>/dev/null && exit 0 ;;
            breakdown)
                # Show cached result with age note
                printf '\033[2m  (cached %ds ago, use --force to refresh)\033[0m\n' "$cache_age" >&2
                ;;
        esac
    fi
fi

# --- Detect project type ---
PROJECT_TYPE="unknown"
SRC_DIR=""

if [[ -f "package.json" ]]; then
    if grep -q '"next"' package.json 2>/dev/null; then
        PROJECT_TYPE="nextjs"
    elif grep -q '"react"' package.json 2>/dev/null; then
        PROJECT_TYPE="react"
    elif grep -q '"vue"' package.json 2>/dev/null; then
        PROJECT_TYPE="vue"
    elif grep -q '"svelte"' package.json 2>/dev/null; then
        PROJECT_TYPE="svelte"
    else
        PROJECT_TYPE="node"
    fi
fi

# Find source directory
if [[ -d "apps/web/src" ]]; then
    SRC_DIR="apps/web/src"
elif [[ -d "src" ]]; then
    SRC_DIR="src"
elif [[ -d "app" ]]; then
    SRC_DIR="app"
fi

# Component extensions
COMP_EXT="tsx"
if [[ "$PROJECT_TYPE" == "vue" ]]; then COMP_EXT="vue"; fi
if [[ "$PROJECT_TYPE" == "svelte" ]]; then COMP_EXT="svelte"; fi

# --- 1. Build Health (0-100, gate) ---
# FAST mode: check for recent build artifacts instead of running full build.
# Only runs tsc/build if --force is passed. This is training loss — speed matters.
score_build_health() {
    local score=100

    # Check for TypeScript errors via build output cache, not live compilation
    if [[ -f "tsconfig.json" ]] || [[ -f "apps/web/tsconfig.json" ]]; then
        if [[ "$FORCE" == true ]]; then
            local ts_errors
            ts_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
            if [[ "$ts_errors" -gt 0 ]]; then
                score=$((score - 30))
            fi
        else
            # Fast check: look for recent .next/build or dist artifacts
            local has_build=false
            local build_age=999999
            if [[ -d ".next" ]]; then
                has_build=true
                build_age=$(( $(date +%s) - $(stat -f %m ".next" 2>/dev/null || echo 0) ))
            elif [[ -d "dist" ]]; then
                has_build=true
                build_age=$(( $(date +%s) - $(stat -f %m "dist" 2>/dev/null || echo 0) ))
            elif [[ -d "apps/web/.next" ]]; then
                has_build=true
                build_age=$(( $(date +%s) - $(stat -f %m "apps/web/.next" 2>/dev/null || echo 0) ))
            fi
            if ! $has_build; then
                score=$((score - 30))  # No build artifacts = unknown health
            elif [[ "$build_age" -gt 86400 ]]; then
                score=$((score - 10))  # Stale build (>24h)
            fi
        fi
    fi

    # Skip full build — check if build script exists and last build succeeded
    if grep -q '"build"' package.json 2>/dev/null; then
        if [[ "$FORCE" == true ]]; then
            if ! npm run build > /dev/null 2>&1; then
                score=$((score - 50))
            fi
        fi
    fi

    echo "$score"
}

# --- 2. Structure (0-100, subtractive) ---
score_structure() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # Count pages
    local total_pages
    total_pages=$(find "$SRC_DIR" -name "page.$COMP_EXT" -o -name "index.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$total_pages" -eq 0 ]] && total_pages=1

    # Dead-end screens
    local dead_ends=0
    dead_ends=$(find "$SRC_DIR" -name "page.$COMP_EXT" 2>/dev/null | while read -r f; do
        if ! grep -ql "Link\|href\|router\|navigate\|onClick" "$f" 2>/dev/null; then
            echo "$f"
        fi
    done | wc -l | tr -d ' ')

    if [[ "$dead_ends" -gt 0 ]]; then
        local dead_pct=$((dead_ends * 100 / total_pages))
        score=$((score - dead_pct / 2))
    fi

    # Empty states without CTAs
    local empty_states
    empty_states=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local empty_with_cta
    empty_with_cta=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | xargs grep -l "Link\|button\|onClick\|href" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$empty_states" -gt 0 ]]; then
        local cta_pct=$((empty_with_cta * 100 / empty_states))
        local missing_pct=$((100 - cta_pct))
        score=$((score - missing_pct / 3))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# --- 3. Product Signals (0-100) ---
# Measures FLOW COMPLETION depth, not feature existence.
# Rewards CONNECTED flows where steps link together. Single keyword matches = low score.
score_product() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0

    # --- CREATION → DISTRIBUTION flow (0-30) ---
    # Requires DEPTH: create alone = 5pts. Full chain create→save→share→preview = 30pts.
    # Each step must appear in 2+ files (not just one accidental match).
    local has_create=0 has_save=0 has_share=0 has_preview=0
    [[ $(grep -rn "onSubmit\|handleSubmit\|createPost\|editor\|compose\|publish" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_create=1
    [[ $(grep -rn "mutation\|\.post(\|\.put(\|addDoc\|setDoc\|insertOne" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_save=1
    [[ $(grep -rn "navigator\.share\|copy.*link\|copy.*url\|shareUrl\|ShareSheet" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_share=1
    [[ $(grep -rn "og:title\|og:image\|openGraph" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_preview=1

    local creation_flow=$((has_create + has_save + has_share + has_preview))
    case "$creation_flow" in
        4) score=$((score + 30)) ;;
        3) score=$((score + 18)) ;;
        2) score=$((score + 8)) ;;
        1) score=$((score + 3)) ;;
    esac

    # --- RETURN PULL flow (0-30) ---
    # Hardest to earn. Most apps score 0-5 here.
    local has_notif=0 has_unread=0 has_return_ux=0 has_digest=0
    [[ $(grep -rn "Notification\.requestPermission\|sendNotification\|pushNotification" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_notif=1
    [[ $(grep -rn "unreadCount\|unseen\|badge.*count\|new.*since" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_unread=1
    [[ $(grep -rn "since you left\|welcome back\|what you missed\|new since last" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_return_ux=1
    [[ $(grep -rn "digest\|daily.*email\|weekly.*summary\|recap" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_digest=1

    local return_flow=$((has_notif + has_unread + has_return_ux + has_digest))
    case "$return_flow" in
        4) score=$((score + 30)) ;;
        3) score=$((score + 18)) ;;
        2) score=$((score + 8)) ;;
        1) score=$((score + 3)) ;;
    esac

    # --- SOCIAL flow (0-20) ---
    local has_profiles=0 has_follow=0 has_feed=0 has_realtime=0
    [[ $(grep -rn "UserProfile\|user.*avatar\|ProfilePage\|member.*list" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_profiles=1
    [[ $(grep -rn "follow\|connect.*user\|friend.*request\|join.*group" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_follow=1
    [[ $(grep -rn "feed\|timeline\|activity.*stream\|recent.*posts" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 3 ]] && has_feed=1
    [[ $(grep -rn "onSnapshot\|WebSocket\|presence\|typing.*indicator" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ') -ge 2 ]] && has_realtime=1

    local social_flow=$((has_profiles + has_follow + has_feed + has_realtime))
    case "$social_flow" in
        4) score=$((score + 20)) ;;
        3) score=$((score + 12)) ;;
        2) score=$((score + 6)) ;;
        1) score=$((score + 2)) ;;
    esac

    # --- REAL USER SIGNAL (0-20) ---
    # Require actual integration depth, not just one import
    local has_analytics=0 has_error_tracking=0
    [[ $(grep -rn "posthog\|mixpanel\|plausible\|gtag\|analytics\.track\|trackEvent" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 3 ]] && has_analytics=1
    [[ $(grep -rn "sentry\|bugsnag\|errorBoundary\|captureException" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 2 ]] && has_error_tracking=1

    [[ "$has_analytics" -eq 1 ]] && score=$((score + 10))
    [[ "$has_error_tracking" -eq 1 ]] && score=$((score + 10))

    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# --- 4. Capabilities (0-100, additive) ---
# How many user-facing features exist? Rewards feature depth, not just file count.
# Calibrated so a typical medium app scores 40-60, not 100.
score_capabilities() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0

    # Count unique routes/pages — higher thresholds
    local pages
    pages=$(find "$SRC_DIR" -name "page.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    # 1-5 = 5pts, 6-12 = 15pts, 13-25 = 25pts, 26+ = 35pts
    if [[ "$pages" -ge 26 ]]; then score=$((score + 35))
    elif [[ "$pages" -ge 13 ]]; then score=$((score + 25))
    elif [[ "$pages" -ge 6 ]]; then score=$((score + 15))
    elif [[ "$pages" -ge 1 ]]; then score=$((score + 5))
    fi

    # Components — require real depth
    local components
    components=$(find "$SRC_DIR" -name "*.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    # 1-20 = 5pts, 21-50 = 10pts, 51-100 = 15pts, 101+ = 20pts
    if [[ "$components" -ge 101 ]]; then score=$((score + 20))
    elif [[ "$components" -ge 51 ]]; then score=$((score + 15))
    elif [[ "$components" -ge 21 ]]; then score=$((score + 10))
    elif [[ "$components" -ge 1 ]]; then score=$((score + 5))
    fi

    # API routes (backend functionality)
    local api_routes
    api_routes=$(find "$SRC_DIR" -path "*/api/*" -name "route.*" 2>/dev/null | wc -l | tr -d ' ')
    # 1-5 = 5pts, 6-15 = 10pts, 16+ = 15pts
    if [[ "$api_routes" -ge 16 ]]; then score=$((score + 15))
    elif [[ "$api_routes" -ge 6 ]]; then score=$((score + 10))
    elif [[ "$api_routes" -ge 1 ]]; then score=$((score + 5))
    fi

    # Auth system — require depth (multiple files using it, not just one import)
    local auth
    auth=$(grep -rn "signIn\|signUp\|useAuth\|useSession\|getServerSession\|auth()\|currentUser" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$auth" -ge 3 ]] && score=$((score + 10))

    # Search — require actual search UI + results, not just searchParams
    local search
    search=$(grep -rn "useSearch\|search.*results\|SearchBar\|SearchInput" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$search" -ge 2 ]] && score=$((score + 5))

    # File upload / media — require real implementation
    local media
    media=$(grep -rn "dropzone\|FileInput\|image.*upload\|useUpload\|UploadButton" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$media" -ge 2 ]] && score=$((score + 5))

    # Analytics / tracking — require 3+ files (real integration, not one config)
    local analytics
    analytics=$(grep -rn "analytics\|trackEvent\|posthog\|mixpanel\|gtag\|plausible" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$analytics" -ge 3 ]] && score=$((score + 5))

    # Bonus: Accessibility (screen reader, aria labels, focus management)
    local a11y
    a11y=$(grep -rn "aria-label\|role=\|sr-only\|focus-visible\|tabIndex" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$a11y" -ge 5 ]] && score=$((score + 5))

    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# --- 5. Code Hygiene (0-100, subtractive) ---
score_hygiene() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # Hardcoded colors
    local hardcoded_colors
    hardcoded_colors=$(grep -rn '#[0-9A-Fa-f]\{6\}' --include="*.$COMP_EXT" --include="*.css" "$SRC_DIR" 2>/dev/null | grep -v 'node_modules\|tokens\|\.svg\|tailwind\|theme' | wc -l | tr -d ' ')
    if [[ "$hardcoded_colors" -gt 20 ]]; then score=$((score - 25))
    elif [[ "$hardcoded_colors" -gt 10 ]]; then score=$((score - 15))
    elif [[ "$hardcoded_colors" -gt 5 ]]; then score=$((score - 10))
    fi

    # `any` types
    local any_count
    any_count=$(grep -rn ": any\b" --include="*.ts" --include="*.tsx" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|\.d\.ts" | wc -l | tr -d ' ')
    if [[ "$any_count" -gt 20 ]]; then score=$((score - 25))
    elif [[ "$any_count" -gt 10 ]]; then score=$((score - 15))
    elif [[ "$any_count" -gt 3 ]]; then score=$((score - 10))
    fi

    # console.log in production
    local console_count
    console_count=$(grep -rn "console\.\(log\|warn\|error\)" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|test\|spec\|__test__" | wc -l | tr -d ' ')
    if [[ "$console_count" -gt 20 ]]; then score=$((score - 20))
    elif [[ "$console_count" -gt 10 ]]; then score=$((score - 10))
    elif [[ "$console_count" -gt 3 ]]; then score=$((score - 5))
    fi

    # TODO/FIXME count (unfinished work)
    local todo_count
    todo_count=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
    if [[ "$todo_count" -gt 20 ]]; then score=$((score - 15))
    elif [[ "$todo_count" -gt 10 ]]; then score=$((score - 10))
    elif [[ "$todo_count" -gt 3 ]]; then score=$((score - 5))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# --- Taste is NOT scored here. ---
# Taste requires LOOKING at the product, not grepping code.
# Use: rhino taste eval (Playwright + Claude vision)
# That's your eval loss. This file is training loss.

# --- Compute all scores ---
[[ "$OUTPUT_MODE" != "score" ]] && echo -e "\033[1m=== rhino lint ===\033[0m" >&2

start_spinner "checking build health..."
BUILD=$(score_build_health)
stop_spinner "build health: $BUILD/100"

start_spinner "analyzing structure..."
STRUCTURE=$(score_structure)
stop_spinner "structure: $STRUCTURE/100"

start_spinner "measuring product flows..."
PRODUCT=$(score_product)
stop_spinner "product flows: $PRODUCT/100"

start_spinner "counting capabilities..."
CAPABILITIES=$(score_capabilities)
stop_spinner "capabilities: $CAPABILITIES/100"

start_spinner "checking hygiene..."
HYGIENE=$(score_hygiene)
stop_spinner "hygiene: $HYGIENE/100"

# --- No composite score. Each dimension tracked independently. ---
# A composite hides whether you have a build problem or a product problem.
# Track each dimension over time. The trend per-dimension IS the signal.

# Build is a gate: if it fails, nothing else matters
if [[ "$BUILD" -lt 70 ]]; then
    BUILD_GATE="FAIL"
else
    BUILD_GATE="PASS"
fi

# --- Append to history (append-only TSV, like experiment logs) ---
HISTORY_DIR=".claude/scores"
HISTORY_FILE="$HISTORY_DIR/history.tsv"
mkdir -p "$HISTORY_DIR"

if [[ ! -f "$HISTORY_FILE" ]]; then
    printf "timestamp\tbuild\tstructure\tproduct\tcapabilities\thygiene\tproject_type\n" > "$HISTORY_FILE"
fi

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$BUILD" "$STRUCTURE" "$PRODUCT" "$CAPABILITIES" "$HYGIENE" \
    "$PROJECT_TYPE" >> "$HISTORY_FILE"

# --- Write cache (for other tools to read) ---
mkdir -p "$CACHE_DIR"
cat > "$CACHE_FILE" <<CEOF
{"build":$BUILD,"structure":$STRUCTURE,"product":$PRODUCT,"capabilities":$CAPABILITIES,"hygiene":$HYGIENE,"build_gate":"$BUILD_GATE","project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR","cached_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
CEOF

# --- Check for most recent taste eval ---
TASTE_SCORE=""
TASTE_FILE=""
if [[ -d ".claude/evals/reports" ]]; then
    TASTE_FILE=$(ls -t .claude/evals/reports/taste-*.json 2>/dev/null | head -1)
    if [[ -n "$TASTE_FILE" ]] && command -v jq &> /dev/null; then
        TASTE_SCORE=$(jq -r '.score_100 // empty' "$TASTE_FILE" 2>/dev/null)
    fi
fi

# --- Trend (compare to last run) ---
trend_for() {
    local dim="$1" current="$2" col="$3"
    if [[ $(wc -l < "$HISTORY_FILE" | tr -d ' ') -ge 3 ]]; then
        local prev
        prev=$(tail -2 "$HISTORY_FILE" | head -1 | cut -f"$col")
        if [[ -n "$prev" && "$prev" =~ ^[0-9]+$ ]]; then
            local delta=$((current - prev))
            if [[ "$delta" -gt 0 ]]; then echo "↑$delta"
            elif [[ "$delta" -lt 0 ]]; then echo "↓$((delta * -1))"
            else echo "—"
            fi
            return
        fi
    fi
    echo "·"
}

# --- Output ---
case "$OUTPUT_MODE" in
    score)
        # For scripts that need a single number: lowest non-build dimension
        # This surfaces the weakest link, not a comfortable average
        local_min=$STRUCTURE
        [[ "$PRODUCT" -lt "$local_min" ]] && local_min=$PRODUCT
        [[ "$CAPABILITIES" -lt "$local_min" ]] && local_min=$CAPABILITIES
        [[ "$HYGIENE" -lt "$local_min" ]] && local_min=$HYGIENE
        if [[ "$BUILD_GATE" == "FAIL" ]]; then
            echo "0"
        else
            echo "$local_min"
        fi
        ;;
    json)
        cat <<EOF
{"build":$BUILD,"build_gate":"$BUILD_GATE","structure":$STRUCTURE,"product":$PRODUCT,"capabilities":$CAPABILITIES,"hygiene":$HYGIENE,"taste_eval":${TASTE_SCORE:-null},"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR"}
EOF
        ;;
    breakdown)
        echo ""
        if [[ "$BUILD_GATE" == "FAIL" ]]; then
            echo "  ✗ BUILD GATE: FAIL ($BUILD/100) — fix build before anything else"
        else
            echo "  ✓ build gate: PASS ($BUILD/100)"
        fi
        echo ""
        echo "  structure:     $STRUCTURE/100  $(trend_for structure $STRUCTURE 3)  dead ends, empty states"
        echo "  product:       $PRODUCT/100  $(trend_for product $PRODUCT 4)  creation→share, return pull, social"
        echo "  capabilities:  $CAPABILITIES/100  $(trend_for capabilities $CAPABILITIES 5)  routes, components, auth, depth"
        echo "  hygiene:       $HYGIENE/100  $(trend_for hygiene $HYGIENE 6)  hardcoded colors, any types, console.log"
        echo ""
        if [[ -n "$TASTE_SCORE" ]]; then
            echo "  taste:         $TASTE_SCORE/100  (visual, last: $(basename "$TASTE_FILE"))"
        else
            echo "  taste:         —  run: rhino taste eval"
        fi
        echo ""
        echo "  Project: $PROJECT_TYPE ($SRC_DIR)"
        echo "  History: $HISTORY_FILE ($(( $(wc -l < "$HISTORY_FILE" | tr -d ' ') - 1 )) runs)"
        ;;
esac
