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
parser.add_argument("--level", type=int, choices=[1,2,3], default=1)
parser.add_argument("--route", choices=["short","service"], default="short")
parser.add_argument("--resume-check", action="store_true")
parser.add_argument("--saved-complete", action="store_true")
parser.add_argument("--speed", type=float, default=1)
parser.add_argument("--order", choices=["ab","ba"], default="ab")
parser.add_argument("--transition", action="store_true", help="Verify Level 1 to Level 2 session handoff")
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
        script = "res://tests/network_transition.gd" if args.transition else f"res://tests/network_level_{'three' if args.level==3 else ('two' if args.level==2 else 'one')}.gd"
        if args.resume_check: script = "res://tests/network_waterworks_resume.gd"
        command = [args.godot, *([] if args.graphical else ["--headless"]), "--path", str(project), "--script",
                   script, "--", *flags, f"--port={args.port}", f"--route={args.route}", f"--order={args.order}", f"--speed={args.speed}", "--no-save", *(["--saved-complete"] if args.saved_complete else []), *(["--transition-three"] if args.transition and args.level==3 else []), *(["--boot-only"] if args.boot_only else []), *(["--finish-only"] if args.finish_only else [])]
        process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                   env=environment, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        processes.append((role, process, output))
        time.sleep(2)
    deadline = time.monotonic() + (1400 if args.level==3 else (465 if args.level==2 else 305))
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
