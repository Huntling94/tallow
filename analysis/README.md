# Tallow analysis

Python that reads the game's telemetry and fits models from it. It never re-implements game rules: the simulation in `game/` is the only source of truth (ADR-0002). Telemetry is JSON Lines, one file per run (ADR-0003).

| Folder | What lives there |
|---|---|
| `src/tallow_analysis/` | The package: loading and validating telemetry, and later models and reports |
| `tests/` | `pytest` tests |
| `fixtures/` | Small sample telemetry files for tests only |
| `notebooks/` | Exploratory notebooks; outputs are stripped on commit, and anything worth keeping moves into `src/` with tests |

From this folder:

```bash
uv sync
uv run pytest
uv run ruff format
uv run ruff check
```
