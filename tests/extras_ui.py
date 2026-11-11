#!/usr/bin/env python3
"""Exercise Add Language with a local registry fixture through the real Extras UI."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

# Only the external registry is a fixture; the editor, wizard and installer are real.
source = Path(__file__).resolve().parents[1]
configuration = Path(tempfile.mkdtemp(prefix='uzume-extras-config-')) / 'editor'
shutil.copytree(source / 'editor', configuration)
registry = json.dumps([dict(name='gopls', languages=['Go'], categories=['LSP'],
                            source={'id':'pkg:golang/golang.org/x/tools/gopls@v0.23.0'},
                            bin={'gopls':'golang:gopls'}, neovim={'lspconfig':'gopls'})])
lock = json.loads((configuration / 'tools.lock.json').read_text())
lock['registry']['sha256'] = hashlib.sha256(registry.encode()).hexdigest()
(configuration / 'tools.lock.json').write_text(json.dumps(lock))
os.environ['UZUME_TEST_CONFIG'] = str(configuration)
from agent_harness import *

def picker(): return 'Snacks.picker.get()[1]'
def idle(): wait(lambda: not js(picker()+':is_active()'))
def select(query):
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys(query); idle(); keys('<CR>')
try:
    wait(lambda: lua('vim.v.vim_did_enter') == '1')
    directory = data / 'mason/registries/github/mason-org/mason-registry'
    directory.mkdir(parents=True)
    (directory / 'registry.json').write_text(registry)
    # Already-installed external executable: enabling must not download anything.
    executable = fixtures / 'gopls'
    executable.write_text('#!/bin/sh\nexit 0\n'); executable.chmod(0o755)
    keys(' l')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    keys('<C-a>')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_input')
    keys('go'); keys('<CR>')
    select('gopls')
    select('No formatter')
    select('Create disabled')
    wait(lambda: lua('vim.bo.filetype') == 'snacks_picker_input')
    path = root / 'config/uzume-user/languages/go.json'
    wait(path.exists)
    saved = json.loads(path.read_text())
    assert saved['servers'][0]['version'] == 'v0.23.0', saved
    assert saved['prerequisites'] == ['Go toolchain on PATH'], saved
    assert js('require("uzume.editor.extras").desired["user:go"]') is False
    for columns in (80, 150):
        do(f'vim.o.columns={columns}; vim.api.nvim_exec_autocmds("VimResized",{{}})')
        time.sleep(.2)
        preview = js(picker()+'.preview.win.win')
        assert js('vim.wo['+str(preview)+'].wrap'), 'Details must wrap in narrow menus'
    keys('Go'); idle()
    assert any(x.get('id') == 'user:go' for x in js(picker()+':items()'))
    keys('<CR>'); keys('<C-s>')
    wait(lambda: (data / 'extras.json').exists())
    assert json.loads((data / 'extras.json').read_text())['enabled']['user:go'] is True
    assert js('require("uzume.editor.extras").active["user:go"]') is False, 'Activation must wait for restart'
    keys(' l'); keys('Go'); idle(); keys('<C-e>')
    wait(lambda: lua('vim.api.nvim_buf_get_name(0)') == str(path))
    original = path.read_text()
    # Exclusive creation must not replace a customization.
    assert js('(function() local ok = pcall(require("uzume.extras.packs").create,"go",vim.json.decode(table.concat(vim.fn.readfile('+json.dumps(str(path))+'),"\\n"))); return ok end)()') is False
    assert path.read_text() == original
    print('PASS: Add Language wizard, registry pins/prerequisites, disabled creation, enable/install/save and external edit path')
finally:
    if proc.poll() is None:
        try: do('vim.cmd("qa!")')
        except RuntimeError: pass
        proc.wait(timeout=10)
    print('Artifacts:', root)
