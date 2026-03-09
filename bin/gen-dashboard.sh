#!/usr/bin/env bash
set -euo pipefail

# gen-dashboard.sh — Generate an HTML dashboard for a project scored by rhino-os.
#
# Reads:
#   .claude/scores/history.tsv     — score dimensions over time
#   .claude/evals/reports/taste-*  — taste eval results
#   .claude/experiments/*.tsv      — experiment logs
#   git log                        — commit history
#
# Outputs: docs/dashboard.html (self-contained, no dependencies)
#
# Usage:
#   gen-dashboard.sh [project-dir] [--output path]

PROJECT_DIR="."
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: gen-dashboard.sh [project-dir] [--output path]"
            exit 0
            ;;
        -*) shift ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done

cd "$PROJECT_DIR"

PROJECT_NAME=$(basename "$(pwd)")
[[ -f "package.json" ]] && PROJECT_NAME=$(grep -o '"name": *"[^"]*"' package.json | head -1 | cut -d'"' -f4 || echo "$PROJECT_NAME")

OUTPUT="${OUTPUT:-docs/dashboard.html}"
mkdir -p "$(dirname "$OUTPUT")"

# --- Gather data ---

# Score history
SCORE_DATA="[]"
HISTORY_FILE=".claude/scores/history.tsv"
if [[ -f "$HISTORY_FILE" ]]; then
    SCORE_DATA=$(tail -n +2 "$HISTORY_FILE" | awk -F'\t' '{
        printf "{\"ts\":\"%s\",\"build\":%s,\"structure\":%s,\"hygiene\":%s},", $1, $2, $3, $4
    }' | sed 's/,$//')
    SCORE_DATA="[$SCORE_DATA]"
fi

# Taste evals
TASTE_DATA="[]"
if [[ -d ".claude/evals/reports" ]] && command -v jq &>/dev/null; then
    TASTE_DATA=$(ls -t .claude/evals/reports/taste-*.json 2>/dev/null | while read -r f; do
        jq -c '{
            date: (.meta.timestamp // "?" | .[0:10]),
            overall: .overall,
            score_100: .score_100,
            dimensions: [.dimensions | to_entries[] | {name: .key, score: .value.score, evidence: .value.evidence}],
            strongest: .strongest,
            weakest: .weakest,
            one_thing: .one_thing
        }' "$f" 2>/dev/null
    done | jq -s '.' 2>/dev/null || echo "[]")
fi

# Experiment data
EXP_DATA="[]"
if [[ -d ".claude/experiments" ]]; then
    EXP_DATA=$(find .claude/experiments -name "*.tsv" -exec tail -n +2 {} \; 2>/dev/null | awk -F'\t' '{
        gsub(/"/, "\\\"", $0);
        printf "{\"commit\":\"%s\",\"score\":%s,\"delta\":\"%s\",\"status\":\"%s\"},", $1, ($2 ~ /^[0-9]+$/ ? $2 : "0"), $4, $5
    }' | sed 's/,$//')
    EXP_DATA="[$EXP_DATA]"
fi

# Git commit history (last 60)
COMMIT_DATA=$(git log --format="%ai|%s" -60 --reverse 2>/dev/null | while IFS='|' read -r date msg; do
    date_short="${date:0:10}"
    type="${msg%%:*}"
    # escape quotes in msg
    msg_safe=$(echo "$msg" | sed 's/"/\\"/g' | cut -c1-80)
    printf '{"date":"%s","type":"%s","msg":"%s"},' "$date_short" "$type" "$msg_safe"
done | sed 's/,$//')
COMMIT_DATA="[$COMMIT_DATA]"

# Current score (run fresh)
RHINO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT_SCORES="{}"
if [[ -f "$RHINO_DIR/bin/score.sh" ]]; then
    CURRENT_SCORES=$("$RHINO_DIR/bin/score.sh" . --json 2>/dev/null || echo '{}')
fi

TOTAL_RUNS=$(wc -l < "$HISTORY_FILE" 2>/dev/null | tr -d ' ' || echo "0")
[[ "$TOTAL_RUNS" -gt 0 ]] && TOTAL_RUNS=$((TOTAL_RUNS - 1))  # subtract header

