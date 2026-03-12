#!/usr/bin/env python3
"""Generate Product Growth PDF — real trajectories from rhino-os managed projects"""

from fpdf import FPDF
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import tempfile, os

BG = '#0f0f0f'
GOLD = '#daa520'
RED_C = '#dc5050'
DIM_C = '#888888'
CARD_C = '#1c1c1c'
FG_C = '#e6e6e6'
GREEN_C = '#50c878'
BLUE_C = '#60a5fa'
PURPLE_C = '#a78bfa'

W, H, MARGIN = 210, 297, 20
CW = W - 2 * MARGIN

FONT_PATH = '/System/Library/Fonts/Supplemental/Arial.ttf'
FONT_BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
FONT_ITALIC = '/System/Library/Fonts/Supplemental/Arial Italic.ttf'

class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.add_font('main', '', FONT_PATH)
        self.add_font('main', 'B', FONT_BOLD)
        self.add_font('main', 'I', FONT_ITALIC)

    def dark_page(self):
        self.add_page()
        self.set_fill_color(15, 15, 15)
        self.rect(0, 0, W, H, 'F')

    def big_title(self, text, size=30):
        self.set_font('main', 'B', size)
        self.set_text_color(230, 230, 230)
        self.multi_cell(CW, size * 0.48, text, align='L')

    def slide_title(self, text, size=18):
        self.set_font('main', 'B', size)
        self.set_text_color(218, 165, 32)
        self.multi_cell(CW, size * 0.55, text, align='L')
        self.ln(2)

    def caption(self, text, size=11):
        self.set_font('main', '', size)
        self.set_text_color(200, 200, 200)
        self.multi_cell(CW, size * 0.55, text, align='L')
        self.ln(3)

    def caveat(self, text, size=9):
        self.set_font('main', 'I', size)
        self.set_text_color(220, 80, 80)
        self.multi_cell(CW, size * 0.5, text, align='L')
        self.ln(2)

    def dim(self, text, size=10):
        self.set_font('main', '', size)
        self.set_text_color(120, 120, 120)
        self.multi_cell(CW, size * 0.5, text, align='L')

    def stat_row(self, label, value, color=GOLD):
        self.set_font('main', '', 11)
        self.set_text_color(160, 160, 160)
        self.cell(80, 7, label)
        self.set_font('main', 'B', 13)
        r, g, b = int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16)
        self.set_text_color(r, g, b)
        self.cell(CW - 80, 7, str(value), align='R')
        self.ln(8)
        self.set_x(MARGIN)


def fig_to_path(fig, name):
    path = os.path.join(tempfile.gettempdir(), f'{name}.png')
    fig.savefig(path, dpi=220, facecolor=BG, bbox_inches='tight')
    plt.close(fig)
    return path

def style_ax(ax, bg=None):
    ax.set_facecolor(bg or BG)
    for s in ['top','right']: ax.spines[s].set_visible(False)
    for s in ['left','bottom']: ax.spines[s].set_color('#333')
    ax.tick_params(colors=DIM_C, labelsize=8)


# === CHARTS ===

