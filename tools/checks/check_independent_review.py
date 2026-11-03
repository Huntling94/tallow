#!/usr/bin/env python3
"""Check that a pull request's "Independent review" section is filled in.

Reads the PR body from the PR_BODY environment variable. Fails when:
  - the section is missing;
  - Reviewer, Reviewed commit or Verdict is empty;
  - the verdict is not "Pass" or "Pass with notes";
  - the findings are empty (write "None" when there were none);
  - the reviewed commit is not one of this pull request's own commits: it must
    be on the branch (PR_HEAD_SHA) and not already on the base (PR_BASE_SHA);
  - PR_HEAD_SHA is set but PR_BASE_SHA is not, so the commit checks cannot run;
  - commits after the reviewed commit touch any file the review did not cover
    (one that is not in the diff from the base to the reviewed commit).

Warns, without failing, when later commits only touch files the review covered.

This is a plain text check. It confirms the review was recorded, not that it
was good: judging that is the maintainer's job at merge.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys

SECTION = "independent review"
PASSING_VERDICTS = {"pass", "pass with notes"}
FIELDS = ("Reviewer", "Reviewed commit", "Verdict")
FINDINGS_LABEL = "Findings and actions"

COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
NEXT_LABEL = re.compile(r"^[ \t]*\*\*[^*\n]+:\*\*", re.MULTILINE)
HEADING = re.compile(r"^##\s+(.+?)\s*$", re.MULTILINE)
SHA = re.compile(r"^[0-9a-f]{7,40}$", re.IGNORECASE)


def extract_section(body: str, title: str) -> str | None:
    """Return the text under a level-2 heading, up to the next one."""
    headings = list(HEADING.finditer(body))
    for index, heading in enumerate(headings):
        if heading.group(1).strip().lower() == title:
            end = headings[index + 1].start() if index + 1 < len(headings) else len(body)
            return body[heading.end():end]
    return None


def field_value(section: str, name: str) -> str:
    match = re.search(
        rf"^[ \t]*\**{re.escape(name)}:\**[ \t]*(.*?)[ \t]*$", section, re.MULTILINE | re.IGNORECASE
    )
    return match.group(1).strip("* ").strip() if match else ""


def findings_text(section: str) -> str:
    """Return the findings, stopping at the next bold label (such as **Checked:**)."""
    match = re.search(rf"\**{re.escape(FINDINGS_LABEL)}:\**", section, re.IGNORECASE)
    if not match:
        return ""
    rest = section[match.end():]
    following = NEXT_LABEL.search(rest)
    return (rest[:following.start()] if following else rest).strip()


def is_ancestor(sha: str, of: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", sha, of], capture_output=True
    )
    return result.returncode == 0


def changed_paths(start: str, end: str, since_branch_point: bool = False) -> set[str]:
    """Return every path that differs between two commits (a rename counts as both paths).

    With since_branch_point, compare from where the two histories meet (start...end),
    so changes made on the base branch after the branch was cut are left out.
    """
    commits = [f"{start}...{end}"] if since_branch_point else [start, end]
    result = subprocess.run(
        ["git", "diff", "--name-only", "--no-renames", *commits],
        capture_output=True,
        text=True,
        check=True,
    )
    return {line for line in result.stdout.splitlines() if line}


def unreviewed_paths(base: str, reviewed: str, head: str) -> list[str]:
    """Return this pull request's paths changed after the review that the review did not cover."""
    covered = changed_paths(base, reviewed, since_branch_point=True)
    own = changed_paths(base, head, since_branch_point=True)
    return sorted((changed_paths(reviewed, head) & own) - covered)


def check(body: str, head_sha: str | None, base_sha: str | None = None) -> list[str]:
    """Return a list of problems; empty means the check passes."""
    raw = extract_section(body.replace("\r\n", "\n"), SECTION)
    if raw is None:
        return ['The "## Independent review" section is missing. Use the PR template.']

    section = COMMENT.sub("", raw)
    problems = [f'"{name}" is empty.' for name in FIELDS if not field_value(section, name)]

    verdict = field_value(section, "Verdict")
    if verdict and verdict.lower() not in PASSING_VERDICTS:
        problems.append(
            f'Verdict is "{verdict}". It must be "Pass" or "Pass with notes" before merging.'
        )

    if not findings_text(section):
        problems.append('"Findings and actions" is empty. Write "None" if there were none.')

    sha = field_value(section, "Reviewed commit")
    if sha and not SHA.match(sha):
        problems.append(f'"Reviewed commit" should be a commit SHA, not "{sha}".')
    elif sha and head_sha:
        if not base_sha:
            problems.append(
                "PR_BASE_SHA is not set, so the check cannot tell which commits belong "
                "to this pull request."
            )
        elif not is_ancestor(sha, head_sha):
            problems.append(f"Reviewed commit {sha} is not on this branch.")
        elif is_ancestor(sha, base_sha):
            problems.append(
                f"Reviewed commit {sha} is already on the base branch, "
                "so it is not this pull request's change."
            )
        elif not head_sha.lower().startswith(sha.lower()):
            unreviewed = unreviewed_paths(base_sha, sha, head_sha)
            if unreviewed:
                problems.append(
                    f"Commits after the reviewed commit {sha} touch files the review did "
                    f"not cover: {', '.join(unreviewed)}. Re-run the review."
                )
            else:
                print(
                    f"::warning title=Independent review::The review covers {sha}, not the "
                    f"latest commit {head_sha[:7]}. Re-run it if the changes since are significant."
                )

    return problems


def main() -> int:
    author = os.environ.get("PR_AUTHOR", "")
    if author == "dependabot[bot]":
        print("Dependabot PR: independent review not required (dependency bumps only).")
        return 0

    problems = check(
        os.environ.get("PR_BODY", ""),
        os.environ.get("PR_HEAD_SHA"),
        os.environ.get("PR_BASE_SHA"),
    )
    if problems:
        for problem in problems:
            print(f"::error title=Independent review::{problem}")
        return 1

    print("Independent review section is complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
