# Dashboard Gotchas

- **Dashboard addiction**: Checking /rhino repeatedly without building. The dashboard shows state, it doesn't change state.
- **Opinion over-scripting**: The decision tree produces mechanical advice. Good opinions need judgment.
- **Pattern detection false positives**: "Bottleneck stagnation" fires when working on a hard problem. Not every stall is wrong.
- **Snapshot bloat**: rhino-snapshots.json grows unbounded. Keep last 20, prune older.
- **Score-product divergence**: Score improves while product doesn't (assertion gaming) or product improves while score doesn't (formula lag).
- **Health grade inflation**: A-F grade can show A when learning loop is broken (predictions ungraded for weeks).
