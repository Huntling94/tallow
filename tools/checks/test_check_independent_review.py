"""Tests for check_independent_review.py. Run: python -m unittest discover tools/checks"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))

import check_independent_review as review  # noqa: E402

TEMPLATE = (Path(__file__).parents[2] / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(
    encoding="utf-8"
)

HEAD = "c" * 40
BASE = "b" * 40


def body(
    reviewer: str = "reviewer agent",
    commit: str = "ccccccc",
    verdict: str = "Pass",
    findings: str = "None",
    tail: str = "**Checked:** AC1",
) -> str:
    return (
        "## Summary\n\nText.\n\n## Independent review\n\n"
        f"**Reviewer:** {reviewer}\n"
        f"**Reviewed commit:** {commit}\n"
        f"**Verdict:** {verdict}\n\n"
        f"**Findings and actions:**\n\n{findings}\n\n{tail}\n\n"
        "## Definition of done\n\n- [ ] Done\n"
    )


def ancestry(on_branch: set[str], on_base: set[str]):
    """Fake git ancestry: which short SHAs are on the branch and on the base."""

    def is_ancestor(sha: str, of: str) -> bool:
        return sha in (on_base if of == BASE else on_branch)

    return mock.patch.object(review, "is_ancestor", side_effect=is_ancestor)


class SectionTests(unittest.TestCase):
    def test_untouched_template_fails_on_every_field(self) -> None:
        problems = review.check(TEMPLATE, None)
        self.assertEqual(len(problems), 4, problems)

    def test_missing_section_fails(self) -> None:
        self.assertIn("missing", review.check("## Summary\n\nText.\n", None)[0])

    def test_complete_section_passes(self) -> None:
        self.assertEqual(review.check(body(), None), [])

    def test_windows_line_endings_pass(self) -> None:
        self.assertEqual(review.check(body().replace("\n", "\r\n"), None), [])

    def test_pass_with_notes_passes(self) -> None:
        self.assertEqual(review.check(body(verdict="Pass with notes"), None), [])

    def test_changes_needed_fails(self) -> None:
        problems = review.check(body(verdict="Changes needed"), None)
        self.assertTrue(any("Changes needed" in p for p in problems), problems)

    def test_empty_field_does_not_read_the_next_line(self) -> None:
        problems = review.check(body(verdict=""), None)
        self.assertEqual(problems, ['"Verdict" is empty.'])

    def test_empty_findings_followed_by_checked_line_fails(self) -> None:
        problems = review.check(body(findings=""), None)
        self.assertTrue(any("Findings" in p for p in problems), problems)

    def test_findings_inside_a_comment_do_not_count(self) -> None:
        problems = review.check(body(findings="<!-- None -->"), None)
        self.assertTrue(any("Findings" in p for p in problems), problems)

    def test_invalid_sha_fails(self) -> None:
        problems = review.check(body(commit="latest"), None)
        self.assertTrue(any("commit SHA" in p for p in problems), problems)


class CommitTests(unittest.TestCase):
    def test_latest_commit_passes(self) -> None:
        with ancestry({"ccccccc"}, set()):
            self.assertEqual(review.check(body(), HEAD, BASE), [])

    def test_commit_not_on_branch_fails(self) -> None:
        with ancestry(set(), set()):
            problems = review.check(body(commit="abcdef1"), HEAD, BASE)
        self.assertTrue(any("not on this branch" in p for p in problems), problems)

    def test_commit_already_on_base_fails(self) -> None:
        with ancestry({"abcdef1"}, {"abcdef1"}):
            problems = review.check(body(commit="abcdef1"), HEAD, BASE)
        self.assertTrue(any("base branch" in p for p in problems), problems)

    def test_earlier_branch_commit_passes_with_a_warning(self) -> None:
        with ancestry({"abcdef1"}, set()), mock.patch("builtins.print") as printed:
            self.assertEqual(review.check(body(commit="abcdef1"), HEAD, BASE), [])
        self.assertIn("::warning", printed.call_args.args[0])


class MainTests(unittest.TestCase):
    def test_dependabot_is_exempt(self) -> None:
        env = {"PR_AUTHOR": "dependabot[bot]", "PR_BODY": ""}
        with mock.patch.dict("os.environ", env, clear=True), mock.patch("builtins.print"):
            self.assertEqual(review.main(), 0)

    def test_incomplete_body_exits_non_zero(self) -> None:
        with mock.patch.dict("os.environ", {"PR_BODY": TEMPLATE}, clear=True), mock.patch(
            "builtins.print"
        ):
            self.assertEqual(review.main(), 1)


if __name__ == "__main__":
    unittest.main()
