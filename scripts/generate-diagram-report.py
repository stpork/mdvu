#!/usr/bin/env python3
"""Summarize per-case native snapshots without treating audit completion as feature support."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('run', help='Directory produced by test-macos-system.py for isolated cases')
args = parser.parse_args()
run = (ROOT / args.run).resolve()
native = json.loads((run / 'results.json').read_text())
catalogue = json.loads((ROOT / 'tests/benchmarks/diagram-catalogue.json').read_text())
expected = {case['id']: case for case in catalogue.get('candidates',catalogue['cases'])}
if len(native['fixtures']) != len(expected):
    raise SystemExit(f"Incomplete run: {len(native['fixtures'])}/{len(expected)} cases")
if native['runtimeManifest'] != json.loads((ROOT / 'scripts/runtime-assets/manifest.json').read_text()):
    raise SystemExit('Runtime changed after the run')
if hashlib.sha256(Path(native['binary']).read_bytes()).hexdigest() != native['binarySha256']:
    raise SystemExit('Executable changed after the run')
core = Path(native['binary']).parent.parent/'Frameworks/libmdvu_core.dylib'
if hashlib.sha256(core.read_bytes()).hexdigest() != native['coreSha256']:
    raise SystemExit('Rust core changed after the run')
renderer = Path(native['binary']).parent.parent/'Resources/mdvu_mdvu.bundle/Contents/Resources/diagram-renderer.js'
if renderer.read_bytes() != (ROOT/'assets/diagram-renderer.js').read_bytes():
    raise SystemExit('Bundled diagram renderer differs from the current source')
reasons = {
    '@startditaa': 'Ditaa is not included in the bundled PlantUML JavaScript engine.',
    '@startchronology': 'The chronology diagram factory is not registered in the browser build.',
    '@startmath': 'The browser build has no PlantUML AsciiMath renderer. Ordinary MDVu LaTeX/math blocks use KaTeX separately.',
    '@startlatex': 'The browser build has no PlantUML JLaTeXMath renderer. Ordinary MDVu LaTeX/math blocks use KaTeX separately.',
    '@startchen': 'The Chen ER diagram factory is absent from the browser build.',
    '@startfiles': 'The files-tree diagram factory is absent from the browser build.',
    '@startboard': 'The board diagram factory is absent from the browser build.',
    '@startwire': 'The wire diagram factory is absent from the browser build.',
    '@startflow': 'The flow diagram factory is absent from the browser build.',
    '@starthcl': 'The HCL diagram factory is absent from the browser build.',
    '@startbpm': 'The BPM diagram factory is absent from the browser build.',
    '@startgit': 'The git diagram factory is absent from the browser build.',
}
results = []
svg_texts = []
for fixture in native['fixtures']:
    ident = Path(fixture['fixture']).stem
    if ident not in expected or not fixture['passed']:
        raise SystemExit(f'Incomplete native audit: {ident}')
    path = Path(native['fixtureRoot']) / fixture['fixture']
    if hashlib.sha256(path.read_bytes()).hexdigest() != fixture['fixtureSha256']:
        raise SystemExit(f'Fixture changed: {ident}')
    ui_cases = fixture['ui']['cases']
    if len(ui_cases) != 1 or ui_cases[0]['id'] != ident:
        raise SystemExit(f'Wrong native document: {ident}')
    result = ui_cases[0]
    metadata = expected[ident]
    lines = path.read_text().splitlines(keepends=True)
    opening = next(i for i,line in enumerate(lines) if line.startswith(('```','~~~')))
    closing = len(lines)-1
    while not lines[closing].strip(): closing -= 1
    if hashlib.sha256(''.join(lines[opening+1:closing]).encode()).hexdigest() != metadata['sha256']:
        raise SystemExit(f'Case differs from the main catalogue: {ident}')
    status = result['status']
    reason = ''
    svg_hash = None
    if status == 'rendered':
        svg_path = run / (ident + '-cache') / (result['cacheKey'] + '.svg')
        svg = svg_path.read_bytes()
        node = ET.fromstring(svg)
        visible = {'text','path','rect','circle','ellipse','line','polygon','polyline','image','foreignObject'}
        if node.tag.rsplit('}',1)[-1] != 'svg' or not any(child.tag.rsplit('}',1)[-1] in visible for child in node.iter()):
            raise SystemExit(f'Empty or invalid SVG: {ident}')
        svg_texts.append({'id':ident,'renderer':result['renderer'],'text':' '.join(node.itertext())})
        svg_hash = hashlib.sha256(svg).hexdigest()
    elif status == 'error':
        reason = reasons.get(metadata['kind'], '')
        if ident == 'D098': reason = 'Service command help types: the browser build does not register HelpFactory. This is not a diagram family.'
        if ident == 'D099': reason = 'Service command listsprites: the browser build does not register ListSpriteDiagramFactory. This is not a diagram family.'
        if not reason: reason = result.get('error','Unknown rendering error')
    else:
        raise SystemExit(f'Needs investigation ({status}): {ident}')
    screenshot = Path(fixture['screenshot'])
    results.append({'id':ident,'language':metadata['language'],'kind':metadata['kind'],'heading':metadata['heading'],
                    'sourceSha256':metadata['sha256'],'status':status,'reason':reason,
                    'screenshot':screenshot.relative_to(ROOT).as_posix(),'screenshotSha256':hashlib.sha256(screenshot.read_bytes()).hexdigest(),
                    'svgSha256':svg_hash, **({'diagnostic':result.get('error','')} if status == 'error' else {})})
# Recheck actual SVG content independently of the browser audit's status.
check = subprocess.run(['node','-e',
    "const fs=require('fs'),classify=require(process.argv[1]);"
    "const cases=JSON.parse(fs.readFileSync(0,'utf8'));"
    "process.stdout.write(JSON.stringify(cases.filter(c=>classify(c.renderer,c.text)).map(c=>c.id)));",
    str(ROOT/'assets/diagram-output.js')],input=json.dumps(svg_texts),capture_output=True,text=True,check=True,timeout=30)
if json.loads(check.stdout):
    raise SystemExit('Diagnostic SVG counted as a diagram: '+check.stdout)
results.sort(key=lambda result:result['id'])
report = {'schema':1,'verifiedAt':'2026-10-18','scope':'One fresh native MDVu process and cold diagram cache per numbered case; DOM status, SVG structure and native screenshot retained. Not a speed benchmark.',
          'binarySha256':native['binarySha256'],'coreSha256':native['coreSha256'],'macOS':native['macOS'],'machine':native['machine'],
          'runtimeManifestSha256':hashlib.sha256((ROOT/'scripts/runtime-assets/manifest.json').read_bytes()).hexdigest(),
          'rendererSourceSha256':hashlib.sha256(renderer.read_bytes()).hexdigest(),
          'parserSourceSha256':hashlib.sha256((ROOT/'src/core/src/parser.rs').read_bytes()).hexdigest(),
          'summary':{status:sum(result['status']==status for result in results) for status in ['rendered','error','source','unresolved']},'cases':results}
output = ROOT/'tests/benchmarks/mdvu-diagram-validation.json'
output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report['summary']))