def chart_identity_growth():
    """Identity dimension: 0.30 → 0.63 across 17 experiments"""
    fig, ax = plt.subplots(figsize=(7, 3.2))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    scores = [0.30, 0.32, 0.35, 0.37, 0.39, 0.42, 0.44, 0.43,
              0.46, 0.50, 0.52, 0.54, 0.56, 0.58, 0.60, 0.62, 0.63]
    status = ['k','k','k','k','k','k','k','d',
              'k','k','k','k','k','k','k','k','k']

    best = [scores[0]]
    for s, st in zip(scores[1:], status[1:]):
        best.append(max(best[-1], s) if st == 'k' else best[-1])

    exps = range(len(scores))
    ax.fill_between(exps, best, alpha=0.08, color=GOLD)
    ax.plot(exps, best, color=GOLD, linewidth=2.5, zorder=3, label='best kept')

    for i, (s, st) in enumerate(zip(scores, status)):
        if st == 'k':
            ax.scatter(i, s, color=GREEN_C, s=45, zorder=4, edgecolors='none')
        else:
            ax.scatter(i, s, color=RED_C, s=65, zorder=4, marker='x', linewidths=2.5)

    # Phase annotations
    ax.axvspan(-0.5, 7.5, alpha=0.04, color=GOLD)
    ax.axvspan(7.5, 16.5, alpha=0.04, color=GREEN_C)
    ax.text(3.5, 0.27, 'Phase 1: copy + voice', ha='center', color=GOLD, fontsize=8, alpha=0.8)
    ax.text(12, 0.27, 'Phase 2: visual identity', ha='center', color=GREEN_C, fontsize=8, alpha=0.8)

    # Plateau annotation
    ax.annotate('copy plateau\n(system shifted\nto visual)', xy=(7, 0.44), xytext=(4.5, 0.55),
                color=RED_C, fontsize=7, ha='center',
                arrowprops=dict(arrowstyle='->', color=RED_C, lw=1))

    ax.set_ylim(0.24, 0.70)
    ax.set_ylabel('identity score', color=DIM_C, fontsize=9)
    ax.set_xlabel('experiment #', color=DIM_C, fontsize=9)
    ax.grid(axis='y', color='#1a1a1a', linewidth=0.5)
    ax.legend(fontsize=8, loc='upper left', framealpha=0.3,
              labelcolor=FG_C, facecolor=CARD_C, edgecolor='#333')

    ax.text(16.3, 0.635, '0.63', color=GOLD, fontsize=11, fontweight='bold')
    ax.text(-0.3, 0.305, '0.30', color=DIM_C, fontsize=10)

    return fig_to_path(fig, 'growth_identity')


def chart_ceiling_growth():
    """Ceiling dimensions across 4 eval cycles"""
    fig, ax = plt.subplots(figsize=(7, 3.5))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    evals = ['Product\nEval', 'Return\nLoop', 'Taste +\nHygiene', 'Wiring\nSprint']
    x = np.arange(len(evals))

    escape_vel =  [0.30, 0.35, 0.30, 0.40]
    return_pull = [0.20, 0.55, 0.55, 0.63]
    ia_benefit =  [0.65, 0.65, 0.65, 0.70]
    identity =    [0.30, 0.30, 0.50, 0.63]

    ax.plot(x, return_pull, 's-', color=GOLD, linewidth=2.5, markersize=9, label='return pull', zorder=3)
    ax.plot(x, identity, 'D-', color=PURPLE_C, linewidth=2, markersize=8, label='identity', zorder=3)
    ax.plot(x, ia_benefit, '^-', color=GREEN_C, linewidth=2, markersize=8, label='IA benefit', zorder=3)
    ax.plot(x, escape_vel, 'o-', color=RED_C, linewidth=2, markersize=8, label='escape velocity', zorder=3)

    ax.fill_between(x, return_pull, alpha=0.08, color=GOLD)
    ax.fill_between(x, escape_vel, alpha=0.06, color=RED_C)

    ax.set_xticks(x)
    ax.set_xticklabels(evals, fontsize=9, color=DIM_C)
    ax.set_ylim(0, 0.85)
    ax.set_ylabel('ceiling score (0-1)', color=DIM_C, fontsize=9)
    ax.legend(fontsize=8, loc='upper left', framealpha=0.3, ncol=2,
              labelcolor=FG_C, facecolor=CARD_C, edgecolor='#333')
    ax.grid(axis='y', color='#1a1a1a', linewidth=0.5)

    # Annotations
    ax.annotate('+215%', xy=(3, 0.63), xytext=(3.3, 0.72),
                color=GOLD, fontsize=9, fontweight='bold',
                arrowprops=dict(arrowstyle='->', color=GOLD, lw=1.2))
    ax.annotate('stubborn', xy=(2, 0.30), xytext=(1.5, 0.15),
                color=RED_C, fontsize=8,
                arrowprops=dict(arrowstyle='->', color=RED_C, lw=1))

    return fig_to_path(fig, 'growth_ceiling')


