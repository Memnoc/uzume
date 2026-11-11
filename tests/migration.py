#!/usr/bin/env python3
"""Public namespace migration with real Git state and retained absolute paths."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='uzume-migration-')).resolve()
env = dict(os.environ, **{f'XDG_{key}_HOME': str(root / value) for key, value in
                        [('CONFIG', 'config'), ('DATA', 'data'), ('STATE', 'state'), ('CACHE', 'cache')]})
for kind in ('config', 'data', 'state', 'cache'):
    (root / kind).mkdir()
legacy = root / 'data/ai-nvim'
legacy.mkdir()
(root / 'config/ai-nvim').symlink_to(REPO / 'editor')
(root / 'state/ai-nvim').mkdir(); (root / 'cache/ai-nvim').mkdir()
(legacy / 'extras.json').write_text('{"version":1,"packs":{"smear":false}}\n')
(legacy / 'extras.json').chmod(0o600)
project = root / 'source'; project.mkdir()
def git(where, *args):
    return subprocess.check_output(['git', '-C', str(where), *args], text=True).strip()
git(project, 'init', '-q')
(project / 'file.txt').write_text('base\n'); git(project, 'add', '.')
git(project, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'base')
worktree = legacy / 'worktrees/retained'
git(project, 'worktree', 'add', '-qb', 'retained', str(worktree))
(worktree / 'file.txt').write_text('staged\n'); git(worktree, 'add', '.')
(worktree / 'file.txt').write_text('unsaved to git\n')
before = [git(worktree, *args) for args in [('rev-parse','HEAD'), ('diff','--cached'), ('diff',)]]
record = root / 'state/ai-nvim/integrations/retained.json'; record.parent.mkdir()
record.write_text(json.dumps({'record':str(record), 'state':'integrated', 'cwd':str(worktree)}))
command = ['python3', str(REPO / 'setup-editor'), '--migrate-only']
result = subprocess.run(command, env=env, capture_output=True, text=True)
assert result.returncode == 0, result.stdout + result.stderr
for kind in ('config', 'data', 'state', 'cache'):
    old, new = root / kind / 'ai-nvim', root / kind / 'uzume'
    assert old.is_symlink() and old.resolve() == new.resolve(), kind
assert (root / 'data/uzume/extras.json').stat().st_mode & 0o777 == 0o600
assert before == [git(worktree, *args) for args in [('rev-parse','HEAD'), ('diff','--cached'), ('diff',)]]
assert (root / 'data/uzume/worktrees/retained/file.txt').read_text() == 'unsaved to git\n'
assert json.loads(record.read_text())['record'] == str(record), 'Saved history must not be rewritten blindly'
subprocess.run(command, env=env, check=True, capture_output=True)
# History accessed through its new directory must still recognize its old identity.
result = subprocess.run(['python3', str(REPO / 'editor/review/integration.py')],
    input=json.dumps({'action': 'status', 'record': str(root / 'state/uzume/integrations/retained.json')}),
    capture_output=True, text=True, env=env)
assert result.returncode == 0, result.stderr
# A journaled rename with its alias missing is recoverable without moving again.
(root / 'data/ai-nvim').unlink()
subprocess.run(command, env=env, check=True, capture_output=True)
assert (root / 'data/ai-nvim').is_symlink()
# Never migrate data underneath a running editor using those XDG roots.
(root / 'state-alias').symlink_to(root / 'state', target_is_directory=True)
for editor_env in (env, dict(env, XDG_DATA_HOME=str(root / 'other-data'),
                           XDG_CONFIG_HOME=str(root / 'other-config'), XDG_CACHE_HOME=str(root / 'other-cache'),
                           XDG_STATE_HOME=str(root / 'state-alias'))):
    editor = subprocess.Popen(['nvim', '--headless', '-u', 'NONE', '-i', 'NONE', '-c', 'lua vim.wait(10000)', '-c', 'qa!'],
        env=dict(editor_env, NVIM_APPNAME='ai-nvim'), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(.3)
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        assert result.returncode != 0 and 'Save and close Uzume' in result.stderr, result.stdout + result.stderr
    finally:
        editor.terminate(); editor.wait(timeout=5)
# Preflight every directory before changing any, even when a later one conflicts.
collision = root / 'collision'; collision.mkdir()
conflict_env = dict(os.environ, **{f'XDG_{key}_HOME': str(collision / value) for key,value in
    [('CONFIG','config'),('DATA','data'),('STATE','state'),('CACHE','cache')]})
for kind in ('config','data','state','cache'):
    (collision / kind / 'ai-nvim').mkdir(parents=True)
(collision / 'state/uzume').mkdir()
result = subprocess.run(command, env=conflict_env, capture_output=True, text=True)
assert result.returncode != 0 and 'will not merge' in result.stderr
assert all(not (collision / kind / 'ai-nvim').is_symlink() for kind in ('config','data','state','cache'))
assert not (collision / 'data/uzume').exists()
print('PASS: namespace migration preserves Git staging, files, private modes, old absolute paths and integration history')
print('PASS: repeat/recovery works; live editors and conflicting destinations prevent mutation')
print('Artifacts:', root)
