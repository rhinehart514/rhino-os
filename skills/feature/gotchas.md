# Feature Management Gotchas

- **Feature creep**: Adding features is exciting. Killing them is hard. Every feature that exists demands maintenance.
- **Weight inflation**: Founders overweight features they enjoy working on, not features users need.
- **Detection false positives**: Auto-detect finds "features" that are just utility code. Not every module is a feature.
- **Maturity wishful thinking**: Labeling a feature as "working" (50-69) when eval says 35. Let the score determine maturity.
- **Dependency cycle**: A depends on B depends on A. Detect and break cycles before they block the build loop.
- **Killed feature guilt**: Marking a feature as killed feels like failure. It's not — it's honest resource allocation.
- **Missing "for" field**: Features without a specific user ("developers" is not specific) can't be evaluated for delivery.
