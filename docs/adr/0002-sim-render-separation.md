# ADR-0002: Keep one deterministic simulation, separate from rendering

- **Status:** Accepted (2026-11-03)
- **Date:** 2026-11-03
- **Related:** [ADR-0001](0001-engine-godot.md), [ADR-0003](0003-telemetry-format.md), [architecture overview](../architecture/overview.md)

## Context

The game's rules (herds, routes, defences, harvest, economy, town, rare events) need to be:

- **Testable without a screen:** unit tests, invariants, golden seeds and design contracts in CI.
- **Run at scale:** bots play thousands of seasons per PR to check balance.
- **Reproducible:** any run can be replayed from its seed, for bug reports, golden tests and shared seeds.
- **The source of truth for analysis:** Python fits models on telemetry from the simulation and checks they recover the true parameters. That only works if there is one set of rules and it is known exactly.

Godot makes it easy to mix rules into scenes and nodes, where they depend on frame timing and rendering, and cannot run without them.

## Options

### Option 1: Rules inside scenes and nodes

- **For:** the quickest way to get something on screen. Godot's tutorials work this way.
- **Against:** rules depend on frame rate and node order, so runs are not reproducible. Cannot run thousands of seasons headless. Hard to test.

### Option 2: A separate simulation in another language (for example Python), with Godot only for presentation

- **For:** Python is quick to test and analyse.
- **Against:** two copies of the rules that will drift apart, or a bridge between processes. The web build cannot run Python.

### Option 3: One pure simulation inside the Godot project, separate from rendering

- **For:** one copy of the rules, run by both the game and the headless runner. Testable with gdUnit4. Runs in the web build.
- **Against:** needs discipline: the boundary is enforced by convention, review and tests rather than by the language. Some duplication between simulation state and its 3D presentation.

## Decision

**Option 3.** The simulation is plain, typed GDScript in `game/src/sim/`, with no dependency on scenes or rendering. The game and the headless runner both drive the same simulation. Python reads its telemetry and never re-implements its rules.

## Rules

1. **No engine scene types in `game/src/sim/`.** Classes extend `RefCounted` (or nothing). No `Node`, scenes, resource loading, signals to the scene tree, input or rendering.
2. **Fixed ticks.** The simulation advances in fixed steps of its own time. It never reads frame time or the wall clock.
3. **Seeded randomness only.** One run seed. Each system gets its own random stream derived from the run seed and a fixed hash of the system's name, so adding a system does not change the others' random numbers. The hash is written in the simulation code, not taken from the engine (Godot's `String.hash()` is not guaranteed to stay the same between versions). The engine's seeded generator could also change between Godot versions, so every engine upgrade is checked against the golden-seed tests before it merges. No global `randi()` or `randf()`.
4. **Commands in, state and events out.** Presentation and bots send commands (build a pit, assign crews, sell oil). The simulation applies them at a tick boundary and exposes read-only state and a stream of events. Presentation never changes simulation state directly.
5. **Deterministic order.** No iteration over unordered collections where order affects results; sort by a stable id.
6. **Telemetry through one interface.** The simulation emits events; a writer outside `sim/` turns them into files (ADR-0003).
7. **Presentation interpolates.** The 3D world reads simulation state each frame and animates between ticks. Visual smoothness never feeds back into the rules.

## Consequences

- **Easier:** fast headless tests and bot runs in CI; exact replays from a seed; golden-seed regression tests; one source of truth for the statistical models; the same simulation in desktop and web builds.
- **Harder:** every feature is designed twice, as rules and as presentation. First-person moments that affect the rules (the harpoon, the dawn hunt) must go through commands, not physics callbacks.
- **What we now have to do:**
  - A headless runner in `game/tools/` that runs seeded seasons and writes telemetry (M0, step 8).
  - Golden-seed tests in CI.
  - A lint or test check that fails if `game/src/sim/` references scene or rendering types (added with the Godot skeleton).
  - Check that results match across Windows and the Linux CI. Basic floating-point maths is consistent, but some functions (trigonometry, for example) can differ by platform; use integer or fixed-step maths where order and exact values matter.
- **Revisit if:** the simulation cannot run fast enough in GDScript for bot runs at scale. The first step would be optimising hot paths, then a GDExtension for them, before any change to this separation.
