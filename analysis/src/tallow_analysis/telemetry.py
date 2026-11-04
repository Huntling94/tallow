"""Load one run's telemetry file in the JSON Lines format from ADR-0003.

A file holds a run header (`run_start`), then one event per line, then a run
summary (`run_end`). A file without a summary is an incomplete run. Every
record carries a whole-number `schema_version`; a version this loader does not
know is an error, never a guess.

The writer ends every line with a newline. A last line with no newline that is
not valid JSON was cut off mid-write, so it is dropped and the run loads as
incomplete. Any other malformed line, including a blank one, is an error.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SUPPORTED_SCHEMA_VERSIONS: frozenset[int] = frozenset({1})

RUN_START = "run_start"
RUN_END = "run_end"

# Fields each kind of record must have. The data dictionary in
# docs/architecture/telemetry.md (M1) becomes the full reference.
HEADER_FIELDS = ("type", "schema_version", "rules_version", "run_id", "seed", "settings")
EVENT_FIELDS = ("type", "schema_version", "run_id", "season", "tick", "seq")
SUMMARY_FIELDS = ("type", "schema_version", "run_id", "outcome", "score", "seasons")

Record = dict[str, Any]


class TelemetryError(ValueError):
    """The file is not valid telemetry. The message names the file and line."""


class UnsupportedSchemaVersionError(TelemetryError):
    """A record uses a schema version this loader does not support."""


@dataclass(frozen=True)
class Run:
    """One run: its header, its events in file order, and its summary if it finished."""

    header: Record
    events: tuple[Record, ...]
    summary: Record | None
    truncated: bool = False

    @property
    def run_id(self) -> str:
        return self.header["run_id"]

    @property
    def complete(self) -> bool:
        return self.summary is not None


def load_run(path: str | Path) -> Run:
    """Read and validate one telemetry file.

    Raises `UnsupportedSchemaVersionError` for an unknown schema version and
    `TelemetryError` for anything else malformed.
    """
    path = Path(path)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    truncated = bool(lines) and not text.endswith("\n") and not _is_json(lines[-1])
    if truncated:
        lines.pop()
    records = [_parse_line(path, number, line) for number, line in enumerate(lines, start=1)]
    if not records:
        raise TelemetryError(f"{path}: file is empty")

    header = records[0]
    if header.get("type") != RUN_START:
        raise TelemetryError(f"{path}:1: first record must be {RUN_START!r}")
    _require(path, 1, header, HEADER_FIELDS)

    summary: Record | None = None
    body = records[1:]
    if body and body[-1].get("type") == RUN_END:
        summary = body.pop()
        _require(path, len(records), summary, SUMMARY_FIELDS)
        _check_run_id(path, len(records), summary, header["run_id"])

    previous: tuple[int, int, int] | None = None
    for number, event in enumerate(body, start=2):
        if event.get("type") in (RUN_START, RUN_END):
            raise TelemetryError(f"{path}:{number}: {event['type']!r} out of place")
        _require(path, number, event, EVENT_FIELDS)
        _check_run_id(path, number, event, header["run_id"])
        order = (event["season"], event["tick"], event["seq"])
        if previous is not None and order <= previous:
            raise TelemetryError(
                f"{path}:{number}: (season, tick, seq) {order} does not follow {previous}"
            )
        previous = order

    return Run(header=header, events=tuple(body), summary=summary, truncated=truncated)


def _is_json(line: str) -> bool:
    try:
        json.loads(line)
    except json.JSONDecodeError:
        return False
    return True


def _parse_line(path: Path, number: int, line: str) -> Record:
    try:
        record = json.loads(line)
    except json.JSONDecodeError as error:
        raise TelemetryError(f"{path}:{number}: not valid JSON ({error.msg})") from error
    if not isinstance(record, dict):
        raise TelemetryError(f"{path}:{number}: record must be a JSON object")

    version = record.get("schema_version")
    # bool is a subclass of int in Python, so rule it out explicitly.
    if not isinstance(version, int) or isinstance(version, bool):
        raise TelemetryError(f"{path}:{number}: schema_version must be a whole number")
    if version not in SUPPORTED_SCHEMA_VERSIONS:
        supported = ", ".join(str(v) for v in sorted(SUPPORTED_SCHEMA_VERSIONS))
        raise UnsupportedSchemaVersionError(
            f"{path}:{number}: schema_version {version} is not supported (supported: {supported})"
        )
    return record


def _require(path: Path, number: int, record: Record, fields: tuple[str, ...]) -> None:
    missing = [field for field in fields if field not in record]
    if missing:
        raise TelemetryError(f"{path}:{number}: missing field(s) {', '.join(missing)}")


def _check_run_id(path: Path, number: int, record: Record, run_id: str) -> None:
    if record["run_id"] != run_id:
        raise TelemetryError(
            f"{path}:{number}: run_id {record['run_id']!r} does not match header {run_id!r}"
        )
