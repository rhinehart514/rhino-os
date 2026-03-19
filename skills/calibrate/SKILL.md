---
name: calibrate
description: "Redirects to /taste calibrate. Calibration is now part of the taste skill."
user-invocable: true
---

# /calibrate has moved

Calibration is now part of `/taste`. Run:

- `/taste calibrate` — full calibration
- `/taste calibrate profile` — founder preferences
- `/taste calibrate design-system` — extract design system
- `/taste calibrate verify` — check calibration accuracy
- `/taste calibrate drift` — detect preference drift

This redirect exists for backward compatibility.

## If something breaks

- "/calibrate not found": the skill is installed but redirects to `/taste calibrate` — use that directly
- Calibration data not persisting: check that `.claude/cache/taste-calibration.json` is writable
- Design system extraction fails: ensure the project has a running dev server or static HTML to analyze
