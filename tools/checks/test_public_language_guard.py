"""Tests for public_language_guard.py. Run: python -m unittest discover -s tools/checks

The terms below are neutral stand-ins; the real list is private and never in the repo.
"""

from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))

import public_language_guard as guard  # noqa: E402


def patterns(*terms: str):
    return [guard.compile_term(term) for term in terms]


class MatchingTests(unittest.TestCase):
    def test_whole_words_only(self) -> None:
        hits = guard.scan_text("a zebra, not unzebra or zebras", "t", patterns("zebra"))
        self.assertEqual([(hit.line, hit.column) for hit in hits], [(1, 3)])

    def test_case_is_ignored(self) -> None:
        self.assertEqual(len(guard.scan_text("ZEBRA Zebra", "t", patterns("zebra"))), 2)

    def test_trailing_star_matches_word_endings(self) -> None:
        hits = guard.scan_text("giraffe giraffes giraff", "t", patterns("giraff*"))
        self.assertEqual(len(hits), 3)

    def test_phrases_match_across_line_breaks(self) -> None:
        hits = guard.scan_text("the blue\n  whale", "t", patterns("blue whale"))
        self.assertEqual([(hit.line, hit.column) for hit in hits], [(1, 5)])

    def test_report_names_the_term_number_not_the_term(self) -> None:
        hit = guard.scan_text("x zebra", "f.md", patterns("lion", "zebra"))[0]
        self.assertEqual(str(hit), "f.md:1:3: blocked term #2")


class InputTests(unittest.TestCase):
    def test_git_comment_lines_are_ignored(self) -> None:
        message = "Add a feature\n# zebra in a comment\n# ------------------------ >8\nzebra"
        cleaned = guard.strip_git_comments(message)
        self.assertEqual(guard.scan_text(cleaned, "m", patterns("zebra")), [])

    def test_environment_list_wins_over_file(self) -> None:
        with mock.patch.dict(os.environ, {guard.ENV_TERMS: "zebra\n# note\n\nlion"}):
            self.assertEqual(guard.load_terms(), ["zebra", "lion"])

    def test_empty_file_setting_falls_back_to_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            default = Path(tmp) / "terms.txt"
            default.write_text("zebra\n", encoding="utf-8")
            env = {guard.ENV_TERMS: "", guard.ENV_FILE: ""}
            with mock.patch.dict(os.environ, env), mock.patch.object(guard, "DEFAULT_FILE", default):
                self.assertEqual(guard.load_terms(), ["zebra"])

    def test_missing_list_fails_loudly(self) -> None:
        env = {guard.ENV_TERMS: "", guard.ENV_FILE: "does-not-exist.txt"}
        with mock.patch.dict(os.environ, env), mock.patch("sys.stderr", io.StringIO()):
            self.assertEqual(guard.main(["text"]), guard.EXIT_NO_LIST)


class HookTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name).resolve()
        self.file = self.project / "notes.md"
        self.file.write_text("a zebra here\n", encoding="utf-8")

    def run_hook(self, tool_input: dict, terms=("zebra",)) -> int:
        event = io.StringIO(json.dumps({"tool_input": tool_input}))
        env = {"CLAUDE_PROJECT_DIR": str(self.project)}
        with mock.patch("sys.stdin", event), mock.patch.dict(os.environ, env), mock.patch(
            "sys.stderr", io.StringIO()
        ):
            return guard.run_hook(patterns(*terms))

    def test_edited_file_with_a_term_is_flagged(self) -> None:
        self.assertEqual(self.run_hook({"file_path": str(self.file)}), guard.EXIT_HOOK_MATCH)

    def test_notebook_edits_are_checked(self) -> None:
        notebook = self.project / "analysis.ipynb"
        notebook.write_text('{"cells": [{"source": ["a zebra"]}]}', encoding="utf-8")
        self.assertEqual(self.run_hook({"notebook_path": str(notebook)}), guard.EXIT_HOOK_MATCH)

    def test_clean_file_passes(self) -> None:
        self.file.write_text("nothing to see\n", encoding="utf-8")
        self.assertEqual(self.run_hook({"file_path": str(self.file)}), guard.EXIT_OK)

    def test_files_outside_the_project_are_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as other:
            outside = Path(other) / "notes.md"
            outside.write_text("a zebra here\n", encoding="utf-8")
            self.assertEqual(self.run_hook({"file_path": str(outside)}), guard.EXIT_OK)


if __name__ == "__main__":
    unittest.main()
