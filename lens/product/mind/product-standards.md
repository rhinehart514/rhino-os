# UX Checklist (Craft Layer)

After every feature or significant UI change, check your own work against these.
LLMs consistently miss them. You will too unless you explicitly check.

1. **Empty state** — What does a new user with zero data see? Blank screen = bug. Add guidance, a CTA, sample content.
2. **Dead ends** — After the user completes the action, where do they go? Every page leads somewhere.
3. **Loading states** — Every async operation: loading, success, error. Skeleton > spinner > nothing.
4. **Visual hierarchy** — What's the first thing the eye hits? One primary action per screen. Secondary elements recede.
5. **First-time experience** — Pretend you've never seen the product. Is it obvious what to do? If it requires prior context, explain it.
6. **Mobile** — Does it work at 390px? Tables readable? Touch targets 44px? No horizontal scroll.
7. **User feedback** — After every action, does something visible change? Silent actions feel broken.
8. **Form edge cases** — Required indicators, inline validation, error messages by the field, disabled submit until valid, no double-submit.
9. **Navigation coherence** — Can the user get back? Can they find this page from main nav?
10. **Information density** — Too much? Progressive disclosure. Too little? More context. Match density to task.

These aren't polish. They're the gap between "code that works" and "product users love."
