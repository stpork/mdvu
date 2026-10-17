#!/usr/bin/env python3
"""Run the native macOS UI on every Markdown fixture; retain checks, profiles and screenshots."""
import argparse, csv, ctypes, hashlib, json, os, pathlib, platform, re, shutil, subprocess, time
root = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('binary', nargs='?', default='dist/mdvu.app/Contents/MacOS/mdvu')
parser.add_argument('--output', default='test-results/macos')
parser.add_argument('--fixture', help='Optional fixture path relative to tests/fixtures')
parser.add_argument('--fail-fast', action='store_true', help='Run the largest fixture first and stop on failure')
parser.add_argument('--timer-only', action='store_true', help='CI correctness checks without animation-frame performance claims')
args = parser.parse_args()
os.chdir(root)
output = pathlib.Path(args.output).resolve(); output.mkdir(parents=True, exist_ok=True)
binary = pathlib.Path(args.binary).resolve()
fixtures = [root/'tests/fixtures'/args.fixture] if args.fixture else sorted((root/'tests/fixtures').rglob('*.md'))
if args.fail_fast: fixtures.sort(key=lambda path: -path.stat().st_size)
class RUsage(ctypes.Structure):
    _fields_ = [('uuid',ctypes.c_uint8*16)] + [(name,ctypes.c_uint64) for name in ('user','system','idle','interrupt','pageins','wired','resident','footprint','start','exit','childUser','childSystem','childIdle','childInterrupt','childPageins','childElapsed','diskRead','diskWrite')]
libproc=ctypes.CDLL('/usr/lib/libproc.dylib')
libproc.proc_pid_rusage.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
def footprint(pid):
    usage=RUsage()
    return usage.footprint if libproc.proc_pid_rusage(pid,2,ctypes.byref(usage))==0 else None
def processes():
    data = subprocess.check_output(['/bin/ps','-axo','pid=,ppid=,rss=,time=,comm='], text=True)
    result = {}
    for line in data.splitlines():
        fields = line.strip().split(None,4)
        if len(fields) != 5: continue
        pid, parent, rss, cpu, command = fields
        seconds = 0.0
        for part in cpu.split(':'): seconds = seconds*60+float(part)
        result[int(pid)] = {'parent':int(parent),'rssBytes':int(rss)*1024,'cpuMs':seconds*1000,'command':command}
    return result
expected_errors=json.loads((root/'tests/ui/expected-diagram-errors.json').read_text())
ui_source=(root/'tests/ui/check-controls.js').read_text()+'\n'+(root/'tests/ui/check-fixture.js').read_text()
if args.timer_only:
    ui_source="window.__mdvuTimingMode='timer';window.requestAnimationFrame=callback=>setTimeout(()=>callback(performance.now()),16);\n"+ui_source
results = {'binary':str(binary),'binarySha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'macOS':platform.mac_ver()[0],'machine':platform.machine(),'fixtures':[], 'memoryNote':'App RSS is sampled directly. WebKit RSS includes only processes newly created during this isolated fixture run; XPC services may have parent PID 1. Shared pages can be counted more than once.'}
for fixture in fixtures:
    name = fixture.relative_to(root/'tests/fixtures').as_posix()
    stem = name[:-3].replace('/','__')
    image, diagnostic = output/(stem+'.png'), output/(stem+'-ui.json')
    for path in [image,diagnostic]: path.unlink(missing_ok=True)
    check_script=output/(stem+'-check.js')
    check_script.write_text('window.__mdvuAuditIdleProbe='+json.dumps(name=='test-heavy.md')+';window.__mdvuExpectedDiagramErrors='+json.dumps(expected_errors.get(name,[]),ensure_ascii=False)+';\n'+ui_source)
    before = set(processes()); start = time.perf_counter()
    cache = output/(stem+'-cache')
    if cache.exists(): shutil.rmtree(cache)
    env = dict(os.environ, MDVU_PROFILE='1', MDVU_CACHE_DIR=str(cache), MDVU_UI_SCRIPT=str(check_script), MDVU_UI_RESULT_FILE=str(diagnostic))
    samples = []
    with (output/(stem+'-stderr.log')).open('w') as log:
        process = subprocess.Popen([str(binary),'--theme','light','--snapshot',str(image),str(fixture)], stdout=log, stderr=log, env=env)
        while process.poll() is None and time.perf_counter()-start < 180:
            all_processes = processes(); own = all_processes.get(process.pid,{})
            webkit = {pid: info for pid,info in all_processes.items() if pid not in before and 'com.apple.WebKit.' in info['command']}
            physical=[footprint(pid) for pid in [process.pid,*webkit]]
            samples.append({'elapsedMs':(time.perf_counter()-start)*1000,'appRssBytes':own.get('rssBytes',0),'appCpuMs':own.get('cpuMs',0),'webkitRssBytes':sum(p['rssBytes'] for p in webkit.values()),'webkitCpuMs':sum(p['cpuMs'] for p in webkit.values()),'webkitProcesses':len(webkit),'physicalFootprintBytes':sum(physical) if all(p is not None for p in physical) else None,'processMemory':{pid:{'rssBytes':p['rssBytes'],'physicalFootprintBytes':physical[i+1]} for i,(pid,p) in enumerate(webkit.items())}})
            time.sleep(.25)
        if process.poll() is None:
            for pid in [process.pid,*webkit]:
                try: subprocess.run(['/usr/bin/sample',str(pid),'1','-file',str(output/(stem+f'-timeout-{pid}.txt'))],stdout=log,stderr=log,timeout=10)
                except subprocess.TimeoutExpired: pass
            process.kill(); process.wait()
    ui = json.loads(diagnostic.read_text()) if diagnostic.exists() else None
    profile = (output/(stem+'-stderr.log')).read_text()
    phases = {name:float(value) for name,value in re.findall(r'mdvu.profile\s+(\S+)\s+[\d.]+ ms\s+total\s+([\d.]+) ms',profile)}
    result = {'fixture':name,'bytes':fixture.stat().st_size,'exit':process.returncode,'elapsedMs':(time.perf_counter()-start)*1000,'phases':phases,'ui':ui,'screenshot':str(image) if image.exists() else None,'samples':samples,'passed':process.returncode==0 and image.exists() and bool(ui and ui.get('passed'))}
    results['fixtures'].append(result)
    (output/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    if samples:
        with (output/(stem+'-processes.csv')).open('w') as f:
            writer=csv.DictWriter(f,fieldnames=samples[0]);writer.writeheader();writer.writerows(samples)
    print(f"{name}: {'PASS' if result['passed'] else 'FAIL'}; {result['elapsedMs']:.0f} ms",flush=True)
    if not result['passed']: print(profile[-12000:],flush=True)
    if args.fail_fast and not result['passed']: break
raise SystemExit(0 if all(item['passed'] for item in results['fixtures']) else 1)
