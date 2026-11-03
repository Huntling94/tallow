#!/usr/bin/env python3
"""Create or update the repo's labels and milestones from .github/*.json.

Safe to run repeatedly: existing labels and milestones are updated in place.
Uses the GitHub CLI (`gh`), so run it from inside the repo after `gh auth login`.

Usage:
  python tools/github/sync_meta.py              apply changes
  python tools/github/sync_meta.py --dry-run    show what would change
  python tools/github/sync_meta.py --prune      also delete labels not in labels.json
                                                (for example GitHub's default labels)
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LABELS_FILE = ROOT / ".github" / "labels.json"
MILESTONES_FILE = ROOT / ".github" / "milestones.json"


def gh(*args: str, dry_run: bool = False) -> str:
    if dry_run:
        print("  would run: gh", " ".join(args))
        return ""
    result = subprocess.run(["gh", *args], capture_output=True, text=True, check=True)
    return result.stdout


def gh_json(*args: str) -> list[dict]:
    return json.loads(gh(*args) or "[]")


def sync_labels(dry_run: bool, prune: bool) -> None:
    wanted = json.loads(LABELS_FILE.read_text(encoding="utf-8"))
    existing = {label["name"] for label in gh_json("label", "list", "--limit", "500", "--json", "name")}
    print(f"Labels: {len(wanted)} wanted, {len(existing)} existing")
    for label in wanted:
        action = "update" if label["name"] in existing else "create"
        print(f"  {action}: {label['name']}")
        gh(
            "label", "create", label["name"],
            "--color", label["color"],
            "--description", label["description"],
            "--force",
            dry_run=dry_run,
        )
    if prune:
        for name in sorted(existing - {label["name"] for label in wanted}):
            print(f"  delete: {name}")
            gh("label", "delete", name, "--yes", dry_run=dry_run)


def sync_milestones(dry_run: bool) -> None:
    wanted = json.loads(MILESTONES_FILE.read_text(encoding="utf-8"))
    existing = {
        milestone["title"]: milestone["number"]
        for milestone in gh_json("api", "repos/{owner}/{repo}/milestones?state=all&per_page=100")
    }
    print(f"Milestones: {len(wanted)} wanted, {len(existing)} existing")
    for milestone in wanted:
        fields = ["-f", f"title={milestone['title']}", "-f", f"description={milestone['description']}"]
        number = existing.get(milestone["title"])
        if number is None:
            print(f"  create: {milestone['title']}")
            gh("api", "--method", "POST", "repos/{owner}/{repo}/milestones", *fields, dry_run=dry_run)
        else:
            print(f"  update: {milestone['title']}")
            gh("api", "--method", "PATCH", f"repos/{{owner}}/{{repo}}/milestones/{number}", *fields, dry_run=dry_run)


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync labels and milestones to GitHub.")
    parser.add_argument("--dry-run", action="store_true", help="show changes without making them")
    parser.add_argument("--prune", action="store_true", help="delete labels not in labels.json")
    args = parser.parse_args()
    try:
        sync_labels(args.dry_run, args.prune)
        sync_milestones(args.dry_run)
    except subprocess.CalledProcessError as error:
        print(f"gh failed: {error.stderr.strip()}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
