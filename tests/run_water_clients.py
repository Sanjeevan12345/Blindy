"""Three real role clients: rendered 1080p benchmark or machinery traversal."""
import argparse
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--benchmark', action='store_true')
parser.add_argument('--port', type=int, default=28840)
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
logs = project / '.godot' / 'water-network' / str(args.port)
logs.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(project / '.godot' / 'test-user')
processes = []
try:
    for role, flags in [('head', ['--host', '--autostart']), ('hands', ['--join=127.0.0.1']), ('wheel', ['--join=127.0.0.1'])]:
        file = (logs / (role+'.log')).open('w')
        script = 'water_performance' if args.benchmark else 'network_water_traversal'
        command = [args.godot, *([] if args.benchmark else ['--headless']), '--path', str(project), '--script', f'res://tests/{script}.gd', '--', *flags, f'--port={args.port}', '--no-save']
        process = subprocess.Popen(command, env=env, stdout=file, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        processes.append((role, process, file))
        time.sleep(2)
    deadline = time.monotonic()+180
    while any(p.poll() is None for _, p, _ in processes):
        if time.monotonic()>deadline: raise TimeoutError(str(logs))
        time.sleep(.5)
    failed = False
    for role, process, file in processes:
        file.close()
        log = (logs / (role+'.log')).read_text(errors='replace')
        passed = process.returncode==0 and 'NETWORK PASS' in log and 'ERROR:' not in log
        print(('PASS' if passed else 'FAIL')+': '+role)
        print(log[-800:])
        failed |= not passed
    raise SystemExit(int(failed))
finally:
    for _, process, file in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        file.close()
