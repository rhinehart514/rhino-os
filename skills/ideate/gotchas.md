# Ideation Gotchas

Built from real failure modes across sessions. Update this when /ideate fails in a new way.

## Evidence failures
- **"Wouldn't it be cool if..."**: Ideas without evidence are wishes. Every idea needs a cite from eval-cache, predictions.tsv, customer-intel, or market data. If you can't cite, say "exploring unknown territory" explicitly.
- **Stale evidence**: market-context.json from 2 weeks ago is not evidence. Check dates. Run `scripts/evidence-scan.sh` for fresh data.
- **Citing your own prediction as evidence**: "I predicted X, therefore X" is circular. Predictions are hypotheses, not evidence. Evidence is what HAPPENED.

## Generation failures
- **Quadrant filling**: Innovation matrices tempt you to fill every cell. Some cells should be empty. 2 good ideas beats a full matrix of mediocre ones.
- **Feature-as-idea**: "Add a dashboard" is a solution, not an idea. Ideas are about problems: "Users can't see their progress over time." The solution might be a dashboard, or a weekly email, or a CLI sparkline.
- **Incremental only**: If every idea is "+5 to a sub-score," you're optimizing, not ideating. Include at least one idea that changes the shape of the product.
- **Ignoring the backlog**: 3+ todos on the same topic IS an idea. The backlog is telling you something. Don't duplicate it — promote it.

## Kill list failures
- **Kill list avoidance**: "I can't find anything to kill" means you're not looking hard enough. Run `scripts/kill-audit.sh` for candidates.
- **Killing the easy thing**: Killing a stale todo is free. Killing a feature you spent 3 sessions on is hard. The hard kills are the ones that matter.
- **Re-proposing killed ideas**: Check rhino.yml for `status: killed` features before proposing. If an idea was killed, you need NEW evidence to revive it.

## Technique failures
- **One technique only**: If you always use evidence-weighted generation, you'll always get the same type of ideas. Rotate techniques from `techniques/` folder.
- **Technique as theater**: Running through SCAMPER mechanically produces mechanical ideas. The technique is a starting point, not a formula.
- **Divergent without convergent**: 30 raw ideas are useless without the killer pass. Always pair divergent generation with `techniques/killer.md`.

## Materialization failures
- **Idea without assertion**: If you can't write 2 mechanical assertions for an idea, it's not testable. Not testable = not buildable.
- **Committing without killing**: Every commit should pair with a kill. Attention is finite. You can't add without removing.
- **Skipping the prediction**: Every committed idea needs a logged prediction. "I predict this will raise [feature] from X to Y because Z." No prediction = no learning.
