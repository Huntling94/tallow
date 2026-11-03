# AI collaboration

Tallow is built with Claude Code. This page says what the AI does, what it may not do, and how its work is checked and recorded.

## Principles

1. **A human decides.** The maintainer approves every spec, every plan and every merge. AI drafts; it does not decide what ships.
2. **AI work is checked by something other than the AI that wrote it.** Tests, an independent reviewer with fresh context, CI, and the maintainer playing the build.
3. **AI use is recorded, not hidden.** Every PR says how AI was used and what it got wrong.
4. **Mistakes are written up.** When the AI gets something wrong and a check catches it, that goes in the devlog. Those entries show the process working.

## What Claude does

- Drafts issues, specs, plans and ADRs for the maintainer to approve.
- Writes code and tests on a branch, tests first for simulation code.
- Runs the independent review and records it in the PR.
- Opens PRs and fills in the template.
- Squash merges a PR once the maintainer has explicitly approved it.
- Drafts devlog entries, milestone reviews and release notes.

## What Claude may not do

- Push to `main` or force-push. (Branch protection on `main` blocks it; `.claude/settings.json` also catches the common forms of the command.)
- Merge a PR without the maintainer's explicit approval of that PR. (Every merge command also asks the maintainer to confirm, set in `.claude/settings.json`.)
- Write or alter the reviewer's verdict.
- Change branch protection, repository settings or secrets.
- Mark something as tested or verified when it was not.
- Bring in third-party code or assets without listing their source and licence.
- Reference or copy anything from outside the repository, such as private notes.

## Agents and skills

Defined in `.claude/` and committed, so anyone can see exactly how the AI is instructed.

- **`reviewer` agent:** reviews a diff against its spec with fresh context. Read-only. It is given only the branch, the base branch, the issue, the spec and the PR number, never the implementer's own summary, so its review is independent.
- **`test-writer` agent:** writes tests from acceptance criteria without reading the implementation, so tests check behaviour rather than mirror the code.
- **Skills:** `/spec`, `/adr`, `/independent-review` and `/devlog` encode the repeatable steps of the workflow.

The main Claude Code session does the planning (in plan mode) and the building. We keep agents to jobs that need a fresh, separate context; more are added only when a job needs one (for example a statistics reviewer once models land).

## The independent review

Every PR has an "Independent review" section filled in from the reviewer agent's output: who reviewed, which commit, the verdict, and each finding with what was done about it. A plain CI check (no AI) fails the PR if the section is incomplete or the verdict is "Changes needed". If the code changes significantly after review, the review is run again.

There is no AI review bot on GitHub. The review runs locally, and its record is in the PR for anyone to read.

## Recording AI use in a PR

The "How AI was used" section of each PR covers:

- Which parts were drafted by AI and which were written or changed by hand.
- Anything the AI got wrong, and what caught it.
- Any AI suggestion the maintainer rejected, and why, when it matters.

## Hooks and guards

- After every file edit, a hook runs the public-language guard on the file. It keeps public text about the game and how it is made.
- Pre-commit hooks and CI run the same guard, plus formatting, linting and tests as they land.

## Assets

Whether and where AI-generated art may be used is an open decision, to be recorded as an ADR before any such asset lands. Until then, the project uses no AI-generated art, and every asset's provenance is listed in `CREDITS.md`.
