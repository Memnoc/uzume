#!/usr/bin/env python3
"""Local CLI stand-in: no network, credentials, model calls or source edits."""
import json
import os
from pathlib import Path
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
while True:
    time.sleep(.05)
