#!/usr/bin/env python3
"""Regenerate literal-find classes from pinned Unicode simple case folding."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from urllib.request import urlopen

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--data', type=Path, help='Local CaseFolding-17.0.0.txt; otherwise download it')
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
data = args.data.read_bytes() if args.data else urlopen('https://www.unicode.org/Public/17.0.0/ucd/CaseFolding.txt', timeout=30).read()
if hashlib.sha256(data).hexdigest() != 'ff8d8fefbf123574205085d6714c36149eb946d717a0c585c27f0f4ef58c4183':
    raise SystemExit('Unexpected Unicode input; review the version and checksum before updating')
parents = {}

def find(point):
    while parents.setdefault(point, point) != point:
        point = parents[point]
    return point

for line in data.decode().splitlines():
    line = line.split('#')[0].strip()
    if not line:
        continue
    source, status, target, *_ = line.split(';')
    if status.strip() in ('C', 'S'):
        parents[find(int(source, 16))] = find(int(target.strip(), 16))
groups = {}
for point in parents:
    groups.setdefault(find(point), []).append(point)
classes = ' ' + ' '.join(''.join(map(chr, sorted(group))) for group in sorted(groups.values(), key=min)) + ' '
path = Path(__file__).resolve().parents[1] / 'assets/app.js'
before = path.read_text(encoding='utf-8')
notice = '/* Unicode case folding license (generated)\n' + Path(__file__).with_name('unicode-LICENSE.txt').read_text(encoding='utf-8') + '*/'
after, count = re.subn(r'/\* Unicode case folding license \(generated\)\n.*?\*/', lambda _: notice, before, flags=re.DOTALL)
if count != 1:
    raise SystemExit('Expected one generated Unicode license notice')
after, count = re.subn(r'^const findCaseClasses=.*;$', lambda _: 'const findCaseClasses=' + json.dumps(classes, ensure_ascii=False) + ';', after, flags=re.MULTILINE)
if count != 1:
    raise SystemExit('Expected one generated findCaseClasses constant')
if args.check:
    if after != before:
        raise SystemExit('Generated case-folding classes are out of date')
else:
    path.write_text(after, encoding='utf-8', newline='\n')
print(f'Unicode 17.0.0: {len(groups)} classes, {len(classes.encode())} UTF-8 bytes')
