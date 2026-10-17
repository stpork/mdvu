#!/usr/bin/env python3
"""Compare matching native UI fixture runs without treating CI timers as frames."""
import argparse
import csv
import json
import pathlib
import statistics

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('before', type=pathlib.Path, help='Before results.json')
parser.add_argument('after', type=pathlib.Path, help='After results.json from the same machine')
parser.add_argument('--output', type=pathlib.Path, required=True, help='CSV output')
args = parser.parse_args()


def load(path):
    report = json.loads(path.read_text(encoding='utf-8-sig'))
    if report.get('failures'):
        raise ValueError(f'System runner failures: {report["failures"]}')
    platform = 'macOS' if 'fixtures' in report else 'Windows'
    rows = report.get('fixtures', report.get('metrics', []))
    fixtures = {}
    for row in rows:
        name = row['fixture'].replace('\\', '/')
        if name in fixtures:
            raise ValueError(f'Duplicate fixture: {name}')
        ui = row.get('ui') or {}
        if not row.get('passed', True) or not ui.get('passed'):
            raise ValueError(f'Failed fixture: {name}')
        if ui.get('timingMode') != 'animation-frame':
            raise ValueError('Only native animation-frame results establish UI performance')
        perf = ui['performance']
        zoom = [c['ms'] for c in perf['controls'] if c['action'].startswith('zoom')]
        memory_key = 'physicalFootprintBytes' if platform == 'macOS' else 'privateBytes'
        memory = [s[memory_key] / 2**20 for s in row['samples'] if s.get(memory_key) is not None]
        fixtures[name] = {
            'documentReadyMs': row.get('phases', {}).get('webview.firstContent') if platform == 'macOS' else row.get('documentReady', {}).get('documentReadyMs'),
            **{key: perf[key] for key in ['renderFrameMaxMs', 'coldScrollMaxMs', 'coldZoomMaxMs', 'zoomRangeMaxMs', 'paneMaxMs', 'scrollFrameP95Ms', 'homeMs', 'endMs']},
            'zoomMedianMs': statistics.median(zoom),
            'zoomP95Ms': sorted(zoom)[int(len(zoom) * .95)],
            'fullscreenMaxMs': max((c['ms'] for c in perf['controls'] if c['action'] == 'fullscreen'), default=None),
            'peakMiB': max(memory) if memory else None,
            'tailMedianMiB': statistics.median(memory[-10:]) if memory else None,
        }
    if not fixtures:
        raise ValueError('No native fixture results')
    return platform, fixtures


platform, before = load(args.before)
after_platform, after = load(args.after)
if platform != after_platform or before.keys() != after.keys():
    raise ValueError('Platform and fixture sets must match')
args.output.parent.mkdir(parents=True, exist_ok=True)
with args.output.open('w', encoding='utf-8', newline='') as stream:
    writer = csv.writer(stream)
    writer.writerow(['platform', 'fixture', 'metric', 'before', 'after', 'changePercent'])
    for fixture in sorted(before):
        for metric, old in before[fixture].items():
            new = after[fixture][metric]
            change = (new / old - 1) * 100 if old and new is not None else None
            writer.writerow([platform, fixture, metric, old, new, change])
print(f'{platform}: {len(before)} matched fixtures; {args.output}')
for metric in next(iter(before.values())):
    old = [row[metric] for row in before.values() if row[metric] is not None]
    new = [row[metric] for row in after.values() if row[metric] is not None]
    if old and new:
        print(f'{metric}: maximum {max(old):.1f} -> {max(new):.1f}; median {statistics.median(old):.1f} -> {statistics.median(new):.1f}')
