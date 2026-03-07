---
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.jsx"
  - "**/*.js"
  - "**/*.css"
---

# Quality Bar — Every Line of Code Serves the User

The goal is not clean code. The goal is: a user opens this, loves it, gets value, and comes back.

## Before writing any code, answer:
1. **What user moment does this create?** If you can't describe the moment of delight or value → stop and think
2. **Will a real person (not a developer) notice this change?** If no → is it worth doing right now?
3. **Does this move the product closer to "someone would miss this if it disappeared"?** If no → deprioritize

## The Completion Lens
Code is not "done" when it compiles. Code is done when:
- [ ] A new user can discover this feature without being told it exists
- [ ] The feature delivers its value prop within 10 seconds of interaction
- [ ] The happy path feels effortless (no hesitation, no confusion)
- [ ] Failure states guide the user back to the happy path (not dead ends)
- [ ] Empty states explain what WILL be here and invite the user to create it
- [ ] The UI communicates the value prop visually (not just functionally)
- [ ] Mobile touch targets ≥ 44px, text readable without zoom
- [ ] Loading states show progress, not emptiness
- [ ] The feature connects to the rest of the product (outbound links, next actions)

## UI/UX Non-Negotiables
- Every screen answers: "What should I do here?" within 3 seconds
- Every action has visible feedback (optimistic UI, toasts, transitions)
- Every error tells the user what went wrong AND what to do next
- No orphan screens — every view has a way in and a way out
- Visual hierarchy guides the eye: primary action obvious, secondary discoverable
- Consistency: same pattern = same component (use shared packages)

## Technical Quality (serves the user indirectly)
- TypeScript strict — no `any` (broken types → broken features later)
- No stub functions in user-facing code (if it's clickable, it must work)
- No console.log in production (users don't see your debug output, but performance suffers)
- Error boundaries around async operations (crashes → lost users)
- Performance: lazy load below-fold, code-split routes, memoize expensive renders

## The "Would I Use This?" Test
After implementing, ask honestly:
- Would I show this to a friend and feel proud?
- Would I use this daily if I were the target user?
- Is there anything that makes me wince?
If you wince → fix it before calling it done.
