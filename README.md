# rhino-os

For solo technical founders building products with Claude Code.

A plugin that turns Claude into a cofounder — it measures whether your product actually delivers value (not just code quality), learns what works across sessions, builds autonomously, and thinks about customers, pricing, and distribution.

## How it's different

Most dev tools measure code quality — linting, test coverage, type safety. rhino-os measures **product quality**: does the user get value? It plants testable beliefs about your product ("the signup flow completes in under 30 seconds"), scores them, and reverts changes that make things worse. SonarQube tells you your code is clean. rhino-os tells you your product is better.

## Install

```bash
claude /plugin marketplace add rhinehart514/rhino-os
claude /plugin install rhino-os@rhino-marketplace
```

No plugin system? `git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os && cd ~/rhino-os && ./install.sh`

**Requires:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code), macOS/Linux (Windows not yet supported), [jq](https://jqlang.github.io/jq/download/)

---

## Walkthrough: Building a recipe app from scratch

You have an idea for a recipe sharing app. Here's what a real session looks like with rhino-os installed.

One key concept: rhino-os uses **assertions** — testable beliefs about your product, like "the import extracts a title from any recipe URL." It plants them automatically, scores them, and tracks which ones pass. Your score is the percentage of assertions passing.

### 1. Start with the idea — not the code

```
> I want to build a recipe sharing app for home cooks
```

rhino-os matches your intent to `/product` automatically:

```
── verdict ────────────────────────────────
  product clarity: 4/10
  biggest risk: demand assumption — "home cooks want to share recipes"
    untested. Every recipe app that failed assumed sharing was the draw.
    The ones that survived (Paprika, Mela) focused on personal organization.

  "You're building for 'home cooks' — that's 200 million people.
   Name one. What's their Saturday morning look like?"

  top assumption: people want to SHARE recipes (risk: 5, ignorance: 4)
  #2: they'll use a new app instead of Notes/screenshots (risk: 4, ignorance: 4)

  draft value hypothesis:
    hypothesis: "Home cooks who collect recipes from 5+ sources want one
                 place to save, organize, and cook from them"
    user: "A home cook who has recipes in screenshots, bookmarks,
           Instagram saves, and a physical notebook"

/onboard    bootstrap the repo with this hypothesis
/research   validate the top assumption before building
```

### 2. Bootstrap the project

```
> /onboard
```

rhino-os reads the value hypothesis, generates features with weights, plants assertions, and gives you a starting score:

```
◆ onboard — recipe-app

  value: "Home cooks who collect recipes from 5+ sources want one
          place to save, organize, and cook from them"
  user: home cook with recipes scattered across 5+ sources

  features:
    recipe-import  w:5  — import from URL, photo, or text
    recipe-viewer  w:4  — clean cook-mode display
    collections    w:3  — organize by meal, cuisine, season
    search         w:2  — find by ingredient or name

  assertions planted: 12
  score: 0/100

/plan    find the bottleneck and start building
```

### 3. Find the bottleneck, start building

```
> what should I work on?
```

rhino-os runs `/plan`:

```
◆ plan

  score: 0 · assertions: 0/12 · thesis: v1.0

  ● Building Without a Named Person — warning
    evidence: rhino.yml user is generic ("home cook")
    "Name one human being and their situation before writing more code."

  bottleneck: recipe-import at 0 — w:5, everything depends on it
    d:0 c:0 v:0 — no code exists

  move 1: build recipe-import — URL parsing + display
    predict: "URL import will reach delivery_score 50+ in one session"
    acceptance: url-extracts-title PASS, url-extracts-ingredients PASS

  move 2: build recipe-viewer — cook-mode with step highlighting
    depends on: recipe-import

/go recipe-import    build it autonomously
```

Notice the startup pattern warning — rhino-os detected "building without a named person" from `mind/startup-patterns.md` and flagged it before you wrote any code.

### 4. Build autonomously

```
> /go recipe-import
```

The `/go` loop: predict, build, measure, learn. It shows you the plan, waits for approval, then builds:

```
◆ go — recipe-import

  ⚠ Building recipe-import with no customer signal.
    Proceed / /discover first / /strategy user
> Build it

  predict: "URL import will reach delivery_score 50+"
  because: "exploring — no prior data on this feature"

  move 1: URL parsing + recipe extraction
  ▾ commit — a1b2c3d
    built: URL parser extracts title, ingredients, steps from common recipe sites
    files: src/lib/parser.ts, src/components/RecipeImport.tsx
    ✓ url-extracts-title        PASS
    ✓ url-extracts-ingredients   PASS
    · url-extracts-steps         FAIL — schema.org markup only, misses plain HTML

  measure: recipe-import at 42 (d:48 c:40 v:35)
  score: 0 → 35 ↑35

  move 2: plain HTML fallback + error states
  ▾ commit — c3d4e5f
    ✓ url-extracts-steps         PASS
    ✓ import-shows-error         PASS

  measure: recipe-import at 58 (d:62 c:55 v:48)
  score: 35 → 52 ↑17

  grade: "URL import reached delivery 62, predicted 50+. Correct."
  session: 2 moves, 2 kept, score 0→52
```

### 5. Check if the product is any good

```
> is this good?
```

rhino-os runs `/eval`:

```
◆ eval — 4 features

  recipe-import  ████████████░░░░░░░░  58  d:62 c:55 v:48
    plain HTML parsing fragile — breaks on non-English sites

  recipe-viewer  ░░░░░░░░░░░░░░░░░░░░   0  d:0 c:0 v:0
    no code exists

  collections    ░░░░░░░░░░░░░░░░░░░░   0
  search         ░░░░░░░░░░░░░░░░░░░░   0

  beliefs: 5/12 passing
  bottleneck: recipe-viewer at 0 — w:4, blocks the cook experience
```

### 6. Think about who this is actually for

A few sessions in, you have a working import and viewer. Time to think about the business:

```
> who is this for really?
```

rhino-os runs `/product`:

```
── verdict ────────────────────────────────
  product clarity: 6/10
  stage: one (0 users)
  biggest risk: demand — nobody has asked for this

  ● Revenue Avoidance — warning
    evidence: 3 features scoring 50+, no pricing section in rhino.yml
    "You have working features and no pricing. Run /money price."

  "The recipe import works. The viewer works. But you've never
   talked to a home cook about whether they'd use this. The code
   is ahead of the evidence."

/discover    find customer signal before building more
/money       pricing and distribution strategy
```

### 7. Figure out distribution and pricing

```
> /money price
```

The gtm agent researches competitor pricing while the market-analyst pulls real data:

```
◆ money — pricing

  competitors:
    Paprika    — $4.99 one-time — iOS/Android/Mac
    Mela       — $2.99/mo — Apple ecosystem
    Copy Me That — free + $3/mo premium
    Whisk      — free (Samsung subsidiary)

  recommend: freemium at $3/mo per user
    free: 50 recipes, basic import
    paid: unlimited, collections, cook-mode
  why: matches Mela pricing, undercuts on platform (web-first)
  risk: one-time purchase (Paprika) is strong competition

  unit economics:
    revenue/user: $3/mo
    est. CAC: $5-15 (content marketing)
    est. LTV: $36 (12mo × $3)
    payback: 2-5 months
    confidence: low (no retention data)
```

### 8. Write the landing page

```
> /copy landing
```

The copywriter agent reads your market context, customer signal, and value hypothesis:

```
◆ copy — landing

  for: "A home cook with recipes in screenshots, bookmarks, and a notebook"

⎯⎯ hero ⎯⎯

  # All your recipes. One place.

  Import from any URL. Organized automatically. Cook-mode for hands-free.

  [Save your first recipe]

  quality gate:
    ✓ names person: home cook with scattered recipes
    ✓ states change: one place instead of 5+ sources
    ✓ differentiates: web-first (vs Apple-only Mela/Paprika)
    ✓ slop-free
```

### 9. Keep going

Every session, rhino-os picks up where you left off. The score compounds. The predictions get sharper. The startup pattern checks keep you honest.

```
> /plan

  score: 68 · assertions: 9/12 · v1.0: 60% proven

  ● Thesis Drift — warning
    evidence: roadmap evidence unchanged 8 days
    "Either the thesis is wrong or you're avoiding it."

  bottleneck: search at 32 — d:35 c:30 v:28
```

---

## Commands

You don't need to memorize these. Just talk — rhino-os routes your intent.

**Build**
- `/plan` — find the bottleneck, propose what to work on
- `/go` — autonomous build loop with prediction grading
- `/eval` — score every feature 0-100 (delivery/craft/viability)
- `/taste` — visual product intelligence via Playwright

**Think**
- `/product` — pressure-test assumptions, name the person
- `/strategy` — market intelligence, honest diagnosis
- `/discover` — what systems should this product have?
- `/ideate` — evidence-weighted ideas + kill list
- `/research` — gather evidence before deciding

**Business**
- `/money` — pricing, unit economics, channels, runway
- `/copy` — landing pages, pitch, outreach, release notes
- `/ship` — commit, push, deploy, GitHub releases

**Manage**
- `/feature` — define and track features
- `/todo` — living backlog with decay and promotion
- `/assert` — plant testable beliefs
- `/retro` — grade predictions, update the knowledge model
- `/roadmap` — version theses and external narrative
- `/rhino` — dashboard + system status

## The score

Your score is the percentage of assertions that pass. Not lint. Not code quality. **Does your product do what you said it should do?**

Score goes up = you shipped value. Score drops = the change gets reverted.

## How the pieces fit

rhino-os has three layers that work together:

**Measurement** — `/eval` scores your features 0-100 across delivery, craft, and viability. `/taste` evaluates visual quality via screenshots. `rhino score .` runs fast structural checks. Score drops after a change trigger automatic reverts.

**Learning** — Every action starts with a prediction ("I predict URL import will reach delivery 50+"). After building, the grader agent checks the prediction against the result. Wrong predictions update the knowledge model. Over sessions, the system stops guessing and starts citing evidence.

**Strategy** — 14 specialized agents handle different jobs. The builder writes code in isolated worktrees. The founder-coach detects startup failure modes (building without a named user, polishing before delivering). The customer agent synthesizes real signal. The gtm agent handles pricing and distribution. They're coordinated by commands like `/go` and `/plan`, not invoked manually.

## Tested on

- **rhino-os itself** — score 20 to 93 over ~30 sessions across 2 weeks, 59/66 assertions passing
- **commander.js** — 80/100 on first `rhino init`, zero configuration

---

[MIT](LICENSE)
