#!/usr/bin/env python3
"""Validate the complete release set before making a GitHub release public."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

PACKAGES = (
    "macos.dmg", "macos-arm64.zip", "macos-universal.zip",
    "macos-x86_64.zip", "windows-x86_64.msi", "windows-x86_64.zip",
)


def validate(directory, version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Expected a version such as 0.5.0")
    assets = []
    for suffix in PACKAGES:
        name = f"mdvu-{version}-{suffix}"
        path = directory / name
        checksum = directory / (name + ".sha256")
        if not path.is_file() or not checksum.is_file() or not path.stat().st_size:
            raise ValueError(f"Missing or empty release package/checksum: {name}")
        parts = checksum.read_text(encoding="utf-8-sig").split()
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if len(parts) != 2 or parts[1].lstrip("*") != name or parts[0].lower() != digest:
            raise ValueError(f"Invalid SHA-256 sidecar: {name}")
        assets.append({"name": name, "bytes": path.stat().st_size, "sha256": digest})
    return assets


def release_notes(path, version):
    match = re.search(r"^## \[" + re.escape(version) + r"\][^\n]*\n(.*?)(?=^## \[|\Z)",
                      path.read_text(), re.MULTILINE | re.DOTALL)
    if not match or not match[1].strip():
        raise ValueError(f"CHANGELOG.md has no release notes for {version}")
    return match[1].strip()


def prepare_latest_aliases(directory, version):
    """Copy validated packages to stable names; preserve every versioned file."""
    assets = validate(directory, version)
    files = []
    for suffix, asset in zip(PACKAGES, assets):
        name = f"mdvu-{suffix}"
        path = directory / name
        shutil.copyfile(directory / asset["name"], path)
        checksum = directory / (name + ".sha256")
        checksum.write_text(asset["sha256"] + "  " + name + "\n")
        files.extend((path, checksum))
    return files


def publish(directory, version, commit, repository, changelog):
    assets = validate(directory, version)
    notes = release_notes(changelog, version)
    tag = "v" + version
    gh = ["gh", "release"]
    repo_args = ["--repo", repository]
    existing = subprocess.run(gh + ["view", tag, "--json", "isDraft"] + repo_args,
                              capture_output=True, text=True)
    if existing.returncode == 0 and not json.loads(existing.stdout)["isDraft"]:
        raise ValueError(f"{tag} is already public; published assets must not be replaced")
    manifest = directory / "release-manifest.json"
    manifest.write_text(json.dumps({"version": version, "commit": commit, "packages": assets}, indent=2) + "\n")
    notes_path = directory / "release-notes.md"
    table = "\n\n### Downloads\n\n| Package | Format |\n| --- | --- |\n"
    labels = ("macOS installer · Universal", "Portable · Apple Silicon", "Portable · Universal",
              "Portable · Intel", "Windows installer · x64", "Portable · Windows x64")
    for asset, label in zip(assets, labels):
        url = f"https://github.com/{repository}/releases/download/{tag}/{asset['name']}"
        table += f"| [{asset['name']}]({url}) | {label} |\n"
    notes_path.write_text(notes + table + "\nSHA-256 sidecars accompany all six packages.\n")
    if existing.returncode:
        subprocess.run(gh + ["create", tag, "--draft", "--verify-tag",
                             "--title", f"mdvu {tag}", "--notes-file", str(notes_path)] + repo_args, check=True)
    else:
        subprocess.run(gh + ["edit", tag, "--notes-file", str(notes_path)] + repo_args, check=True)
    files = [directory / (a["name"] + suffix) for a in assets for suffix in ("", ".sha256")]
    files += prepare_latest_aliases(directory, version)
    files += [manifest] + [directory / name for name in ("mdvu.rb", "mdvu.json", "stpork.mdvu.yaml")
                           if (directory / name).is_file()]
    subprocess.run(gh + ["upload", tag, "--clobber", *map(str, files)] + repo_args, check=True)
    remote = json.loads(subprocess.check_output(gh + ["view", tag, "--json", "assets"] + repo_args, text=True))
    uploaded = {a["name"]: a for a in remote["assets"]}
    for path in files:
        item = uploaded.get(path.name)
        if not item or item["size"] != path.stat().st_size:
            raise ValueError(f"Incomplete upload: {path.name}; release remains a draft")
    subprocess.run(gh + ["edit", tag, "--draft=false", "--latest"] + repo_args, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("version")
    parser.add_argument("--publish", action="store_true")
    parser.add_argument("--commit")
    parser.add_argument("--repository", default="stpork/mdvu")
    parser.add_argument("--changelog", type=Path, default=Path("CHANGELOG.md"))
    args = parser.parse_args()
    if args.publish:
        if not args.commit or not re.fullmatch(r"[0-9a-f]{40}", args.commit):
            parser.error("--publish requires the exact 40-character --commit")
        publish(args.directory, args.version, args.commit, args.repository, args.changelog)
    else:
        print(json.dumps(validate(args.directory, args.version), indent=2))


if __name__ == "__main__":
    main()
