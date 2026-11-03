# Contributing to Tallow

Thanks for your interest. Tallow is built in the open by one maintainer working with Claude Code, and every change follows the same written process.

## What we welcome

- **Issues:** bug reports, balance observations, ideas and questions. Pick the matching issue form; blank issues are turned off so each report has what we need.
- **Feedback:** on the design docs, decisions (ADRs) and playable builds.

## What we are not taking yet

**Outside code contributions.** Pull requests from outside the project will be closed with thanks for now. That keeps the design coherent while the foundations settle. If you have a fix in mind, open an issue describing it instead. We will revisit this once the game is playable.

## How work flows

Every change after the first commit arrives by pull request:

1. **Issue.** Raised from a template and triaged into a milestone.
2. **Spec (gate 1: what and why).** Testable acceptance criteria, approved by the maintainer.
3. **Plan (gate 2: how).** An implementation and test plan, plus an ADR for architectural choices, approved by the maintainer.
4. **Build.** One branch per issue, small commits, tests first for simulation code.
5. **Independent review.** A reviewer agent with fresh context checks the diff against the spec. Its findings, and what was done about each, are recorded in the PR.
6. **Pull request.** The template is filled in, including how AI was used. CI checks must pass.
7. **Maintainer review (gate 3: is it right and is it good).** The maintainer reads the review, plays the build and decides.
8. **Merge.** Squash merge to `main`. The maintainer's merge is the approval.

A CI check fails the pull request if the Independent review section is incomplete, the verdict is "Changes needed", or the reviewed commit is not one of the pull request's own commits. If later commits follow the review, the check warns rather than fails: the review is re-run after significant changes, and the maintainer judges whether that was needed before merging.

The full process documentation is being added during milestone M0.

## Standards

- **Commits and PR titles** use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`.
- **GDScript** is typed. Simulation code in `game/src/sim/` never touches scenes or rendering.
- **Python** is for analysis only and never duplicates game rules.
- **Docs** use Australian spelling and plain language.
- **Public text stays on topic:** the game and how it is made. A pre-commit hook and a CI check enforce this.
- **Assets:** every third-party asset is listed in `CREDITS.md` with its source and licence.

## Local setup

```bash
pre-commit install
```

This installs the commit hooks. The Godot and Python setup steps will be added here as those parts of the project land.

## Conduct and security

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). To report a security problem, see [SECURITY.md](SECURITY.md); please do not open a public issue.
