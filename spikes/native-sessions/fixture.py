"""SPIKE: local simulated agent. stdin controls state; JSON exposes evidence."""
import argparse
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("--token", required=True)
parser.add_argument("--state")
parser.add_argument("--name", default="worker")
parser.add_argument("--worker", action="store_true")
args = parser.parse_args()
running = True


def stop(_sig, _frame):
    global running
    running = False


for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
    signal.signal(sig, stop)

if args.worker:
    while running:
        time.sleep(0.1)
    sys.exit(0)

child = subprocess.Popen(
    [sys.executable, __file__, "--worker", "--token", args.token],
    stdin=subprocess.DEVNULL,
)
state = {
    "pid": os.getpid(), "child": child.pid, "state": "working", "tick": 0,
    "since": time.time(), "reason": "Preparing a simulated change", "name": args.name,
}
path = Path(args.state)


def save():
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(path)


def transition(value, reason):
    state.update(state=value, reason=reason, since=time.time())
    print(f"\n  {value.upper()}  {reason}\n", flush=True)


save()
print(f"\033[38;2;235;188;186m  {args.name} · SIMULATED AGENT\033[0m", flush=True)
print(f"  PID {state['pid']}  worker {child.pid}", flush=True)
print("  w = input needed · b = blocked · r = review ready", flush=True)
print("  c = continue · x = fail · q = stop (press Enter)", flush=True)
print("  F1 help · F2 next pane · F6 next session", flush=True)
last = time.monotonic()
try:
    while running:
        ready, _, _ = select.select([sys.stdin], [], [], 0.15)
        if ready:
            command = sys.stdin.readline()
            if not command:
                break
            command = command.strip().lower()
            if command == "w":
                transition("waiting", "Choose the API naming before I continue")
            elif command == "b":
                transition("blocked", "A fixture dependency needs your decision")
            elif command == "r":
                transition("review", "Changes are ready for your review")
            elif command == "x":
                transition("failed", "Simulated check failed; inspect the output")
            elif command == "c":
                transition("working", "Continuing after your instruction")
            elif command == "q":
                break
            else:
                print("  Use w / b / r / c / x / q, then Enter.", flush=True)
            save()
        if time.monotonic() - last >= 1:
            state["tick"] += 1
            if state["state"] == "working":
                print(f"  [{state['tick']:04}] working · worker {child.pid} · {args.name}", flush=True)
            save()
            last = time.monotonic()
finally:
    child.terminate()
    try:
        child.wait(timeout=1)
    except subprocess.TimeoutExpired:
        child.kill()
        child.wait()
    state["state"] = "stopped"
    save()
