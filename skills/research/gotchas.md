# Research Gotchas — Research Failure Modes

LLMs doing research hit these traps. Read before every `/research` run.

## Research as procrastination
Researching is easier than building. If previous research produced actionable findings that haven't been built, flag it. Check research-memory.json for unacted-on findings before starting new research.

## Confirmation bias
Searching for evidence that supports your existing belief. Research should seek to DISPROVE, not confirm. Frame search queries as "why X might be wrong" not "evidence that X works."

## Source quality blindness
WebSearch returns SEO content farms. Not all sources are equal. Academic > practitioner > blog > SEO. Weight findings by source quality, not by how well they support your thesis.

## Topic repetition
Same topic researched 3+ times means either it's unresolvable or the research method is wrong. Check `scripts/research-log.sh` for repeat topics. If a topic keeps recurring, change the research approach or accept the uncertainty.

## Context7 gaps
For obscure libraries, real-time docs may be incomplete. Fall back to WebSearch + official docs. Context7 is best for popular frameworks — don't assume it covers everything.

## Findings without action
Research that produces "interesting" findings but no build recommendation is waste. Every research session must end with: "Build X" or "Don't build X because Y" or "Need more data on Z before deciding."

## Unknown territory neglect
Known patterns are comfortable to re-validate. Unknown territory is where the learning value is highest. If all research targets known areas, you're not learning — you're confirming.

## Market research hallucination
Market size numbers from WebSearch are unreliable. Use specific competitor evidence instead. "Series B competitor with 50 employees" tells you more than "$4.2B TAM."
