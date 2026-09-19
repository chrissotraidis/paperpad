#!/usr/bin/env python3
"""Verify the exact preserved ReCut contents and modes without modifying source."""
import hashlib
import json
from pathlib import Path
import stat

root = Path(__file__).resolve().parents[1]
source = root / "vendor/paper-mario-recut"
manifest = json.loads((root / "docs/source-maintenance/prepared-recut.json").read_text())
exceptions = json.loads((root / "docs/source-maintenance/path-exceptions.json").read_text())
manifest.update({name: {k: value[k] for k in ("sha256", "mode")} for name, value in exceptions.items()})
for name, expected in manifest.items():
    path = source / name
    if not path.is_file() or path.is_symlink():
        raise SystemExit(f"Missing or unexpected source file: {name}")
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected["sha256"]:
        raise SystemExit(f"Prepared source content mismatch: {name}")
    if stat.S_IMODE(path.stat().st_mode) != expected["mode"]:
        raise SystemExit(f"Prepared source mode mismatch: {name}")
print(f"Verified {len(manifest)} prepared ReCut files and modes.")
