#!/usr/bin/env python3
"""Print separate core, platform and Swift coverage; never hide unexecuted GUI code."""
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
report = root / 'target/coverage'
report.mkdir(parents=True, exist_ok=True)
lines = {'Rust core': [0, 0], 'Rust Windows frontend (host tests)': [0, 0]}
for record in (report / 'rust.lcov').read_text().split('end_of_record'):
    source = next((line[3:] for line in record.splitlines() if line.startswith('SF:')), '')
    group = 'Rust core' if '/src/core/src/' in source else 'Rust Windows frontend (host tests)' if '/src/windows/src/' in source else None
    if group:
        for line in record.splitlines():
            if line.startswith('DA:'):
                count = int(line.split(',')[1]); lines[group][1] += 1; lines[group][0] += count > 0
for name, (covered, total) in lines.items():
    print(f'{name}: {covered}/{total} executable lines ({covered / total:.2%})' if total else f'{name}: no data')
# SwiftPM exposes LLVM JSON on standard builders; Xcode-backed SwiftPM stores it in .build/out.
paths = ([report / 'swift.json'] if (report / 'swift.json').exists() else list((root / '.build').glob('**/codecov/*.json')))
for path in paths:
    payload = json.loads(path.read_text())
    covered = total = 0
    for file in payload.get('data', [{}])[0].get('files', []):
        if not pathlib.Path(file.get('filename', '')).is_relative_to(root / 'src/macos'): continue
        summary = file['summary']['lines']; covered += summary['covered']; total += summary['count']
    if total:
        print(f'Swift application: {covered}/{total} executable lines ({covered / total:.2%}) [{path}]')
        break
else:
    print('Swift JSON: unavailable; inspect the native Swift coverage artifacts in .build.')
