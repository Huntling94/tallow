# Roadmap

Simulation first, then the 3D defence, then everything that makes it a town. Each milestone answers one question. M2 to M6 together build the vertical slice described in the [concept](../vision/concept.md); the milestones go beyond it in places (five seasons in M2, a full 12-season run in M4).

| Milestone | What gets built | The question it answers |
|---|---|---|
| **M0 Foundations** | Public repo, governance, process docs, ADRs, CI, Godot and Python skeletons, a walking skeleton | Does one real PR pass the whole loop end to end? |
| **M1 Simulation core** | Headless season sim: individual beasts on a road network, defences, harvest, one price. Bots play 10,000 seasons. The first route model is fitted on telemetry and recovers the true parameters. | Does committing under uncertainty create interesting choices? Is there a dominant strategy? |
| **M2 3D defence** | The simulation's tower defence in Godot: one valley, the command view, a build menu, five seasons, grey boxes. Prototype #58 showed the shape and is rebuilt, not promoted. | Does the real game keep what made the prototype worth keeping? |
| **M3 Economy** | The exchange with supply-driven price, clean vs damaged kills, storage costs | Does selling create decisions or admin? |
| **M4 Town, breach and the run** | Wall, garrison, district damage, the Lamphouse, a 12-season run with win, loss and score | Does the slow dread work? Are runs worth finishing? |
| **M5 Wow and the wall** | The dusk cold open, the first-person harpoon on the wall | Does it impress in five seconds? Does the wall add agency? |
| **M6 Town walk** | Your house, shops, the exchange floor, rumours | Does walking change a decision? |
| **M7 Depth** | Survey office, evolving herds, a second species, unlocks, generated valleys, modifiers | Is the tenth run as interesting as the third? |

One simulation only: the authoritative simulation runs inside Godot, headless when needed, and exports telemetry. Python analyses and fits models; it does not duplicate the rules. See [ADR-0002](../adr/0002-sim-render-separation.md).

## M0: Foundations

**Timebox:** one to two weeks, part-time.

### Pull request sequence

1. Review check: a plain CI check that the PR's Independent review section is complete (done: landed with step 2 in #2)
2. Governance: issue and PR templates, CODEOWNERS, contributing, conduct, security, labels, milestones (done: #2)
3. AI workflow and process docs: CLAUDE.md, agents, skills, workflow, standards (done: #7)
4. Vision, design skeleton, roadmap and risks (done: #10)
5. ADRs 0001 to 0004, the architecture overview and the docs index (done: merged in #10, reviewed in #12)
6. Godot project skeleton, gdformat and gdlint, gdUnit4, a first test, and a CI lint-and-test job (done: #19)
7. Python analysis skeleton (uv, ruff, pytest) and its CI job (done: #22)
8. A headless runner stub writing telemetry, a notebook reading it, and a CI smoke run (done: #28)
9. Web export and GitHub Pages deploy: a grey-box valley with the dusk camera move (done: #25, brought forward ahead of step 8 so there was something to look at early)
10. All checks required, tag `v0.1.0`, devlog entry 1, the M0 review (devlog entry 1 in #14; the [M0 review](m0-review.md) in #31; required checks and the tag follow #31, tracked in #30)

### Exit criteria

- `main` is protected, and every change after the first commit arrived by PR with green checks and the maintainer's explicit approval.
- Every PR, except Dependabot's dependency updates, carries a completed Independent review section, enforced by CI.
- The web build is live on GitHub Pages.
- The headless runner writes telemetry that Python reads, with a test at each layer.
- ADRs 0001 to 0004, the roadmap, the risk register and the process docs are merged.
- Devlog entry 1 and the M0 review are written.

## M1: Simulation core

**Planning issue:** #33, changed by the [winnable run prototype](../prototypes/0058-winnable-run.md) and [ADR-0005](../adr/0005-beasts-choose-at-forks.md). The valley is a road network. Individual beasts come through one or more entrances and choose at each fork by multinomial logit. One M1 run is a 5-season mini-run in which money and defences carry over and breaches cost town. The town is one number here, with no districts or Lamphouse yet.

### Pull request sequence

1. Data-path groundwork from the review of #28, and these exit criteria (#29)
2. Routes and herd choice
3. Defences and the night
4. The top-down 2D viewer
   - 4a. Placing defences in the viewer (#51), brought forward from M2's command view so that a person plays the choice before the bots balance it
5. Harvest and one price
6. The road network and entrances, replacing the braided valley (#54, PR #55), with choice at each fork
7. Beasts and towers in fixed ticks, with the viewer showing them
8. Bots playing 10,000 seasons, with the GDD section 16 design contracts as tests. They settle first whether steering pays (#46).
9. The Python route-model fit, with a ground-truth recovery test
10. The M1 review

### Exit criteria

- A headless 5-season mini-run plays end to end: beasts come through known entrances and choose at each fork of the road network by multinomial logit, the fence, pit and harpoon tower change both the odds and the outcome, kills are harvested and sold at one price, money and defences carry over, breaches cost town, and the run ends when the town falls.
- The same seed and the same commands give byte-identical telemetry, checked by golden-seed tests in CI.
- Bots with at least three distinct strategies play 10,000 seasons, and the results are summarised in a report.
- The GDD section 16 contracts that apply to M1 run as tests in CI: a sensible defence survives season 1 on 95% of seeds; no single tower type dominates; neither all-defence nor all-harvest spending is best. Exact thresholds go in each spec.
- Python fits the fork-choice model on bot telemetry and recovers the true parameters within a stated tolerance, tested in CI against a known ground truth.
- A top-down 2D viewer in the Godot project replays a season on the road network from simulation state, with no rules of its own.
- The telemetry data dictionary lists every M1 event and field.
- The M1 review answers the milestone question, including whether a dominant strategy was found and whether steering the herd pays.

## Later milestones

Each later milestone gets its exit criteria written at its planning session, from its question. This page is updated at every milestone start and review.
