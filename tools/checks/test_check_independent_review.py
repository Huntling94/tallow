"""Tests for check_independent_review.py. Run: python -m unittest discover tools/checks"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
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


def environment_without_git() -> dict[str, str]:
    """The current environment minus GIT_ variables, which a git hook would point at this repository."""
    return {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}


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
    def test_missing_base_fails_loudly(self) -> None:
        problems = review.check(body(), HEAD)
        self.assertTrue(any("PR_BASE_SHA" in p for p in problems), problems)

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

    def test_edits_after_review_pass_with_a_warning(self) -> None:
        with ancestry({"abcdef1"}, set()), mock.patch.object(
            review, "unreviewed_paths", return_value=[]
        ), mock.patch("builtins.print") as printed:
            self.assertEqual(review.check(body(commit="abcdef1"), HEAD, BASE), [])
        self.assertIn("::warning", printed.call_args.args[0])

    def test_unreviewed_files_after_review_fail(self) -> None:
        with ancestry({"abcdef1"}, set()), mock.patch.object(
            review, "unreviewed_paths", return_value=["docs/adr/0002.md"]
        ):
            problems = review.check(body(commit="abcdef1"), HEAD, BASE)
        self.assertTrue(any("docs/adr/0002.md" in p for p in problems), problems)


class GitTests(unittest.TestCase):
    """Run the git helpers against a real throwaway repository.

    Git hooks pass settings such as GIT_DIR and GIT_INDEX_FILE to the commands
    they run. Inherited here, they would point these tests at the surrounding
    repository, so every GIT_ variable is cleared first.
    """

    def setUp(self) -> None:
        isolate = mock.patch.dict(os.environ, environment_without_git(), clear=True)
        isolate.start()
        self.addCleanup(isolate.stop)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.cwd = os.getcwd()
        os.chdir(self.tmp.name)
        self.addCleanup(os.chdir, self.cwd)
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "user.name", "Test")
        Path("a.md").write_text("one\n", encoding="utf-8")
        self.first = self.commit("first")

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", *args], capture_output=True, text=True, check=True
        ).stdout.strip()

    def commit(self, message: str) -> str:
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def reviewed_edit_of_a(self) -> str:
        """Add b.md on the base, then make a reviewed commit that edits only a.md."""
        Path("b.md").write_text("base\n", encoding="utf-8")
        self.base = self.commit("base")
        Path("a.md").write_text("reviewed\n", encoding="utf-8")
        return self.commit("reviewed")

    def test_later_edit_to_a_reviewed_file_is_covered(self) -> None:
        reviewed = self.reviewed_edit_of_a()
        Path("a.md").write_text("fixed\n", encoding="utf-8")
        head = self.commit("fix")
        self.assertEqual(review.unreviewed_paths(self.base, reviewed, head), [])

    def test_later_edit_to_an_unreviewed_file_is_reported(self) -> None:
        reviewed = self.reviewed_edit_of_a()
        Path("b.md").write_text("slipped in\n", encoding="utf-8")
        head = self.commit("edit b")
        self.assertEqual(review.unreviewed_paths(self.base, reviewed, head), ["b.md"])

    def test_new_and_renamed_files_are_reported(self) -> None:
        reviewed = self.reviewed_edit_of_a()
        Path("c.md").write_text("new\n", encoding="utf-8")
        Path("b.md").rename("d.md")
        head = self.commit("add and rename")
        self.assertEqual(
            review.unreviewed_paths(self.base, reviewed, head), ["b.md", "c.md", "d.md"]
        )

    def test_base_moving_ahead_does_not_count_as_reviewed(self) -> None:
        # main and the branch both start here, with a.md and b.md.
        Path("b.md").write_text("base\n", encoding="utf-8")
        self.commit("start")
        start_branch = self.git("rev-parse", "--abbrev-ref", "HEAD")
        self.git("checkout", "-q", "-b", "feature")
        Path("a.md").write_text("reviewed\n", encoding="utf-8")
        reviewed = self.commit("reviewed edit of a")
        # main moves ahead and edits b.md, which the review never saw.
        self.git("checkout", "-q", start_branch)
        Path("b.md").write_text("main changed\n", encoding="utf-8")
        base = self.commit("main edits b")
        # After the review, the branch edits b.md too.
        self.git("checkout", "-q", "feature")
        Path("b.md").write_text("branch changed\n", encoding="utf-8")
        head = self.commit("branch edits b")
        self.assertEqual(review.unreviewed_paths(base, reviewed, head), ["b.md"])

    def test_merging_the_base_in_is_not_reported(self) -> None:
        Path("b.md").write_text("base\n", encoding="utf-8")
        self.commit("start")
        start_branch = self.git("rev-parse", "--abbrev-ref", "HEAD")
        self.git("checkout", "-q", "-b", "feature")
        Path("a.md").write_text("reviewed\n", encoding="utf-8")
        reviewed = self.commit("reviewed edit of a")
        self.git("checkout", "-q", start_branch)
        Path("b.md").write_text("main changed\n", encoding="utf-8")
        base = self.commit("main edits b")
        self.git("checkout", "-q", "feature")
        self.git("merge", "-q", "--no-edit", start_branch)
        head = self.git("rev-parse", "HEAD")
        self.assertEqual(review.unreviewed_paths(base, reviewed, head), [])

    def test_ancestry_uses_real_history(self) -> None:
        Path("a.md").write_text("two\n", encoding="utf-8")
        head = self.commit("edit")
        self.assertTrue(review.is_ancestor(self.first, head))
        self.assertFalse(review.is_ancestor(head, self.first))


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


class IsolationTests(unittest.TestCase):
    def test_git_tests_leave_a_surrounding_repository_alone(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            decoy = Path(tmp)
            subprocess.run(
                ["git", "init", "-q", str(decoy)], check=True, env=environment_without_git()
            )
            decoy_git = str(decoy / ".git")
            before = (decoy / ".git" / "config").read_text(encoding="utf-8")
            env = {"GIT_DIR": decoy_git, "GIT_INDEX_FILE": str(decoy / ".git" / "index")}
            with mock.patch.dict(os.environ, env):
                suite = unittest.defaultTestLoader.loadTestsFromTestCase(GitTests)
                result = unittest.TestResult()
                suite.run(result)
            self.assertTrue(result.wasSuccessful(), result.errors + result.failures)
            self.assertEqual((decoy / ".git" / "config").read_text(encoding="utf-8"), before)
            self.assertFalse((decoy / ".git" / "index").exists(), "the decoy's staging area was used")


if __name__ == "__main__":
    unittest.main()
