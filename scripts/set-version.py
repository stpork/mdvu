#!/usr/bin/env python3
"""Update the release, native bundle and Rust package versions together."""
import argparse
from pathlib import Path
import plistlib
import re


def set_version(root, version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a version such as 0.5.0")
    updates = {root / "version.txt": version + "\n"}
    for name in ("core", "windows"):
        path = root / "src" / name / "Cargo.toml"
        content, count = re.subn(r'^version = "[^"]+"$', f'version = "{version}"',
                                 path.read_text(), count=1, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f"Missing package version: {path}")
        updates[path] = content
    path = root / "Cargo.lock"
    content, count = re.subn(r'(\[\[package\]\]\nname = "mdvu-(?:core|windows)"\nversion = ")[^"]+("\n)',
                             lambda match: match[1] + version + match[2], path.read_text())
    if count != 2:
        raise ValueError("Cargo.lock must contain both MDVu packages")
    updates[path] = content
    path = root / "packaging/macos/Info.plist"
    info = plistlib.loads(path.read_bytes())
    info["CFBundleShortVersionString"] = version
    updates[path] = plistlib.dumps(info, sort_keys=False).decode()
    # Read and validate every input before changing any file.
    for path, content in updates.items():
        path.write_text(content)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    args = parser.parse_args()
    set_version(Path(__file__).resolve().parent.parent, args.version)
