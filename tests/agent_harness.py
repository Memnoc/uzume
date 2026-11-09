#!/usr/bin/env python3
"""Run with python3 tests/agents.py. Uses installed pinned packages, isolated state.
Exercises the actual editor/PTY, four mock CLIs and real disposable Git worktrees.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pty
import shutil
import struct
import sys
import subprocess
import tempfile
import termios
import threading
import time

REPO = Path(__file__).resolve().parents[1]
NVIM = os.environ.get('UZUME_TEST_NVIM', shutil.which('nvim'))
BUNDLE = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'ai-nvim/releases'
root = Path(tempfile.mkdtemp(prefix='uzume-agents-')).resolve()
project = root / 'project with spaces'
project.mkdir()
def git(*args):
    return subprocess.check_output(['git', '-C', str(project), *args], text=True).strip()
git('init', '-q')
(project / 'example.txt').write_text('base\n')
(project / 'z-extra.txt').write_text('extra\n')
git('add', '.')
git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'base')
(project / 'example.txt').write_text('uncommitted source\n')
config = root / 'config/ai-nvim'
config.parent.mkdir()
config.symlink_to(REPO / 'editor')
data = root / 'data/ai-nvim'
data.mkdir(parents=True)
(data / 'releases').symlink_to(BUNDLE)
fixtures = root / 'bin'
fixtures.mkdir()
for name in ('codex', 'claude'):
    path = fixtures / name
    shutil.copy(REPO / 'tests/agent_fixture.py', path)
    path.chmod(0o755)
env = dict(os.environ, NVIM_APPNAME='ai-nvim', TERM='xterm-256color',
           XDG_CONFIG_HOME=str(root / 'config'), XDG_DATA_HOME=str(root / 'data'),
           XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'),
           PATH=str(fixtures) + os.pathsep + os.environ['PATH'])
sock = str(root / 'nvim.sock')
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 45, 150, 0, 0))
log = (root / 'editor.log').open('wb')
proc = subprocess.Popen([NVIM, '--listen', sock, str(project / 'example.txt')], cwd=project,
                        env=env, stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
os.close(slave)
def drain():
    while True:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk: break
        log.write(chunk); log.flush()
threading.Thread(target=drain, daemon=True).start()
def lua(expr):
    response = subprocess.run([NVIM, '--clean', '--server', sock, '--remote-expr',
                               'luaeval(' + json.dumps(expr) + ')'], capture_output=True, text=True, timeout=10)
    if response.returncode: raise RuntimeError(response.stderr)
    return response.stdout.strip()
def do(code): return lua('(function() ' + code + '; return true end)()')
def js(expr): return json.loads(lua('vim.json.encode(' + expr + ')'))
def keys(text):
    lua("vim.api.nvim_input(" + json.dumps(text, ensure_ascii=False) + ")")
    time.sleep(.2)
def wait(fn):
    for _ in range(120):
        try:
            if fn(): return
        except (RuntimeError, ValueError, FileNotFoundError): pass
        time.sleep(.1)
    print('Editor diagnostics:', lua('vim.api.nvim_exec2("messages", {output=true}).output'), lua('vim.v.errmsg'))
    print('Notifications:', lua('vim.inspect(Snacks.notifier.get_history())'))
    raise AssertionError('Timed out')
def living(pid):
    response = subprocess.run(['ps', '-p', str(pid), '-o', 'stat='], capture_output=True, text=True)
    return response.returncode == 0 and not response.stdout.strip().startswith('Z')
def item(index): return js('require("uzume.agents").list()[' + str(index) + ']')
def emit(entry, event, **extra):
    event_env = dict(env, UZUME_EVENTS=entry['directory'] + '/events')
    result = subprocess.run(['python3', str(REPO / 'editor/agent/hook.py'), event],
        input=json.dumps(dict(hook_event_name=event, prompt='PRIVATE_SENTINEL', **extra)),
        capture_output=True, text=True, env=event_env, check=True)
    assert result.stdout.strip() == '{}'
