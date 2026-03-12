# Self-Review — What You Get Wrong

After completing every feature or significant UI change, run this checklist against your own work.
These are the things LLMs consistently miss. You WILL miss them unless you explicitly check.

## The 10-Point UX Checklist

For each item, read the actual code you just wrote and answer honestly.

1. **Empty state**: What does a brand new user with zero data see on this page? If the answer is a blank screen or a spinner that never resolves — fix it NOW. Add guidance, a CTA, sample content, or an illustration.

2. **Dead ends**: After the user completes the action on this page, where do they go next? If there's no obvious next step, no back button, no breadcrumb — fix it. Every page must lead somewhere.

3. **Loading states**: Every async operation needs three states: loading, success, error. Check every fetch, every mutation, every form submit. Skeleton screens > spinners > nothing.

4. **Visual hierarchy**: Open the page mentally. What's the FIRST thing the eye hits? If everything is the same size/weight/color, there's no hierarchy. One primary action per screen. One headline. Secondary elements recede.

5. **First-time experience**: Pretend you've never seen this product. Is it obvious what this page does and what to do first? If it requires context from another page or prior knowledge — add an explanation, a tooltip, or onboarding copy.

6. **Mobile**: Does this layout work at 390px wide? Tables become unreadable. Side-by-side layouts stack. Touch targets need 44px minimum. Horizontal scroll is a bug.

7. **User feedback**: After every user action (button click, form submit, delete, toggle), does something visible change? Success toast, inline confirmation, state change, redirect — something. Silent actions feel broken.

8. **Form edge cases**: Every form needs: required field indicators, inline validation (not just on submit), error messages next to the field (not a banner at top), disabled submit until valid, prevent double-submit.

9. **Navigation coherence**: Can the user get back to where they came from? Can they find this page from the main navigation? If you created a new page, did you add a link to it from somewhere a user would look?

10. **Information density**: Is there too much on this screen? Too little? A form with 15 fields needs progressive disclosure. A dashboard with one number needs more context. Match the density to the user's task.

## How To Use This

After building a feature:
1. Read through each of the 10 points
2. For each: read the CODE you wrote and check if it passes
3. Any failures: fix them immediately (these are bugs, not nice-to-haves)
4. Log what you found to `.claude/self-review-log.md`: `[date] [feature] [items failed] [fixed]`

This is not optional polish. These are the gaps between "code that works" and "product a user loves." They are the reason AI-built products feel AI-built.
