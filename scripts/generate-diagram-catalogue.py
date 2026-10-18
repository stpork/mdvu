#!/usr/bin/env python3
"""Collect comparison cases and explicitly recorded syntax corrections into one document."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = [f"tests/fixtures/test-{name}.md" for name in
            ("light", "medium", "complete", "heavy", "onescreen")]
LANGUAGES = {"mermaid", "plantuml", "puml", "zenuml"}
NEGATIVE_KINDS = {"notARealDiagram", "futureDiagram-beta"}
DOCUMENT = ROOT / "tests/fixtures/test-diagrams.md"
MANIFEST = ROOT / "tests/benchmarks/diagram-catalogue.json"
REGISTRY = ROOT / "tests/benchmarks/diagram-registry.json"


def blocks(source):
    lines = (ROOT / source).read_text().splitlines(keepends=True)
    index, heading = 0, ""
    while index < len(lines):
        line = lines[index]
        opening = re.fullmatch(r" {0,3}(`{3,}|~{3,})([^\n]*)\n?", line)
        if not opening:
            if re.match(r"^#{1,6} ", line):
                heading = line.lstrip("# ").strip()
            index += 1
            continue
        fence, info = opening.groups()
        language = info.strip().split()[0] if info.strip() else ""
        start = index
        index += 1
        closing = re.compile(r" {0,3}" + re.escape(fence[0]) +
                             "{" + str(len(fence)) + r",}\s*")
        while index < len(lines) and not closing.fullmatch(lines[index]):
            index += 1
        if index == len(lines):
            raise ValueError(f"Unclosed fence: {source}:{start + 1}")
        body = "".join(lines[start + 1:index])
        index += 1
        if language not in LANGUAGES:
            continue
        declaration = body.strip()
        if declaration.startswith("---\n"):
            declaration = declaration.split("\n---", 1)[1].lstrip()
        meaningful = [line.strip() for line in declaration.splitlines()
                      if line.strip() and not line.strip().startswith(("%%", "'"))]
        kind = meaningful[0].split()[0] if meaningful else "empty"
        yield dict(language=language, kind=kind, heading=heading, source=source,
                   sourceLine=start + 1, sha256=hashlib.sha256(body.encode()).hexdigest(),
                   body=body, fence=fence)


def signature(case):
    return case["language"], "standalone" if case["language"] == "zenuml" else case["kind"]


def generate():
    inventory = [case for source in FIXTURES for case in blocks(source)]
    previous = json.loads((ROOT / "tests/benchmarks/diagram-compatibility.json").read_text())
    cases = []
    for reference in previous["cases"]:
        case = next((case for case in inventory if
                     (case["source"], case["sourceLine"], case["sha256"]) ==
                     (reference["source"], reference["sourceLine"], reference["sha256"])), None)
        if case is None:
            raise ValueError(f"Source changed: {reference['id']}; review the original comparison case")
        cases.append(dict(case, id=reference["id"]))
    seen = {signature(case) for case in cases}
    for case in inventory:
        if case["kind"] in NEGATIVE_KINDS or signature(case) in seen:
            continue
        cases.append(dict(case, id=f"D{len(cases) + 1:03d}"))
        seen.add(signature(case))
    registry = json.loads(REGISTRY.read_text())
    for case in cases:
        correction = registry.get('fixtureCorrections',{}).get(case['id'])
        if correction:
            case['originalSourceSha256'] = case['sha256']
            case['body'] = correction['body']
            case['sha256'] = hashlib.sha256(case['body'].encode()).hexdigest()
            case['fixtureCorrection'] = correction['reason']
    for reference in registry['additionalCases']:
        assert reference['id'] == f'D{len(cases) + 1:03d}'
        cases.append(dict(reference, fence='```',
                          sha256=hashlib.sha256(reference['body'].encode()).hexdigest()))
    ids = {case['id'] for case in cases}
    for entry in registry['entries']:
        if not entry['caseIds'] and not entry.get('reason'):
            raise ValueError(f"Unaccounted upstream entry: {entry['engine']}/{entry['id']}")
        if not set(entry['caseIds']) <= ids:
            raise ValueError(f"Unknown case in registry: {entry['id']}")
    candidates = [{key:value for key,value in case.items() if key not in {'body','fence'}} for case in cases]
    validation = json.loads((ROOT/'tests/benchmarks/mdvu-diagram-validation.json').read_text())
    verified = {case['id']:case for case in validation['cases']}
    if (len(verified) != len(cases)
        or any(verified.get(case['id'],{}).get('sourceSha256') != case['sha256'] for case in cases)
        or validation['runtimeManifestSha256'] != hashlib.sha256((ROOT/'scripts/runtime-assets/manifest.json').read_bytes()).hexdigest()
        or validation.get('rendererSourceSha256') != hashlib.sha256((ROOT/'assets/diagram-renderer.js').read_bytes()).hexdigest()
        or validation['parserSourceSha256'] != hashlib.sha256((ROOT/'src/core/src/parser.rs').read_bytes()).hexdigest()):
        raise ValueError('Native diagram verification is stale; recheck candidates before changing the supported catalogue')
    selection = registry['comparisonSelection']
    excluded = []
    selected = []
    for case in cases:
        result = verified[case['id']]
        if result['status'] != 'rendered':
            excluded.append(dict(id=case['id'],category='unsupported',reason=result['reason']))
        elif case['id'] in selection['duplicates']:
            excluded.append(dict(id=case['id'],category='duplicate',canonical=selection['duplicates'][case['id']]))
        elif case['id'] in selection['utilities']:
            excluded.append(dict(id=case['id'],category='utility',reason='Runtime information or text formatting, not a diagram family'))
        else:
            selected.append(case)
    cases = selected
    for case in cases:
        correction = registry.get('comparisonCorrections',{}).get(case['id'])
        if correction:
            case['originalSourceSha256'] = case['sha256']
            case['body'] = correction['body']
            case['sha256'] = hashlib.sha256(case['body'].encode()).hexdigest()
            case['fixtureCorrection'] = correction['reason']
    if not set(selection['duplicates'].values()) <= {case['id'] for case in cases}:
        raise ValueError('Duplicate points to an excluded canonical case')
    parts = ['# Supported diagram catalogue\n\n',
             f'{len(cases)} diagram grammar/view examples, verified in native MDVu on 2026-10-18. '
             'One example per engine and distinct grammar or library view. '
             'Mermaid and PlantUML are separate source languages. '
             'Aliases, repeated feature probes, utility commands and unsupported cases are excluded. '
             'Stable case IDs retain gaps for traceability.\n\n',
             'Mermaid 12.2.0 · ZenUML plugin 1.0.1 · PlantUML Core 1.2026.9 · '
             'C4-PlantUML 2.14.0 · ArchiMate 3.2.2.\n\n']
    metadata = []
    for case in cases:
        engine = 'Mermaid' if case['language'] in {'mermaid','zenuml'} else 'PlantUML'
        label = case['kind'] if engine == 'Mermaid' else re.sub(r'^\d+(?:\.\d+)*\s+', '', case['heading'])
        parts.append(f"## {case['id']} — {engine} / {label}\n\n")
        parts.append(f"{case['fence']}{case['language']}\n{case['body']}{case['fence']}\n\n")
        metadata.append({key: value for key, value in case.items() if key not in {"body", "fence"}})
    document = "".join(parts)
    manifest = dict(schema=3, document=DOCUMENT.relative_to(ROOT).as_posix(),
                    documentSha256=hashlib.sha256(document.encode()).hexdigest(),
                    registrySha256=hashlib.sha256(REGISTRY.read_bytes()).hexdigest(),
                    inputs={source: hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
                            for source in FIXTURES}, cases=metadata, candidates=candidates, excluded=excluded, selectionRule=selection['rule'])
    return document, json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify generated files and source hashes")
    parser.add_argument('--case-dir', help='Also export one Markdown document per case for isolated native rendering')
    args = parser.parse_args()
    if args.check and args.case_dir:
        parser.error('--case-dir writes files and cannot be combined with --check')
    document, manifest = generate()
    for path, content in [(DOCUMENT, document), (MANIFEST, manifest)]:
        if args.check:
            if not path.exists() or path.read_text() != content:
                raise SystemExit(f"Out of date: {path.relative_to(ROOT)}")
        else:
            path.write_text(content)
    if args.case_dir:
        directory = (ROOT / args.case_dir).resolve()
        directory.mkdir(parents=True, exist_ok=True)
        for case in blocks(DOCUMENT.relative_to(ROOT)):
            ident = case['heading'].split()[0]
            (directory / (ident + '.md')).write_text(
                f"## {case['heading']}\n\n{case['fence']}{case['language']}\n{case['body']}{case['fence']}\n")
    print(f"{'Checked' if args.check else 'Generated'} {len(json.loads(manifest)['cases'])} cases")
