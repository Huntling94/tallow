# Coding standards

Standards are enforced by tools wherever possible. Where a tool does not exist yet, it is marked with the M0 step that adds it.

## Everywhere

- Small, focused changes. One concern per PR.
- Names say what things are. No abbreviations beyond the common ones (`id`, `rng`, `ui`).
- Comments explain why, not what.
- Australian spelling and plain language in comments, docs and messages. Code identifiers follow the language and engine (Godot's `color`, not `colour`).
- No secrets, keys or personal data in code, tests or fixtures.

## GDScript (Godot 4)

- **Typed everywhere.** Every variable, parameter and return value has a type. Required in `game/src/sim/`, expected elsewhere.
- **Style:** the official GDScript style guide. `snake_case` for files, functions and variables; `PascalCase` for classes and nodes; `CONSTANT_CASE` for constants. Tabs for indentation.
- **Formatting and linting:** `gdformat` and `gdlint` in pre-commit and CI.
- **Simulation code (`game/src/sim/`)** follows ADR-0002:
  - No `Node`, scene, resource-loading or rendering references. Plain classes (`RefCounted`) only.
  - No wall-clock time (`Time`, `OS.get_ticks_*`). Time is the simulation's own tick.
  - No global randomness (`randi()`, `randf()`, `shuffle()`, `pick_random()`). Random generators are created only by the random-streams code, each seeded from the run seed; everything else uses the generator it is given.
  - Same seed and inputs give the same outputs, on every platform.
  - Emit telemetry events through the telemetry interface; never write files directly.
- **Presentation code (`game/src/world/`, `game/src/camera/`, `game/src/player/`, `game/src/ui/`)** reads simulation state and sends commands; it never changes simulation state directly.
- Signals for events flowing up; method calls for commands flowing down.

## Python (analysis)

- Managed with `uv`. Python version pinned in `analysis/pyproject.toml`.
- Type hints on public functions.
- `ruff` for formatting and linting; `pytest` for tests.
- Reads telemetry and writes models, reports and coefficient files. Never re-implements game rules.
- Notebooks in `analysis/notebooks/` are exploratory only. Their outputs are stripped on commit, and anything worth keeping moves into `src/` with tests.

## Tests

| Layer | What it guarantees | Where |
|---|---|---|
| Unit | Each simulation rule does what its spec says | `game/tests/unit/` |
| Invariants | Properties that hold on every seed (no negative stock, herds conserve beasts) | `game/tests/invariants/` |
| Golden seeds | Outputs do not change unless a PR says why | `game/tests/golden/` |
| Design contracts | Balance targets and design rules hold over many seeded runs | CI (from M1) |
| Analysis | Models recover known parameters from simulated data | `analysis/tests/` |
| Play | Feel, visuals and scenes | Playtests, not unit tests |

- Seed every simulation test. Never depend on timing.
- Tests are named after behaviour.
- We do not chase coverage numbers. We do require a test for every acceptance criterion.

## Commits

Conventional Commits: `type(scope): summary` in the imperative, under 72 characters. Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`, `perf`, `build`, `ci`. PRs are squash-merged, so the PR title becomes the commit on `main`.

Stage files by name, never a whole folder, and check `git diff --cached --stat` before every commit, so only the intended files go in.
