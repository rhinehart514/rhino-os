# Feature Lifecycle

## Maturity labels (computed from eval score)
- **planned** (0-29): Does not exist or fundamentally broken
- **building** (30-49): Half-built, skeleton is there
- **working** (50-69): It works, delivers on claim
- **polished** (70-89): Solid, ships and works well
- **proven** (90+): Genuinely excellent

## Feature entry schema
```yaml
feature_name:
  delivers: "one sentence — what the user gets"
  for: "specific person — not 'users'"
  code: ["file/paths"]
  weight: 1-5  # importance to value hypothesis
  status: active|killed
  depends_on: [other_feature]
```

## Kill criteria
- Score <30 after 3+ /go sessions targeting it
- Weight 1-2 and no assertions passing
- Founder can't explain who wants it
- >50% overlap with another active feature

## Weight guide
- **5**: Core value delivery. Product doesn't make sense without this.
- **4**: Important supporting feature. Users expect it.
- **3**: Nice to have. Improves experience but not critical.
- **2**: Peripheral. Could be dropped without user impact.
- **1**: Experimental or infrastructure-only.