# --- Generate HTML ---
cat > "$OUTPUT" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PROJ_NAME — rhino-os Dashboard</title>
<style>
  :root {
    --bg: #0a0a0a; --surface: #141414; --border: #222; --text: #e0e0e0;
    --dim: #555; --accent: #f59e0b; --feat: #22c55e; --fix: #f87171;
    --blue: #60a5fa; --purple: #a78bfa; --cyan: #22d3ee;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: var(--bg); color: var(--text);
    font-family: 'SF Mono', 'Fira Code', 'JetBrains Mono', monospace;
    font-size: 13px; line-height: 1.6; padding: 40px;
  }
  h1 { font-size: 28px; font-weight: 700; margin-bottom: 4px; }
  h1 span { color: var(--accent); }
  .meta { color: var(--dim); font-size: 12px; margin-bottom: 32px; }
  h2 { font-size: 16px; font-weight: 600; margin: 32px 0 8px; }
  h2 span { color: var(--dim); font-weight: 400; font-size: 13px; }

  .grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 12px; margin-bottom: 24px; }
  .stat-card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 8px; padding: 16px; text-align: center;
  }
  .stat-card .val { font-size: 28px; font-weight: 700; }
  .stat-card .label { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--dim); margin-top: 4px; }
  .stat-card.gate-pass .val { color: var(--feat); }
  .stat-card.gate-fail .val { color: var(--fix); }

  .chart-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px; }
  .chart-card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 10px; padding: 24px; overflow: hidden;
  }
  .chart-card.wide { grid-column: span 2; }
  .chart-card h3 { font-size: 13px; font-weight: 600; margin-bottom: 4px; }
  .chart-card .sub { font-size: 11px; color: var(--dim); margin-bottom: 16px; }
  canvas { width: 100% !important; height: auto !important; }

  .legend { display: flex; gap: 16px; flex-wrap: wrap; margin-top: 12px; }
  .legend-item { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--dim); }
  .legend-dot { width: 8px; height: 8px; border-radius: 50%; }

  .taste-card {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 10px; padding: 20px; margin-bottom: 12px;
  }
  .taste-card h4 { font-size: 13px; margin-bottom: 8px; }
  .taste-dim { display: flex; align-items: center; gap: 8px; margin: 4px 0; font-size: 12px; }
  .taste-bar { height: 6px; border-radius: 3px; background: var(--border); flex: 1; max-width: 120px; position: relative; }
  .taste-fill { height: 100%; border-radius: 3px; position: absolute; left: 0; top: 0; }
  .taste-name { min-width: 140px; color: var(--dim); }
  .taste-score { min-width: 30px; font-weight: 600; }
  .taste-evidence { color: var(--dim); font-size: 11px; margin-left: 8px; }
  .insight { font-size: 12px; color: var(--dim); margin-top: 8px; line-height: 1.5; }
  .insight strong { color: var(--accent); }

  .empty { color: var(--dim); font-size: 12px; padding: 20px; text-align: center; }
  footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid var(--border); color: var(--dim); font-size: 11px; }

  @media (max-width: 768px) {
    body { padding: 20px; }
    .grid { grid-template-columns: repeat(2, 1fr); }
    .chart-row { grid-template-columns: 1fr; }
    .chart-card.wide { grid-column: span 1; }
  }
</style>
</head>
<body>

<h1><span>PROJ_NAME</span> dashboard</h1>
<div class="meta">Scored by rhino-os &middot; TOTAL_RUNS scoring runs &middot; Generated GENERATED_DATE</div>

<!-- Current scores -->
<div class="grid" id="currentScores"></div>

<!-- Score dimensions over time -->
<h2>Score dimensions over time <span>training loss</span></h2>
<div class="chart-row">
  <div class="chart-card wide">
    <h3>All dimensions</h3>
    <div class="sub">Each line = one dimension. Track independently. The trend matters more than the number.</div>
    <canvas id="dimensionChart" height="220"></canvas>
    <div class="legend">
      <div class="legend-item"><div class="legend-dot" style="background: var(--feat);"></div> structure</div>
      <div class="legend-item"><div class="legend-dot" style="background: var(--accent);"></div> product</div>
      <div class="legend-item"><div class="legend-dot" style="background: var(--blue);"></div> capabilities</div>
      <div class="legend-item"><div class="legend-dot" style="background: var(--purple);"></div> hygiene</div>
    </div>
  </div>
</div>

<!-- Weakest link over time -->
<div class="chart-row">
  <div class="chart-card">
    <h3>Weakest dimension over time</h3>
    <div class="sub">The bottleneck. This is what --score returns.</div>
    <canvas id="weakestChart" height="180"></canvas>
  </div>
  <div class="chart-card">
    <h3>Dimension radar (latest)</h3>
    <div class="sub">Current shape of the product</div>
    <canvas id="radarChart" height="180"></canvas>
  </div>
