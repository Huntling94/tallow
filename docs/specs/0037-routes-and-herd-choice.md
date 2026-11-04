# Spec 0037: Routes and herd choice on the route graph

- **Issue:** #37
- **Status:** Approved (2026-11-05)
- **Pillar:** Steer the herd
- **Milestone:** M1

## Problem and why it matters

The herd is the game's central uncertainty: you build before you know which way it will come. Today the simulation draws a placeholder herd size and nothing else, so there is nothing to commit against. This change gives the valley its routes and the herd its choice, using the model the player will later learn to read and Python will later fit (GDD section 5). Every later M1 step builds on it: defences add a term to the same utility, the 2D viewer draws the same graph, and the route fit recovers the same weights.

## Scope

- **The route graph** for the grey-box valley, as data in `game/data/valleys/grey_box.json`: nodes, segments (length in metres, roughness from 0 to 1) and named routes as ordered lists of segments from the valley entry to the town gate. Three routes, with shared segments at both ends.
- **A herd personality** as data in `game/data/herds/steady.json`: the route-choice weights and placeholder herd and band sizes.
- **A data loader** outside `game/src/sim/` that reads and checks both files and passes typed values into the simulation. The simulation itself never reads files (ADR-0002).
- **Herd choice in the simulation.** Each season a herd of beasts arrives and splits into bands; each band chooses a route by multinomial logit (see Design notes), drawing from its own random stream.
- **Telemetry** for the arrival, the options with their features and odds, and each band's choice, in schema version 1 (new event types and an optional new field; no field changes meaning).
- **The telemetry data dictionary**, `docs/architecture/telemetry.md`, started with every current event (an ADR-0003 consequence assigned to M1).

## Out of scope

- Defences, threat values above zero, the night as ticks, breaches and money (step 3). The utility has a threat term from the start, always 0 here.
- Beasts' individual attributes beyond belonging to a band (size, health and hide come with harvest).
- Movement along routes and re-routing mid-night.
- Any player commands.
- The 2D viewer (step 4) and the Python fit (step 7).

## Acceptance criteria

- **AC1:** Given the grey-box valley file, when it is loaded, then there are three routes, each a connected chain of segments from the entry node to the gate node. Given a file with an unknown segment, a broken chain, or a route that does not reach the gate, then loading fails with a message naming the route.
- **AC2:** Given route utilities of −4.4, −4.1 and −4.0, then the choice probabilities are 0.2603, 0.3514 and 0.3883 (to 4 decimal places), they sum to exactly 1,000,000 parts per million, and adding the same constant to every utility leaves them unchanged.
- **AC3:** Given a segment shared by every route, when its length or roughness changes, then the probabilities do not change.
- **AC4:** Given 20,000 band choices over seeds 1 to N on the grey-box valley, then each route's observed share is within 0.015 of its model probability.
- **AC5:** Given seed 42 and 5 seasons, when the run is repeated, then the events are identical, and the first season's herd size, band sizes and chosen routes match pinned golden values.
- **AC6:** Given a run, then each season emits `herd_arrived`, then one `route_options`, then one `route_chosen` per band, then `season_ended`, with (`season`, `tick`, `seq`) strictly increasing, and the bands' beasts adding up to the herd size.
- **AC7:** Given the headless runner, when it runs for seed 42, then `check_run` accepts the file, and the boundary test still passes.
- **AC8:** Given `docs/architecture/telemetry.md`, then it lists every record type the runner writes, with each field, its type and the version it arrived in.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1 | gdUnit4 tests on the loader with the real file and small broken fixtures |
| AC2, AC3 | gdUnit4 unit tests on the choice model with hand-computed values |
| AC4 | gdUnit4 statistical test over fixed seeds (deterministic, so never flaky) |
| AC5 | gdUnit4 golden-seed test |
| AC6 | gdUnit4 test over a run's events |
| AC7 | CI smoke job and the existing boundary test |
| AC8 | Review against the runner's output |

## Telemetry

Schema version stays 1: these are new record types, and `herd_arrived` gains an optional field.

| Record | Fields (beyond the common event fields) |
|---|---|
| `herd_arrived` | `herd_size` (whole number), `bands` (whole number, new) |
| `route_options` | `routes`: list of `{route, length_m, rough_m, threat, utility, p_ppm}` in route order |
| `route_chosen` | `band` (whole number from 1), `beasts` (whole number), `route` (route id) |
| `season_ended` | none |

`run_start.settings` already names the valley and herd personality, so Python can find the true weights in `game/data/` for the recovery test in step 7. The utilities are logged as a check on the fit, not as an input to it.

## Design notes

- **Additive route features.** Each route's features are sums over its segments: length in metres, rough metres (length × roughness) and threat. The utility is `U = w_length × km + w_rough × rough_km + w_threat × threat`. Because every feature adds up over segments, a segment shared by all routes shifts every utility by the same amount and so cannot change the odds (AC3). This is the rule that makes a pit at The Neck useless for steering.
- **Multinomial logit.** `P(route) = exp(U_route) / Σ exp(U)`, computed after subtracting the largest utility so nothing overflows.
- **Determinism across platforms.** `exp` can differ in the last bit between Windows and Linux. Probabilities are rounded to whole parts per million, the last route takes the remainder so they sum to exactly 1,000,000, and the band draws a whole number from 0 to 999,999 against the running total. A platform difference could only change a choice if a probability landed exactly on a rounding boundary. The golden-seed test runs on the Linux CI and locally on Windows.
- **Random streams.** `herd` draws the herd size and band sizes; `routes` draws the choices. Separate streams mean a later change to band sizes does not reshuffle every route choice.
- **Placeholder numbers** (for the spec, not balance): herd of 18 to 30 beasts in bands of 3 to 6. Weights for `steady`: length −1.0 per km, roughness −2.0 per rough km, threat −1.5 per unit. Routes: Cairn Pass (long and easy), Split Ridge (middle) and Low Ford (short, wet and rough), tuned so no route is below 25% before defences.
- **Season timing.** Everything happens at tick 0 for now, ordered by `seq`. The night's ticks arrive in step 3.
- **The loader** lives in `game/src/loading/`, converts JSON numbers to whole numbers where the schema says so, and returns typed `RouteGraph` and `HerdPersonality` values defined in `game/src/sim/`. Valley and herd files count towards the rules version because they are in `game/data/`.
- **Data dictionary.** One table per record type, with field, type, meaning and version. It replaces the spec tables as the reference.

## Open questions

- None blocking. The maintainer chose bands over a single herd choice (2026-11-05): it gives the player a spread to hedge against, reads well in the viewer, and gives the route fit four to eight observations a season instead of one. The placeholder sizes and weights can change at any time; they are data.
