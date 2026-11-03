#!/usr/bin/env python3
"""Install the pinned gdUnit4 test framework into game/addons/gdUnit4.

gdUnit4 is a development tool, not shipped with the game, so it is not
committed. This script downloads a pinned release, checks it against a pinned
SHA-256, and extracts only the addon folder. Safe to run repeatedly.

Usage: python tools/godot/install_gdunit4.py
"""

from __future__ import annotations

import hashlib
import io
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

VERSION = "6.2.3"
URL = f"https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v{VERSION}.zip"
SHA256 = "8fb1a298af110be6d73067af66132bf036049deb6d5929d4a16756e18d2228bb"

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "game" / "addons" / "gdUnit4"
MARKER = TARGET / ".tallow-version"
PREFIX = f"gdUnit4-{VERSION}/addons/gdUnit4/"


def main() -> int:
    if MARKER.is_file() and MARKER.read_text(encoding="utf-8").strip() == VERSION:
        print(f"gdUnit4 {VERSION} is already installed.")
        return 0

    print(f"Downloading gdUnit4 {VERSION}...")
    with urllib.request.urlopen(URL, timeout=60) as response:
        data = response.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SHA256:
        print(f"Checksum mismatch: expected {SHA256}, got {digest}.", file=sys.stderr)
        return 1

    if TARGET.exists():
        shutil.rmtree(TARGET)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for member in archive.infolist():
            if member.is_dir() or not member.filename.startswith(PREFIX):
                continue
            relative = Path(member.filename[len(PREFIX):])
            if relative.is_absolute() or ".." in relative.parts:
                print(f"Refusing unsafe path in archive: {member.filename}", file=sys.stderr)
                return 1
            destination = TARGET / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(archive.read(member))

    MARKER.write_text(VERSION + "\n", encoding="utf-8")
    print(f"Installed gdUnit4 {VERSION} into {TARGET.relative_to(ROOT).as_posix()}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