</div>

<!-- Taste evals -->
<h2>Taste evaluations <span>eval loss (visual)</span></h2>
<div id="tasteSection"></div>

<!-- Experiments -->
<h2>Experiments <span>keep/discard loop</span></h2>
<div class="chart-row">
  <div class="chart-card wide" id="expSection">
    <h3>Experiment scores</h3>
    <div class="sub">Each dot = one experiment. Green = kept, red = discarded.</div>
    <canvas id="expChart" height="140"></canvas>
  </div>
</div>

<footer>
  Generated by <strong>rhino-os</strong> &middot; <code>rhino dashboard [dir]</code> to regenerate
</footer>

<script>
// === EMBEDDED DATA (replaced by gen-dashboard.sh) ===
const PROJECT_NAME = "PROJ_NAME";
const scoreHistory = SCORE_HISTORY_DATA;
const tasteEvals = TASTE_EVAL_DATA;
const experiments = EXPERIMENT_DATA;
const currentScores = CURRENT_SCORES_DATA;
const commitHistory = COMMIT_HISTORY_DATA;

// === COLORS ===
const dimColors = {
  structure: '#22c55e',
  product: '#f59e0b',
  capabilities: '#60a5fa',
  hygiene: '#a78bfa',
};
const tasteColors = [
  '#f59e0b', '#22c55e', '#60a5fa', '#a78bfa', '#22d3ee', '#f87171', '#facc15', '#ec4899'
];

// === HELPERS ===
function getCtx(id) {
  const canvas = document.getElementById(id);
  if (!canvas) return null;
  const dpr = window.devicePixelRatio || 1;
  const rect = canvas.getBoundingClientRect();
  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  const ctx = canvas.getContext('2d');
  ctx.scale(dpr, dpr);
  return { ctx, w: rect.width, h: rect.height };
}

// === CURRENT SCORES ===
function renderCurrentScores() {
  const el = document.getElementById('currentScores');
  if (!currentScores || !currentScores.build) {
    el.innerHTML = '<div class="empty">No scores yet. Run <code>rhino score .</code> in this project.</div>';
    return;
  }
  const dims = [
    { key: 'build', label: 'build', gate: true },
    { key: 'structure', label: 'structure' },
    { key: 'product', label: 'product' },
    { key: 'capabilities', label: 'capabilities' },
    { key: 'hygiene', label: 'hygiene' },
  ];
  el.innerHTML = dims.map(d => {
    const val = currentScores[d.key] || 0;
    const cls = d.gate ? (val >= 70 ? 'gate-pass' : 'gate-fail') : '';
    const color = !d.gate ? `color: ${dimColors[d.key] || 'var(--text)'}` : '';
    return `<div class="stat-card ${cls}">
      <div class="val" style="${color}">${val}</div>
      <div class="label">${d.label}</div>
    </div>`;
  }).join('');
}

