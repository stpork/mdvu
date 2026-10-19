"""Verify that shipped offline runtimes match the reviewed dependency manifest."""
import hashlib
import json
import lzma
import subprocess
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent


class RendererAssetsTests(unittest.TestCase):
    def test_svg_diagnostics_and_shared_dot_adapter(self):
        result = subprocess.run(['node', '--test', 'tests/ui/diagram-output.test.cjs',
                                 'tests/ui/plantuml-adapter.test.mjs',
                                 'tests/ui/windows-find.test.cjs',
                                 'tests/ui/windows-links.test.cjs'], cwd=ROOT,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_compressed_assets_match_locked_manifest(self):
        manifest = json.loads((ROOT / 'scripts/runtime-assets/manifest.json').read_text())
        packages = json.loads((ROOT / 'scripts/runtime-assets/package.json').read_text())['dependencies']
        lock = json.loads((ROOT / 'scripts/runtime-assets/package-lock.json').read_text())['packages']
        self.assertEqual(packages, manifest['packages'])
        stdlib = json.loads((ROOT / 'scripts/runtime-assets/stdlib-lock.json').read_text())
        self.assertEqual(stdlib, manifest['stdlib'])
        self.assertEqual(set(stdlib), {'c4', 'archimate'})
        for name, version in packages.items():
            self.assertEqual(lock['node_modules/' + name]['version'], version)
        for name, expected in manifest['assets'].items():
            with self.subTest(asset=name):
                compressed = (ROOT / 'assets' / (name + '.lzma')).read_bytes()
                self.assertEqual(len(compressed), expected['compressedBytes'])
                self.assertEqual(hashlib.sha256(compressed).hexdigest(), expected['sha256'])
                self.assertEqual(compressed[:5], bytes.fromhex('5d00000004'))
                source = lzma.decompress(compressed)
                self.assertEqual(len(source), expected['sourceBytes'])
                self.assertNotIn(b'\x00', source)


if __name__ == '__main__':
    unittest.main()
