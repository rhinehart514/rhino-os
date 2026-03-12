---
name: corpus
description: Manage the taste corpus. Add, update, and view examples of exceptional work.
user-invocable: true
argument-hint: "[update|add|list] [category]"
---

# /corpus

The corpus is a curated database of top 0.1% examples used to calibrate evals.

## /corpus update [category]

Run the AI discovery loop for a category. Categories: ui/saas, ui/consumer, ui/developer, copy/landing, copy/onboarding, code/patterns.

Steps:
1. Web search for "best [category] examples [current year]"
2. Focus on reputation signals: Awwwards, Product Hunt top products, designer community consensus
3. For each candidate, describe it and ask: would this be considered top 0.1% in its category?
4. Use multi-perspective evaluation (consider: clarity, hierarchy, polish, distinctiveness, emotional quality)
5. Only admit examples with clear consensus exceptional quality (not just "good" — genuinely exceptional)
6. Add admitted examples to `corpus/[category]/` with a metadata entry
7. Log what was added and why

## /corpus add [url or description]

Add a specific example manually. Describe why it's exceptional. Add to appropriate category.

## /corpus list

Show current corpus size by category and when last updated.

## Quality Bar

The corpus sets the target for top 0.1% output. Be ruthless about quality — it's better to have 5 genuinely exceptional examples than 20 mediocre ones. When in doubt, don't admit.

If something is "good" or "above average" -> reject.
If something makes you think "this is exceptional" -> admit.