// === DIMENSION CHART (line chart) ===
function drawDimensionChart() {
  if (scoreHistory.length < 2) {
    document.getElementById('dimensionChart').parentElement.innerHTML =
      '<div class="empty">Need 2+ scoring runs to show trends. Run <code>rhino score .</code> multiple times.</div>';
    return;
  }
  const r = getCtx('dimensionChart');
  if (!r) return;
  const { ctx, w, h } = r;
  const pad = { top: 20, right: 20, bottom: 30, left: 40 };
  const cw = w - pad.left - pad.right;
  const ch = h - pad.top - pad.bottom;

  // Grid
  ctx.strokeStyle = '#1a1a1a';
  ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i++) {
    const y = pad.top + (i / 4) * ch;
    ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(w - pad.right, y); ctx.stroke();
    ctx.fillStyle = '#444'; ctx.font = '10px monospace'; ctx.textAlign = 'right';
    ctx.fillText(Math.round((1 - i/4) * 100), pad.left - 6, y + 4);
  }

  // Lines
  const keys = ['structure', 'product', 'capabilities', 'hygiene'];
  keys.forEach(key => {
    ctx.beginPath();
    ctx.strokeStyle = dimColors[key];
    ctx.lineWidth = 2;
    scoreHistory.forEach((d, i) => {
      const x = pad.left + (i / (scoreHistory.length - 1)) * cw;
      const y = pad.top + (1 - (d[key] || 0) / 100) * ch;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.stroke();

    // End dot + label
    const last = scoreHistory[scoreHistory.length - 1];
    const lx = pad.left + cw;
    const ly = pad.top + (1 - (last[key] || 0) / 100) * ch;
    ctx.beginPath(); ctx.arc(lx, ly, 3, 0, Math.PI * 2); ctx.fillStyle = dimColors[key]; ctx.fill();
  });
}

// === WEAKEST LINK CHART ===
function drawWeakestChart() {
  if (scoreHistory.length < 2) return;
  const r = getCtx('weakestChart');
  if (!r) return;
  const { ctx, w, h } = r;
  const pad = { top: 20, right: 20, bottom: 30, left: 40 };
  const cw = w - pad.left - pad.right;
  const ch = h - pad.top - pad.bottom;

  const weakest = scoreHistory.map(d => {
    const vals = [d.structure||0, d.product||0, d.capabilities||0, d.hygiene||0];
    return Math.min(...vals);
  });

  // Area
  ctx.beginPath();
  weakest.forEach((v, i) => {
    const x = pad.left + (i / (weakest.length - 1)) * cw;
    const y = pad.top + (1 - v / 100) * ch;
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  });
  ctx.lineTo(pad.left + cw, pad.top + ch);
  ctx.lineTo(pad.left, pad.top + ch);
  ctx.closePath();
  ctx.fillStyle = '#f59e0b15';
  ctx.fill();

  // Line
  ctx.beginPath();
  ctx.strokeStyle = '#f59e0b';
  ctx.lineWidth = 2;
  weakest.forEach((v, i) => {
    const x = pad.left + (i / (weakest.length - 1)) * cw;
    const y = pad.top + (1 - v / 100) * ch;
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  });
  ctx.stroke();

  // Grid
  ctx.strokeStyle = '#1a1a1a'; ctx.lineWidth = 1;
  for (let i = 0; i <= 4; i++) {
    const y = pad.top + (i / 4) * ch;
    ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(w - pad.right, y); ctx.stroke();
    ctx.fillStyle = '#444'; ctx.font = '10px monospace'; ctx.textAlign = 'right';
    ctx.fillText(Math.round((1 - i/4) * 100), pad.left - 6, y + 4);
  }
}

// === RADAR CHART ===
function drawRadar() {
  const r = getCtx('radarChart');
  if (!r || !currentScores.structure) return;
  const { ctx, w, h } = r;
  const cx = w / 2, cy = h / 2;
  const radius = Math.min(cx, cy) - 30;
  const dims = ['structure', 'product', 'capabilities', 'hygiene'];
  const n = dims.length;

  // Grid rings
  [0.25, 0.5, 0.75, 1].forEach(pct => {
    ctx.beginPath();
    for (let i = 0; i <= n; i++) {
      const angle = (i / n) * Math.PI * 2 - Math.PI / 2;
      const x = cx + Math.cos(angle) * radius * pct;
      const y = cy + Math.sin(angle) * radius * pct;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    }
    ctx.strokeStyle = '#1a1a1a';
    ctx.lineWidth = 1;
    ctx.stroke();
  });

  // Axis lines + labels
  dims.forEach((dim, i) => {
    const angle = (i / n) * Math.PI * 2 - Math.PI / 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius);
    ctx.strokeStyle = '#222'; ctx.stroke();

    const lx = cx + Math.cos(angle) * (radius + 16);
    const ly = cy + Math.sin(angle) * (radius + 16);
    ctx.fillStyle = dimColors[dim]; ctx.font = '10px monospace'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(dim.slice(0, 6), lx, ly);
  });

  // Data polygon
  ctx.beginPath();
  dims.forEach((dim, i) => {
    const val = (currentScores[dim] || 0) / 100;
    const angle = (i / n) * Math.PI * 2 - Math.PI / 2;
    const x = cx + Math.cos(angle) * radius * val;
    const y = cy + Math.sin(angle) * radius * val;
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  });
  ctx.closePath();
  ctx.fillStyle = '#f59e0b20';
  ctx.fill();
  ctx.strokeStyle = '#f59e0b';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Dots
  dims.forEach((dim, i) => {
    const val = (currentScores[dim] || 0) / 100;
    const angle = (i / n) * Math.PI * 2 - Math.PI / 2;
    const x = cx + Math.cos(angle) * radius * val;
    const y = cy + Math.sin(angle) * radius * val;
    ctx.beginPath(); ctx.arc(x, y, 4, 0, Math.PI * 2);
    ctx.fillStyle = dimColors[dim]; ctx.fill();
  });
}