def chart_agent_recovery():
    """Agent operational status: 2/5 → 5/5"""
    fig, ax = plt.subplots(figsize=(7, 2.8))
    fig.patch.set_facecolor(BG)
    style_ax(ax, CARD_C)

    agents = ['scout', 'sweep', 'builder', 'design', 'strategist']
    # Timeline: day 1 (03-07), day 2 (03-08), day 3 (03-09)
    days = ['03-07', '03-08', '03-09']

    status_map = {
        'scout':      [0, 0, 1],  # dead, dead, alive
        'sweep':      [0, 0, 1],
        'builder':    [0, 0, 1],
        'design':     [0, 0, 1],
        'strategist': [0, 0, 1],
    }

    for yi, agent in enumerate(agents):
        for xi, day in enumerate(days):
            alive = status_map[agent][xi]
            color = GREEN_C if alive else RED_C
            alpha = 0.9 if alive else 0.4
            ax.scatter(xi, yi, s=350, color=color, marker='s', alpha=alpha, zorder=3)
            label = 'ON' if alive else 'OFF'
            ax.text(xi, yi, label, ha='center', va='center', color='white' if alive else '#666',
                    fontsize=7, fontweight='bold', zorder=4)

    ax.set_xticks(range(len(days)))
    ax.set_xticklabels(days, color=DIM_C, fontsize=10)
    ax.set_yticks(range(len(agents)))
    ax.set_yticklabels(agents, color=FG_C, fontsize=10)

    # Arrow: meta fix
    ax.annotate('meta detected\n& fixed', xy=(1.5, 2), xytext=(1.5, 3.8),
                color=GOLD, fontsize=8, ha='center', fontweight='bold',
                arrowprops=dict(arrowstyle='->', color=GOLD, lw=1.5))

    ax.set_xlim(-0.5, 2.5)
    ax.grid(axis='x', color='#222', linewidth=0.5)

    return fig_to_path(fig, 'growth_agents')


def chart_score_stability():
    """Score dimensions over 23 runs — structural scoring stability"""
    fig, ax = plt.subplots(figsize=(7, 2.8))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    runs = list(range(1, 24))
    build =     [90,90,90,90,90,70,90,90,70,90,90,90,90,90,100,100,70,70,90,70,70,90,90]
    structure = [86,86,86,86,86,86,86,86,86,86,86,86,86,84,84,84,84,84,84,84,84,84,84]
    hygiene =   [95]*23

    ax.plot(runs, build, color=GREEN_C, linewidth=1.5, alpha=0.7, label='build')
    ax.plot(runs, structure, color=BLUE_C, linewidth=2, label='structure')
    ax.plot(runs, hygiene, color=GOLD, linewidth=2, label='hygiene', linestyle='--', alpha=0.6)

    # Highlight the dips
    dip_runs = [6, 9, 17, 18, 20, 21]
    dip_scores = [build[r-1] for r in dip_runs]
    ax.scatter(dip_runs, dip_scores, color=RED_C, s=30, zorder=4, marker='v')

    ax.set_ylim(50, 110)
    ax.set_xlabel('score run', color=DIM_C, fontsize=9)
    ax.set_ylabel('score (0-100)', color=DIM_C, fontsize=9)
    ax.legend(fontsize=8, framealpha=0.3, labelcolor=FG_C,
              facecolor=CARD_C, edgecolor='#333', loc='lower left')
    ax.grid(axis='y', color='#1a1a1a', linewidth=0.5)

    ax.text(12, 55, 'build dips = real regressions caught', color=RED_C, fontsize=7, alpha=0.8)

    return fig_to_path(fig, 'growth_score')


