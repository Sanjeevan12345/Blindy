"""Run the complete level using three real Godot processes over localhost UDP."""
import argparse
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True, help="Path to the Godot console executable")
parser.add_argument("--port", type=int, default=28767)
parser.add_argument("--graphical", action="store_true", help="Open three rendered game windows")
parser.add_argument("--boot-only", action="store_true", help="Short graphical input/session check through Boot Bay")
parser.add_argument("--finish-only", action="store_true", help="Short reliable completion and disconnect regression")
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
logs = project / ".godot" / "multiplayer-check" / str(args.port)
logs.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment["APPDATA"] = str(project / ".godot" / "test-user")
processes = []
try:
    for role, flags in [("head", ["--host", "--autostart"]),
                        ("hands", ["--join=127.0.0.1"]),
                        ("wheel", ["--join=127.0.0.1"])]:
        output = (logs / (role + ".log")).open("w")
        command = [args.godot, *([] if args.graphical else ["--headless"]), "--path", str(project), "--script",
                   "res://tests/network_level_one.gd", "--", *flags, f"--port={args.port}", *(["--boot-only"] if args.boot_only else []), *(["--finish-only"] if args.finish_only else [])]
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                   env=environment, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        processes.append((role, process, output))
        time.sleep(2)
    deadline = time.monotonic() + 305
    while any(process.poll() is None for _, process, _ in processes):
        if time.monotonic() > deadline:
            raise TimeoutError("Three-client level run timed out. Inspect " + str(logs))
        time.sleep(0.5)
    failed = False
    for role, process, output in processes:
        output.close()
        text = (logs / (role + ".log")).read_text(errors="replace")
        passed = process.returncode == 0 and "NETWORK PASS" in text and "ERROR:" not in text
        print(f"{'PASS' if passed else 'FAIL'}: {role} — exit {process.returncode}", flush=True)
        print(text[-1200:], flush=True)
        failed |= not passed
    raise SystemExit(1 if failed else 0)
finally:
    for _, process, output in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        output.close()
