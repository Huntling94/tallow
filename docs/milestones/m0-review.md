# M0 review: Foundations

*4 November 2026 · Milestone M0 · issues #1 to #30*

**Question:** does one real PR pass the whole loop end to end?

**Answer:** yes. Every change after the first commit reached `main` by pull request, with an independent review recorded and checked by CI, green checks and the maintainer's explicit approval. M0 took two days against a timebox of one to two weeks. The cost was process weight, not scope: about half the pull requests were about the process itself, and one feature PR needed four review rounds over a rule with no exception route.

## Exit criteria

| Criterion | Met | Evidence |
|---|---|---|
| `main` is protected, and every change after the first commit arrived by PR with green checks and the maintainer's explicit approval | Yes | 11 merged PRs, #2 to #28. Every CI check is required from step 10. |
| Every PR except Dependabot's carries a completed Independent review section, enforced by CI | Yes | `review-check` workflow, required since #2 |
| The web build is live on GitHub Pages | Yes | [huntling94.github.io/tallow](https://huntling94.github.io/tallow/), deployed from `main` by #25 |
| The headless runner writes telemetry that Python reads, with a test at each layer | Yes | #28: gdUnit4 tests for the simulation, writer and runner; pytest for the loader and `check_run`; the CI `smoke` job runs the whole path |
| ADRs 0001 to 0004, the roadmap, the risk register and the process docs are merged | Yes | #7, #10, #12 |
| Devlog entry 1 and the M0 review are written | Yes | #14 and this page |

## What shipped

- **Governance and process:** templates, CODEOWNERS, contributing, conduct, security, labels, milestones (#2); Claude Code agents, skills and process docs (#7, #15); the review check (#2, #12, #16).
- **Direction:** vision, design skeleton, roadmap, risk register, ADRs 0001 to 0004 and the architecture overview (#10, #12).
- **Game:** a Godot 4.7.2 project with typed GDScript, gdformat, gdlint, gdUnit4 and the simulation boundary test (#19). A grey-box valley with the dusk cold open, playable in the browser (#25). A stub simulation with seeded per-system random streams, a telemetry writer and a headless runner (#28).
- **Analysis:** a uv project with ruff, pytest, a telemetry loader, a `check_run` command and the first notebook (#22, #28).
- **CI:** public-language guard, review check, tool tests, Godot lint and tests, analysis lint and tests, the runner-to-Python smoke run, and the web build and Pages deploy.

## What slipped or changed

- **Steps 8 and 9 swapped.** The web build came first so there was something to look at and direct. The two had no dependency, so nothing broke.
- **An unreviewed merge.** #10 carried eight files its review never saw (devlog entry 1, #14). The catch-up review (#12) tightened the check so a commit after the review that touches an unreviewed file fails it.
- **Four review rounds on #25.** The grey-box valley skipped the spec as a "small change", but it touched 14 files and the workflow had no other route. Three rounds returned "Changes needed" until the maintainer recorded the exception on the PR in their own words. Each round also found real minor issues, which were fixed.
- **Follow-ups carried into M1:** #26 (valley), #29 (data path, two items to fix before M1 builds on it), #17 and #20 (CI hardening), and Dependabot PR #5.

## Risks

- **R2, process outruns the game, happened.** On day one, foundations and review rounds took the time with nothing built. Since then, docs and chores get one review round, with nits going to an issue rather than another round. Likelihood raised to High.
- **R8, the web build disappoints:** tested. The dusk shot reads well in the Compatibility renderer. Judge the visual target on desktop as planned.
- **R10, AI-written code hides mistakes:** the reviewer agent caught real defects in every feature PR. Examples: a herd that never reset on replay (#25), and a check command that printed a traceback instead of the loader's error (#28, deferred to #29). It also caught the unreviewed merge in #10.
- **R12, public text drifts off topic:** the guard ran on every commit and PR with no escapes.

## One process change

**A written route for the maintainer to waive the spec gate.** The workflow had two ways to skip gates 1 and 2: prototypes, and small changes. Work like the grey-box valley fitted neither, so the reviewer correctly blocked it until an exception was recorded in a way it could verify. `docs/process/workflow.md` now says how to waive the gates: the maintainer writes the waiver on the PR in their own words, and the issue's "Done when" list stands in for the acceptance criteria. It is a route for the maintainer, not a default: production code still takes the full loop.

## Next

M1, simulation core: a headless season simulation with herd, routes, three defences, harvest and one price, played by bots over 10,000 seasons. Start with the two #29 items that M1 builds on: the simulation is given its random streams rather than creating them, and the loader reports clean errors.