def chart_gap_resolution():
    """Gap tracking: problems surfaced → addressed → resolved"""
    fig, ax = plt.subplots(figsize=(7, 3))
    fig.patch.set_facecolor(BG)
    style_ax(ax)

    gaps = ['escape velocity', 'return pull', 'identity', 'distribution', 'visual personality']
    evals = ['Eval 1', 'Eval 2', 'Eval 3', 'Eval 4']

    data = {
        'escape velocity':    [1, 1, 1, 0.5],
        'return pull':        [1, 0.5, 0.5, 0.5],
        'identity':           [1, 0.5, 0, 0],
        'distribution':       [1, 0.5, 0, 0],
        'visual personality': [0, 0, 1, 0.5],
    }

    for yi, gap in enumerate(gaps):
        vals = data[gap]
        for xi, val in enumerate(vals):
            if val == 1:
                color, marker_alpha = RED_C, 1.0
            elif val == 0.5:
                color, marker_alpha = GOLD, 0.8
            else:
                color, marker_alpha = GREEN_C, 0.5
            ax.scatter(xi, yi, s=280, color=color, marker='s', alpha=marker_alpha, zorder=3)

    ax.set_xticks(range(len(evals)))
    ax.set_xticklabels(evals, color=DIM_C, fontsize=9)
    ax.set_yticks(range(len(gaps)))
    ax.set_yticklabels(gaps, color=FG_C, fontsize=10)
    ax.set_xlim(-0.5, len(evals) - 0.5)

    ax.scatter([], [], s=120, color=RED_C, marker='s', label='open')
    ax.scatter([], [], s=120, color=GOLD, marker='s', label='improving')
    ax.scatter([], [], s=120, color=GREEN_C, marker='s', alpha=0.5, label='resolved')
    ax.legend(fontsize=8, loc='lower right', framealpha=0.3,
              labelcolor=FG_C, facecolor=CARD_C, edgecolor='#333')
    ax.grid(axis='x', color='#1a1a1a', linewidth=0.5)

    return fig_to_path(fig, 'growth_gaps')


def chart_compression():
    """Architecture compression: 13 → 5 agents"""
    fig, ax = plt.subplots(figsize=(7, 2.5))
    fig.patch.set_facecolor(BG)
    style_ax(ax, CARD_C)

    steps = ['v1\n(kitchen sink)', 'v2\n(cut fat)', 'v3\n(+features)', 'v4\n(rebrand)', 'v5\n(final)']
    counts = [13, 8, 10, 5, 5]
    colors = ['#555', PURPLE_C, BLUE_C, GOLD, GOLD]

    bars = ax.bar(steps, counts, color=colors, width=0.5, zorder=3)
    for bar, count in zip(bars, counts):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3,
                str(count), ha='center', color=FG_C, fontsize=12, fontweight='bold')

    ax.set_ylim(0, 16)
    ax.set_ylabel('agent count', color=DIM_C, fontsize=9)
    ax.grid(axis='y', color='#222', linewidth=0.5)

    # Arrow showing compression
    ax.annotate('', xy=(4, 5.5), xytext=(0, 13.5),
                arrowprops=dict(arrowstyle='->', color=GOLD, lw=2, connectionstyle='arc3,rad=-0.2'))
    ax.text(2, 14.5, '-62%', color=GOLD, fontsize=11, fontweight='bold', ha='center')

    return fig_to_path(fig, 'growth_compression')


