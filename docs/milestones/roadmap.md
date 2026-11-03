# Roadmap

Simulation first, then the 3D defence, then everything that makes it a town. Each milestone answers one question. M2 to M5 together form the vertical slice.

| Milestone | What gets built | The question it answers |
|---|---|---|
| **M0 Foundations** | Public repo, governance, process docs, ADRs, CI, Godot and Python skeletons, a walking skeleton | Does one real PR pass the whole loop end to end? |
| **M1 Simulation core** | Headless season sim: herd, routes, three defences, harvest, one price. Bots play 10,000 seasons. The first route model is fitted on telemetry and recovers the true parameters. | Does committing under uncertainty create interesting choices? Is there a dominant strategy? |
| **M2 Bare 3D defence** | One valley, one beast, fence, pit and harpoon tower, the command view, five seasons, grey boxes | Is one night fun to watch and fiddle with? |
| **M3 Economy** | The exchange with supply-driven price, clean vs damaged kills, storage costs | Does selling create decisions or admin? |
| **M4 Town, breach and the run** | Wall, garrison, district damage, the Lamphouse, a 12-season run with win, loss and score | Does the slow dread work? Are runs worth finishing? |
| **M5 Wow and the wall** | The dusk cold open, the first-person harpoon on the wall | Does it impress in five seconds? Does the wall add agency? |
| **M6 Town walk** | Your house, shops, the exchange floor, rumours | Does walking change a decision? |
| **M7 Depth** | Survey office, evolving herds, a second species, unlocks, generated valleys, modifiers | Is the tenth run as interesting as the third? |

One simulation only: the authoritative simulation runs inside Godot, headless when needed, and exports telemetry. Python analyses and fits models; it does not duplicate the rules. See ADR-0002 (simulation separate from rendering).

## M0: Foundations

**Timebox:** one to two weeks, part-time.

### Pull request sequence

1. Review check: a plain CI check that the PR's Independent review section is complete (done: landed with step 2 in #2)
2. Governance: issue and PR templates, CODEOWNERS, contributing, conduct, security, labels, milestones (done: #2)
3. AI workflow and process docs: CLAUDE.md, agents, skills, workflow, standards (done: #7)
4. Vision, design skeleton, roadmap and risks
5. ADRs 0001 to 0004, the architecture overview and the docs index
6. Godot project skeleton, gdformat and gdlint, gdUnit4, a first test, and a CI lint-and-test job
7. Python analysis skeleton (uv, ruff, pytest) and its CI job
8. A headless runner stub writing telemetry, a notebook reading it, and a CI smoke run
9. Web export and GitHub Pages deploy: a grey-box valley with the dusk camera move
10. All checks required, tag `v0.1.0`, devlog entry 1, the M0 review

### Exit criteria

- `main` is protected, and every change after the first commit arrived by PR with green checks and the maintainer's explicit approval.
- Every PR with code or doc changes carries a completed Independent review section, enforced by CI.
- The web build is live on GitHub Pages.
- The headless runner writes telemetry that Python reads, with a test at each layer.
- ADRs 0001 to 0004, the roadmap, the risk register and the process docs are merged.
- Devlog entry 1 and the M0 review are written.

## Later milestones

Each later milestone gets its exit criteria written at its planning session, from its question. This page is updated at every milestone start and review.
