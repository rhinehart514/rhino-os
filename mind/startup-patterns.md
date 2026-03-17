# Startup Failure Mode Detection

Loaded into every session. Makes all agents startup-aware with zero cost.

## Failure Mode Detection Rules

Eight patterns, mechanically checkable from repo state. Each rule includes what to check, where to check it, and the intervention.

### 1. Building Without a Named Person

**Check:** `config/rhino.yml` → `value.user` field is empty, generic ("users", "developers", "teams"), or missing.
**Intervention:** "You're building for nobody. Name one human being and their situation before writing more code."
**Severity:** Critical at any stage.

### 2. Polishing Before Delivering

**Check:** `eval-cache.json` → any feature where `craft_score > delivery_score + 15`.
**Intervention:** "Feature [name] has craft [C] but delivery [D]. You're polishing something that doesn't work yet. Ship the value, then polish."
**Severity:** Critical at stage one. Warning at stage some.

### 3. Feature Sprawl

**Check:** `eval-cache.json` → count features where score is 30-60 simultaneously. If >3, triggered.
**Intervention:** "You have [N] features half-built. Pick one. Finish it. Kill or defer the rest."
**Severity:** Warning. Becomes critical if >5 features in the range.

### 4. Prediction Starvation

**Check:** `predictions.tsv` → count predictions in last 7 days. If <3, triggered.
**Intervention:** "Only [N] predictions in 7 days. The learning loop is starving. Every move needs a prediction."
**Severity:** Warning. The system learns nothing without predictions.

### 5. Strategy Avoidance

**Check:** `strategy.yml` → missing OR `last_updated` field >14 days old.
**Intervention:** "No strategy in [N] days. You're building without knowing if it matters. Run `/strategy honest`."
**Severity:** Warning at stage one. Critical at stage some+.

### 6. Thesis Drift

**Check:** `roadmap.yml` → current version's `evidence_needed` items all unchanged >14 days.
**Intervention:** "Thesis evidence hasn't moved in [N] days. Either the thesis is wrong or you're avoiding it."
**Severity:** Warning. Points to stale thesis or avoidance.

### 7. Revenue Avoidance

**Check:** `rhino.yml` → no `pricing` section AND `eval-cache.json` → 3+ features scoring 50+.
**Intervention:** "You have [N] working features and no pricing. At some point 'build more' becomes avoidance. Run `/money price`."
**Severity:** None at stage one. Warning at stage some. Critical at stage many.

### 8. Burnout Signals

**Check:** `git log` → >15 commits/day for 3+ consecutive days.
**Intervention:** "You've averaged [N] commits/day for [D] days. Sustained intensity without measurement usually means building in circles."
**Severity:** Warning. Not a command to stop — a signal to check if the work is moving the score.

---

## Stage-Appropriate Expectations

| Stage | Score | Focus | Acceptable debt | Red flags |
|-------|-------|-------|-----------------|-----------|
| **Pre-product** (no code) | N/A | Name the person, test demand assumption | Everything | Building before validating demand |
| **Stage one** (0 users) | 30-60 | First loop: discover → value moment → return trigger | Low craft, rough edges, manual processes | Polishing, growth features, pricing optimization |
| **Stage some** (1-10 users) | 50-75 | Retention: do they come back? Why/why not? | Some feature gaps, imperfect onboarding | New features instead of retention fixes, ignoring feedback |
| **Stage many** (10-100 users) | 65-85 | Distribution: how do new users find this? | Minor UX issues, incomplete docs | Building without distribution plan, feature sprawl |
| **Growth** (100+ users) | 75-95+ | Unit economics: does the business work? | Edge case gaps | Revenue avoidance, ignoring churn signals |

---

## Anti-Pattern Rationalization Table

Observed founder behavior patterns and their rationalizations. When you see the excuse, name it.

| Behavior | Excuse | Reality |
|----------|--------|---------|
| Building feature #4 before feature #1 scores 70 | "I need variety to stay motivated" | You're avoiding the hard part of feature #1 |
| Skipping /strategy for 2+ weeks | "I know my market" | You knew it 2 weeks ago. Markets move. |
| No predictions on any move | "Predictions slow me down" | Predictions take 10 seconds. You're avoiding accountability. |
| Polishing UI before core loop works | "First impressions matter" | First impressions of WHAT? Ship the value first. |
| Adding config options instead of defaults | "Users want flexibility" | You don't know what users want. Pick a default. |
| Reading competitor docs instead of building | "Research is important" | Research without a specific question is procrastination. |
| Rewriting architecture before shipping | "Tech debt will slow us down" | You have zero users. Debt to whom? |
| Refusing to name a price | "I'll figure out pricing later" | Pricing IS the product decision. Free = no signal. |
| Building growth features at stage one | "We need distribution" | You need ONE person who loves it. That's not a distribution problem. |
| Ignoring failing assertions | "Those assertions are wrong" | If they're wrong, delete them. If they're right, fix the code. |
