#!/usr/bin/env python3
"""Shared native CLI contract. Run against a packaged macOS binary or Windows exe."""
import json
import os
import pathlib
import signal
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
    def test_version_matches_release_metadata(self):
        version = (pathlib.Path(__file__).resolve().parents[1] / 'version.txt').read_text().strip()
        result = subprocess.run([BINARY, '--version'], cwd=self.root, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'mdvu ' + version)
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
        for mode in ('auto', 'automatic', ' AUTO '):
            with self.subTest(mode=mode):
                self.assertIn('href="Architecture%20Overview.md"', self.run_cli(
                    source, '--stdout', '--dialect', mode))
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
        self.run_cli('# Export Åя中文', '-o', str(output))
        self.assertIn('<h1>Export Åя中文</h1>', output.read_text(encoding='utf-8'))
    def test_missing_input_fails(self):
        result = subprocess.run([BINARY, str(self.root / 'missing.md'), '--stdout'], capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
    def test_benchmark_requires_input(self):
        result = subprocess.run([BINARY, '--benchmark'], input=b'', capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
    def test_benchmark_missing_file_fails(self):
        result = subprocess.run([BINARY, '--benchmark', str(self.root / 'missing.md')],
                                capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
    def test_benchmark_accepts_normal_input_position(self):
        self.assertIn('median', self.run_cli('# Benchmark', '--benchmark'))
    def test_closed_stdout_does_not_crash(self):
        source = self.root / 'pipe.md'
        source.write_text('# Pipe\n\n' + ('A paragraph.\n\n' * 20000))
        # Python ignores SIGPIPE, as some CI launchers do; preserve that inherited state.
        with subprocess.Popen([BINARY, str(source), '--stdout'], stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, restore_signals=False) as process:
            self.assertTrue(process.stdout.read(1))
            process.stdout.close()
            process.stdout = None
            _, diagnostic = process.communicate(timeout=30)
        self.assertNotEqual(process.returncode, 0)
        self.assertNotIn(b'NSFileHandleOperationException', diagnostic)
        self.assertNotIn(b'panicked', diagnostic)
        if sys.platform == 'darwin':
            self.assertEqual(process.returncode, -signal.SIGPIPE, diagnostic)
            self.assertEqual(diagnostic, b'')
    def test_supported_dialects(self):
        for dialect in ('generic', 'gfm', 'obsidian', 'mkdocs', 'docusaurus', 'commonmark', 'hugo'):
            with self.subTest(dialect=dialect):
                html = self.run_cli('[[Target]]', '--stdout', '--dialect', dialect)
                self.assertIn('Target.md' if dialect == 'obsidian' else '[[Target]]', html)
    @unittest.skipUnless(sys.platform == 'darwin', 'macOS native core loader')
    def test_core_override_does_not_fall_back_to_another_build(self):
        result = subprocess.run([BINARY, '-', '--stdout'], input=b'# Test', cwd=self.root,
                                env=dict(os.environ, MDVU_CORE_LIB=str(self.root/'missing.dylib')),
                                capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'mdvu-core', result.stderr)
    @unittest.skipUnless(sys.platform == 'darwin', 'macOS packaged command symlink')
    def test_packaged_command_symlink_finds_its_core(self):
        link = self.root/'mdvu'
        link.symlink_to(BINARY)
        result = subprocess.run([str(link), '-', '--stdout'], input=b'# Via symlink', cwd=self.root,
                                capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b'Via symlink', result.stdout)

unittest.main()
