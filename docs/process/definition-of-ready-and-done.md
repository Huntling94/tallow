# Definitions of ready and done

## An issue is ready to build when

- [ ] It has a type label, a priority and a milestone.
- [ ] Its spec is approved (or, for a small chore or docs change, the issue itself says what done looks like).
- [ ] Every acceptance criterion is testable: a test or a playtest step could show it is met or not.
- [ ] What is out of scope is written down.
- [ ] Open questions are answered.
- [ ] Any architectural choice has an ADR, at least in Proposed status.

## A pull request is done when

- [ ] Every acceptance criterion is met and verified as the spec says.
- [ ] Tests are added or updated. Simulation code was tested first.
- [ ] All CI checks pass.
- [ ] The Independent review section is complete with a passing verdict, and every finding has an action.
- [ ] Docs are updated: spec, ADR, design, architecture or process docs as the change needs.
- [ ] `CREDITS.md` lists any new third-party asset with its source and licence.
- [ ] The PR template is filled in, including how AI was used.
- [ ] The build has been played, if the change is playable.

## A milestone is done when

- [ ] Its exit criteria in `docs/milestones/roadmap.md` are met.
- [ ] Its question has an answer, written in the milestone review.
- [ ] The risk register is reviewed.
- [ ] A release is tagged, if the milestone ships a build.
