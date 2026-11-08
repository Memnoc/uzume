"""Process metadata: track owned descendants without reading argv."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def snapshot():
    result = subprocess.run(
        ["ps", "-axo", "pid=,ppid=,lstart="], capture_output=True, text=True
    )
    if result.returncode:
        raise RuntimeError("Process inspection unavailable; cannot supervise agents")
    rows = {}
    for line in result.stdout.splitlines():
        fields = line.split(None, 2)
        if len(fields) == 3:
            rows[int(fields[0])] = {"parent": int(fields[1]), "started": fields[2]}
    return rows


def descendants(rows, owner, known):
    alive = {pid for pid, started in known.items() if rows.get(pid, {}).get("started") == started}
    alive.add(owner)
    while True:
        found = {pid for pid, item in rows.items() if item["parent"] in alive}
        if found <= alive:
            break
        alive |= found
    for pid in alive:
        if pid != owner and pid in rows:
            known[pid] = rows[pid]["started"]
    return known


def stop(known):
    for sig in (signal.SIGTERM, signal.SIGKILL):
        rows = snapshot()
        for pid, started in known.items():
            if rows.get(pid, {}).get("started") == started:
                try:
                    os.kill(pid, sig)
                except ProcessLookupError:
                    pass
        if sig == signal.SIGTERM:
            time.sleep(0.4)


def atomic(path, value):
    path = Path(path)
    tmp = path.with_name(path.name + f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(value))
    tmp.replace(path)

