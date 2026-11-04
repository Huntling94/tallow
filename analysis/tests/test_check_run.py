"""Tests for the check_run command, against the sample files in fixtures/."""

from pathlib import Path

import pytest

from tallow_analysis.check_run import main

FIXTURES = Path(__file__).parent.parent / "fixtures"


def test_a_valid_file_prints_a_summary_and_exits_0(capsys: pytest.CaptureFixture[str]) -> None:
    assert main([str(FIXTURES / "run_complete.jsonl")]) == 0

    out = capsys.readouterr().out
    assert "run_id:   3f9a1c2e-42-a1b2" in out
    assert "seed:     42" in out
    assert "seasons:  1" in out
    assert "events:   3" in out
    assert "status:   complete" in out


def test_an_invalid_file_exits_1_with_the_loader_error(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    path = tmp_path / "run.jsonl"
    path.write_text('{"type": "herd_arrived", "schema_version": 1}\n', encoding="utf-8")

    assert main([str(path)]) == 1
    assert "first record must be 'run_start'" in capsys.readouterr().err


def test_a_missing_file_exits_1(tmp_path: Path) -> None:
    assert main([str(tmp_path / "missing.jsonl")]) == 1


def test_wrong_arguments_exit_2() -> None:
    assert main([]) == 2
