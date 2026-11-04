"""Tests for the telemetry loader against the sample files in fixtures/."""

import json
from pathlib import Path

import pytest

from tallow_analysis.telemetry import (
    TelemetryError,
    UnsupportedSchemaVersionError,
    load_run,
)

FIXTURES = Path(__file__).parent.parent / "fixtures"
COMPLETE = FIXTURES / "run_complete.jsonl"


def records() -> list[dict]:
    return [json.loads(line) for line in COMPLETE.read_text(encoding="utf-8").splitlines()]


def write(tmp_path: Path, rows: list[dict]) -> Path:
    path = tmp_path / "run.jsonl"
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")
    return path


def test_loads_a_complete_run() -> None:
    run = load_run(COMPLETE)

    assert run.run_id == "3f9a1c2e-42-a1b2"
    assert run.header["seed"] == 42
    assert [event["type"] for event in run.events] == [
        "herd_arrived",
        "route_chosen",
        "beast_killed",
    ]
    assert run.complete
    assert run.summary is not None
    assert run.summary["outcome"] == "survived"


def test_a_file_without_a_summary_is_an_incomplete_run(tmp_path: Path) -> None:
    run = load_run(write(tmp_path, records()[:-1]))

    assert not run.complete
    assert len(run.events) == 3


@pytest.mark.parametrize("line", [0, 2, 4], ids=["header", "event", "summary"])
def test_rejects_an_unknown_schema_version_on_any_line(tmp_path: Path, line: int) -> None:
    rows = records()
    rows[line]["schema_version"] = 99

    with pytest.raises(UnsupportedSchemaVersionError, match=rf":{line + 1}: schema_version 99"):
        load_run(write(tmp_path, rows))


@pytest.mark.parametrize("version", [None, "1", 1.0, True])
def test_rejects_a_schema_version_that_is_not_a_whole_number(tmp_path: Path, version) -> None:
    rows = records()
    rows[1]["schema_version"] = version

    with pytest.raises(TelemetryError, match="must be a whole number"):
        load_run(write(tmp_path, rows))


def test_rejects_a_file_that_does_not_start_with_a_run_header(tmp_path: Path) -> None:
    with pytest.raises(TelemetryError, match=":1: first record must be 'run_start'"):
        load_run(write(tmp_path, records()[1:]))


def test_rejects_an_event_missing_a_required_field(tmp_path: Path) -> None:
    rows = records()
    del rows[2]["tick"]

    with pytest.raises(TelemetryError, match=":3: missing field"):
        load_run(write(tmp_path, rows))


def test_rejects_an_event_from_another_run(tmp_path: Path) -> None:
    rows = records()
    rows[3]["run_id"] = "other-run"

    with pytest.raises(TelemetryError, match=":4: run_id 'other-run' does not match"):
        load_run(write(tmp_path, rows))


def test_rejects_a_summary_before_the_last_line(tmp_path: Path) -> None:
    rows = records()
    rows.insert(2, rows[-1])

    with pytest.raises(TelemetryError, match=":3: 'run_end' out of place"):
        load_run(write(tmp_path, rows))


def test_rejects_a_line_that_is_not_json(tmp_path: Path) -> None:
    path = write(tmp_path, records())
    path.write_text(path.read_text(encoding="utf-8") + "{not json\n", encoding="utf-8")

    with pytest.raises(TelemetryError, match=":6: not valid JSON"):
        load_run(path)


def test_rejects_an_empty_file(tmp_path: Path) -> None:
    with pytest.raises(TelemetryError, match="file is empty"):
        load_run(write(tmp_path, []))


def test_a_cut_off_last_line_loads_as_an_incomplete_run(tmp_path: Path) -> None:
    path = write(tmp_path, records()[:-1])
    path.write_text(path.read_text(encoding="utf-8") + '{"type": "run_e', encoding="utf-8")

    run = load_run(path)

    assert not run.complete
    assert run.truncated
    assert len(run.events) == 3


def test_a_malformed_last_line_that_ends_with_a_newline_is_still_an_error(
    tmp_path: Path,
) -> None:
    path = write(tmp_path, records()[:-1])
    path.write_text(path.read_text(encoding="utf-8") + '{"type": "run_e\n', encoding="utf-8")

    with pytest.raises(TelemetryError, match=":5: not valid JSON"):
        load_run(path)


def test_a_valid_last_line_without_a_newline_is_kept(tmp_path: Path) -> None:
    path = write(tmp_path, records())
    path.write_text(path.read_text(encoding="utf-8").rstrip("\n"), encoding="utf-8")

    run = load_run(path)

    assert run.complete
    assert not run.truncated


def test_a_blank_line_is_an_error(tmp_path: Path) -> None:
    path = write(tmp_path, records())
    lines = path.read_text(encoding="utf-8").splitlines()
    path.write_text("\n".join([*lines[:2], "", *lines[2:]]) + "\n", encoding="utf-8")

    with pytest.raises(TelemetryError, match=":3: not valid JSON"):
        load_run(path)


@pytest.mark.parametrize(
    ("line", "field"), [(0, "rules_version"), (4, "outcome")], ids=["header", "summary"]
)
def test_rejects_a_header_or_summary_missing_a_field(tmp_path: Path, line: int, field: str) -> None:
    rows = records()
    del rows[line][field]

    with pytest.raises(TelemetryError, match=rf":{line + 1}: missing field\(s\) {field}"):
        load_run(write(tmp_path, rows))


def test_rejects_a_summary_from_another_run(tmp_path: Path) -> None:
    rows = records()
    rows[-1]["run_id"] = "other-run"

    with pytest.raises(TelemetryError, match=":5: run_id 'other-run' does not match"):
        load_run(write(tmp_path, rows))


@pytest.mark.parametrize(
    ("row", "order"),
    [(2, (1, 0, 0)), (3, (1, 0, 0)), (2, (0, 99, 9))],
    ids=["repeated", "earlier seq", "earlier season"],
)
def test_rejects_events_out_of_order(tmp_path: Path, row: int, order: tuple[int, int, int]) -> None:
    rows = records()
    rows[row]["season"], rows[row]["tick"], rows[row]["seq"] = order

    with pytest.raises(TelemetryError, match=rf":{row + 1}: .* does not follow"):
        load_run(write(tmp_path, rows))


def test_a_loaded_run_cannot_be_changed() -> None:
    run = load_run(COMPLETE)

    assert isinstance(run.events, tuple)
