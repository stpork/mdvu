"""Keep a fresh source checkout independent of local research/build artifacts."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


class RepositoryTests(unittest.TestCase):
    def test_no_local_artifacts_are_tracked(self):
        tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
        excluded = (".build/", ".swiftpm/", "target/", "dist/", "test-results/",
                    "tests/benchmarks/", "competitors/", "apps/", "results/")
        binaries = {".exe", ".dll", ".msi", ".dmg", ".zip", ".7z", ".pdb", ".profraw", ".profdata"}
        unexpected = [p for p in tracked if p and (p.startswith(excluded)
                      or ".app/" in p or Path(p).suffix.lower() in binaries)]
        self.assertEqual(unexpected, [], "Keep downloads, research and outputs under ignored test-results/")

    def test_documentation_local_links_exist(self):
        for doc in ROOT.glob("*.md"):
            links = re.findall(r'\]\(([^)]+)\)|(?:src|href)="([^"]+)"', doc.read_text())
            for markdown, html in links:
                target = urlsplit((markdown or html).strip('<>'))
                if target.scheme or target.netloc or not target.path:
                    continue
                with self.subTest(document=doc.name, target=target.path):
                    self.assertTrue((doc.parent / unquote(target.path)).exists())

    @unittest.skipUnless(shutil.which("sh") and shutil.which("bash"), "POSIX shell syntax checked on Linux/macOS")
    def test_shell_scripts_parse(self):
        for script in [ROOT / "build.sh", *ROOT.glob("scripts/*.sh")]:
            shell = "bash" if "bash" in script.read_text().splitlines()[0] else "sh"
            with self.subTest(script=script.name):
                subprocess.run([shell, "-n", str(script)], check=True, capture_output=True)

    @unittest.skipUnless(shutil.which("sh"), "POSIX driver checked on Linux/macOS")
    def test_check_driver_runs_core_and_visual_checks_from_other_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            temp = Path(directory)
            stub = temp / "make"
            stub.write_text('#!/bin/sh\nprintf "%s:%s\\n" "$PWD" "$*" >> "$MDVU_TEST_COMMANDS"\n')
            stub.chmod(0o755)
            log = temp / "commands"
            env = {**os.environ, "PATH": str(temp) + os.pathsep + os.environ["PATH"], "MDVU_TEST_COMMANDS": str(log)}
            subprocess.run(["sh", str(ROOT / "build.sh"), "check"], cwd=temp, env=env, check=True)
            self.assertEqual(log.read_text().splitlines(), [f"{ROOT}:check", f"{ROOT}:visual-test"])


if __name__ == "__main__":
    unittest.main()
