import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("release_assets", Path(__file__).parents[1] / "scripts/release-assets.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseAssetsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for suffix in release.PACKAGES:
            name = "mdvu-0.5.0-" + suffix
            data = name.encode()
            (self.root / name).write_bytes(data)
            (self.root / (name + ".sha256")).write_text(hashlib.sha256(data).hexdigest() + "  " + name + "\n")
        self.changelog = self.root / "CHANGELOG.md"
        self.changelog.write_text("## [0.5.0]\n\nTest release.\n\n## [0.4.1]\n\nOld release.\n")

    def test_requires_all_six_formats(self):
        self.assertEqual(len(release.validate(self.root, "0.5.0")), 6)
        (self.root / "mdvu-0.5.0-windows-x86_64.msi").unlink()
        with self.assertRaisesRegex(ValueError, "Missing"):
            release.validate(self.root, "0.5.0")

    def test_rejects_corruption_and_wrong_sidecar_filename(self):
        path = self.root / "mdvu-0.5.0-macos.dmg"
        original = path.read_bytes()
        path.write_bytes(b"corrupt")
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            release.validate(self.root, "0.5.0")
        path.write_bytes(original)
        path.with_name(path.name + ".sha256").write_text(hashlib.sha256(original).hexdigest() + "  wrong.dmg")
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            release.validate(self.root, "0.5.0")

    def test_missing_package_never_creates_a_release(self):
        (self.root / "mdvu-0.5.0-windows-x86_64.zip.sha256").unlink()
        with patch.object(release.subprocess, "run") as run:
            with self.assertRaises(ValueError):
                release.publish(self.root, "0.5.0", "a" * 40, "owner/repo", self.changelog)
            run.assert_not_called()

    def test_incomplete_upload_stays_draft(self):
        with patch.object(release.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "")) as run, \
             patch.object(release.subprocess, "check_output", return_value=json.dumps({"assets": []})):
            with self.assertRaisesRegex(ValueError, "Incomplete upload"):
                release.publish(self.root, "0.5.0", "a" * 40, "owner/repo", self.changelog)
            self.assertTrue(any("--draft" in call.args[0] for call in run.call_args_list))
            self.assertFalse(any("--draft=false" in call.args[0] for call in run.call_args_list))

    def test_publishes_only_after_all_uploads_are_verified(self):
        def uploaded(*args, **kwargs):
            return json.dumps({"assets": [{"name": p.name, "size": p.stat().st_size}
                                         for p in self.root.iterdir()]})
        result = subprocess.CompletedProcess([], 0, '{"isDraft": true}')
        with patch.object(release.subprocess, "run", return_value=result) as run, \
             patch.object(release.subprocess, "check_output", side_effect=uploaded):
            release.publish(self.root, "0.5.0", "a" * 40, "owner/repo", self.changelog)
            commands = [call.args[0] for call in run.call_args_list]
            upload = next(c for c in commands if c[2] == "upload")
            self.assertEqual(sum("mdvu-0.5.0-" in value for value in upload), 12)
            self.assertIn("--draft=false", commands[-1])
            self.assertEqual(commands[-1][-2:], ["--repo", "owner/repo"])
            manifest = json.loads((self.root / "release-manifest.json").read_text())
            self.assertEqual(manifest["commit"], "a" * 40)
            self.assertEqual(len(manifest["packages"]), 6)

    def test_public_release_is_immutable(self):
        result = subprocess.CompletedProcess([], 0, '{"isDraft": false}')
        with patch.object(release.subprocess, "run", return_value=result) as run:
            with self.assertRaisesRegex(ValueError, "already public"):
                release.publish(self.root, "0.5.0", "a" * 40, "owner/repo", self.changelog)
            self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
