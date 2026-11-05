# ADR-0005: Simulate the night as individual beasts choosing at forks

- **Status:** Proposed
- **Date:** 2026-11-06
- **Related:** issue #60, [prototype report](../prototypes/0058-winnable-run.md), #46, #54, #56, PR #55, [ADR-0002](0002-sim-render-separation.md), [ADR-0003](0003-telemetry-format.md)

## Context

M1's simulation treats the night as bands of beasts. Each band picks a whole route at the start of the night by multinomial logit, then walks it. Defences kill when a band enters their segment, by chance, up to a capacity. A breach costs money.

Prototype #58 tested a season as a 3D tower defence, and the maintainer chose to keep it. Its beasts are individual units with their own health, spaced along the road. Towers fire shots that take time to land. Each beast chooses at every fork, weighing the way from there to the town. Herds use up to three entrances, and beast types answer to different defences. A breach costs town, and the run ends when the town falls.

The forces:

- The simulation is the only source of truth, and ADR-0002 requires it to stay pure, typed, seeded and deterministic. The prototype's rules are throwaway JavaScript and cannot be promoted.
- A presentation cannot fake this. Bands cannot show a beast being shot, because no such event exists in the simulation.
- M1's bots and route-model fit are the next steps, and would measure the old game.
- Prototype bots show steering's lead over plain spreading is fragile: 93% against 84% wins on the final numbers, level on slightly different ones. That is a crude measurement in another language, so it is a question for step 6 to answer, not a result.
- Bots must play 10,000 seasons, so the cost of a season matters.

## Options

### Option 1: Keep bands and whole-route choice

- **For:** already built and tested. No rework. Bots and the fit can start now.
- **Against:** it is not the game the maintainer kept. Every later measurement would be of something else, and M2 would need a second simulation or a fake one.

### Option 2: Individual beasts, each choosing a whole route at the start

- **For:** one choice per beast keeps the model and the Python fit close to what exists. Odds are simple to compute.
- **Against:** a beast cannot react to anything built after it sets out, which removes building during a herd as a way to steer. Forks stop mattering as places: a route is only a list.

### Option 3: Individual beasts, each choosing at every fork

- **For:** matches what was played. Forks become places worth defending, and each entrance offers a different set of choices. Each fork is one multinomial logit choice, so the model stays the same kind and each beast gives several observations for the fit.
- **Against:** the most work. The route graph, night, viewer and telemetry all change. Choices along one beast's walk are not independent draws of a single route, so the fit's recovery test has to be rewritten. A fixed-tick season costs far more than today's event list.

## Decision

Option 3. Beasts are individual units walking a road network in fixed ticks, and each chooses at every fork by multinomial logit on the way ahead, because this is the game that was played and kept.

Four rules follow, all open to change by spec:

- A road network of nodes and roads replaces named routes.
- A herd has one or more entrances, known before the player builds.
- Towers and shots are simulated on the same tick. The view only draws them, between ticks.
- A breach costs town, and the run ends when the town falls.

## Consequences

- **Easier:**
  - The view can show every shot, hit and death from simulation state, so M2's 3D rebuild has real events to draw.
  - Beast types and new defences become data on units, not new rules.
  - #56 gains a way to lose that does not depend on debt.
- **Harder:**
  - Tick size becomes part of the rules. In the prototype, changing the step from 1/30 s to 1/60 s moved one bot's win rate by about 5 points, so the tick is fixed in rules data and covered by golden-seed tests.
  - A season costs more to run. Whether 10,000 seasons stay practical in GDScript must be measured early in the work. If not, use a coarser tick or simpler shots.
  - Telemetry grows, because every fork choice and kill is an event. ADR-0003's format holds, and the data dictionary needs updating.
  - Existing specs, tests and golden seeds for routes and the night are replaced.
- **What we now have to do:**
  - Update the roadmap's M1 sequence and exit criteria.
  - Close PR #55 and rewrite #54 as the road network.
  - Write a spec for each simulation step, with tests first.
  - Have step 6's bots measure steering against spreading and against chokepoints (#46).
  - Rewrite the Python fit for choices made at forks.

Revisit this if step 6 shows steering does not pay on the real simulation. That would question the design's core idea, and it should be decided before the M2 rebuild. Also revisit it if a season proves too slow for bots even at a coarser tick.
