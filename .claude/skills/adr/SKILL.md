---
name: adr
description: Draft the next architecture decision record (ADR) in docs/adr/. Use when a plan makes a significant or hard-to-reverse technical choice.
argument-hint: <decision title>
disable-model-invocation: true
---

Draft an ADR titled "$ARGUMENTS".

1. Find the next number: the highest `docs/adr/NNNN-*.md` plus one.
2. Create `docs/adr/<NNNN>-<short-name>.md` from `docs/adr/0000-template.md`.
3. Fill it in:
   - **Context:** the forces at play, constraints and what prompted the decision.
   - **Options:** at least two real options, each with honest pros and cons. Include "do nothing" if it is viable.
   - **Decision:** the chosen option and the main reason, in one or two sentences.
   - **Consequences:** what becomes easier, what becomes harder, and what we now have to do.
   - Links to the issue, spec or PR that prompted it.
4. Set the status to Proposed. The maintainer accepts it; on acceptance set the status to Accepted with the date.
5. Add the ADR to the index in `docs/adr/README.md`.
6. If it replaces an earlier ADR, set the earlier one's status to "Superseded by ADR-NNNN". Change nothing else in an accepted ADR.
