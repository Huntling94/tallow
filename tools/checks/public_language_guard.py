#!/usr/bin/env python3
"""Public-language guard.

Fails when tracked text, file names, commit messages or pull request text
contain a term from the project's blocked-term list. The list is kept out of
the repository on purpose. It is read from the TALLOW_BLOCKLIST environment
variable (CI, from a repository secret) or from a local file (developer
machines). Matches are reported by position and term number only, so the
terms never appear in logs.

List format: one term per line. Matching ignores case and works on whole
words. A trailing * matches any word ending ("plan*" matches "plans").
Spaces inside a term match any run of whitespace, including line breaks.
Blank lines and lines starting with # are ignored.

Usage:
  public_language_guard.py files [--all] [PATH ...]  scan files (pre-commit, CI)
  public_language_guard.py message FILE              scan a commit message
  public_language_guard.py text [--label LABEL]      scan stdin (PR title and body)
  public_language_guard.py hook                      Claude Code PostToolUse hook

Exit codes: 0 clean, 1 blocked term found, 3 no term list available.
In hook mode a match exits 2 so Claude Code shows the message to Claude.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ENV_TERMS = "TALLOW_BLOCKLIST"
ENV_FILE = "TALLOW_BLOCKLIST_FILE"
DEFAULT_FILE = Path.home() / ".config" / "tallow" / "blocked-terms.txt"

EXIT_OK = 0
EXIT_MATCH = 1
EXIT_HOOK_MATCH = 2
EXIT_NO_LIST = 3

BINARY_SNIFF_BYTES = 8000


@dataclass(frozen=True)
class Hit:
    source: str
    line: int
    column: int
    term_number: int

    def __str__(self) -> str:
        return f"{self.source}:{self.line}:{self.column}: blocked term #{self.term_number}"


def load_terms() -> list[str]:
    """Read terms from the environment variable, else from the local file."""
    raw = os.environ.get(ENV_TERMS, "")
    if not raw.strip():
        path = Path(os.environ.get(ENV_FILE, DEFAULT_FILE)).expanduser()
        if not path.is_file():
            return []
        raw = path.read_text(encoding="utf-8")
    terms = []
    for line in raw.splitlines():
        term = line.strip()
        if term and not term.startswith("#"):
            terms.append(term)
    return terms


def compile_term(term: str) -> re.Pattern[str]:
    stem = term.endswith("*")
    words = [re.escape(word) for word in term.rstrip("*").split()]
    body = r"\s+".join(words)
    tail = r"\w*" if stem else ""
    return re.compile(rf"(?<!\w){body}{tail}(?!\w)", re.IGNORECASE)


def scan_text(text: str, source: str, patterns: list[re.Pattern[str]]) -> list[Hit]:
    hits = []
    for number, pattern in enumerate(patterns, start=1):
        for match in pattern.finditer(text):
            start = match.start()
            line = text.count("\n", 0, start) + 1
            column = start - (text.rfind("\n", 0, start) + 1) + 1
            hits.append(Hit(source, line, column, number))
    return sorted(hits, key=lambda hit: (hit.line, hit.column, hit.term_number))


def read_text_file(path: Path) -> str | None:
    """Return the file's text, or None if it is binary or unreadable."""
    try:
        data = path.read_bytes()
    except OSError:
        return None
    if b"\0" in data[:BINARY_SNIFF_BYTES]:
        return None
    return data.decode("utf-8", errors="replace")


def scan_file(
    path: Path, patterns: list[re.Pattern[str]], name: str | None = None
) -> list[Hit]:
    name = name or path.as_posix()
    hits = scan_text(name, f"{name} (file name)", patterns)
    text = read_text_file(path)
    if text is not None:
        hits.extend(scan_text(text, name, patterns))
    return hits


def tracked_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z"], capture_output=True, check=True, text=True
    )
    return [Path(name) for name in result.stdout.split("\0") if name]


def strip_git_comments(message: str) -> str:
    """Blank out git's comment lines, keeping line numbers stable."""
    lines = []
    for line in message.splitlines():
        if line.startswith("# ------------------------ >8"):
            break
        lines.append("" if line.startswith("#") else line)
    return "\n".join(lines)


def report(hits: list[Hit]) -> None:
    for hit in hits:
        print(hit, file=sys.stderr)
    print(
        f"\npublic-language-guard: {len(hits)} blocked term(s) found. "
        "Reword the text; see the term list for what each number means.",
        file=sys.stderr,
    )


def missing_list_message() -> str:
    return (
        "public-language-guard: no blocked-term list found.\n"
        f"Set {ENV_TERMS} (CI) or create {DEFAULT_FILE} "
        f"(or point {ENV_FILE} at another file). The list is kept outside the repo."
    )


def run_hook(patterns: list[re.Pattern[str]]) -> int:
    """Check a file Claude Code just wrote. Only files inside the project count."""
    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError:
        return EXIT_OK
    file_path = (event.get("tool_input") or {}).get("file_path")
    if not file_path or not patterns:
        return EXIT_OK
    project = Path(os.environ.get("CLAUDE_PROJECT_DIR") or event.get("cwd") or ".").resolve()
    path = Path(file_path).resolve()
    if not path.is_file() or not path.is_relative_to(project):
        return EXIT_OK
    hits = scan_file(path, patterns, path.relative_to(project).as_posix())
    if not hits:
        return EXIT_OK
    report(hits)
    print(
        "This repository keeps its public text about the game and how it is made. "
        "Rewrite the flagged text before continuing.",
        file=sys.stderr,
    )
    return EXIT_HOOK_MATCH


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="mode", required=True)
    files = sub.add_parser("files", help="scan files")
    files.add_argument("--all", action="store_true", help="scan every tracked file")
    files.add_argument("paths", nargs="*", type=Path)
    message = sub.add_parser("message", help="scan a commit message file")
    message.add_argument("path", type=Path)
    text = sub.add_parser("text", help="scan text from stdin")
    text.add_argument("--label", default="stdin")
    sub.add_parser("hook", help="Claude Code PostToolUse hook")
    args = parser.parse_args(argv)

    patterns = [compile_term(term) for term in load_terms()]

    if args.mode == "hook":
        return run_hook(patterns)

    if not patterns:
        print(missing_list_message(), file=sys.stderr)
        return EXIT_NO_LIST

    hits: list[Hit] = []
    if args.mode == "files":
        paths = tracked_files() if args.all else args.paths
        for path in paths:
            hits.extend(scan_file(path, patterns))
    elif args.mode == "message":
        body = args.path.read_text(encoding="utf-8", errors="replace")
        hits = scan_text(strip_git_comments(body), "commit message", patterns)
    elif args.mode == "text":
        hits = scan_text(sys.stdin.read(), args.label, patterns)

    if hits:
        report(hits)
        return EXIT_MATCH
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
