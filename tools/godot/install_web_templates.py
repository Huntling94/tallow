#!/usr/bin/env python3
"""Install the Godot web export templates needed to build the web version.

Godot ships every platform's templates in one large archive (about 1.3 GB).
This script downloads the pinned release once, checks it against the SHA-512
published with the release, and extracts only the single-threaded web
templates into Godot's templates folder. Single-threaded builds need no
special server headers, so they run on GitHub Pages. Safe to run repeatedly.

Set GODOT_TEMPLATES_ARCHIVE to a local copy of the archive to skip the
download. CI caches the extracted templates folder instead, so it downloads
only when that cache is empty.

Usage: python tools/godot/install_web_templates.py
"""

from __future__ import annotations

import hashlib
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

VERSION = "4.7.2"
ARCHIVE = f"Godot_v{VERSION}-stable_export_templates.tpz"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/{ARCHIVE}"
SHA512 = (
    "ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5"
    "f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
)
TEMPLATES = ("web_nothreads_release.zip", "web_nothreads_debug.zip")
CHUNK = 1 << 20


def templates_dir() -> Path:
    """Godot's export templates folder for this version, per platform."""
    if sys.platform == "win32":
        base = Path(os.environ["APPDATA"]) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot"
    else:
        data_home = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
        base = Path(data_home) / "godot"
    return base / "export_templates" / f"{VERSION}.stable"


def sha512_of(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as file:
        while chunk := file.read(CHUNK):
            digest.update(chunk)
    return digest.hexdigest()


def download(destination: Path) -> None:
    print(f"Downloading {ARCHIVE} (about 1.3 GB)...")
    with urllib.request.urlopen(URL, timeout=60) as response, destination.open("wb") as file:
        shutil.copyfileobj(response, file, CHUNK)


def main() -> int:
    target = templates_dir()
    if all((target / name).is_file() for name in TEMPLATES):
        print(f"Web templates for Godot {VERSION} are already installed in {target}.")
        return 0

    with tempfile.TemporaryDirectory() as temp:
        local = os.environ.get("GODOT_TEMPLATES_ARCHIVE")
        archive = Path(local) if local else Path(temp) / ARCHIVE
        if not archive.is_file():
            download(archive)
        digest = sha512_of(archive)
        if digest != SHA512:
            print(f"Checksum mismatch: expected {SHA512}, got {digest}.", file=sys.stderr)
            return 1

        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as tpz:
            (target / "version.txt").write_bytes(tpz.read("templates/version.txt"))
            for name in TEMPLATES:
                (target / name).write_bytes(tpz.read(f"templates/{name}"))

    print(f"Installed Godot {VERSION} web templates into {target}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
