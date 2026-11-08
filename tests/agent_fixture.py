#!/usr/bin/env python3
"""Local CLI stand-in: no network, credentials, model calls or source edits."""
import json
import os
from pathlib import Path
import select
import tty
import signal
import subprocess
import sys
import time

root = Path(os.environ['UZUME_EVENTS']).parent
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(600)'])
(root / 'fixture.json').write_text(json.dumps({'pid': os.getpid(), 'child': child.pid, 'cwd': os.getcwd(), 'args': sys.argv[1:]}))
def interrupt(*_):
    (root / 'interrupted').write_text('yes')
signal.signal(signal.SIGINT, interrupt)
tty.setraw(sys.stdin.fileno())
while True:
    if select.select([sys.stdin], [], [], .05)[0]:
        data = os.read(sys.stdin.fileno(), 4096)
        if not data: break
        with (root / 'input.bin').open('ab') as output:
            output.write(data)
