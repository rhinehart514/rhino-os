# LLM Copy Failure Modes

Common ways AI-generated copy goes wrong. Check every piece of copy against these.

## The Adjective Problem

LLMs reach for adjectives when they don't have specifics. "Powerful, intuitive, seamless experience" means the LLM doesn't know what the product actually does.

**Fix:** Replace every adjective with a specific. "Powerful" → what power? "Intuitive" → what's the learning curve? "Seamless" → what friction was removed?

## Generic Value Props

"Save time and increase productivity" could describe any tool ever made. If the value prop works for a competing product, it's not differentiated.

**Fix:** The "swap test" — replace your product name with a competitor. If the copy still works, it's generic. Rewrite.

## Feature-Listing as Copy

"Our product features include: real-time collaboration, AI-powered insights, customizable dashboards..." This is a spec sheet, not copy.

**Fix:** Each feature becomes a benefit sentence. "Real-time collaboration" → "Your whole team sees changes as they happen — no more 'did you see my update?' messages."

## Aspirational Claims

Describing what the product will be, not what it is. "The future of product development" is an aspiration, not a description.

**Fix:** Only claim what the eval score supports. Feature scores <50 = don't claim it. Feature scores 50-70 = claim with caveats. Feature scores 70+ = claim confidently.

## Missing Person

Copy that talks about the product but never names who uses it. "A tool for building better products" — who? A solo founder? A PM at a Fortune 500?

**Fix:** Every piece of copy starts from the person in `rhino.yml value.user`. If that field is empty, fix it before writing copy.

## Hollow Differentiation

"Unlike other tools, we..." followed by something every tool does. "Unlike other tools, we focus on quality" — they all say that.

**Fix:** Name the specific competitor. Name the specific difference. "Unlike Cursor, which measures code quality, rhino measures whether users care."

## Social Proof Fabrication

Inventing testimonials, inflating metrics, using stock photos as "customers."

**Fix:** If you don't have proof, don't fake it. "No social proof yet" is acceptable at stage one. Fake proof is never acceptable.

## Tone Mismatch

Copy that doesn't match the product's design system or the founder's voice. A serious product with jokey copy, or a casual product with corporate language.

**Fix:** Read `.claude/design-system.md` if it exists. Match the documented tone. If no design system, match the tone of the existing README and docs.
