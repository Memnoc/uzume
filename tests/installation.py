#!/usr/bin/env python3
"""Installer CLI and generated launcher, with isolated XDG state and real Neovim."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
root = Path(tempfile.mkdtemp(prefix='uzume-install-test-'))
env = dict(os.environ, **{f'XDG_{key}_HOME': str(root / value) for key, value in
                        [('CONFIG', 'config'), ('DATA', 'data'), ('STATE', 'state'), ('CACHE', 'cache')]})
# This case tests registration against an installed bundle, not network delivery.
release = hashlib.sha256((REPO / 'editor/plugins.lock.json').read_bytes()).hexdigest()[:12]
installed = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'ai-nvim/releases' / release
assert (installed / '.complete').is_file(), 'Install this lockfile before the registration regression'
local = root / 'data/ai-nvim/releases' / release
local.parent.mkdir(parents=True)
local.symlink_to(installed)
launcher = root / 'bin with spaces/uzume'
shell = Path.home() / '.zshrc'
shell_before = shell.read_bytes() if shell.exists() else None
command = ['python3', str(REPO / 'setup-editor'), '--register', '--bin-dir', str(launcher.parent)]
result = subprocess.run(command, env=env, capture_output=True, text=True)
assert result.returncode == 0, result.stdout + result.stderr
assert launcher.is_file() and os.access(launcher, os.X_OK), 'Registration must create a runnable launcher'
assert (shell.read_bytes() if shell.exists() else None) == shell_before, 'Registration must not edit shell configuration'
result = subprocess.run([str(launcher), '--headless', '-i', 'NONE',
                         '+lua assert(vim.fn.exists(":UzumeMotion")==2)', '+qa'],
                        env=env, capture_output=True, text=True)
assert result.returncode == 0 and 'Error' not in result.stderr, result.stderr
first = launcher.read_bytes()
subprocess.run(command, env=env, check=True, capture_output=True)
assert launcher.read_bytes() == first, 'Repeat registration must be stable'
launcher.write_text('#!/bin/sh\nprintf unrelated\n')
result = subprocess.run(command, env=env, capture_output=True, text=True)
assert result.returncode != 0 and 'unrelated launcher' in result.stderr
assert launcher.read_text() == '#!/bin/sh\nprintf unrelated\n'
launcher.unlink()
config = root / 'config/ai-nvim'
config.unlink()
config.mkdir()
(config / 'init.lua').write_text('-- unrelated config\n')
result = subprocess.run(command, env=env, capture_output=True, text=True)
assert result.returncode != 0 and 'existing configuration' in result.stderr
assert (config / 'init.lua').read_text() == '-- unrelated config\n'
# Incomplete or foreign bundles are refused rather than silently reused/replaced.
local.unlink()
local.mkdir()
(local / '.complete').write_bytes((installed / '.complete').read_bytes())
(local / '.platform').write_text('other-os-other-cpu\n')
plain = ['python3', str(REPO / 'setup-editor')]
result = subprocess.run(plain, env=env, capture_output=True, text=True)
assert result.returncode != 0 and 'another platform' in result.stderr
assert (local / '.platform').read_text() == 'other-os-other-cpu\n'
(local / '.complete').unlink()
result = subprocess.run(plain, env=env, capture_output=True, text=True)
assert result.returncode != 0 and 'Incomplete bundle' in result.stderr
assert (local / '.platform').exists(), 'An incomplete bundle needs inspection, not automatic deletion'
result = subprocess.run(plain + ['--cc', 'uzume-missing-compiler-fixture'], env=env, capture_output=True, text=True)
assert result.returncode != 0 and 'Missing prerequisites' in result.stderr
print('PASS: generic registration, repeat install, launcher and unrelated-config protection without shell changes')
print('PASS: foreign/incomplete bundles and missing prerequisites are refused clearly')
print('Artifacts:', root)
