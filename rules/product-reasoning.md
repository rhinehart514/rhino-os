---
paths:
  - "product/**"
  - "docs/**"
  - "**/*.spec.md"
  - "**/*.feature.md"
  - "apps/*/components/**"
  - "apps/*/app/**"
  - "packages/*/src/**"
---

# Product-First Reasoning (loaded only when working on product files)

## Required reasoning order
1. Value prop — Who benefits? What friction removed?
2. Workflow impact — Which workflow? Faster/more reliable/more obvious?
3. Feature behavior — User sees what? Inputs, outputs, failure modes
4. Eval plan — Which value proxy moves? Which perspective breaks it?
5. Implementation — Now write code

## Value Mechanisms
| Mechanism | Definition |
|-----------|-----------|
| Time compression | Same outcome faster |
| Quality uplift | Better than user could do alone |
| Reach | Creation gets to more people |
| Engagement | More people interact |
| Aliveness | Surface feels active at low density |
| Loop closure | One action leads to next |
| New capability | Couldn't do before |
| Coordination reduction | Less back-and-forth |

## Anti-Patterns (instant reject)
- Requires more users than product currently has
- Builds consumption before creation when creation is bottleneck
- Screens without outbound links
- Optimizes metrics before core workflow completes
- Builds infrastructure before product is proven
