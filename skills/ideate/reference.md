# /ideate Reference — Output Templates

Loaded on demand. Protocol and routing are in SKILL.md.

---

## Product-level ideation

```
◆ ideate

  v8.0: **43%** · product: **64%** · bottleneck: **learning** (building, w:4, c:40)
  thesis: "Someone who isn't us can complete a loop without help"
  unproven: first-go · return

▾ ideas

  ▸ **Guided onboarding flow** — from wrong prediction
    evidence: prediction "users will find /plan naturally" was wrong.
    Cross-recommendations exist but new users don't know to start with /plan.
    what: After /onboard completes, show a 3-step guide: "1. /plan to see
    what needs work → 2. /go to build it → 3. /eval to measure." Not a
    tutorial — a signpost. One screen, three commands, done.
    who: stranger who just ran /onboard and sees a score but doesn't know
    what to do next.
    changes: delivery_score on commands +10, directly proves "reach-plan" evidence
    costs: 1 session. Defers learning feature work.
    kills it: users skip guidance and explore on their own anyway
    draft assertions:
      - commands: /onboard output includes next-step guidance
      - commands: /plan is reachable within 2 commands of /onboard

  ▸ **Mechanical prediction grading** — from sub-score gap
    evidence: learning craft_score is 40 (lowest across all features).
    Known Pattern: "prediction grading is manual, breaks the learning loop."
    16 predictions, only 10 graded.
    what: `bin/grade.sh` reads predictions.tsv, matches against eval-cache
    scores and git log, fills in result/correct for directional claims
    automatically. Runs on session start.
    who: the learning system itself — compounds across sessions.
    changes: learning craft_score 40→55+, directly proves "first-go" evidence
    costs: 1 session. Requires touching session_start hook (Known fragile).
    kills it: predictions too vague to grade mechanically
    draft assertions:
      - learning: grade.sh fills result column for >50% of predictions
      - learning: grading accuracy matches human judgment >80%

  ▸ **Steal: Linear's project updates pattern** — from market
    evidence: WebSearch shows Linear auto-generates project status from
    completed issues. rhino-os has all the data (/go sessions, eval deltas,
    todo completion) but no auto-generated status update.
    what: `/rhino` auto-generates a 3-sentence project update from the last
    session's data: what was built, what improved, what's next. Copyable
    for Slack/Discord/standup.
    who: founder who needs to tell someone what happened this week.
    changes: commands delivery_score +5, new capability for /rhino
    costs: small — extends existing dashboard, doesn't block anything
    kills it: founders don't share status updates with anyone (solo = no audience)
    draft assertions:
      - rhino: /rhino output includes a copyable status update

▾ kill list

  ✗ **defer self-diagnostic feature** (w:2, working)
    reason: self-diagnostic doesn't advance the v8.0 thesis. It's working
    and stable. Every session spent on it is a session not spent on learning
    (w:4, building) or proving first-go.
    action: keep as-is, remove from active work, revisit in v9.0

  ✗ **kill todo [xx-09] "redesign dashboard layout"** (32 days stale)
    reason: dashboard works. This is polish on a non-bottleneck feature.

  ✗ **remove assertion "score-has-history"** (always passes, low signal)
    reason: history.tsv has existed since v7.0. This assertion will never
    fail and teaches nothing.

Which ideas to commit? Which kills to confirm? (pick numbers or "all")
```

## Feature-level ideation

```
◆ ideate — learning

  learning: 48/100 (d:55 c:40 v:48) — weakest: **craft_score 40**
  eval: 48 → target: 60+ (needs >50% assertions + core flow)
  rubric: integrity axis says "all file I/O paths handled" for 80
  backlog: 3 todos tagged to learning

▾ ideas (targeting craft_score)

  ▸ **Wrap prediction grading in error handling**
    evidence: 4 unhandled paths in grade.sh (from rubric check)
    what: try/catch around file reads, handle empty predictions.tsv,
    handle malformed rows gracefully.
    changes: craft_score 40→55
    costs: half a session
    kills it: error handling is already there and the rubric is wrong

  ▸ **Extract grading into standalone module**
    evidence: Known Pattern — "session_start hook is fragile." Moving
    grading out of the hook and into a standalone script reduces blast radius.
    what: bin/grade.sh becomes independently callable. Hook calls it but
    failure doesn't break boot.
    changes: craft_score 40→50, reduces fragility risk
    costs: half a session, touches hook (known risky)
    kills it: the hook isn't actually the problem — grading logic is

▾ kill list

  ✗ **kill todo [km-04] "knowledge model pruning"**
    reason: pruning doesn't help craft_score, which is the bottleneck.
    Defer until learning reaches 60+.

Which to commit?

/feature learning    see current state
/go learning         build the committed idea
/eval deep learning  verify after
```

## Wild mode

```
◆ ideate wild

  3 high-conviction bets. Not experiments — committed directions.

  ▸ **Kill the CLI entirely**
    evidence: Known Pattern — "commands are the product, CLI is the wrapper."
    Founder said "transform from CLI to within Claude Code." Plugin mode
    already works. The CLI is legacy.
    what: Remove bin/ scripts as user-facing tools. Everything is a slash
    command. Score, eval, taste — all /eval, not rhino eval. The CLI
    becomes an internal build tool only.
    who: every Claude Code user — zero install friction
    burns: CI/script integration. External tooling that calls rhino directly.
    draft assertions:
      - all user-facing operations work via slash commands
      - no README references bin/ scripts as user commands

  ▸ **Agent-native architecture**
    evidence: /go beta showed speculative branching produces better outcomes.
    Claude Code agent teams are designed for this. Nobody else ships
    autonomous multi-agent product development.
    what: Every /go session spawns a team — builder, measurer, reviewer
    working in parallel. Not sequential. The founder watches, not directs.
    burns: single-agent simplicity. Debug complexity. Token cost 5x.

  ▸ **Plugin marketplace — be the platform**
    evidence: .claude-plugin format works. Skills are portable. No other
    Claude Code plugin has a measurement layer. Be the App Store, not an app.
    what: rhino-os becomes the distribution layer for Claude Code skills.
    Other developers publish skills. rhino-os handles measurement, scoring,
    quality gates. `/skill install` becomes the npm of Claude Code.
    burns: focus. Building a platform before the product is proven for one user.

Which direction? (These are irreversible — pick carefully)
```

## Formatting rules

- Header: `◆ ideate — [scope]`
- State bar: version completion + product completion + bottleneck with sub-score
- Ideas: `▸ **[Name]** — [evidence source]` (not quadrant labels)
- Brief fields: evidence/what/who/changes/costs/kills it/draft assertions
- `evidence:` is FIRST — every idea leads with why, not what
- Kill list: `✗ **[what to kill]**` with reason and action
- Kill list is mandatory — at least one kill per session
- AskUserQuestion at end — founder picks commits and kills
- Bottom: 2-3 relevant next commands
