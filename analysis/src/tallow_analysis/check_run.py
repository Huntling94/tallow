"""Check one telemetry file and print a short summary of the run.

Usage: python -m tallow_analysis.check_run <file>
Exit code: 0 for a valid file, 1 for an invalid one.
"""

from __future__ import annotations

import sys
from pathlib import Path

from tallow_analysis.telemetry import TelemetryError, load_run


def summarise(path: str | Path) -> str:
    """One line per fact about the run in `path`. Raises `TelemetryError` if invalid."""
    run = load_run(path)
    state = "complete" if run.complete else "incomplete"
    if run.truncated:
        state += " (last line cut off)"
    seasons = run.summary["seasons"] if run.summary else "unknown"
    return "\n".join(
        [
            f"run_id:   {run.run_id}",
            f"seed:     {run.header['seed']}",
            f"rules:    {run.header['rules_version']}",
            f"seasons:  {seasons}",
            f"events:   {len(run.events)}",
            f"status:   {state}",
        ]
    )


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print("usage: python -m tallow_analysis.check_run <file>", file=sys.stderr)
        return 2
    try:
        print(summarise(argv[0]))
    except (TelemetryError, OSError) as error:
        print(f"invalid: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
