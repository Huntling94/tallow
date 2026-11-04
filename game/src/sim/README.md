# Simulation

The authoritative game rules: herds, routes, defences, harvest, economy, town and the run. Pure, typed, seeded and deterministic, as set by [ADR-0002](../../../docs/adr/0002-sim-render-separation.md).

`game/tests/unit/test_sim_boundary.gd` fails the build if code here uses scene, node or resource types, scene access, engine servers, the wall clock or frame counters, unseeded randomness, files or input.

Random generators are created only by the random-streams code, each seeded from the run seed (ADR-0002, rule 3). Simulation code never makes its own streams: the caller (the headless run, later the game) creates them from the run seed and passes them in.