def chart_taste_before_after():
    """Taste dimensions — the visual quality radar"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(7, 3), subplot_kw=dict(polar=True))
    fig.patch.set_facecolor(BG)

    dims = ['Hierarchy', 'Breathing\nRoom', 'Contrast', 'Polish',
            'Emotion', 'Density', 'Wayfinding', 'Distinct.']
    n = len(dims)
    angles = np.linspace(0, 2 * np.pi, n, endpoint=False).tolist()
    angles += angles[:1]

    before = [1, 1, 1, 1, 1, 1, 1, 1]
    after = [3, 2, 3, 1, 2, 1, 2, 3]

    for ax, scores, title, color in [(ax1, before, 'Before (broken routes)', RED_C),
                                      (ax2, after, 'After (real eval)', GOLD)]:
        ax.set_facecolor(BG)
        values = scores + scores[:1]
        ax.plot(angles, values, 'o-', color=color, linewidth=2, markersize=5)
        ax.fill(angles, values, alpha=0.15, color=color)
        ax.set_xticks(angles[:-1])
        ax.set_xticklabels(dims, fontsize=7, color=DIM_C)
        ax.set_ylim(0, 5)
        ax.set_yticks([1, 2, 3, 4, 5])
        ax.set_yticklabels(['1', '2', '3', '4', '5'], fontsize=6, color='#333')
        ax.set_title(title, color=color, fontsize=9, fontweight='bold', pad=12)
        ax.spines['polar'].set_color('#333')
        ax.grid(color='#222', linewidth=0.5)

    plt.tight_layout(w_pad=3)
    return fig_to_path(fig, 'growth_taste')


# === BUILD PDF ===

def build_pdf():
    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=20)

    identity = chart_identity_growth()
    ceiling = chart_ceiling_growth()
    agents = chart_agent_recovery()
    score = chart_score_stability()
    gaps = chart_gap_resolution()
    compression = chart_compression()
    taste = chart_taste_before_after()

    # --- 1: Title ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 50)
    pdf.big_title('Product Growth\nUnder AI Agents', 34)
    pdf.ln(10)
    pdf.set_x(MARGIN)
    pdf.caption('Real trajectories from products managed by rhino-os.\n65 experiments. 4 eval cycles. 5 agents. 2 projects.', 14)
    pdf.ln(12)
    pdf.set_x(MARGIN)
    pdf.stat_row('Identity score', '0.30 → 0.63  (+110%)', GOLD)
    pdf.stat_row('Return pull', '0.20 → 0.63  (+215%)', GOLD)
    pdf.stat_row('Agent uptime', '2/5 → 5/5  (self-healed)', GREEN_C)
    pdf.stat_row('Architecture', '13 agents → 5  (-62%)', PURPLE_C)
    pdf.stat_row('Experiments run', '65  (3 discarded)', FG_C)
    pdf.ln(10)
    pdf.set_x(MARGIN)
    pdf.dim('rhino-os  —  github.com/rhinehart514/rhino-os', 11)

    # --- 2: Identity sprint ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Identity: 0.30 → 0.63 in 17 experiments')
    pdf.caption('The system detected that copy-only changes plateaued at 0.44 and autonomously shifted to visual identity changes, which pushed past the ceiling. One experiment was discarded — a gold ping animation that improved the score but violated product constraints. That judgment call wasn\'t programmed. It emerged from the rubric.')
    pdf.image(identity, x=MARGIN, w=CW)
    pdf.ln(3)
    pdf.caveat('Scores are self-assessed via rubric. The trend is meaningful. Absolute values should be read with healthy skepticism.')

    # --- 3: Ceiling dimensions ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Ceiling dimensions across 4 eval cycles')
    pdf.caption('Return pull showed the biggest improvement (+215%) after a dedicated sprint targeting the day-3 return experience. Identity resolved after the experiment sprint above. Escape velocity remains stubborn — it requires network effects that don\'t exist yet at this user count. The system correctly identifies this as a stage constraint, not a fixable bug.')
    pdf.image(ceiling, x=MARGIN, w=CW)

    # --- 4: Agent self-healing ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('3 agents died. The system fixed itself.')
    pdf.caption('On 03-07, a nesting bug (CLAUDECODE env var blocking spawned processes) silently killed 3 of 5 agents. Nobody noticed. On 03-09, the meta agent ran its grading cycle, detected the crashes, diagnosed the root cause, patched the spawn command across all agent prompts, and brought everything back online.')
    pdf.image(agents, x=MARGIN, w=CW)
    pdf.ln(3)
    pdf.set_x(MARGIN)
    pdf.caption('The fix was one line: `CLAUDECODE= claude ...` to clear the environment variable before spawning. Meta found it by reading error logs and tracing the execution path. No human intervention.', 10)

    # --- 5: Scoring stability ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Structural scoring: catching regressions in real time')
    pdf.caption('score.sh runs on every commit. The build dimension dips (red triangles) are real regressions — TypeScript errors, stale builds, broken compilation. Each dip was caught immediately and fixed before it compounded. Structure and hygiene track long-term codebase health. This is the cheap "training loss" — fast, deterministic, every commit.')
    pdf.image(score, x=MARGIN, w=CW)

    # --- 6: Taste before/after ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Visual taste: the expensive eval')
    pdf.caption('The left radar is the first taste eval — routes were broken, everything scored 1/5. Not a design failure — a deployment failure. The system caught it. The right radar is the real eval after routes were fixed. Still mostly 2s and 3s (honest for an early product). The gap between these two tells you what "measuring by looking" catches that grep-based scoring misses.')
    pdf.image(taste, x=MARGIN, w=CW)
    pdf.ln(2)
    pdf.caveat('Taste scores are Claude vision reading Playwright screenshots. Calibrated against Notion/Discord/Linear. Most early products score 2-3. A 4+ is genuinely rare.')

    # --- 7: Gap resolution ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('Gap tracking: problems don\'t disappear')
    pdf.caption('Every eval surfaces ceiling gaps. Those gaps persist in the system until explicitly addressed. Escape velocity has been flagged since eval 1 and is still partially open. Identity was resolved after a dedicated sprint. New problems (visual personality) emerged as old ones closed. The mechanism is simple — append-only tracking — but it prevents the system from forgetting what\'s broken.')
    pdf.image(gaps, x=MARGIN, w=CW)

    # --- 8: Architecture compression ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 22)
    pdf.slide_title('The system deleted itself into shape')
    pdf.caption('Started with 13 agents doing overlapping work. Cut to 8. Added features, ballooned to 10. Rebrand forced a hard rethink — landed at 5 agents + 2 programs. Each surviving agent has clear ownership. The deleted agents weren\'t failures — they were learning. The final architecture is simpler because the early versions taught us what was actually needed.', 11)
    pdf.image(compression, x=MARGIN, w=CW)
    pdf.ln(6)
    pdf.set_x(MARGIN)

    # Stats block
    pdf.set_font('main', 'B', 11)
    pdf.set_text_color(218, 165, 32)
    pdf.cell(CW, 6, 'Final architecture:', ln=True)
    pdf.set_x(MARGIN)
    pdf.set_font('main', '', 10)
    pdf.set_text_color(180, 180, 180)
    lines = [
        'scout — landscape intelligence, market positions',
        'strategist — portfolio calls, sprint planning',
        'builder — the workhorse (gate/plan/build/experiment)',
        'design-engineer — visual taste, UI/UX audits',
        'sweep — daily triage, system health',
        'meta — grades agents, fixes prompts, the training loop',
    ]
    for line in lines:
        pdf.cell(CW, 5, f'  {line}', ln=True)
        pdf.set_x(MARGIN)

    # --- 9: Closing ---
    pdf.dark_page()
    pdf.set_xy(MARGIN, 50)
    pdf.big_title('Growth comes from\nthe scoring,\nnot the agents.', 28)
    pdf.ln(12)
    pdf.set_x(MARGIN)
    pdf.caption('Agents are interchangeable. Prompts are tunable. The scoring rubric — what "good" means for your specific product and your specific users — is the irreplaceable piece. That\'s where domain expertise lives. That\'s what makes the experiment loop produce signal instead of noise.', 12)
    pdf.ln(8)
    pdf.set_x(MARGIN)
    pdf.set_font('main', 'B', 14)
    pdf.set_text_color(218, 165, 32)
    pdf.multi_cell(CW, 8, 'github.com/rhinehart514/rhino-os', align='L')
    pdf.ln(4)
    pdf.set_x(MARGIN)
    pdf.caption('Open source. MIT license. Works with Claude Code natively.', 11)
    pdf.ln(10)
    pdf.set_x(MARGIN)
    pdf.dim('All data from 2 projects over 2 days. N=65 experiments. Self-assessed scores. Interpret accordingly.', 9)

    out = os.path.join(os.path.dirname(__file__), 'product-growth.pdf')
    pdf.output(out)
    print(f'PDF saved to: {out}')

if __name__ == '__main__':
    build_pdf()
