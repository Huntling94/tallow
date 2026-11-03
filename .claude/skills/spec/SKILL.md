---
name: spec
description: Draft a feature spec with testable acceptance criteria from a GitHub issue (gate 1). Use when the maintainer asks for a spec for an issue.
argument-hint: <issue number>
disable-model-invocation: true
---

Draft a spec for issue #$ARGUMENTS.

1. Read the issue with `gh issue view $ARGUMENTS --comments`. Read the relevant parts of `docs/vision/`, `docs/design/gdd.md` and any ADRs it touches.
2. Create `docs/specs/<NNNN>-<short-name>.md` from `docs/specs/TEMPLATE.md`, where NNNN is the issue number padded to four digits.
3. Fill it in:
   - The problem and why it matters, and which pillar it serves.
   - Scope and, just as important, what is out of scope.
   - Acceptance criteria numbered AC1, AC2 and so on. Each must be testable: a test or a playtest step could show it is met or not. Prefer "Given ..., when ..., then ...".
   - How each criterion will be verified (unit test, invariant, golden seed, playtest).
   - Telemetry events added or changed.
   - Open questions for the maintainer.
4. Set the status to Draft. Do not write any code.
5. Show the maintainer the acceptance criteria and open questions, and ask for approval. On approval, set the status to Approved with the date, and change the issue's label from `status: needs-spec` to `status: ready`.
