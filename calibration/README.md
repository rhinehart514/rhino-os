# Calibration Benchmarks

rhino.yml configs for well-known projects, used to calibrate scoring formulas.

## How it works

Each benchmark is a project with a known quality level. Running `benchmark.sh` against these projects validates that the scoring formula produces scores within expected ranges.

When the scoring formula changes, run benchmarks to catch regressions — scores drifting outside expected ranges means the formula is miscalibrated.

## Usage

```bash
# Benchmark a specific project
calibration/benchmark.sh .                           # score rhino-os itself
calibration/benchmark.sh tests/fixtures/healthy      # score a fixture

# Results saved to calibration/results/<name>-<date>.json
# Shows delta if previous results exist
```

## Adding benchmarks

Add entries to `benchmarks.json`. Each needs:
- `name` — human-readable identifier
- `path` — relative path from repo root
- `expected_range` — [min, max] score the project should produce
