# rhino-os

A knowledge-compounding strategy engine for solo founders. Not another Claude Code workflow kit — there are 349 of those.

rhino-os does three things no other system does:
1. **Portfolio intelligence** — Buy/Sell/Hold verdicts across your entire project and feature set
2. **Landscape positions** — Opinionated strategic beliefs about 2026, not trend lists. Agents reason FROM these.
3. **Taste learning** — Observes your decisions and builds a preference profile that every agent respects

```
5 Agents  ·  3 Intelligence Layers  ·  1 MCP Server  ·  1 CLI
Thick-skinned. Charges forward. Kills what isn't working.
```

## Quickstart

```bash
git clone https://github.com/YOUR_USERNAME/rhino-os.git ~/rhino-os
cd ~/rhino-os
./install.sh
```

Edit `~/.claude/CLAUDE.md` with your identity and project info. Then:

```bash
rhino doctor                 # verify installation
rhino strategy               # portfolio evaluation — start here
rhino scout                  # update landscape positions
rhino sweep                  # daily triage
```

## Why This Exists

The Claude Code ecosystem has 40+ workflow orchestrators, 100+ agent collections, and 349+ skills. All commodity. rhino-os doesn't compete there.

The gap: no system learns your judgment. No system evaluates your entire portfolio and tells you what to kill. No system maintains opinionated positions about the world and reasons from them.

rhino-os is the strategic brain. The builder/design-engineer agents are just hands.

## The Three Intelligence Layers

### Portfolio Model (`rhino_portfolio`)
Structured JSON, not markdown. Every project, every feature, every kill criterion.

```
rhino_portfolio(action: "evaluate")
→ HIVE → BUY (core loop incomplete, but wedge is real, campus is underserved)
→ rhino-os → HOLD (useful to you, commodity market, don't chase stars)
→ side-project-X → SELL (no users in 60 days, kill trigger hit)
```

The strategist reads the ENTIRE portfolio before making any recommendation. Not project-level cheerleading — portfolio-level calls.

### Landscape Positions (`rhino_landscape`)
Opinionated beliefs about what works in 2026. Not trends — positions with evidence and implications.

```
[STRONG] "AI wrappers are dead — the wedge is proprietary data + workflow"
  Implications: Any product wrapping Claude/GPT API is on borrowed time
  Evidence: Anthropic shipping natively, enterprise consolidating spend

[STRONG] "Solo founders win on context engineering + distribution, not product quality"
  Implications: Stop polishing. Focus on reaching users.

[MODERATE] "Campus infrastructure is underserved — incumbents sell to admins, not students"
  Implications: Student-first distribution is the wedge for HIVE
```

Scout maintains these. Strategist reasons from them. Every recommendation references a position.

### Taste Signals (`rhino_taste`)
Observations about your preferences, recorded as agents watch you work.

```
[product]  "Rejects onboarding flows — wants users dropped into value immediately"
[design]   "Prefers dense data layouts over whitespace"
[strategy] "Kills features aggressively when no user signal exists"
[technical] "Prefers simple bash over complex TypeScript when both work"
```

Every agent reads taste before acting. The design-engineer uses it instead of generic rubrics. The builder respects your technical preferences. The strategist aligns recommendations with your judgment patterns.

## Agent Catalog

| Agent | Role | Intelligence Used |
|-------|------|-------------------|
| **strategist** | Portfolio evaluation, Buy/Sell/Hold, kill calls | Portfolio + Landscape + Taste |
| **scout** | Landscape position maintenance, market intelligence | Landscape + Portfolio + Taste |
| **sweep** | Daily triage, system health, operational state | Portfolio + Taste |
| **builder** | Gate → Plan → Build → Doctor | Taste (technical + product) |
| **design-engineer** | Visual eval, design systems, UI fixes | Taste (design) |

## Workflow

```
Weekly (strategic):
  rhino strategy                    # Portfolio evaluation + hard calls
  rhino scout                       # Update landscape positions

Daily (operational):
  rhino sweep                       # What needs attention?
  rhino status                      # System state at a glance

During work:
  rhino build                       # Auto-detects mode from context
  rhino build "gate"                # Should I build this?
  rhino build "implement task 3"    # Build specific task

API (programmatic):
  rhino serve                       # Start API on :7890
```

## MCP Tools

The intelligence layers are accessible via MCP tools that agents use automatically:

| Tool | Purpose |
|------|---------|
| `rhino_portfolio` | Read/update/evaluate project portfolio |
| `rhino_landscape` | Read/update strategic positions |
| `rhino_taste` | Record/query preference signals |
| `rhino_get_state` | Inter-agent operational state |
| `rhino_set_state` | Write operational state |
| `rhino_query_knowledge` | Query accumulated knowledge |
| `rhino_update_knowledge` | Update knowledge files |
| `rhino_backup_knowledge` | Snapshot all knowledge |

## Honest Limitations

**The taste system requires sessions to compound.** It starts empty. It gets better as you work and agents observe your decisions. First week is generic. By week four, agents know your judgment patterns.

**Portfolio evaluation is only as good as the data.** You need to populate the portfolio model with your actual projects. The strategist can auto-discover projects, but you need to confirm stages and user counts.

**Landscape positions are opinionated and sometimes wrong.** That's the point — they're positions, not facts. Scout revises them when evidence changes.

**Budget caps are real.** `rhino` CLI passes `--max-budget-usd` to Claude. Still check the dashboard.

**Knowledge files are gitignored.** Use `rhino backup` regularly.

## Credits

Informed by [PAHF](https://arxiv.org/abs/2602.16173) (preference learning from feedback), [compound engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents) (knowledge loops), and [HBR portfolio management](https://hbr.org/2026/01/manage-your-ai-investments-like-a-portfolio) (Buy/Sell/Hold for AI investments).
