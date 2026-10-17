#!/usr/bin/env python3
"""Rebuild the shared offline engines from locked npm packages (Node 22+, Python 3)."""
import hashlib
import json
import lzma
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / 'scripts/runtime-assets'
BUILD = ROOT / 'target/runtime-assets'
BUILD.mkdir(parents=True, exist_ok=True)
for name in ('package.json', 'package-lock.json'):
    shutil.copyfile(LOCK / name, BUILD / name)
subprocess.run(['npm', 'ci', '--prefix', str(BUILD), '--ignore-scripts', '--no-audit', '--no-fund'], check=True)
modules = BUILD / 'node_modules'
esbuild = ['node', str(modules / 'esbuild/bin/esbuild')]

def bundle(entry, output, *options):
    subprocess.run(esbuild + [str(entry), '--bundle', '--format=iife', '--platform=browser',
                             '--target=es2022', '--minify', '--outfile=' + str(output), *options], check=True)
    return output.read_bytes()

entry = BUILD / 'mermaid-entry.mjs'
entry.write_text("import mermaid from 'mermaid';\nimport zenuml from '@mermaid-js/mermaid-zenuml';\n"
                 "globalThis.mermaid=mermaid;globalThis['mermaid-zenuml']=zenuml;\n")
mermaid = bundle(entry, BUILD / 'mermaid.js')
entry = BUILD / 'plantuml-entry.mjs'
entry.write_text("import * as Viz from '@viz-js/viz';\nimport * as PlantUML from '@plantuml/core';\n"
                 "globalThis.PLANTUML_VIZ=Viz;globalThis.PlantUML=PlantUML;\n")
# Viz embeds its WASM. A fixed module URL also works in standalone about:blank
# documents; it is an identifier, never a network dependency.
plantuml = bundle(entry, BUILD / 'plantuml.js',
                  '--define:import.meta.url="https://mdvu-runtime.invalid/viz.js"')
katex = (modules / 'katex/dist/katex.min.js').read_bytes()
manifest = {'compression': 'LZMA1 / .lzma, preset 9 extreme (64 MiB dictionary)', 'packages': {}, 'assets': {}}
for name in json.loads((BUILD / 'package.json').read_text())['dependencies']:
    package = json.loads((modules / name / 'package.json').read_text())
    manifest['packages'][name] = package['version']
for name, source in [('mermaid', mermaid), ('plantuml', plantuml), ('katex', katex)]:
    compressed = lzma.compress(source, format=lzma.FORMAT_ALONE, preset=9 | lzma.PRESET_EXTREME)
    assert lzma.decompress(compressed) == source
    (ROOT / 'assets' / (name + '.lzma')).write_bytes(compressed)
    manifest['assets'][name] = {'sourceBytes': len(source), 'compressedBytes': len(compressed),
                              'sha256': hashlib.sha256(compressed).hexdigest()}
    print(f'{name}: {len(source):,} -> {len(compressed):,} bytes', flush=True)
(LOCK / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
