# Workflow

How a change gets from an idea to `main`. Every change after the first commit follows this loop.

## Roles

- **Maintainer:** game director and product owner. Sets priorities, approves every spec, plan and merge, and plays every build.
- **Claude (Claude Code and its agents):** architect, implementer, test writer and first reviewer. Drafts, and merges a PR only after the maintainer explicitly approves it; never decides alone what reaches `main`.

## The loop

| Step | What happens | Who | Output |
|---|---|---|---|
| 1. Issue | An issue is raised from a template, or Claude drafts one from the roadmap. The maintainer triages it into a milestone with a priority. | Maintainer | Issue with labels and milestone |
| 2. Spec (gate 1: what and why) | Claude drafts the spec with `/spec`. The maintainer approves or changes it. | Claude drafts, maintainer approves | `docs/specs/NNNN-*.md`, status Approved |
| 3. Plan (gate 2: how) | Claude proposes an implementation and test plan in plan mode, plus an ADR (`/adr`) for architectural choices. The maintainer approves. | Claude drafts, maintainer approves | Approved plan; ADR if needed |
| 4. Build | One branch per issue. Tests first for simulation code. Small commits with conventional messages. Hooks check every edit. | Claude | Commits on the branch |
| 5. Independent review | `/independent-review` runs the reviewer agent with fresh context against the diff and the spec. Findings are fixed or deferred, and recorded. | Claude (reviewer agent) | Completed "Independent review" section |
| 6. Pull request | The PR template is filled in, including how AI was used. CI runs. | Claude | PR with green checks |
| 7. Maintainer review (gate 3: is it right and is it good) | The maintainer reads the diff summary and the review, plays the build, and requests changes or approves the merge. | Maintainer | Approval, or change requests |
| 8. Merge and ship | On the maintainer's explicit approval, Claude squash merges to `main`. The web build deploys and the changelog updates (once those pipelines exist). | Claude, on approval | Updated `main` |
| 9. Record | A devlog entry (`/devlog`) when something notable happened, especially an AI mistake and the check that caught it. | Claude drafts, maintainer approves | `docs/devlog/` entry |

Steps 2 and 3 can be combined for small changes (chores, docs, single-file fixes): the issue says what done looks like, the PR description states what and why, and the maintainer's review covers both gates.

**Maintainer waiver.** For a change that is neither small nor a prototype but does not need a spec (for example grey-box presentation with no simulation rules), the maintainer may waive gates 1 and 2. The maintainer writes the waiver on the PR in their own words; a waiver quoted or posted by Claude does not count. The issue's "Done when" list then stands as the acceptance criteria, and the PR links the waiver. Simulation code never takes this route.

## Two tracks

- **Production:** everything that ships. Always the full loop.
- **Prototypes:** timeboxed (1 to 3 days) experiments that answer one question. They skip gates 1 and 2 and strict CI, live in `prototypes/`, and end with a report in `docs/prototypes/`: keep, kill or change. Prototype code is never promoted to production directly; it is rebuilt through the full loop.

## Branches and commits

- Branch from `main`: `<type>/<issue>-<short-name>`, for example `feat/42-route-choice`.
- Conventional Commits for every commit and PR title.
- `main` is protected: PRs only, required checks green, squash merge, linear history.

## Issue status

`status: needs-spec` → `status: ready` (spec approved) → in progress (a linked branch or PR) → closed by the merged PR. `status: blocked` at any point, with a comment saying what it is waiting on.

## Sessions

Every Claude Code session starts from an issue and ends with its state recorded in the PR or issue: what is done, what is next, anything blocked. Any session can then be picked up cold.

## Cadence

- **Milestone start:** scope, risks and issues for the milestone.
- **Milestone end:** a review in `docs/milestones/`: what shipped, what slipped, and one process change.
- **Playtests** from first playable onwards.
