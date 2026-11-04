# Spec 0027: Headless runner, telemetry writer and the first data path

- **Issue:** #27
- **Status:** Approved (2026-11-04)
- **Pillar:** Foundations
- **Milestone:** M0

## Problem and why it matters

The game's balance and its statistical models depend on one path: the simulation runs seeded seasons with no window, writes what happened, and Python reads it (ADR-0002, ADR-0003). Nothing on that path exists yet. Building it now, with a stub simulation, proves the format, the determinism rules and the CI wiring before M1 puts real herd rules on top. It also meets the M0 exit criterion "the headless runner writes telemetry that Python reads, with a test at each layer".

## Scope

- **A stub simulation** in `game/src/sim/`: a season clock that, for each season, draws a placeholder herd size from a seeded random stream and emits `herd_arrived` and `season_ended` events. It follows ADR-0002: plain classes, fixed ticks, no wall clock, no global randomness.
- **Random streams** in `game/src/sim/`: one generator per system, seeded from the run seed and a fixed hash of the system's name written in the simulation code (ADR-0002, rule 3).
- **A telemetry writer** in `game/src/telemetry/`: turns the run's settings and events into one JSON Lines file in the ADR-0003 shape (run header, events, run summary), with sorted keys so the bytes are stable.
- **The rules version**: a hash of the simulation code and the game data files, computed automatically. The run id is derived from the rules version, the seed and the settings.
- **A headless runner** in `game/tools/`: `godot --headless --path game -s res://tools/headless_runner.gd -- --seed 42 --seasons 3 --out <file>`.
- **Python**: the loader follow-ups from #23 (see Design notes), a small command that checks a run file and prints a summary, and a notebook in `analysis/notebooks/` that loads a run and charts herd size by season.
- **CI smoke run**: a job that runs the runner for one seed and checks the file with the Python command.

## Out of scope

- Real herd behaviour, routes, defences or bots (M1).
- Parquet conversion (when there are enough runs to need it).
- The telemetry data dictionary (`docs/architecture/telemetry.md`, M1).
- Golden files committed to the repo; determinism is tested by running the same seed twice.
- Running the simulation in the web build.

## Acceptance criteria

- **AC1:** Given seed 42 and 3 seasons, when the runner is run headless, then it exits 0 and writes a file whose first line is a `run_start` header, then one `herd_arrived` and one `season_ended` event per season, then a `run_end` summary with `seasons` equal to 3.
- **AC2:** Given the same seed and settings, when the runner is run twice, then the two files are byte-identical. Given a different seed, then the herd sizes differ.
- **AC3:** Given any record the runner writes, then it has `schema_version` 1 and the header's `run_id`, and every event has `season`, `tick` and `seq`, with (`season`, `tick`, `seq`) strictly increasing through the file.
- **AC4:** Given a change to any file in `game/src/sim/` or `game/data/`, then the rules version changes, and so does the run id for the same seed.
- **AC5:** Given the simulation code, then the boundary test still passes: no scene, wall-clock, file or unseeded-randomness references in `game/src/sim/`.
- **AC6:** Given a runner file, when `uv run python -m tallow_analysis.check_run <file>` runs, then it exits 0 and prints the run id, seed, season count and event count. Given an invalid file, it exits non-zero with the loader's error.
- **AC7:** Given a file whose last line is cut off partway (a run that stopped mid-write), then the loader returns an incomplete run with the complete records before it, rather than an error. A malformed line anywhere else is still an error.
- **AC8:** Given a pull request, then CI runs the runner for seed 42 and checks the file with `check_run`, and fails if either step fails.
- **AC9:** Given the notebook, when it is run against a runner file, then it shows the run's header and a chart of herd size by season.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1 | gdUnit4 test running the runner's entry point to a temporary file; CI smoke run |
| AC2 | gdUnit4 test: two runs, same seed, byte comparison; different seed, different sizes |
| AC3 | gdUnit4 test over the written file; pytest on the loader's ordering check |
| AC4 | gdUnit4 test: rules version over two folders that differ by one file |
| AC5 | Existing boundary test |
| AC6 | pytest for `check_run` on the fixture and on a broken file |
| AC7 | pytest |
| AC8 | The CI job itself, on this PR |
| AC9 | Run by hand once; outputs are stripped on commit |

## Telemetry

Schema version 1.

| Record | Fields |
|---|---|
| `run_start` | `schema_version`, `rules_version`, `run_id`, `seed`, `settings` (`valley`, `herd_personality`, `modifier`, `bot_strategy`, `seasons`) |
| `herd_arrived` | common event fields, `herd_size` (whole number, placeholder) |
| `season_ended` | common event fields |
| `run_end` | `schema_version`, `run_id`, `outcome` (`"completed"`), `score` (0 for now), `seasons` |

Common event fields: `schema_version`, `run_id`, `season`, `tick`, `seq`, `type`.

## Design notes

- **Stub rules:** 3 seasons by default; each season is one tick for now. Herd size is a whole number from 8 to 24 drawn from the `herd` stream. These numbers exist only to give the chart something to show.
- **Stream seeding:** FNV-1a 64-bit hash of the system name, combined with the run seed. Written in GDScript in `sim/`, not `String.hash()`.
- **Rules version:** the first 16 hex characters of SHA-256 over each file's path and contents under `game/src/sim/` and `game/data/`, in sorted path order, with line endings normalised to LF so Windows and Linux agree. Computed outside `sim/`.
- **Run id:** the first 16 hex characters of SHA-256 over the rules version, seed and settings as sorted JSON.
- **Writer:** keys sorted, no spaces, `\n` line endings, no wall-clock values anywhere in the file.
- **Loader changes from #23:** a cut-off last line is an incomplete run (AC7); tests for a header or summary missing a field and a summary from another run; `Run.events` becomes a tuple; the docstring says blank lines are rejected; the loader checks event order (AC3). The architecture overview's first module name is corrected to `telemetry`.
- **Notebook dependencies** (`matplotlib`, `ipykernel`) go in a separate `notebook` dependency group, so CI and tests do not install them.

## Open questions

- None blocking. The placeholder herd size range (8 to 24) is arbitrary and is replaced in M1.
