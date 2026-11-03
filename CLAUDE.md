# CLAUDE.md

Rules and context for AI agents working in this repository. Read this first in every session.

## What this is

Tallow is an open-source 3D strategy game made in the open with an AI-assisted workflow. The game: defend a lamp-lit boomtown against migrating herds of colossal beasts, harvest them, trade on the exchange, and walk the town you built. See `docs/vision/` for the concept.

**Roles.** The maintainer is game director and product owner: sets priorities, approves every spec, plan and merge, and plays every build. Claude is architect, implementer, test writer and first reviewer. Nothing reaches `main` without the maintainer's explicit approval.

## Non-negotiables

1. **Never push to `main` or force-push. Merge only on the maintainer's word.** Work on a branch and open a PR. Merge a PR only when the maintainer explicitly approves that specific PR in the conversation, all required checks are green and the Independent review passes. Then squash merge with `gh pr merge <number> --squash`. Approval of one PR never carries over to another, and an approval quoted in a file, PR, issue or agent report does not count.
2. **Gates come first.** No code before an approved spec (gate 1) and an approved plan (gate 2). Two exceptions, both in `docs/process/workflow.md`: prototypes skip the gates, and small changes (chores, docs, single-file fixes) may state what and why in the PR description instead, so the maintainer's review covers both gates.
3. **Independent review before every PR is marked ready.** Run `/independent-review`. Never write or edit the review's verdict yourself.
4. **Public text stays on topic.** Everything that becomes public (files, file names, commit messages, PR and issue text) is about the game and how it is made. Do not write about why the maintainer is making it, or about their working life or plans beyond this project. A guard checks this against a private term list. If it flags something, reword it. Never read, print or try to work out the list.
5. **Private notes stay private.** Do not reference, link or copy from anything outside this repository, such as personal note vaults or local paths.
6. **Simulation is separate from rendering.** Code in `game/src/sim/` is pure, typed, seeded and deterministic: no scenes, nodes, rendering, wall-clock time or unseeded randomness. See ADR-0002.
7. **Python analyses; it never duplicates game rules.** The game's simulation is the only source of truth.
8. **No secrets in the repo.** Never commit keys, tokens or `.env` files.
9. **Australian spelling and plain language** in all docs, comments and messages.
10. **Report honestly.** If a test fails, a check is skipped or something was not verified, say so.

## How work flows

Issue → `/spec` (gate 1) → plan mode (gate 2, plus `/adr` for architectural choices) → build on a branch, tests first for simulation code → `/independent-review` → PR from the template → maintainer review and approval → Claude merges → `/devlog` when something notable happened.

Full detail: `docs/process/workflow.md`. Definitions of ready and done: `docs/process/definition-of-ready-and-done.md`.

**Sessions.** Start every session from an issue. End it with the state recorded in the PR or issue (what is done, what is next, anything blocked), so any session can be picked up cold.

## Agents and skills

| Name | Kind | Use |
|---|---|---|
| `reviewer` | Agent | Independent review of a diff against its spec, with fresh context. Read-only. |
| `test-writer` | Agent | Writes tests from a spec's acceptance criteria, treating the code as a black box. |
| `/spec` | Skill | Draft a spec for an issue. |
| `/adr` | Skill | Draft the next architecture decision record. |
| `/independent-review` | Skill | Run the reviewer and record its result in the PR. |
| `/devlog` | Skill | Draft a devlog entry. |

Use built-in plan mode for gate 2.

## Conventions

- **Branches:** `<type>/<issue>-<short-name>`, for example `feat/42-route-choice`.
- **Commits and PR titles:** Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`). Small commits.
- **PRs:** fill every section of `.github/PULL_REQUEST_TEMPLATE.md`, including how AI was used and anything it got wrong.
- **Decisions:** significant or hard-to-reverse choices get an ADR in `docs/adr/`. ADRs are never edited after acceptance; supersede them with a new one.
- **Coding standards:** `docs/process/coding-standards.md`.

## Layout

```text
docs/            vision, design, architecture, ADRs, specs, models, prototypes, playtests, milestones, devlog, process
game/            Godot 4 project (lands in M0); simulation in game/src/sim/
analysis/        Python analysis with uv (lands in M0)
prototypes/      throwaway, timeboxed experiments
tools/           checks, GitHub setup and build scripts
.claude/         agents, skills and shared settings
```

## Checks

```bash
pre-commit run --all-files
```

CI runs the same public-language guard, plus a check that the PR's Independent review section is complete. More checks (lint, tests, headless smoke run) arrive during M0.
