#!/usr/bin/env python3
"""Shared native CLI contract. Run against a packaged macOS binary or Windows exe."""
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

BINARY = str(pathlib.Path(sys.argv.pop(1)).resolve())

class NativeCLI(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mdvu contract #")
        self.root = pathlib.Path(self.temp.name)
    def tearDown(self):
        self.temp.cleanup()
    def run_cli(self, content, *flags):
        path = self.root / "схема note.md"
        path.write_bytes(content.encode() if isinstance(content, str) else content)
        result = subprocess.run([BINARY, str(path), *flags], cwd=self.root, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        return result.stdout.decode("utf-8")
    def test_auto_dialect_and_explicit_override(self):
        source = "---\r\ndialect: obsidian\r\n---\r\n[[Architecture Overview]]"
        html = self.run_cli(source, "--stdout")
        self.assertIn('href="Architecture%20Overview.md"', html)
        self.assertIn('%23', html)
        self.assertIn('[[Architecture Overview]]', self.run_cli(source, "--stdout", "--dialect", "generic"))
    def test_nul_is_not_end_of_document(self):
        self.assertIn('After', self.run_cli(b'# Before\n\0\n# After', '--stdout'))
    def test_diagram_option_and_selective_standalone(self):
        source = '```mermaid\ngraph TD\nA-->B\n```'
        html = self.run_cli(source, '--stdout', '--standalone', '--no-mermaid')
        article = html.split('<article>')[1].split('</article>')[0]
        self.assertNotIn('diagram-pending', article)
        self.assertLess(len(html), 100_000)
        html = self.run_cli('$x^2$', '--stdout', '--standalone')
        self.assertGreater(len(html), 200_000)
        self.assertLess(len(html), 1_000_000)
        self.assertIn('Content-Security-Policy', html)
    def test_toc_json(self):
        toc = json.loads(self.run_cli('# foo -\n\n# foo\n\n# A {#custom}', '--toc'))
        self.assertEqual([item['id'] for item in toc], ['foo--', 'foo', 'custom'])
    def test_stdin_and_output(self):
        result = subprocess.run([BINARY, '-', '--stdout'], input=b'# stdin', capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'stdin', result.stdout)
        output = self.root / 'export.html'
        self.run_cli('# Export', '-o', str(output))
        self.assertIn('<h1>Export</h1>', output.read_text())
    def test_missing_input_fails(self):
        result = subprocess.run([BINARY, str(self.root / 'missing.md'), '--stdout'], capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)

unittest.main()
