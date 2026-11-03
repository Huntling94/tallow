#!/usr/bin/env python3
"""Run the Godot tests headless with gdUnit4.

Imports the project first (so class names resolve), then runs every test under
game/tests. Uses the Godot binary in the GODOT environment variable, or the
first of godot_console / godot found on PATH.

Usage: python tools/godot/run_tests.py
Exit code: 0 when every test passes.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
RUNNER = "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"


def find_godot() -> str | None:
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    for name in ("godot_console", "godot"):
        found = shutil.which(name)
        if found:
            return found
    return None


def main() -> int:
    godot = find_godot()
    if godot is None:
        print("Godot not found. Put it on PATH or set GODOT.", file=sys.stderr)
        return 1
    if not (GAME / "addons" / "gdUnit4").is_dir():
        print("gdUnit4 is missing. Run: python tools/godot/install_gdunit4.py", file=sys.stderr)
        return 1

    project = ["--headless", "--path", str(GAME)]
    imported = subprocess.run([godot, *project, "--import"], check=False)
    if imported.returncode != 0:
        print("Godot failed to import the project.", file=sys.stderr)
        return imported.returncode

    tests = [godot, *project, "-s", "-d", RUNNER, "--ignoreHeadlessMode", "-a", "res://tests"]
    return subprocess.run(tests, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