// === TASTE EVALS ===
function renderTaste() {
  const el = document.getElementById('tasteSection');
  if (!tasteEvals || tasteEvals.length === 0) {
    el.innerHTML = '<div class="empty">No taste evaluations yet. Run <code>rhino taste eval</code> in this project.</div>';
    return;
  }

  el.innerHTML = tasteEvals.map((ev, idx) => {
    const dimsHtml = (ev.dimensions || []).map((d, i) => {
      const pct = (d.score / 5) * 100;
      const color = tasteColors[i % tasteColors.length];
      return `<div class="taste-dim">
        <span class="taste-name">${d.name}</span>
        <div class="taste-bar"><div class="taste-fill" style="width: ${pct}%; background: ${color};"></div></div>
        <span class="taste-score" style="color: ${color};">${d.score}/5</span>
        <span class="taste-evidence">${(d.evidence || '').slice(0, 80)}</span>
      </div>`;
    }).join('');

    return `<div class="taste-card">
      <h4>${ev.score_100}/100 <span style="color: var(--dim); font-weight: 400;">&middot; ${ev.date}</span></h4>
      ${dimsHtml}
      <div class="insight"><strong>Strongest:</strong> ${ev.strongest || '—'}</div>
      <div class="insight"><strong>Weakest:</strong> ${ev.weakest || '—'}</div>
      <div class="insight"><strong>One thing:</strong> ${ev.one_thing || '—'}</div>
    </div>`;
  }).join('');
}

// === EXPERIMENTS ===
function drawExperiments() {
  if (!experiments || experiments.length === 0) {
    document.getElementById('expSection').innerHTML =
      '<div class="empty">No experiments logged yet. Use the experiment mode in the build loop.</div>';
    return;
  }
  const r = getCtx('expChart');
  if (!r) return;
  const { ctx, w, h } = r;
  const pad = { top: 20, right: 20, bottom: 20, left: 40 };
  const cw = w - pad.left - pad.right;
  const ch = h - pad.top - pad.bottom;
  const maxScore = Math.max(100, ...experiments.map(e => e.score || 0));

  experiments.forEach((exp, i) => {
    const x = pad.left + (i / Math.max(1, experiments.length - 1)) * cw;
    const y = pad.top + (1 - (exp.score || 0) / maxScore) * ch;
    const kept = (exp.status || '').toLowerCase().includes('keep');
    ctx.beginPath();
    ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.fillStyle = kept ? '#22c55e' : '#f87171';
    ctx.fill();
    ctx.beginPath();
    ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.strokeStyle = kept ? '#22c55e' : '#f87171';
    ctx.lineWidth = 2;
    ctx.stroke();
  });

  // Trend line
  if (experiments.length > 1) {
    ctx.beginPath();
    ctx.strokeStyle = '#f59e0b44';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);
    experiments.forEach((exp, i) => {
      const x = pad.left + (i / (experiments.length - 1)) * cw;
      const y = pad.top + (1 - (exp.score || 0) / maxScore) * ch;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.stroke();
    ctx.setLineDash([]);
  }
}

// === RENDER ALL ===
window.addEventListener('load', () => {
  renderCurrentScores();
  drawDimensionChart();
  drawWeakestChart();
  drawRadar();
  renderTaste();
  drawExperiments();
});
</script>

</body>
</html>
HTMLEOF

# --- Inject data ---
sed -i '' "s|PROJ_NAME|$PROJECT_NAME|g" "$OUTPUT"
sed -i '' "s|TOTAL_RUNS|$TOTAL_RUNS|g" "$OUTPUT"
sed -i '' "s|GENERATED_DATE|$(date +%Y-%m-%d)|g" "$OUTPUT"
sed -i '' "s|SCORE_HISTORY_DATA|$SCORE_DATA|g" "$OUTPUT"
sed -i '' "s|TASTE_EVAL_DATA|$TASTE_DATA|g" "$OUTPUT"
sed -i '' "s|EXPERIMENT_DATA|$EXP_DATA|g" "$OUTPUT"
sed -i '' "s|CURRENT_SCORES_DATA|$CURRENT_SCORES|g" "$OUTPUT"
sed -i '' "s|COMMIT_HISTORY_DATA|$COMMIT_DATA|g" "$OUTPUT"

echo "Dashboard generated: $OUTPUT"
echo "Open: open $OUTPUT"
